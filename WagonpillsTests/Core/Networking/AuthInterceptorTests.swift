import Testing
import Foundation
import HTTPTypes
import OpenAPIRuntime
@testable import Wagonpills

// MARK: - Test doubles

// Sendable spy for tracking whether signOut was invoked from the interceptor.
@MainActor
final class SignOutSpy: @unchecked Sendable {
    var callCount = 0
    func call() { callCount += 1 }
}

// Simulates a sequence of (HTTPResponse, HTTPBody?) responses for mock `next` closures.
// @unchecked Sendable because it's mutated by a single-threaded test.
final class ResponseQueue: @unchecked Sendable {
    private var queue: [(HTTPResponse, HTTPBody?)]
    var requestsReceived: [HTTPRequest] = []

    init(_ responses: (HTTPResponse, HTTPBody?)...) {
        self.queue = responses
    }

    func dequeue(for request: HTTPRequest) -> (HTTPResponse, HTTPBody?) {
        requestsReceived.append(request)
        guard !queue.isEmpty else { return (HTTPResponse(status: 200), nil) }
        return queue.removeFirst()
    }
}

// MARK: - Helpers

private func makeInterceptor(
    store: MockTokenStore = MockTokenStore(),
    spy: SignOutSpy,
    refreshResult: Result<TokenPair, Error> = .success(
        TokenPair(accessToken: "new-access", refreshToken: "new-refresh", email: "u@x.com")
    )
) -> AuthInterceptor {
    AuthInterceptor(
        tokenStore: store,
        baseURL: URL(string: "http://localhost:8080")!,
        refresh: { _ in try refreshResult.get() },
        signOut: { spy.call() }
    )
}

private func request(path: String) -> HTTPRequest {
    HTTPRequest(method: .get, scheme: "http", authority: "localhost:8080", path: path)
}

// MARK: - Tests

@Suite("AuthInterceptor")
@MainActor
struct AuthInterceptorTests {

    @Test("Non-auth request receives Bearer header when tokens exist")
    func addsAuthHeader() async throws {
        let store = MockTokenStore()
        try store.save(TokenPair(accessToken: "tok-a", refreshToken: "tok-r", email: "u@x.com"))
        let spy = SignOutSpy()
        let interceptor = makeInterceptor(store: store, spy: spy)
        let queue = ResponseQueue((HTTPResponse(status: 200), nil))

        let (response, _) = try await interceptor.intercept(
            request(path: "/api/v1/medications"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "getAll_3",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        #expect(response.status.code == 200)
        let sentAuth = queue.requestsReceived.first?.headerFields[.authorization]
        #expect(sentAuth == "Bearer tok-a")
    }

    @Test("Auth endpoint request passes through without a Bearer header")
    func authEndpointSkipsHeader() async throws {
        let store = MockTokenStore()
        try store.save(TokenPair(accessToken: "tok-a", refreshToken: "tok-r", email: "u@x.com"))
        let spy = SignOutSpy()
        let interceptor = makeInterceptor(store: store, spy: spy)
        let queue = ResponseQueue((HTTPResponse(status: 200), nil))

        _ = try await interceptor.intercept(
            request(path: "/api/v1/auth/login"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "login",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        let sentAuth = queue.requestsReceived.first?.headerFields[.authorization]
        #expect(sentAuth == nil)
    }

    @Test("401 triggers refresh exactly once then retries with new token")
    func refreshOnUnauthorized() async throws {
        let store = MockTokenStore()
        try store.save(TokenPair(accessToken: "old-access", refreshToken: "old-refresh", email: "u@x.com"))
        let spy = SignOutSpy()
        let newPair = TokenPair(accessToken: "new-access", refreshToken: "new-refresh", email: "u@x.com")
        let interceptor = makeInterceptor(store: store, spy: spy, refreshResult: .success(newPair))
        let queue = ResponseQueue(
            (HTTPResponse(status: 401), nil),
            (HTTPResponse(status: 200), nil)
        )

        let (response, _) = try await interceptor.intercept(
            request(path: "/api/v1/medications"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "getAll_3",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        #expect(response.status.code == 200)
        #expect(queue.requestsReceived.count == 2)
        let retryAuth = queue.requestsReceived.last?.headerFields[.authorization]
        #expect(retryAuth == "Bearer new-access")
        #expect(spy.callCount == 0)
    }

    @Test("Retry 401 calls signOut and returns the retry response")
    func retryAlso401CallsSignOut() async throws {
        let store = MockTokenStore()
        try store.save(TokenPair(accessToken: "old", refreshToken: "old-r", email: "u@x.com"))
        let spy = SignOutSpy()
        let interceptor = makeInterceptor(store: store, spy: spy)
        let queue = ResponseQueue(
            (HTTPResponse(status: 401), nil),
            (HTTPResponse(status: 401), nil)
        )

        let (response, _) = try await interceptor.intercept(
            request(path: "/api/v1/medications"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "getAll_3",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        #expect(response.status.code == 401)
        #expect(queue.requestsReceived.count == 2)
        #expect(spy.callCount == 1)
    }

    @Test("Refresh failure calls signOut and returns original 401")
    func refreshFailureCallsSignOut() async throws {
        let store = MockTokenStore()
        try store.save(TokenPair(accessToken: "old", refreshToken: "old-r", email: "u@x.com"))
        let spy = SignOutSpy()
        let interceptor = makeInterceptor(
            store: store,
            spy: spy,
            refreshResult: .failure(APIError.unauthorized)
        )
        let queue = ResponseQueue((HTTPResponse(status: 401), nil))

        let (response, _) = try await interceptor.intercept(
            request(path: "/api/v1/medications"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "getAll_3",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        #expect(response.status.code == 401)
        #expect(queue.requestsReceived.count == 1)
        #expect(spy.callCount == 1)
    }

    @Test("401 on /auth/* endpoint does not trigger refresh")
    func authEndpoint401NoRefresh() async throws {
        let store = MockTokenStore()
        let spy = SignOutSpy()
        var refreshCalled = false
        let interceptor = AuthInterceptor(
            tokenStore: store,
            baseURL: URL(string: "http://localhost:8080")!,
            refresh: { _ in refreshCalled = true; throw APIError.unauthorized },
            signOut: { spy.call() }
        )
        let queue = ResponseQueue((HTTPResponse(status: 401), nil))

        let (response, _) = try await interceptor.intercept(
            request(path: "/api/v1/auth/refresh"),
            body: nil,
            baseURL: URL(string: "http://localhost:8080")!,
            operationID: "refresh",
            next: { req, body, url in queue.dequeue(for: req) }
        )

        #expect(response.status.code == 401)
        #expect(refreshCalled == false)
        #expect(spy.callCount == 0)
    }
}
