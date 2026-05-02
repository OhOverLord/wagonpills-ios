import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol ReminderRepository: Sendable {
    func fetchRules(medicationId: Int64) async throws -> [ReminderRule]
    func createRule(medicationId: Int64, _ request: ReminderRuleCreateRequest) async throws -> ReminderRule
    func updateRule(medicationId: Int64, ruleId: Int64, _ request: ReminderRuleUpdateRequest) async throws -> ReminderRule
    func deleteRule(medicationId: Int64, ruleId: Int64) async throws
    func addTime(medicationId: Int64, ruleId: Int64, time: DateComponents) async throws -> ReminderTime
    func deleteTime(medicationId: Int64, ruleId: Int64, timeId: Int64) async throws
}

// MARK: - Narrow client protocol

protocol ReminderClient: Sendable {
    func getRules(medicationId: Int64) async throws -> Operations.GetByMedication.Output
    func createRule(
        medicationId: Int64,
        _ body: Components.Schemas.CreateReminderRuleRequest
    ) async throws -> Operations.Create5.Output
    func updateRule(
        medicationId: Int64,
        ruleId: Int64,
        _ body: Components.Schemas.UpdateReminderRuleRequest
    ) async throws -> Operations.Update4.Output
    func deleteRule(medicationId: Int64, ruleId: Int64) async throws -> Operations.Delete4.Output
    func getTimes(medicationId: Int64, ruleId: Int64) async throws -> Operations.GetByRule.Output
    func createTime(
        medicationId: Int64,
        ruleId: Int64,
        _ body: Components.Schemas.CreateReminderTimeRequest
    ) async throws -> Operations.Create6.Output
    func deleteTime(medicationId: Int64, ruleId: Int64, timeId: Int64) async throws -> Operations.Delete5.Output
}

extension APIClient: ReminderClient {
    func getRules(medicationId: Int64) async throws -> Operations.GetByMedication.Output {
        try await client.getByMedication(path: .init(medicationId: medicationId))
    }

    func createRule(
        medicationId: Int64,
        _ body: Components.Schemas.CreateReminderRuleRequest
    ) async throws -> Operations.Create5.Output {
        try await client.create5(path: .init(medicationId: medicationId), body: .json(body))
    }

    func updateRule(
        medicationId: Int64,
        ruleId: Int64,
        _ body: Components.Schemas.UpdateReminderRuleRequest
    ) async throws -> Operations.Update4.Output {
        try await client.update4(path: .init(medicationId: medicationId, ruleId: ruleId), body: .json(body))
    }

    func deleteRule(medicationId: Int64, ruleId: Int64) async throws -> Operations.Delete4.Output {
        try await client.delete4(path: .init(medicationId: medicationId, ruleId: ruleId))
    }

    func getTimes(medicationId: Int64, ruleId: Int64) async throws -> Operations.GetByRule.Output {
        try await client.getByRule(path: .init(medicationId: medicationId, ruleId: ruleId))
    }

    func createTime(
        medicationId: Int64,
        ruleId: Int64,
        _ body: Components.Schemas.CreateReminderTimeRequest
    ) async throws -> Operations.Create6.Output {
        try await client.create6(path: .init(medicationId: medicationId, ruleId: ruleId), body: .json(body))
    }

    func deleteTime(
        medicationId: Int64, ruleId: Int64, timeId: Int64
    ) async throws -> Operations.Delete5.Output {
        try await client.delete5(path: .init(medicationId: medicationId, ruleId: ruleId, timeId: timeId))
    }
}

// MARK: - Live implementation

final class LiveReminderRepository: ReminderRepository {
    private let apiClient: any ReminderClient
    private let cache: any CacheStore
    private let decoder: JSONDecoder

    init(apiClient: any ReminderClient, cache: any CacheStore) {
        self.apiClient = apiClient
        self.cache = cache
        let jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { codingDecoder in
            let container = try codingDecoder.singleValueContainer()
            let string = try container.decode(String.self)
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: string) { return date }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = jsonDecoder
    }

    private func cacheKey(for medicationId: Int64) -> String { "reminders.\(medicationId)" }

    func fetchRules(medicationId: Int64) async throws -> [ReminderRule] {
        let key = cacheKey(for: medicationId)
        let cached = cache.load([ReminderRule].self, forKey: key)

        do {
            let fresh = try await loadRulesFromNetwork(medicationId: medicationId)
            cache.save(fresh, forKey: key)
            return fresh
        } catch let error as APIError {
            if let cached { return cached }
            throw error
        } catch {
            if let cached { return cached }
            throw APIError.from(error)
        }
    }

    func createRule(medicationId: Int64, _ request: ReminderRuleCreateRequest) async throws -> ReminderRule {
        let output = try await apiClient.createRule(medicationId: medicationId, request.toDTO())
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let rule = try decodeRule(from: data, times: [])
            cache.remove(forKey: cacheKey(for: medicationId))
            return rule
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func updateRule(medicationId: Int64, ruleId: Int64, _ request: ReminderRuleUpdateRequest) async throws -> ReminderRule {
        let output = try await apiClient.updateRule(medicationId: medicationId, ruleId: ruleId, request.toDTO())
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let rule = try decodeRule(from: data, times: [])
            cache.remove(forKey: cacheKey(for: medicationId))
            return rule
        case .undocumented(let status, _):
            throw status == 404 ? APIError.notFound : APIError.server(status: status)
        }
    }

    func deleteRule(medicationId: Int64, ruleId: Int64) async throws {
        let output = try await apiClient.deleteRule(medicationId: medicationId, ruleId: ruleId)
        switch output {
        case .ok:
            cache.remove(forKey: cacheKey(for: medicationId))
        case .undocumented(let status, _):
            throw status == 404 ? APIError.notFound : APIError.server(status: status)
        }
    }

    func addTime(medicationId: Int64, ruleId: Int64, time: DateComponents) async throws -> ReminderTime {
        let timeStr = String(format: "%02d:%02d:00", time.hour ?? 0, time.minute ?? 0)
        let body = Components.Schemas.CreateReminderTimeRequest(timeOfDay: timeStr)
        let output = try await apiClient.createTime(medicationId: medicationId, ruleId: ruleId, body)
        switch output {
        case .created(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            let reminderTime = try decodeTime(from: data)
            cache.remove(forKey: cacheKey(for: medicationId))
            return reminderTime
        case .notFound:
            throw APIError.notFound
        case .undocumented(let status, _):
            throw APIError.server(status: status)
        }
    }

    func deleteTime(medicationId: Int64, ruleId: Int64, timeId: Int64) async throws {
        let output = try await apiClient.deleteTime(medicationId: medicationId, ruleId: ruleId, timeId: timeId)
        switch output {
        case .ok:
            cache.remove(forKey: cacheKey(for: medicationId))
        case .undocumented(let status, _):
            throw status == 404 ? APIError.notFound : APIError.server(status: status)
        }
    }
}

// MARK: - Private helpers

private extension LiveReminderRepository {
    func loadRulesFromNetwork(medicationId: Int64) async throws -> [ReminderRule] {
        let output = try await apiClient.getRules(medicationId: medicationId)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 10_485_760)
            let ruleDTOs = try decodeRuleList(from: data)
            return try await withThrowingTaskGroup(of: ReminderRule.self) { group in
                for ruleDTO in ruleDTOs {
                    group.addTask {
                        guard let ruleId = ruleDTO.id else { throw APIError.decoding }
                        let times = try await self.loadTimesFromNetwork(medicationId: medicationId, ruleId: ruleId)
                        return try ReminderRule.from(ruleDTO, times: times)
                    }
                }
                var rules: [ReminderRule] = []
                for try await rule in group { rules.append(rule) }
                return rules.sorted { $0.id < $1.id }
            }
        case .undocumented(let status, _):
            throw status == 401 ? APIError.unauthorized : APIError.server(status: status)
        }
    }

    func loadTimesFromNetwork(medicationId: Int64, ruleId: Int64) async throws -> [ReminderTime] {
        let output = try await apiClient.getTimes(medicationId: medicationId, ruleId: ruleId)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_024_000)
            return try decodeTimeList(from: data)
        case .undocumented(let status, _):
            throw status == 401 ? APIError.unauthorized : APIError.server(status: status)
        }
    }

    func decodeRuleList(from data: Data) throws -> [Components.Schemas.ReminderRuleResponse] {
        do {
            return try decoder.decode([Components.Schemas.ReminderRuleResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func decodeRule(from data: Data, times: [ReminderTime]) throws -> ReminderRule {
        let dto: Components.Schemas.ReminderRuleResponse
        do {
            dto = try decoder.decode(Components.Schemas.ReminderRuleResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try ReminderRule.from(dto, times: times)
    }

    func decodeTimeList(from data: Data) throws -> [ReminderTime] {
        let dtos: [Components.Schemas.ReminderTimeResponse]
        do {
            dtos = try decoder.decode([Components.Schemas.ReminderTimeResponse].self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try dtos.map { try ReminderTime.from($0) }
    }

    func decodeTime(from data: Data) throws -> ReminderTime {
        let dto: Components.Schemas.ReminderTimeResponse
        do {
            dto = try decoder.decode(Components.Schemas.ReminderTimeResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        return try ReminderTime.from(dto)
    }
}
