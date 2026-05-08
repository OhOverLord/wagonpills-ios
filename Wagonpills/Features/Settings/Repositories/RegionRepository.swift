import Foundation
import OpenAPIRuntime

// MARK: - Repository protocol

protocol RegionRepository: Sendable {
    func fetchEnabled() async throws -> [Region]
}

// MARK: - Narrow client protocol

protocol RegionClient: Sendable {
    func getRegions(enabled: Bool?) async throws -> Operations.GetAll1.Output
}

extension APIClient: RegionClient {
    func getRegions(enabled: Bool?) async throws -> Operations.GetAll1.Output {
        try await client.getAll1(query: .init(enabled: enabled))
    }
}

// MARK: - Live implementation

final class LiveRegionRepository: RegionRepository {
    private let apiClient: any RegionClient

    init(apiClient: any RegionClient) {
        self.apiClient = apiClient
    }

    func fetchEnabled() async throws -> [Region] {
        let output = try await apiClient.getRegions(enabled: true)
        switch output {
        case .ok(let response):
            let data = try await Data(collecting: try response.body.any, upTo: 1_048_576)
            let dtos = try Self.decoder.decode([Components.Schemas.RegionResponse].self, from: data)
            return dtos.compactMap { dto in
                guard let code = dto.code, let name = dto.name, !code.isEmpty else { return nil }
                return Region(code: code, name: name, isEnabled: dto.enabled ?? true)
            }
        case .undocumented(let statusCode, _):
            if statusCode == 401 { throw APIError.unauthorized }
            throw APIError.server(status: statusCode)
        }
    }

    private static let decoder = JSONDecoder()
}

// MARK: - Preview implementation

final class PreviewRegionRepository: RegionRepository {
    static let sampleRegions: [Region] = [
        Region(code: "CZ", name: "Czech Republic", isEnabled: true),
        Region(code: "SK", name: "Slovakia", isEnabled: true),
        Region(code: "DE", name: "Germany", isEnabled: true)
    ]

    func fetchEnabled() async throws -> [Region] {
        PreviewRegionRepository.sampleRegions
    }
}
