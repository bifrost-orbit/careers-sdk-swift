import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct Connection: Sendable {
    static let version = "0.1.0"
    static let userAgent = "CareersOrbit-Swift/\(version)"
    private static let retryDelays: [UInt64] = [250, 750, 2000]

    let base: String
    let timeout: TimeInterval
    let retries: Int
    let session: URLSession

    init(baseURL: URL, timeout: TimeInterval, retries: Int, session: URLSession) throws {
        var trimmed = baseURL.absoluteString
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            throw CareersOrbitError.invalidURL(baseURL.absoluteString)
        }
        self.base = trimmed
        self.timeout = timeout
        self.retries = max(0, retries)
        self.session = session
    }

    static func validatePublicKey(_ key: String) throws {
        if key.isEmpty { throw CareersOrbitError.invalidPublicKey("A publicKey is required") }
        if !key.hasPrefix("careers_pk_") {
            throw CareersOrbitError.invalidPublicKey("publicKey must be a Careers Orbit public key, starting with careers_pk_")
        }
    }

    static let unreserved: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return set
    }()

    static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }

    func url(_ path: String, query: [(String, String?)] = []) throws -> URL {
        let pairs = query.compactMap { name, value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return "\(Self.encode(name))=\(Self.encode(value))"
        }
        let string = pairs.isEmpty ? base + path : "\(base)\(path)?\(pairs.joined(separator: "&"))"
        guard let url = URL(string: string) else { throw CareersOrbitError.invalidURL(string) }
        return url
    }

    func request(_ method: String, _ url: URL, headers: [String: String], body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: method == "GET" ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = body
        return request
    }

    /// Sends a request and answers with the body of a `2xx` answer. Only reads are retried.
    func send(_ request: URLRequest, onUnauthorized: (@Sendable (String) -> CareersOrbitError)? = nil) async throws -> Data {
        let attempts = request.httpMethod == "GET" ? retries : 0
        var lastError: Error = CareersOrbitError.unavailable(message: "Careers Orbit could not be reached")
        for attempt in 0...attempts {
            if attempt > 0 {
                let delay = Self.retryDelays[min(attempt - 1, Self.retryDelays.count - 1)]
                try await Task.sleep(nanoseconds: delay * 1_000_000)
            }
            let data: Data
            let response: HTTPURLResponse
            do {
                (data, response) = try await load(request)
            } catch let error as CareersOrbitError {
                lastError = error
                continue
            }
            if (200..<300).contains(response.statusCode) { return data }

            let (code, message) = Self.errorDetails(data, status: response.statusCode)
            switch response.statusCode {
            case 500...:
                lastError = CareersOrbitError.server(status: response.statusCode, message: message)
                continue
            case 401: throw onUnauthorized?(message) ?? CareersOrbitError.unauthorized(message: message)
            case 404: throw CareersOrbitError.notFound(message: message)
            case 429: throw CareersOrbitError.rateLimited(retryAfter: Self.retryAfter(response), message: message)
            default: throw CareersOrbitError.http(status: response.statusCode, code: code ?? "error", message: message)
            }
        }
        throw lastError
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(Envelope<T>.self, from: data).data
        } catch {
            throw CareersOrbitError.decoding(String(describing: error))
        }
    }

    static func json<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    static func multipart(fields: [(String, String)], files: [(String, CareersFile)]) -> (Data, String) {
        let boundary = "----careers\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()
        func quote(_ value: String) -> String {
            value.replacingOccurrences(of: "\"", with: "%22").replacingOccurrences(of: "\r", with: "%0D").replacingOccurrences(of: "\n", with: "%0A")
        }
        for (name, value) in fields {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(quote(name))\"\r\n\r\n\(value)\r\n".utf8))
        }
        for (name, file) in files {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(quote(name))\"; filename=\"\(quote(file.name))\"\r\nContent-Type: \(file.mimeType)\r\n\r\n".utf8))
            body.append(file.data)
            body.append(Data("\r\n".utf8))
        }
        body.append(Data("--\(boundary)--\r\n".utf8))
        return (body, "multipart/form-data; boundary=\(boundary)")
    }

    private func load(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CareersOrbitError.unavailable(message: "Careers Orbit did not answer over HTTP")
            }
            return (data, http)
        } catch let error as CareersOrbitError {
            throw error
        } catch {
            if Task.isCancelled { throw CancellationError() }
            if (error as? URLError)?.code == .timedOut {
                throw CareersOrbitError.unavailable(message: "Careers Orbit did not answer within \(Self.seconds(timeout))")
            }
            throw CareersOrbitError.unavailable(message: "Careers Orbit could not be reached")
        }
    }

    private static func seconds(_ value: TimeInterval) -> String {
        value.rounded() == value ? "\(Int(value))s" : "\(value)s"
    }

    private static func retryAfter(_ response: HTTPURLResponse) -> TimeInterval {
        guard let header = response.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(header), seconds > 0 else {
            return 60
        }
        return seconds
    }

    private static func errorDetails(_ data: Data, status: Int) -> (code: String?, message: String) {
        let fallback = "Careers Orbit answered \(status)"
        guard let body = try? JSONDecoder().decode(JSONValue.self, from: data), let error = body["error"] else { return (nil, fallback) }
        return (error["code"]?.stringValue, error["message"]?.stringValue ?? fallback)
    }
}

struct Envelope<T: Decodable>: Decodable {
    let data: T
}

struct ListEnvelope: Decodable {
    struct Meta: Decodable {
        let locale: String?
        let total: Int?
        let page: Int?
        let perPage: Int?
    }

    let data: [CareersJobSummary]
    let meta: Meta?
}
