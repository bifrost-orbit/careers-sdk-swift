import Foundation

/// Where the clients read from.
public enum CareersEnvironment: Sendable, Hashable {
    /// `https://api.bifrostorbit.com/careers/v1`
    case production
    /// `https://api-stage.bifrostorbit.com/careers/v1`
    case staging
    /// Any other address, such as your own server forwarding the candidate portal.
    case custom(URL)

    public var baseURL: URL {
        switch self {
        case .production: return URL(string: "https://api.bifrostorbit.com/careers/v1")!
        case .staging: return URL(string: "https://api-stage.bifrostorbit.com/careers/v1")!
        case .custom(let url): return url
        }
    }
}

/// Which jobs to list, for ``CareersOrbitClient/jobs(_:)``. Ids come from ``CareersOrbitClient/filters(locale:)``.
public struct CareersJobQuery: Sendable, Hashable {
    /// A department id.
    public var department: String?
    /// A location id.
    public var location: String?
    /// `onsite`, `hybrid` or `remote`.
    public var remote: String?
    /// `fullTime`, `partTime`, `contract`, `temporary`, `internship`, `apprenticeship` or `workingStudent`.
    public var type: String?
    /// Words in the title, summary, department or location.
    public var query: String?
    /// 1 or more.
    public var page: Int?
    /// Up to 100. The API's default is 50.
    public var perPage: Int?
    /// Overrides the client's language.
    public var locale: String?

    public init(
        department: String? = nil,
        location: String? = nil,
        remote: String? = nil,
        type: String? = nil,
        query: String? = nil,
        page: Int? = nil,
        perPage: Int? = nil,
        locale: String? = nil
    ) {
        self.department = department
        self.location = location
        self.remote = remote
        self.type = type
        self.query = query
        self.page = page
        self.perPage = perPage
        self.locale = locale
    }
}

/// What ``CareersOrbitClient/trackJob(_:kind:source:utmSource:)`` counts.
public enum CareersTrackKind: String, Sendable, Hashable, Codable {
    case view
    case start
}
