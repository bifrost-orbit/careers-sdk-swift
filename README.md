# Careers Orbit for Swift

The official Swift SDK for the Careers Orbit delivery API. Show live jobs, take applications with a CV and run the candidate portal in iOS, iPadOS, macOS, tvOS and watchOS apps, and in server-side Swift.

- async/await on `URLSession`, no dependencies
- Safe under Swift 6 strict concurrency: the clients and every model are `Sendable`
- `Codable` models for every answer, with a `JSONValue` for a job's JobPosting data
- Retries, timeouts and typed errors, matching the JavaScript SDK

It needs Swift 5.9 or later, and iOS 15, macOS 12, tvOS 15 or watchOS 8 or later.

Full documentation: [docs.bifrostorbit.com/careers/developers/careers-sdk](https://docs.bifrostorbit.com/careers/developers/careers-sdk/). The delivery API itself is described in [Delivery API](https://docs.bifrostorbit.com/careers/developers/delivery-api/).

## Install

Swift Package Manager reads packages from the root of a Git repository, so the SDK is published from its own repository.

In Xcode, choose **File › Add Package Dependencies…** and enter:

```
https://github.com/bifrost-orbit/careers-sdk-swift
```

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bifrost-orbit/careers-sdk-swift", from: "0.1.0"),
],
targets: [
    .target(name: "App", dependencies: [.product(name: "CareersOrbit", package: "careers-sdk-swift")]),
]
```

## Quick start

Create a public key under **API keys** in Careers Orbit. It starts with `careers_pk_` and can only read live jobs and send applications, so it is safe to ship in an app.

```swift
import CareersOrbit

let careers = try CareersOrbitClient(publicKey: "careers_pk_...", locale: "de")

let list = try await careers.jobs(.init(remote: "hybrid", query: "guide"))
for job in list.items {
    print(job.title, job.locations.first?.city ?? "")
}
```

| Option | What it does |
| --- | --- |
| `publicKey` | A public key, `careers_pk_…`. Required. Anything else is refused with `CareersOrbitError.invalidPublicKey`. |
| `environment` | `.production` (`https://api.bifrostorbit.com/careers/v1`, the default), `.staging` (`https://api-stage.bifrostorbit.com/careers/v1`) or `.custom(url)`. |
| `baseURL` | Overrides the environment's address. |
| `locale` | Used when a call names no language, such as `de`. Without it, the career site's main language answers. |
| `timeout` | Seconds per attempt. 5 by default. |
| `retries` | Extra attempts at a read after a failed connection or a `5xx` answer. 2 by default. Applications are sent once. |
| `session` | The `URLSession` to use. |

## Every method

| Method | Answers with |
| --- | --- |
| `jobs(CareersJobQuery)` | Live jobs, filtered by `department`, `location`, `remote`, `type` and `query`, with `page` and `perPage` |
| `job(_:locale:)` | One job with its description, form, privacy notice and JobPosting data. Throws `.notFound` when it is closed or gone. |
| `findJob(_:locale:)` | The same, or `nil` |
| `filters(locale:)` | Departments, locations, job types and workplaces that have live jobs, with counts |
| `site(locale:)` | The career site's name, introduction, logo, colours, languages and current privacy notice |
| `sitemap()` | Every live job with its address in each language |
| `apply(to:_:files:)` | Sends an application. A second one to the same job from the same email updates the first. |
| `joinTalentPool(_:)` | Keeps someone's details for future jobs |
| `trackJob(_:kind:source:utmSource:)` | Counts a view or an apply start for the reports. Never throws. |

## Applications

```swift
let job = try await careers.job("mountain-guide-lofoten")

let application = CareersApplication(
    firstName: "Kari",
    lastName: "Nordmann",
    email: "kari@northwilds.com",
    phone: "+47 912 34 567",
    answers: ["q-years": 6, "q-areas": ["lofoten", "lyngen"], "q-first-aid": .yesNo(true)],
    privacyVersion: job.privacy.version,
    privacyAccepted: true,
    source: "northwilds-app"
)
let files = CareersApplicationFiles(cv: CareersFile(name: "kari-nordmann.pdf", data: cvData))
let result = try await careers.apply(to: job.slug, application, files: files)
```

Send the standard fields `job.form` asks for (`job.form.asks("phone")`) and an answer for each question, keyed by its id. Choice answers are option ids. `privacyAccepted` must be `true`; the client refuses the application before sending it otherwise. Files are PDF or Word documents up to 10 MB.

## Candidate portal

`CareersPortalClient` lets candidates sign in with an emailed code and follow their applications in your app. Keep the session token somewhere safe, such as the Keychain, by implementing `CareersSessionStore`; `CareersMemorySession` keeps it in memory.

```swift
let portal = try CareersPortalClient(publicKey: "careers_pk_...", locale: "de", session: KeychainSession())

try await portal.requestCode(email: "solveig@northwilds.com")
try await portal.signIn(email: "solveig@northwilds.com", code: "123456")
if let me = try await portal.me(), let offer = me.offers.first(where: { $0.status == "open" }) {
    _ = try await portal.openOffers()
    _ = try await portal.acceptOffer(offer.id, acceptance: CareersOfferAcceptance(name: "Solveig Haugen", consent: true, documentHash: offer.documentHash ?? ""))
}
```

| Method | What it does |
| --- | --- |
| `requestCode(email:)`, `signIn(email:code:)`, `signOut()` | Sign-in with a six-digit code. The session lasts two hours. |
| `me()` | Applications, offers, talent pool and requests, or `nil` when signed out |
| `withdraw(applicationId:reason:)`, `addDocument(applicationId:file:)` | Change an open application |
| `openOffers()`, `acceptOffer(_:acceptance:)`, `declineOffer(_:reason:)`, `offerPDF(_:)` | Read, sign or decline an offer, and download it |
| `exportData()`, `askToCorrect(_:)`, `askToErase()` | The candidate's data and data requests |
| `stayInTalentPool()`, `leaveTalentPool()` | Talent pool consent |
| `stopTexts(_:)` | Stops text messages on `sms` or `whatsapp` |

Calls that change something answer with the whole `CareersPortal` again. A `401` throws `.signedOut` and clears the session store. Leave out `publicKey` when `baseURL` is your own server, which adds the key.

## Errors

Everything throws `CareersOrbitError`, apart from `CancellationError` when the calling task is cancelled.

| Case | When |
| --- | --- |
| `.notFound(message:)` | `404`: no such job, or it isn't live |
| `.unauthorized(message:)` | `401`: the key was refused, revoked or has expired |
| `.signedOut(message:)` | `401` from the portal: the candidate's session is missing or has expired |
| `.rateLimited(retryAfter:message:)` | `429`: wait `retryAfter` seconds |
| `.http(status:code:message:)` | Any other `4xx`, such as `422 invalid` for a missing field |
| `.server(status:message:)` | `5xx`, after the retries |
| `.unavailable(message:)` | Careers Orbit could not be reached or did not answer in time, after the retries |
| `.decoding(_:)` | The answer did not match the type asked for |
| `.invalidPublicKey`, `.invalidURL`, `.invalidInput` | The client was set up wrongly, or an application was refused before it was sent |

Messages are written for candidates, in the language of the request.

## Testing your app

Pass a `URLSession` whose configuration has your own `URLProtocol` in `protocolClasses`, and answer requests with JSON shaped like the [delivery API](https://docs.bifrostorbit.com/careers/developers/delivery-api/). The SDK's own tests do exactly this; see `Tests/CareersOrbitTests/StubProtocol.swift`.

## Licence

MIT
