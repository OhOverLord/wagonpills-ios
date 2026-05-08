# WagonPills

[![CI](https://github.com/OhOverLord/wagonpills-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/OhOverLord/Wagonpills/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5-orange?logo=swift)
![Xcode](https://img.shields.io/badge/Xcode-16.4-blue?logo=xcode)

iOS client for a personal medication management system.

---

## Tech Stack

- **SwiftUI** — declarative UI, iOS 17+
- **swift-openapi-generator** — type-safe API client generated from `openapi.yaml`
- **URLSession** — networking (no third-party HTTP libraries)
- **Keychain** — secure JWT storage
- **UNUserNotificationCenter** — offline-capable local medication reminders
- **URLCache** — response caching with stale-data fallback
- **MVVM + Repository pattern** — strict separation of UI, business logic, and data access

---

## Architecture

```
Wagonpills/
  App/              # @main, RootView, MainTabView
  Core/
    Networking/     # API client, auth interceptor (token refresh, retry)
    Auth/           # AuthState, KeychainStore
    Persistence/    # URLCache config, file cache
    Notifications/  # UNUserNotificationCenter helpers
    UI/             # Shared SwiftUI components
    Errors/         # APIError enum
  Features/
    <Feature>/
      Views/
      ViewModels/
      Repositories/
      Models/
```

ViewModels are `@MainActor final class`. Every View has a `#Preview` backed by a stub repository — no live network in Previews.

---

## Getting Started

### Requirements

- macOS 15+
- Xcode 16.4+
- iOS 17.0+ simulator or device

### Setup

```bash
git clone https://github.com/OhOverLord/Wagonpills.git
cd Wagonpills
```

Copy the local debug config and set your backend URL:

```bash
cp Config/Debug.local.xcconfig.example Config/Debug.local.xcconfig
# Edit BASE_URL if the backend runs on a non-default address
```

Open `Wagonpills.xcodeproj` in Xcode and run on any iOS 17+ simulator. The `swift-openapi-generator` plugin generates the API client automatically on the first build.

### Backend

The app targets a Spring Boot REST API. Run it locally on `localhost:8080` (the Debug scheme is pre-configured for this). See the backend repo for setup instructions.

---

## CI

Every push and pull request to `main` runs two jobs:

| Job              | What it checks                                           |
| ---------------- | -------------------------------------------------------- |
| **SwiftLint**    | Code style — fails on any warning (`--strict`)           |
| **Build & Test** | Full `xcodebuild test` on iPhone 16 / iOS 18.5 simulator |

Test results are uploaded as artifacts and retained for 7 days.
