import Foundation

/// Everything the clients can throw, apart from `CancellationError` when the calling task is cancelled.
public enum CareersOrbitError: Error, Sendable, Equatable {
    /// The key is missing or is not a public `careers_pk_` key.
    case invalidPublicKey(String)
    /// The base URL or a path could not be turned into a request URL.
    case invalidURL(String)
    /// An application or sign-up was refused before it was sent, such as one without consent to the privacy notice.
    case invalidInput(String)
    /// `401`: the key was refused, revoked or has expired.
    case unauthorized(message: String)
    /// `401` from the candidate portal: the candidate's session is missing or has expired. The session store has been cleared.
    case signedOut(message: String)
    /// `404`: no such job, or it is closed, scheduled or unpublished.
    case notFound(message: String)
    /// `429`: too many requests. Wait `retryAfter` seconds before trying again.
    case rateLimited(retryAfter: TimeInterval, message: String)
    /// Any other `4xx` answer, such as `422 invalid` for a missing field.
    case http(status: Int, code: String, message: String)
    /// A `5xx` answer, after the client's retries.
    case server(status: Int, message: String)
    /// Careers Orbit could not be reached or did not answer in time, after the client's retries.
    case unavailable(message: String)
    /// The answer could not be decoded into the type asked for.
    case decoding(String)

    /// The HTTP status, when the error came from an answer.
    public var status: Int? {
        switch self {
        case .unauthorized, .signedOut: return 401
        case .notFound: return 404
        case .rateLimited: return 429
        case .http(let status, _, _), .server(let status, _): return status
        default: return nil
        }
    }

    /// The API's error code, such as `not_found` or `invalid`.
    public var code: String {
        switch self {
        case .invalidPublicKey: return "invalid_public_key"
        case .invalidURL: return "invalid_url"
        case .invalidInput: return "invalid"
        case .unauthorized, .signedOut: return "unauthorized"
        case .notFound: return "not_found"
        case .rateLimited: return "rate_limited"
        case .http(_, let code, _): return code
        case .server, .unavailable: return "unavailable"
        case .decoding: return "decoding_failed"
        }
    }
}

extension CareersOrbitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPublicKey(let message), .invalidInput(let message): return message
        case .invalidURL(let url): return "Not a valid URL: \(url)"
        case .unauthorized(let message), .signedOut(let message), .notFound(let message), .unavailable(let message):
            return message
        case .rateLimited(_, let message), .http(_, _, let message), .server(_, let message):
            return message
        case .decoding(let message): return "The answer could not be decoded: \(message)"
        }
    }
}
