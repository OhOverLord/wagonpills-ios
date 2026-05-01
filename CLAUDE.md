# CLAUDE.md — WagonPills iOS

This file is the source of truth for Claude (terminal `claude` / Claude Code)
when working in this repository. Read it before doing anything.

---

## What this is

iOS client for **WagonPills**, a bachelor thesis project at FIT CTU Prague.
The app manages personal medication schedules, intake logging, and doctor
visit records. The backend is a Spring Boot REST API; this repo is the
SwiftUI frontend that consumes it.

The author is a junior-to-mid Swift developer. Skip basics (what is a
`struct`, what is `async/await`). Do explain non-obvious iOS gotchas
(Keychain quirks, notification permissions, app lifecycle, refresh-token
rotation pitfalls).

This is a thesis prototype, not a production product. Bias toward:

- Working vertical slices over perfect architecture.
- Built-in Apple frameworks over third-party libraries.
- Solutions defendable in a 10-minute thesis committee Q&A.

---

## Sources of truth

When something in a user message contradicts these, **ask before proceeding**.

- `Wagonpills/openapi.yaml` — API contract. Do not invent endpoints or DTO
  fields. If something seems missing, ask.
- Thesis requirements F1–F15 and N1–N9 — listed below in this document.
- Screen designs in `design/` — UI reference for layouts. Match spirit,
  not pixels. If a feature has no design, ask before guessing.
- `database_schema.txt` — backend schema, useful when an API field's
  meaning is unclear.

---

## Thesis requirements

These come from the bachelor thesis (Filippov, 2026, FIT CTU). They are
the contract the project will be defended against. **Priority follows the
MoSCoW model**:

- **Must Have** — core scope. No shortcuts, no "minimum viable" version.
  If the spec asks for create/view/edit/delete, all four ship.
- **Should Have** — important but a leaner implementation is acceptable
  if scope pressure demands it. Discuss with the user before cutting.
- **Could Have** — nice if time permits.
- **Won't Have** — explicitly out of scope. Do not implement, do not
  propose, even if asked casually — confirm with the user that they
  really want to expand scope before doing anything.

### Functional requirements

| ID  | Requirement                          | Priority    |
| --- | ------------------------------------ | ----------- |
| F1  | User Registration and Authentication | Must Have   |
| F2  | Medication Record Management         | Must Have   |
| F3  | Medication Schedule Configuration    | Must Have   |
| F4  | Intake Confirmation Logging          | Must Have   |
| F5  | Medication History Overview          | Must Have   |
| F6  | Doctor Visit Management              | Must Have   |
| F7  | Doctor Visit Attachment Support      | Should Have |
| F8  | Prescription Management              | Should Have |
| F9  | Medication Change Tracking           | Should Have |
| F10 | Medication Stock Tracking            | Should Have |
| F11 | Calendar Event Management            | Should Have |
| F12 | Medication Catalogue Integration     | Should Have |
| F13 | Search and Filtering                 | Could Have  |
| F14 | Data Export                          | Won't Have  |
| F15 | User Account Management (admin)      | Should Have |

**F1 — User Registration and Authentication.** Email + password account
creation, JWT-based login, authenticated access required for all
personal features. Detailed treatment in `prompts/sprint-2-auth.md`.

**F2 — Medication Record Management.** Create, view, edit, delete
personal medication records. Each record: name, dosage, unit, start/end
dates, optional intake instructions. Optional link to a catalogue entry
(see F12). API: `/api/v1/medications`.

**F3 — Medication Schedule Configuration.** Create, view, edit, delete
reminder rules and reminder times for each medication. Rules carry the
repeat pattern (DAILY / WEEKLY / INTERVAL); times are specific
times-of-day under a rule. Schedule data also drives local
notifications (`UNUserNotificationCenter`) so reminders fire offline.
API: `/api/v1/medications/{id}/reminders` and nested `/times`.

**F4 — Intake Confirmation Logging.** Record whether a scheduled dose
was TAKEN, SKIPPED, or MISSED. Each log entry: medication, scheduled
time, status, optional note. Backend automatically decrements stock on
confirmed intake (see F10). API: `/api/v1/intake-logs`.

**F5 — Medication History Overview.** Structured view of past intake
events: per-medication adherence, missed/confirmed dose patterns. Reads
from intake logs. No new endpoints — derived from F4 data with
filtering (`from`, `to`, `status`).

**F6 — Doctor Visit Management.** Create, view, edit, delete medical
consultation records: visit date/time, physician, diagnosis,
recommendations. API: `/api/v1/visits`.

**F7 — Doctor Visit Attachment Support.** Upload, download, delete file
attachments on visit records (`multipart/form-data` upload). Persisted
on the backend. API: `/api/v1/visits/{id}/attachments`.

**F8 — Prescription Management.** Create, view, edit, delete
prescriptions and their items (medication name, dosage, quantity).
Prescriptions optionally link to a doctor visit. Two endpoint groups:
`/api/v1/prescriptions` and `/api/v1/prescriptions/{id}/items`.

**F9 — Medication Change Tracking.** Record modifications to an active
medication: type (START / STOP / DOSAGE_CHANGE / SCHEDULE_CHANGE), old
and new values, optional reason, optional link to a doctor visit. API:
`/api/v1/medications/{id}/changes`.

**F10 — Medication Stock Tracking.** Track current quantity per
medication. User actions: add stock (refill purchase), adjust stock
(correction). Backend automatically decrements on confirmed intake
(F4). View current level, full movement history, set a low-stock
threshold. API: `/api/v1/medications/{id}/stock/{add,adjust,summary,history}`.

**F11 — Calendar Event Management.** Create, view, edit, delete
personal events (DOCTOR_VISIT / MEDICATION_REFILL / LAB_TEST / OTHER):
title, start time, optional end/description/location. Optional link to
a doctor visit. Each event can have reminder notifications (PUSH or
EMAIL channel). APIs: `/api/v1/calendar-events` and nested
`/reminders`.

**F12 — Medication Catalogue Integration.** Read-only access (from the
client's perspective) to a catalogue of standardised medication entries
organised by region. Supports search and aliases. Used during F2
medication creation to optionally pre-fill fields. API:
`/api/v1/catalog?regionCode=...&name=...`.

**F13 — Search and Filtering.** Filter medications, visits, intake
history by name, date range, status. Use the existing query parameters
on those endpoints (e.g. `active=`, `from/to`, `status`). No new
endpoints needed.

**F14 — Data Export. WON'T HAVE.** Out of scope. Do not implement.
Do not propose. If the user asks, confirm they're explicitly expanding
scope.

**F15 — User Account Management.** Admin-level functionality: list
registered users (paginated), permanently delete users (cascading
deletion of personal data). Admin cannot delete their own account.
APIs: `/api/v1/admin/users`. Whether this gets a dedicated admin UI in
the iOS app or is left as backend-only is a scope decision — ask before
building admin screens.

### Non-functional requirements

| ID  | Requirement                              | Priority    |
| --- | ---------------------------------------- | ----------- |
| N1  | Secure Authentication and Access Control | Must Have   |
| N2  | Encrypted Communication                  | Must Have   |
| N3  | Reliable Data Persistence                | Must Have   |
| N4  | iOS Compatibility                        | Must Have   |
| N5  | API Response Performance                 | Should Have |
| N6  | Maintainability                          | Should Have |
| N7  | Usability                                | Should Have |
| N8  | Extensibility                            | Could Have  |
| N9  | GDPR Compliance                          | Won't Have  |

**N1 — Secure Authentication and Access Control.** JWT only. All
protected endpoints reject requests without a valid token. Backend
enforces user-level access — a user cannot read or modify another
user's data. Client side: store tokens in Keychain (see Auth model
below), never log tokens, never put them in URL parameters.

**N2 — Encrypted Communication.** All production traffic over HTTPS.
The Debug-only ATS exception for `localhost:8080` (see Configuration
section below) is for local development only. Release builds must keep
ATS strict — never propagate the localhost exception into Release
config.

**N3 — Reliable Data Persistence.** Backend concern, but it shapes the
client cache strategy: the source of truth is the server, the local
cache is a best-effort read-through. Never write to local cache and
treat it as authoritative — always sync with the server before
mutations.

**N4 — iOS Compatibility.** Thesis text says iOS 16+. **The Xcode
project is currently set to iOS 17.0** (`Config/Shared.xcconfig`). This
is a known divergence — leave it for now, document in the thesis Tech
chapter that iOS 17 was chosen because [reason TBD with the user].
Avoid iOS 17-only APIs gratuitously to keep a possible downgrade easy.

**N5 — API Response Performance.** Show loading states immediately on
any network call. Cache list responses (`URLCache` + lightweight file
cache) so reopens feel instant. Don't add gratuitous spinners on
already-cached data.

**N6 — Maintainability.** This is what the architecture rules below
operationalize: feature folders, MVVM, `APIError` enum, Repository
pattern. If a refactor would make a section easier to defend on the
committee, it's worth it.

**N7 — Usability.** Native iOS HIG: standard `Form`, `List`,
`NavigationStack`. No custom controls when a stock one exists.
Destructive actions get confirmation alerts. Errors are inline, not
modal Alerts (except for confirmations).

**N8 — Extensibility. Could Have.** Don't over-engineer for hypothetical
future features.

**N9 — GDPR Compliance. WON'T HAVE.** Explicitly out of scope per the
thesis. The app should still avoid obviously bad practices (no logging
of PII, no third-party trackers), but no formal GDPR compliance work.

---

## Tech stack (decided — do not re-litigate)

- iOS 17.0 minimum (`IPHONEOS_DEPLOYMENT_TARGET` in `Config/Shared.xcconfig`).
- Swift 5, SwiftUI for all UI.
- `async/await` for concurrency. **No Combine** unless there is a
  specific reason (write it down in the PR if so).
- MVVM. ViewModels are `@MainActor` and `final class`.
- **swift-openapi-generator** as an Xcode build plugin (already wired up
  via SPM in `Wagonpills.xcodeproj`). Generated types live in module
  `WagonpillsAPI` (or whatever the generator target produces — check the
  build log, do not guess).
- **URLSession** under the hood via `swift-openapi-urlsession`. No
  Alamofire, no Moya.
- **Keychain** for both access and refresh JWTs. Rationale: refresh token
  grants long-lived access; storing it in `UserDefaults` would fail N1
  ("Secure Authentication and Access Control"). Use the `Security`
  framework directly — no third-party Keychain wrappers.
- `URLCache` plus a small file cache for response bodies that need to
  outlive process restarts (e.g. medication list, today schedule).
  **No CoreData, no SwiftData.**
- `UNUserNotificationCenter` for local medication reminders, scheduled
  on-device from cached schedule data so reminders fire offline.
- XCTest (or Swift Testing if it fits cleanly) for tests.
- SwiftLint with `force_unwrapping` enabled — never use `!` on optionals
  in production code. Tests may use `try #require` / `XCTUnwrap`.

---

## Architecture rules

- **Repository pattern.** ViewModels never call the generated API client
  directly. They go through a Repository, which:
  - Owns the generated client.
  - Maps generated DTOs to domain models defined in the feature folder.
  - Translates errors into the typed `APIError` enum.
- **Domain models are separate** from generated DTOs. Generated types may
  change shape on every spec regen; views must not depend on them.
- **`APIError`** is the only error type ViewModels surface. No raw
  `Error`, no `URLError` leaking up. Mapping happens in the Repository.
- **No force unwraps** in production code. SwiftLint enforces this.
- **Every View has a SwiftUI `#Preview`.** Use a stub Repository in
  Previews so they don't hit the network.
- **One feature = one folder** under `Wagonpills/Features/<Feature>/`,
  containing `Views/`, `ViewModels/`, `Repositories/`, `Models/`. Cross-
  feature shared code goes in `Wagonpills/Core/`.
- **Dependency injection by constructor.** ViewModels take their
  Repository in the initializer. No service locators, no environment
  singletons for non-UI dependencies. SwiftUI `@Environment` is fine for
  things like the auth state.

### Caching strategy

Online-with-cache-fallback, **not full offline-first**.

- Reads: try network → on failure, return last cached value with a
  visible "stale" indicator in the UI.
- Writes (POST/PUT/DELETE): require network. Show a clear error if
  offline; do not queue them.
- Notifications: scheduled locally from cached schedule data, so
  reminders still fire when offline.

---

## Folder structure

```
Wagonpills/
  App/                       # @main, RootView, MainTabView, env wiring
  Core/
    Networking/              # API client wiring, URLSession transport, auth interceptor
    Auth/                    # AuthState, KeychainStore, token refresh
    Persistence/             # URLCache config, file cache helpers
    Notifications/           # UNUserNotificationCenter helpers
    UI/                      # shared SwiftUI components (LoadingView, ErrorBanner...)
    Errors/                  # APIError enum
  Features/
    <Feature>/
      Views/
      ViewModels/
      Repositories/
      Models/                # domain models for this feature
  Resources/                 # Assets.xcassets, Localizable, etc.
  openapi.yaml
  openapi-generator-config.yaml
  Info.plist

WagonpillsTests/
  Features/<Feature>/        # mirror the Features tree
  Core/
```

When adding a new feature, prefer the `add-feature` skill (see
`.claude/skills/add-feature/`) so the layout stays consistent.

---

## Configuration

- `Config/Shared.xcconfig` — common settings, deployment target.
- `Config/Debug.xcconfig` — `BASE_URL = http://localhost:8080`. The
  `$()` escape is needed because xcconfig treats `//` as a comment.
- `Config/Debug.local.xcconfig` — gitignored, copy from
  `Debug.local.xcconfig.example` to override `BASE_URL` for a real
  device on LAN.
- `Config/Release.xcconfig` — production base URL goes here when there
  is one.

`BASE_URL` reaches the app via `Info.plist` → read once in
`Core/Networking/`. Do not hardcode URLs in code.

**ATS:** Debug builds need `NSAppTransportSecurity` →
`NSExceptionDomains` → `localhost` with `NSExceptionAllowsInsecureHTTPLoads = true`
in `Info.plist` so plain HTTP to `localhost:8080` works. Release config
must keep ATS strict.

---

## Auth model (relevant for every feature, not just Sprint 2)

- Backend exposes `/api/v1/auth/{register,login,refresh,logout,password}`.
- `AuthResponse` returns `{ token, refreshToken, email }`.
- **Refresh tokens rotate.** Every successful `/refresh` revokes the old
  refresh token and issues a new pair. Reusing an old refresh token is
  rejected with 401. The client must atomically swap the stored pair.
- Logout posts the refresh token to `/api/v1/auth/logout` to revoke it
  server-side, then clears Keychain locally. Access tokens are not
  revocable on the server — they expire on their own.
- Password change revokes all the user's refresh tokens server-side, so
  after a successful change the client should re-login or refresh
  immediately with the new pair returned by the change endpoint (if any
  — check the spec; the current spec returns 204, so re-login flow
  applies).
- An interceptor in the API client must:
  1. Attach `Authorization: Bearer <access>` to authenticated requests.
  2. On 401 from a non-refresh endpoint, attempt one refresh, then
     retry the original request once. If refresh fails, transition
     `AuthState` to `.signedOut` and surface the error.
  3. Serialize concurrent refresh attempts (only one refresh in flight
     at a time) — actor or `AsyncSemaphore`.

---

## Coding conventions

- File header: none. No author / date comments.
- One type per file when reasonable; small related helpers may share a
  file.
- Prefer `let` over `var`; prefer value types over reference types
  except for ViewModels and stateful services.
- Use `Swift Testing` (`@Test`, `#expect`) for new tests; XCTest is
  acceptable in existing files. Don't mix in one file.
- Comments explain _why_, not _what_. The code shows the what.
- Strings shown to the user go through `LocalizedStringKey` even if
  there's no other locale yet — easier to extract later.

---

## How Claude should work in this repo

- Be concise and practical, mentor-style. Not a tutorial.
- When showing code edits, show only the new or changed files. Don't
  reprint the whole tree.
- When asked for something suboptimal, push back with reasoning instead
  of just complying.
- Suggest the simplest thing that works; flag overengineering.
- If a request is ambiguous, ask before generating 200 lines of code.
- Production-quality code only: real error handling, loading states,
  no `// TODO` left behind, no `print` for diagnostics in production
  paths (tests and `#if DEBUG` are fine).
- Code and code comments in English. Chat may be Russian or English —
  follow the user's language.

### Before claiming a task is done

Run mentally (or ask the user to run) at least:

1. `swiftlint --strict` — CI fails on any warning.
2. `xcodebuild build` for the `Wagonpills` scheme on iPhone 16 / iOS
   18.5 simulator (matches CI).
3. New tests pass. Existing tests pass.
4. Every new View has a `#Preview` that renders without a live network.

If any of these can't be verified locally, say so explicitly — don't
claim "done" by hope.

---

## Local skills

The `.claude/skills/` directory contains skills for repetitive work:

- **add-feature** — implement a complete feature end-to-end (models,
  repository, viewmodels, views, tests). Read its `SKILL.md` before
  using.

## Regenerating the API client

Not a skill — too rare to justify one. Procedure:

1. Replace `Wagonpills/openapi.yaml` with the new spec from the backend.
2. Build — the `swift-openapi-generator` plugin regenerates the client
   automatically.
3. **Before replacing**, ask Claude to diff the new spec against the
   committed one and call out breaking changes (renamed/removed
   schemas, changed required fields, broken `$ref`s). A silent
   field-rename in a DTO can break the Repository mapping layer
   without a compile error.
