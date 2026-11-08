import Foundation

// MARK: - Jobs

/// A place a job is based.
public struct CareersLocation: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var street: String
    public var postalCode: String
    public var city: String
    public var region: String
    /// An ISO country code, such as `NO`.
    public var country: String
    /// `onsite`, `hybrid` or `remote`.
    public var remote: String
}

/// A job's pay, only when the employer chose to show it.
public struct CareersSalary: Codable, Sendable, Hashable {
    public var min: Double?
    public var max: Double?
    public var currency: String
    /// `year`, `month` or `hour`.
    public var period: String
    /// Ready to show, such as "42.000 NOK – 48.000 NOK pro Monat".
    public var text: String
}

public struct CareersDepartment: Codable, Sendable, Hashable {
    public var id: String
    public var name: String
}

/// A live job in a list.
public struct CareersJobSummary: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var slug: String
    /// On your website when job addresses are set, otherwise on the hosted career pages.
    public var url: String
    public var title: String
    public var summary: String
    public var department: CareersDepartment?
    public var locations: [CareersLocation]
    /// `fullTime`, `partTime`, `contract`, `temporary`, `internship`, `apprenticeship` or `workingStudent`.
    public var employmentType: String
    public var employmentTypeLabel: String
    /// `onsite`, `hybrid` or `remote`.
    public var remote: String
    public var remoteLabel: String
    public var salary: CareersSalary?
    public var publishedAt: String
    public var closesAt: String?
    /// Only shown to employees, with an internal key.
    public var `internal`: Bool
}

/// One page of live jobs.
public struct CareersJobList: Sendable, Hashable {
    public var items: [CareersJobSummary]
    /// The language the jobs are in.
    public var locale: String
    public var total: Int
    public var page: Int
    public var perPage: Int
}

/// A question the job's form asks.
public struct CareersQuestion: Codable, Sendable, Hashable, Identifiable {
    public struct Option: Codable, Sendable, Hashable, Identifiable {
        public var id: String
        public var label: String
    }

    public var id: String
    /// `text`, `longText`, `choice`, `multiChoice`, `yesNo`, `file`, `date` or `number`.
    public var kind: String
    public var label: String
    public var help: String
    public var required: Bool
    public var options: [Option]
}

/// What a job's apply form asks for.
public struct CareersForm: Codable, Sendable, Hashable {
    /// `required`, `optional` or `off` for each standard field: `phone`, `cv`, `coverLetter`, `linkedin`, `location`, `salaryExpectation` and `startDate`.
    public var fields: [String: String]
    public var questions: [CareersQuestion]

    /// Whether a standard field is shown, required or optional.
    public func asks(_ field: String) -> Bool { (fields[field] ?? "off") != "off" }
}

/// The privacy notice candidates agree to. Send its `version` with an application.
public struct CareersPrivacy: Codable, Sendable, Hashable {
    public var version: Int
    public var text: String
}

public struct CareersSEO: Codable, Sendable, Hashable {
    public var title: String
    public var description: String
}

/// One live job with its description, form, privacy notice and JobPosting data.
public struct CareersJob: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var slug: String
    public var url: String
    public var title: String
    public var summary: String
    public var department: CareersDepartment?
    public var locations: [CareersLocation]
    public var employmentType: String
    public var employmentTypeLabel: String
    public var remote: String
    public var remoteLabel: String
    public var salary: CareersSalary?
    public var publishedAt: String
    public var closesAt: String?
    public var `internal`: Bool
    public var locale: String
    /// The languages the job has its own title in, for `hreflang` links.
    public var locales: [String]
    /// The fields shown in the main language because they aren't translated.
    public var fallback: [String]
    /// Cleaned HTML.
    public var description: String
    public var seo: CareersSEO
    public var cmsEntryId: String?
    public var form: CareersForm
    public var privacy: CareersPrivacy
    /// The schema.org JobPosting, for a `<script type="application/ld+json">` or your own use.
    public var jobPosting: JSONValue
}

// MARK: - Site, filters and sitemap

public struct CareersColours: Codable, Sendable, Hashable {
    public var brand: String?
    public var accent: String?
}

public struct CareersInsightsSite: Codable, Sendable, Hashable {
    public var site: String
}

/// The text message channels the career site offers candidates.
public struct CareersTextingChannels: Codable, Sendable, Hashable {
    public var sms: Bool
    public var whatsapp: Bool
}

/// The career site's name, introduction, logo, colours, languages and current privacy notice.
public struct CareersSite: Codable, Sendable, Hashable {
    public var name: String
    public var slug: String
    public var intro: String
    public var logoUrl: String?
    public var colours: CareersColours
    public var locale: String
    public var languages: [String]
    public var defaultLanguage: String
    public var contactEmail: String?
    public var websiteUrl: String?
    public var hostedUrl: String
    public var privacy: CareersPrivacy
    /// Set when the career pages are counted in Insights Orbit.
    public var insights: CareersInsightsSite?
    /// Set when the career site offers text messages.
    public var texting: CareersTextingChannels?
}

public struct CareersFilterOption: Codable, Sendable, Hashable {
    public var value: String
    public var label: String
    public var count: Int
}

public struct CareersLocationFilterOption: Codable, Sendable, Hashable {
    public var value: String
    public var label: String
    public var count: Int
    public var city: String
    public var country: String
}

/// Departments, locations, job types and workplaces that have live jobs, with counts.
public struct CareersFilters: Codable, Sendable, Hashable {
    public var departments: [CareersFilterOption]
    public var locations: [CareersLocationFilterOption]
    public var employmentTypes: [CareersFilterOption]
    public var remote: [CareersFilterOption]
}

/// A live job's address, with its address in each language.
public struct CareersSitemapEntry: Codable, Sendable, Hashable {
    public var url: String
    public var slug: String
    public var updatedAt: String
    public var alternates: [String: String]
}

// MARK: - Applications and the talent pool

/// An answer to one of a job's questions. Choices are option ids.
public enum CareersAnswer: Encodable, Sendable, Hashable {
    case text(String)
    case choices([String])
    case number(Double)
    case bool(Bool)
    case null

    /// A yes or no question's answer, sent as `"yes"` or `"no"`.
    public static func yesNo(_ value: Bool) -> CareersAnswer { .text(value ? "yes" : "no") }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value): try container.encode(value)
        case .choices(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension CareersAnswer: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .text(value) }
}

extension CareersAnswer: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension CareersAnswer: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) { self = .choices(elements) }
}

/// Where an application came from, for the reports' channels.
public struct CareersUTM: Codable, Sendable, Hashable {
    public var source: String?
    public var medium: String?
    public var campaign: String?

    public init(source: String? = nil, medium: String? = nil, campaign: String? = nil) {
        self.source = source
        self.medium = medium
        self.campaign = campaign
    }
}

/// An application, for ``CareersOrbitClient/apply(to:_:files:)``. Send the standard fields the job's form asks for.
public struct CareersApplication: Encodable, Sendable, Hashable {
    public var firstName: String
    public var lastName: String
    public var email: String
    public var phone: String?
    public var coverLetter: String?
    public var linkedin: String?
    public var location: String?
    public var salaryExpectation: String?
    public var startDate: String?
    /// Keyed by question id.
    public var answers: [String: CareersAnswer]
    /// The `privacy.version` of the job the candidate read.
    public var privacyVersion: Int
    /// Must be `true`: the candidate agreed to the privacy notice.
    public var privacyAccepted: Bool
    /// Keep the candidate's details for future jobs.
    public var talentPool: Bool?
    /// The text message channels the candidate agreed to: `sms` and `whatsapp`.
    public var texting: [String]?
    public var locale: String?
    /// Where the form is, such as `northwilds.com`. Used when there is no `utm.source`.
    public var source: String?
    public var utm: CareersUTM?
    public var referrer: String?
    /// The `ref` of a colleague's referral link.
    public var referral: String?

    public init(
        firstName: String,
        lastName: String,
        email: String,
        phone: String? = nil,
        coverLetter: String? = nil,
        linkedin: String? = nil,
        location: String? = nil,
        salaryExpectation: String? = nil,
        startDate: String? = nil,
        answers: [String: CareersAnswer] = [:],
        privacyVersion: Int,
        privacyAccepted: Bool,
        talentPool: Bool? = nil,
        texting: [String]? = nil,
        locale: String? = nil,
        source: String? = nil,
        utm: CareersUTM? = nil,
        referrer: String? = nil,
        referral: String? = nil
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.coverLetter = coverLetter
        self.linkedin = linkedin
        self.location = location
        self.salaryExpectation = salaryExpectation
        self.startDate = startDate
        self.answers = answers
        self.privacyVersion = privacyVersion
        self.privacyAccepted = privacyAccepted
        self.talentPool = talentPool
        self.texting = texting
        self.locale = locale
        self.source = source
        self.utm = utm
        self.referrer = referrer
        self.referral = referral
    }
}

/// A file to send: a PDF or Word document up to 10 MB.
public struct CareersFile: Sendable, Hashable {
    public var name: String
    public var data: Data
    public var mimeType: String

    public init(name: String, data: Data, mimeType: String = "application/pdf") {
        self.name = name
        self.data = data
        self.mimeType = mimeType
    }
}

/// The files that go with an application.
public struct CareersApplicationFiles: Sendable, Hashable {
    public var cv: CareersFile?
    /// A file for each file question, keyed by question id.
    public var questions: [String: CareersFile]

    public init(cv: CareersFile? = nil, questions: [String: CareersFile] = [:]) {
        self.cv = cv
        self.questions = questions
    }
}

/// The answer to an application. `updated` is `true` when it updated an earlier application from the same email.
public struct CareersApplicationResult: Codable, Sendable, Hashable {
    public var applicationId: String
    public var updated: Bool
}

/// A talent pool sign-up, for ``CareersOrbitClient/joinTalentPool(_:)``.
public struct CareersTalentPoolSignup: Encodable, Sendable, Hashable {
    public var firstName: String
    public var lastName: String?
    public var email: String
    /// The `privacy.version` from ``CareersOrbitClient/site(locale:)``.
    public var privacyVersion: Int
    public var privacyAccepted: Bool
    public var locale: String?
    /// Email them when a new job opens.
    public var jobAlerts: Bool?
    /// Only tell them about jobs in these departments.
    public var departmentIds: [String]?

    public init(firstName: String, lastName: String? = nil, email: String, privacyVersion: Int, privacyAccepted: Bool, locale: String? = nil, jobAlerts: Bool? = nil, departmentIds: [String]? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.privacyVersion = privacyVersion
        self.privacyAccepted = privacyAccepted
        self.locale = locale
        self.jobAlerts = jobAlerts
        self.departmentIds = departmentIds
    }
}

// MARK: - Candidate portal

public struct CareersPortalFile: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var size: Int
    /// `cv` or `document`.
    public var kind: String
    public var createdAt: String
}

public struct CareersPortalApplication: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var jobTitle: String
    public var jobUrl: String?
    /// The stage name candidates see.
    public var stage: String
    /// `active`, `rejected`, `withdrawn` or `hired`.
    public var status: String
    public var appliedAt: String
    public var updatedAt: String
    public var canWithdraw: Bool
    public var canUpload: Bool
    public var files: [CareersPortalFile]
}

/// An offer the candidate can read, download, accept or decline.
public struct CareersPortalOffer: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var applicationId: String
    public var jobTitle: String
    public var title: String
    /// HTML.
    public var body: String
    /// `open`, `accepted`, `declined` or `expired`.
    public var status: String
    public var sentAt: String?
    public var expiresAt: String?
    /// Send it back with ``CareersOfferAcceptance`` to sign the version the candidate read.
    public var documentHash: String?
    public var signedAs: String?
    public var answeredAt: String?
}

/// A simple electronic signature for ``CareersPortalClient/acceptOffer(_:acceptance:)``.
public struct CareersOfferAcceptance: Encodable, Sendable, Hashable {
    /// The candidate's name, as they typed it.
    public var name: String
    public var consent: Bool
    /// The offer's `documentHash`.
    public var documentHash: String

    public init(name: String, consent: Bool, documentHash: String) {
        self.name = name
        self.consent = consent
        self.documentHash = documentHash
    }
}

public struct CareersPortalCandidate: Codable, Sendable, Hashable {
    public var firstName: String
    public var lastName: String
    public var email: String
    public var locale: String
}

public struct CareersPortalSite: Codable, Sendable, Hashable {
    public var name: String
    public var privacyVersion: Int
    public var contactEmail: String?
}

public struct CareersPortalTalentPool: Codable, Sendable, Hashable {
    public var member: Bool
    public var until: String?
}

/// A data request the candidate made.
public struct CareersPortalRequest: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// `access`, `erasure` or `correction`.
    public var kind: String
    /// `open`, `done` or `declined`.
    public var status: String
    public var receivedAt: String
    public var dueAt: String
}

/// Everything a signed-in candidate sees in the portal.
public struct CareersPortal: Codable, Sendable, Hashable {
    public var candidate: CareersPortalCandidate
    public var site: CareersPortalSite
    public var applications: [CareersPortalApplication]
    public var offers: [CareersPortalOffer]
    /// The text message channels the candidate agreed to: `sms` and `whatsapp`.
    public var texting: [String]
    public var talentPool: CareersPortalTalentPool
    public var requests: [CareersPortalRequest]
    /// When the candidate's data will be erased, once they have been told.
    public var erasureAt: String?

    private enum CodingKeys: String, CodingKey {
        case candidate, site, applications, offers, texting, talentPool, requests, erasureAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        candidate = try container.decode(CareersPortalCandidate.self, forKey: .candidate)
        site = try container.decode(CareersPortalSite.self, forKey: .site)
        applications = try container.decodeIfPresent([CareersPortalApplication].self, forKey: .applications) ?? []
        offers = try container.decodeIfPresent([CareersPortalOffer].self, forKey: .offers) ?? []
        texting = try container.decodeIfPresent([String].self, forKey: .texting) ?? []
        talentPool = try container.decode(CareersPortalTalentPool.self, forKey: .talentPool)
        requests = try container.decodeIfPresent([CareersPortalRequest].self, forKey: .requests) ?? []
        erasureAt = try container.decodeIfPresent(String.self, forKey: .erasureAt)
    }
}
