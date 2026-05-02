import Foundation

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case notFound
    case conflict(message: String?)
    case validation(message: String?)
    case server(status: Int)
    case network
    case decoding
    case unexpected(String)
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return String(localized: "Invalid email or password.")
        case .forbidden:
            return String(localized: "You don't have permission to perform this action.")
        case .notFound:
            return String(localized: "The requested item could not be found.")
        case .conflict(let message):
            return message ?? String(localized: "A conflict occurred. Please try again.")
        case .validation(let message):
            return message ?? String(localized: "Please check your input and try again.")
        case .server(let status):
            return String(localized: "Server error (\(status)). Please try again later.")
        case .network:
            return String(localized: "No internet connection. Please check your network.")
        case .decoding:
            return String(localized: "Unexpected response from server.")
        case .unexpected(let detail):
            return String(localized: "An unexpected error occurred: \(detail)")
        }
    }
}

extension APIError {
    // Maps low-level transport errors to APIError. HTTP status mapping is done
    // in each Repository, not here, because the generated client returns typed
    // response enums rather than throwing for non-2xx status codes.
    static func from(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .timedOut,
                 .dnsLookupFailed:
                return .network
            default:
                return .network
            }
        }
        if error is DecodingError {
            return .decoding
        }
        return .unexpected(String(describing: error))
    }
}
