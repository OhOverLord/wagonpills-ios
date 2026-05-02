import Foundation
import OpenAPIRuntime

// MARK: - Protocol

protocol AuthRepository: Sendable {
    func login(email: String, password: String) async throws -> TokenPair
    func register(email: String, password: String, preferredRegionCode: String?) async throws -> TokenPair
    func refresh(using refreshToken: String) async throws -> TokenPair
    func logout(refreshToken: String) async throws
}

// MARK: - Live implementation

struct LiveAuthRepository: AuthRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func login(email: String, password: String) async throws -> TokenPair {
        let output = try await apiClient.client.login(
            body: .json(.init(email: email, password: password))
        )
        switch output {
        case .ok(let response):  return try await tokenPair(from: try response.body.any)
        case .unauthorized:     throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.server(status: status)
        }
    }

    func register(
        email: String,
        password: String,
        preferredRegionCode: String?
    ) async throws -> TokenPair {
        let output = try await apiClient.client.register(
            body: .json(.init(email: email, password: password, preferredRegionCode: preferredRegionCode))
        )
        switch output {
        case .ok(let response):  return try await tokenPair(from: try response.body.any)
        case .badRequest:       throw APIError.validation(message: nil)
        case .conflict:         throw APIError.conflict(message: String(localized: "Email already registered."))
        case .undocumented(let status, _): throw APIError.server(status: status)
        }
    }

    func refresh(using refreshToken: String) async throws -> TokenPair {
        let output = try await apiClient.client.refresh(
            body: .json(.init(refreshToken: refreshToken))
        )
        switch output {
        case .ok(let response):  return try await tokenPair(from: try response.body.any)
        case .unauthorized:     throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.server(status: status)
        }
    }

    func logout(refreshToken: String) async throws {
        let output = try await apiClient.client.logout(
            body: .json(.init(refreshToken: refreshToken))
        )
        switch output {
        case .noContent:        return
        case .unauthorized:     throw APIError.unauthorized
        case .undocumented(let status, _): throw APIError.server(status: status)
        }
    }
}

// MARK: - Private helper

private extension LiveAuthRepository {
    // The spec uses */* content type so the generator gives us a raw HTTPBody
    // instead of a typed .json case. We decode manually here.
    func tokenPair(from body: HTTPBody) async throws -> TokenPair {
        let data = try await Data(collecting: body, upTo: 1_024_000)
        let auth: Components.Schemas.AuthResponse
        do {
            auth = try JSONDecoder().decode(Components.Schemas.AuthResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
        guard let token = auth.token, let refreshToken = auth.refreshToken else {
            throw APIError.decoding
        }
        return TokenPair(
            accessToken: token,
            refreshToken: refreshToken,
            email: auth.email ?? ""
        )
    }
}
