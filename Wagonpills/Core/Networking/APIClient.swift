import Foundation
import OpenAPIRuntime
import OpenAPIURLSession

// Only let properties after init — safe to mark Sendable.
final class APIClient: @unchecked Sendable {
    let client: Client

    init(tokenStore: any TokenStore, authState: AuthState) {
        let baseURL = Self.loadBaseURL()
        let interceptor = AuthInterceptor(
            tokenStore: tokenStore,
            baseURL: baseURL,
            refresh: { token in
                try await AuthInterceptor.callRefreshEndpoint(
                    refreshToken: token,
                    tokenStore: tokenStore,
                    baseURL: baseURL
                )
            },
            signOut: {
                authState.signOut()
            }
        )
        client = Client(
            serverURL: baseURL,
            transport: URLSessionTransport(),
            middlewares: [interceptor]
        )
    }

    private static func loadBaseURL() -> URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String,
            let url = URL(string: raw)
        else {
            // Crash on misconfiguration — silent failure would hit an unexpected server.
            fatalError("BASE_URL missing or malformed in Info.plist — check xcconfig setup")
        }
        return url
    }
}
