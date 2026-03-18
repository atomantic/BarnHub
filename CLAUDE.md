# BarnHub

Equine barn management iOS app for tracking horses, clients, schedules, supplies, and accounting.

## Tech Stack

- **SwiftUI** + **SwiftData** (iOS 17.0+)
- Direct `.xcodeproj` (no XcodeGen)
- Bundle ID: `net.shadowpuppet.BarnBook`, Team: `TYQ32QCF6K`

## Build Commands

```bash
# Build
xcodebuild build -project BarnHub.xcodeproj -scheme BarnHub \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project BarnHub.xcodeproj -scheme BarnHub \
  -only-testing:BarnHubTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

## Git Workflow

After every feature or bug fix:

1. **Build and test** — verify `xcodebuild build` and `xcodebuild test` pass
2. **`/simplify`** — run code review for reuse, quality, and efficiency; fix issues found
3. **`/do:review`** — deep code review against best practices
4. **`/do:push`** — commit and push to GitHub
5. **`/release`** — when ready for TestFlight, run the local deploy (see below)

## TestFlight Deployment

Local deploy via `./deploy.sh` (used when CI build credits are exhausted):

```bash
./deploy.sh              # full: tests + archive + upload
./deploy.sh --skip-tests # skip tests for faster iteration
```

Requires `.env` file with App Store Connect API credentials (see `.env.example`).

CI/CD via GitHub Actions (`.github/workflows/ci.yml`) deploys automatically on push to `main`, `testflight`, or `release/*` branches.

## Key Patterns

- **Router**: 5-tab navigation (Home, Horses, Clients, Schedule, Accounting) with `NavigationPath` per tab
- **Models**: SwiftData `@Model` classes with enum-backed raw string properties (see `Enums.swift`)
- **Brand colors**: Use `Color.barnGreen` and other brand colors from `Color+Brand.swift`
- **Currency formatting**: Use `Double.asCurrency` extension
- **Date formatting**: Use extensions in `Date+Formatting.swift`
- **Toasts**: Use `.toast()` modifier from `View+Toast.swift` — never `window.alert`
- **Destructive actions**: Use confirmation dialogs — never `window.confirm`
- **Logging**: Use `BarnHubLogger.info/success/warning/error`
- **Preview data**: Use `PreviewSampleData.previewContainer` and `-SeedSampleData` launch argument
