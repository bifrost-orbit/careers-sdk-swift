# Changelog

## Unreleased

- Text messages: `CareersSite.texting` says which channels the career site offers, `CareersApplication.texting` sends the channels the candidate agreed to, `CareersPortal.texting` lists them, and `CareersPortalClient.stopTexts(_:)` stops one.
- First release. `CareersOrbitClient` reads live jobs, a job with its form and privacy notice, filters, the career site and a sitemap, sends applications with a CV and question files as `multipart/form-data`, signs people up for the talent pool and counts job views and apply starts. `CareersPortalClient` signs candidates in with an emailed code, keeps the `X-Careers-Session` token in a `CareersSessionStore`, and covers withdrawing, documents, offers (open, accept with a simple electronic signature, decline, PDF), the data download, data requests and the talent pool. Every model is `Codable` and `Sendable`, and failures are `CareersOrbitError`.
