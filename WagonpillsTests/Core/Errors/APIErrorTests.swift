import Testing
import Foundation
@testable import Wagonpills

@Suite("APIError.from mapping")
struct APIErrorTests {

    @Test("notConnectedToInternet maps to .network")
    func notConnectedToInternet() {
        let error = URLError(.notConnectedToInternet)
        #expect(APIError.from(error) == .network)
    }

    @Test("networkConnectionLost maps to .network")
    func networkConnectionLost() {
        let error = URLError(.networkConnectionLost)
        #expect(APIError.from(error) == .network)
    }

    @Test("timedOut maps to .network")
    func timedOut() {
        let error = URLError(.timedOut)
        #expect(APIError.from(error) == .network)
    }

    @Test("DecodingError maps to .decoding")
    func decodingError() throws {
        struct Dummy: Decodable {}
        let data = Data("not json".utf8)
        let error = try #require(
            Result { try JSONDecoder().decode(Dummy.self, from: data) }.failure
        )
        #expect(APIError.from(error) == .decoding)
    }

    @Test("APIError passthrough is identity")
    func apiErrorPassthrough() {
        let original = APIError.forbidden
        #expect(APIError.from(original) == .forbidden)
    }

    @Test("Unknown error maps to .unexpected")
    func unknownError() {
        struct BogusError: Error {}
        let result = APIError.from(BogusError())
        if case .unexpected = result {
            // pass
        } else {
            Issue.record("Expected .unexpected, got \(result)")
        }
    }

    @Test("LocalizedError descriptions are non-empty")
    func localizedDescriptions() {
        let cases: [APIError] = [
            .unauthorized, .forbidden, .notFound,
            .conflict(message: nil), .conflict(message: "Email already registered"),
            .validation(message: nil), .validation(message: "Too short"),
            .server(status: 503), .network, .decoding, .unexpected("boom")
        ]
        for apiError in cases {
            #expect(apiError.errorDescription != nil)
            #expect(!(apiError.errorDescription?.isEmpty ?? true))
        }
    }
}
