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
- Thesis text (`ctufitthesis.pdf`) — defines functional requirements
  **F1–F15** and non-functional **N1**. Relevant ones referenced inline
  below.
- Screen designs (`Claude.pdf`) — UI reference for layouts. Match spirit,
  not pixels.
- `database_schema.txt` — backend schema, useful when an API field's
  meaning is unclear.

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
