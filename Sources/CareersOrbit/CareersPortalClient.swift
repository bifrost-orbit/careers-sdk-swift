import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Keeps a candidate's portal session token, such as in the Keychain.
public protocol CareersSessionStore: Sendable {
    func get() -> String?
    func set(_ token: String?)
}

/// Keeps the session token in memory, for as long as the store lives.
public final class CareersMemorySession: CareersSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    public init(_ token: String? = nil) {
        self.token = token
    }

    public func get() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    public func set(_ token: String?) {
        lock.lock()
        defer { lock.unlock() }
        self.token = token
    }
}

/// The candidate portal: sign-in with an emailed code, applications, documents, offers, the talent pool,
/// a data download and requests for a correction or erasure.
///
/// Calls that change something answer with the whole portal again, so a screen can show it straight away.
///
/// ```swift
/// let portal = try CareersPortalClient(publicKey: "careers_pk_...", locale: "de")
/// try await portal.requestCode(email: "solveig@northwilds.com")
/// try await portal.signIn(email: "solveig@northwilds.com", code: "123456")
/// let me = try await portal.me()
/// ```
public final class CareersPortalClient: Sendable {
    public let apiURL: URL
    public let locale: String?
    public let session: CareersSessionStore

    private let publicKey: String?
    private let connection: Connection

    /// Creates a portal client.
    ///
    /// - Parameters:
    ///   - publicKey: A public key, starting with `careers_pk_`. Leave it out when `baseURL` is your own server, which adds the key.
    ///   - environment: Production, staging or your own address.
    ///   - baseURL: Overrides the environment's address.
    ///   - locale: The language for emails and stage names, such as `de`.
    ///   - session: Where the candidate's session token is kept. In memory by default.
    public init(
        publicKey: String? = nil,
        environment: CareersEnvironment = .production,
        baseURL: URL? = nil,
        locale: String? = nil,
        session: CareersSessionStore = CareersMemorySession(),
        timeout: TimeInterval = 5,
        retries: Int = 2,
        urlSession: URLSession = .shared
    ) throws {
        if let publicKey { try Connection.validatePublicKey(publicKey) }
        let connection = try Connection(baseURL: baseURL ?? environment.baseURL, timeout: timeout, retries: retries, session: urlSession)
        self.connection = connection
        self.apiURL = URL(string: connection.base)!
        self.publicKey = publicKey
        self.locale = locale
        self.session = session
    }

    /// Emails a six-digit code if the address has applied. Answers the same either way.
    public func requestCode(email: String) async throws {
        _ = try await call("POST", "code", body: CodeBody(email: email, locale: locale))
    }

    /// Checks the code and keeps the session token, which lasts two hours. Answers with the token.
    @discardableResult
    public func signIn(email: String, code: String) async throws -> String? {
        let data = try await call("POST", "session", body: SessionBody(email: email, code: code, locale: locale))
        let token = try Connection.decode(SessionAnswer.self, from: data).token
        session.set(token)
        return token
    }

    public func signOut() async {
        _ = try? await call("DELETE", "session")
        session.set(nil)
    }

    /// The candidate's applications, offers, talent pool and requests, or `nil` when signed out.
    public func me() async throws -> CareersPortal? {
        let data: Data
        do {
            data = try await call("GET", "me")
        } catch CareersOrbitError.signedOut {
            return nil
        }
        let portal = try Connection.decode(CareersPortal?.self, from: data)
        if portal == nil { session.set(nil) }
        return portal
    }

    public func withdraw(applicationId: String, reason: String? = nil) async throws -> CareersPortal {
        try await view("POST", "applications/\(Connection.encode(applicationId))/withdraw", body: ReasonBody(reason: reason))
    }

    /// Adds a PDF or Word document, up to 10 MB, to an open application.
    public func addDocument(applicationId: String, file: CareersFile) async throws -> CareersPortal {
        let (body, type) = Connection.multipart(fields: [], files: [("file", file)])
        let request = connection.request("POST", try url("applications/\(Connection.encode(applicationId))/documents"), headers: headers(["Content-Type": type]), body: body)
        return try Connection.decode(CareersPortal.self, from: await send(request))
    }

    /// The candidate's data as JSON, with links to their files that work for 15 minutes.
    public func exportData() async throws -> Data {
        try await call("GET", "export")
    }

    public func askToErase() async throws -> CareersPortal {
        try await view("POST", "requests", body: RequestBody(kind: "erasure", detail: nil))
    }

    public func askToCorrect(_ detail: String) async throws -> CareersPortal {
        try await view("POST", "requests", body: RequestBody(kind: "correction", detail: detail))
    }

    /// Notes that the candidate has seen their open offers.
    public func openOffers() async throws -> CareersPortal {
        try await view("POST", "offers")
    }

    /// Accepts an offer with a simple electronic signature.
    public func acceptOffer(_ offerId: String, acceptance: CareersOfferAcceptance) async throws -> CareersPortal {
        try await view("POST", "offers/\(Connection.encode(offerId))/answer", body: AcceptBody(name: acceptance.name, consent: acceptance.consent, documentHash: acceptance.documentHash))
    }

    public func declineOffer(_ offerId: String, reason: String? = nil) async throws -> CareersPortal {
        try await view("POST", "offers/\(Connection.encode(offerId))/answer", body: DeclineBody(reason: reason))
    }

    /// The offer as a PDF, signed once it has been accepted.
    public func offerPDF(_ offerId: String) async throws -> Data {
        try await call("GET", "offers/\(Connection.encode(offerId))/pdf")
    }

    /// Stops text messages on one channel, `sms` or `whatsapp`.
    public func stopTexts(_ channel: String) async throws -> CareersPortal {
        try await view("POST", "texting/stop", body: ChannelBody(channel: channel))
    }

    public func leaveTalentPool() async throws -> CareersPortal {
        try await view("POST", "talent-pool/leave")
    }

    public func stayInTalentPool() async throws -> CareersPortal {
        try await view("POST", "talent-pool/stay")
    }

    // MARK: - Internals

    private func url(_ path: String) throws -> URL {
        try connection.url("/portal/\(path)", query: [("locale", locale)])
    }

    private func headers(_ extra: [String: String] = [:]) -> [String: String] {
        var headers = ["Accept": "application/json"]
        if let publicKey { headers["Authorization"] = "Bearer \(publicKey)" }
        if let token = session.get(), !token.isEmpty { headers["X-Careers-Session"] = token }
        return headers.merging(extra) { $1 }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let session = self.session
        return try await connection.send(request) { message in
            session.set(nil)
            return .signedOut(message: message)
        }
    }

    private func call(_ method: String, _ path: String) async throws -> Data {
        let body: Data? = method == "POST" ? Data("{}".utf8) : nil
        let extra = body == nil ? [:] : ["Content-Type": "application/json"]
        return try await send(connection.request(method, try url(path), headers: headers(extra), body: body))
    }

    private func call<Body: Encodable>(_ method: String, _ path: String, body: Body) async throws -> Data {
        try await send(connection.request(method, try url(path), headers: headers(["Content-Type": "application/json"]), body: try Connection.json(body)))
    }

    private func view(_ method: String, _ path: String) async throws -> CareersPortal {
        try Connection.decode(CareersPortal.self, from: await call(method, path))
    }

    private func view<Body: Encodable>(_ method: String, _ path: String, body: Body) async throws -> CareersPortal {
        try Connection.decode(CareersPortal.self, from: await call(method, path, body: body))
    }
}

private struct CodeBody: Encodable {
    let email: String
    let locale: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(locale, forKey: .locale)
    }

    private enum CodingKeys: String, CodingKey { case email, locale }
}

private struct SessionBody: Encodable {
    let email: String
    let code: String
    let locale: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(email, forKey: .email)
        try container.encode(code, forKey: .code)
        try container.encode(locale, forKey: .locale)
    }

    private enum CodingKeys: String, CodingKey { case email, code, locale }
}

private struct ChannelBody: Encodable {
    let channel: String
}

private struct SessionAnswer: Decodable {
    let token: String?
}

private struct ReasonBody: Encodable {
    let reason: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reason, forKey: .reason)
    }

    private enum CodingKeys: String, CodingKey { case reason }
}

private struct RequestBody: Encodable {
    let kind: String
    let detail: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(detail, forKey: .detail)
    }

    private enum CodingKeys: String, CodingKey { case kind, detail }
}

private struct AcceptBody: Encodable {
    let action = "accept"
    let name: String
    let consent: Bool
    let documentHash: String
}

private struct DeclineBody: Encodable {
    let action = "decline"
    let reason: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(reason, forKey: .reason)
    }

    private enum CodingKeys: String, CodingKey { case action, reason }
}
