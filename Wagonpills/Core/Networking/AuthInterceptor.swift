import Foundation
import HTTPTypes
import OpenAPIRuntime

actor AuthInterceptor: ClientMiddleware {

    typealias RefreshAction = @Sendable (String) async throws -> TokenPair
    typealias SignOutAction = @MainActor @Sendable () -> Void

    private let tokenStore: any TokenStore
    private let baseURL: URL
    private let refreshAction: RefreshAction
    private let signOutAction: SignOutAction

    private var inflightRefresh: Task<TokenPair, Error>?

    init(
        tokenStore: any TokenStore,
        baseURL: URL,
        refresh: @escaping RefreshAction,
        signOut: @escaping SignOutAction
    ) {
        self.tokenStore = tokenStore
        self.baseURL = baseURL
        self.refreshAction = refresh
        self.signOutAction = signOut
    }

    func intercept(
        _ request: consuming HTTPRequest,
        body: consuming HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let originalRequest = request
        let isAuthPath = originalRequest.path?.hasPrefix("/api/v1/auth/") ?? false

        let bodyData: Data?
        if let body {
            bodyData = try await Data(collecting: body, upTo: 4 * 1_024 * 1_024)
        } else {
            bodyData = nil
        }

        var outgoing = originalRequest

        if !isAuthPath, let tokens = try? tokenStore.loadTokens() {
            outgoing.headerFields[.authorization] = "Bearer \(tokens.accessToken)"
        }

        let makeBody: @Sendable () -> HTTPBody? = {
            bodyData.map { HTTPBody($0) }
        }

        let (response, responseBody) = try await next(outgoing, makeBody(), baseURL)

        guard response.status.code == 401, !isAuthPath else {
            return (response, responseBody)
        }

        do {
            let newPair = try await serializedRefresh()

            var retry = originalRequest
            retry.headerFields[.authorization] = "Bearer \(newPair.accessToken)"

            let (retryResponse, retryBody) = try await next(retry, makeBody(), baseURL)

            if retryResponse.status.code == 401 {
                await signOutAction()
            }

            return (retryResponse, retryBody)
        } catch {
            await signOutAction()
            return (response, responseBody)
        }
    }

    // MARK: - Private

    private func serializedRefresh() async throws -> TokenPair {
        if let existing = inflightRefresh {
            return try await existing.value
        }

        guard let tokens = try? tokenStore.loadTokens(), !tokens.refreshToken.isEmpty else {
            throw APIError.unauthorized
        }

        let token = tokens.refreshToken

        let task = Task<TokenPair, Error> { [refreshAction] in
            try await refreshAction(token)
        }

        inflightRefresh = task
        defer { inflightRefresh = nil }

        return try await task.value
    }
}

// MARK: - Refresh endpoint helper

extension AuthInterceptor {

    static func callRefreshEndpoint(
        refreshToken: String,
        tokenStore: any TokenStore,
        baseURL: URL
    ) async throws -> TokenPair {
        let url = baseURL.appendingPathComponent("api/v1/auth/refresh")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode([
            "refreshToken": refreshToken
        ])

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw APIError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network
        }

        guard http.statusCode == 200 else {
            throw APIError.unauthorized
        }

        struct RefreshBody: Decodable {
            let token: String
            let refreshToken: String
            let email: String?
        }

        let body: RefreshBody

        do {
            body = try JSONDecoder().decode(RefreshBody.self, from: data)
        } catch {
            throw APIError.decoding
        }

        let email = body.email ?? (try? tokenStore.loadTokens())?.email ?? ""

        let newPair = TokenPair(
            accessToken: body.token,
            refreshToken: body.refreshToken,
            email: email
        )

        try tokenStore.save(newPair)

        return newPair
    }
}
