import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Reads live jobs from the Careers Orbit delivery API and sends applications and talent pool sign-ups.
///
/// ```swift
/// let careers = try CareersOrbitClient(publicKey: "careers_pk_...", locale: "de")
/// let job = try await careers.job("mountain-guide-lofoten")
/// ```
public final class CareersOrbitClient: Sendable {
    /// The SDK's version, sent in the `User-Agent` header.
    public static let version = Connection.version

    /// The delivery API address, such as `https://api.bifrostorbit.com/careers/v1`.
    public let apiURL: URL
    public let locale: String?
    public let timeout: TimeInterval
    public let retries: Int

    private let publicKey: String
    private let connection: Connection

    /// Creates a client.
    ///
    /// - Parameters:
    ///   - publicKey: A public key, starting with `careers_pk_`, from API keys in Careers Orbit.
    ///   - environment: Production, staging or your own address.
    ///   - baseURL: Overrides the environment's address, such as `https://api.bifrostorbit.com/careers/v1`.
    ///   - locale: The language to read when a call does not name one, such as `de`.
    ///   - timeout: Seconds to wait for each attempt. Default 5.
    ///   - retries: How many times to retry a read after a failed connection or a `5xx` answer. Default 2. Applications are sent once.
    ///   - session: The `URLSession` to use.
    public init(
        publicKey: String,
        environment: CareersEnvironment = .production,
        baseURL: URL? = nil,
        locale: String? = nil,
        timeout: TimeInterval = 5,
        retries: Int = 2,
        session: URLSession = .shared
    ) throws {
        try Connection.validatePublicKey(publicKey)
        let connection = try Connection(baseURL: baseURL ?? environment.baseURL, timeout: timeout, retries: retries, session: session)
        self.connection = connection
        self.apiURL = URL(string: connection.base)!
        self.publicKey = publicKey
        self.locale = locale
        self.timeout = timeout
        self.retries = connection.retries
    }

    // MARK: - Jobs

    /// Live jobs, newest first, filtered and paged.
    public func jobs(_ query: CareersJobQuery = .init()) async throws -> CareersJobList {
        let locale = query.locale ?? self.locale
        let data = try await read("/jobs", query: [
            ("locale", locale),
            ("department", query.department),
            ("location", query.location),
            ("remote", query.remote),
            ("type", query.type),
            ("q", query.query),
            ("page", query.page.map(String.init)),
            ("perPage", query.perPage.map(String.init)),
        ])
        let body: ListEnvelope
        do {
            body = try JSONDecoder().decode(ListEnvelope.self, from: data)
        } catch {
            throw CareersOrbitError.decoding(String(describing: error))
        }
        return CareersJobList(
            items: body.data,
            locale: body.meta?.locale ?? locale ?? "en",
            total: body.meta?.total ?? body.data.count,
            page: body.meta?.page ?? 1,
            perPage: body.meta?.perPage ?? body.data.count
        )
    }

    /// One live job. Throws ``CareersOrbitError/notFound(message:)`` when it is closed or gone.
    public func job(_ slug: String, locale: String? = nil) async throws -> CareersJob {
        try Connection.decode(CareersJob.self, from: await read("/jobs/\(Connection.encode(slug))", query: [("locale", locale ?? self.locale)]))
    }

    /// One live job, or `nil` when it is closed or gone.
    public func findJob(_ slug: String, locale: String? = nil) async throws -> CareersJob? {
        do {
            return try await job(slug, locale: locale)
        } catch CareersOrbitError.notFound {
            return nil
        }
    }

    // MARK: - Site

    /// The career site's name, introduction, logo, colours, languages and current privacy notice.
    public func site(locale: String? = nil) async throws -> CareersSite {
        try Connection.decode(CareersSite.self, from: await read("/site", query: [("locale", locale ?? self.locale)]))
    }

    /// Departments, locations, job types and workplaces that have live jobs, with counts.
    public func filters(locale: String? = nil) async throws -> CareersFilters {
        try Connection.decode(CareersFilters.self, from: await read("/filters", query: [("locale", locale ?? self.locale)]))
    }

    /// Every live job with its address in each language.
    public func sitemap() async throws -> [CareersSitemapEntry] {
        try Connection.decode([CareersSitemapEntry].self, from: await read("/sitemap", query: [("locale", locale)]))
    }

    // MARK: - Applications

    /// Where applications for a job are sent.
    public func applicationURL(slug: String) throws -> URL {
        try connection.url("/jobs/\(Connection.encode(slug))/applications")
    }

    /// Sends an application. A second application to the same job from the same email updates the first.
    public func apply(to slug: String, _ application: CareersApplication, files: CareersApplicationFiles = .init()) async throws -> CareersApplicationResult {
        guard application.privacyAccepted else {
            throw CareersOrbitError.invalidInput("An application needs privacyAccepted: true, once the candidate has agreed to the privacy notice")
        }
        let data = try String(decoding: Connection.json(application), as: UTF8.self)
        var uploads: [(String, CareersFile)] = []
        if let cv = files.cv { uploads.append(("cv", cv)) }
        for id in files.questions.keys.sorted() {
            uploads.append(("file:\(id)", files.questions[id]!))
        }
        let (body, type) = Connection.multipart(fields: [("data", data)], files: uploads)
        let request = connection.request("POST", try applicationURL(slug: slug), headers: headers(["Content-Type": type]), body: body)
        return try Connection.decode(CareersApplicationResult.self, from: await connection.send(request))
    }

    /// Keeps someone's details for future jobs, and with `jobAlerts` emails them when one opens.
    public func joinTalentPool(_ signup: CareersTalentPoolSignup) async throws {
        guard signup.privacyAccepted else {
            throw CareersOrbitError.invalidInput("A sign-up needs privacyAccepted: true, once the person has agreed to the privacy notice")
        }
        let request = connection.request("POST", try connection.url("/talent-pool"), headers: headers(["Content-Type": "application/json"]), body: try Connection.json(signup))
        _ = try await connection.send(request)
    }

    /// Counts a view of a job or the start of an application, for the reports' channels. Carries nothing about the person, and never throws.
    public func trackJob(_ slug: String, kind: CareersTrackKind, source: String? = nil, utmSource: String? = nil) async {
        guard let url = try? connection.url("/jobs/\(Connection.encode(slug))/track"),
              let body = try? Connection.json(TrackBody(kind: kind, source: source, utmSource: utmSource)) else { return }
        _ = try? await connection.send(connection.request("POST", url, headers: headers(["Content-Type": "application/json"]), body: body))
    }

    // MARK: - Internals

    private func headers(_ extra: [String: String] = [:]) -> [String: String] {
        ["Authorization": "Bearer \(publicKey)", "Accept": "application/json"].merging(extra) { $1 }
    }

    private func read(_ path: String, query: [(String, String?)]) async throws -> Data {
        try await connection.send(connection.request("GET", try connection.url(path, query: query), headers: headers()))
    }
}

private struct TrackBody: Encodable {
    let kind: CareersTrackKind
    let source: String?
    let utmSource: String?
}
