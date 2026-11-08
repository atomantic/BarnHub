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
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -project BarnHub.xcodeproj -scheme BarnHub \
  -only-testing:BarnHubTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

When more than one iOS runtime is installed, `name=iPhone 17` matches several
simulators and xcodebuild picks one. Pin the OS (`...,name=iPhone 17,OS=26.5`) or
use `id=<udid>` from `xcrun simctl list devices`. Run tests that touch SwiftData
on both the oldest iOS you have (26.x) and the newest. SwiftData behaves
differently across them; for example, batched fetches lose relationships before
iOS 27 (#69).

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

CI via GitHub Actions (`.github/workflows/ci.yml`) builds and runs `BarnHubTests` on the `xcode-27` runner image (the iOS 27 SDK isn't on `macos-latest`), but it is **manual-only** (`workflow_dispatch`): run it from the Actions tab ("Run workflow") or with `gh workflow run ci.yml --ref <branch>`. It doesn't run automatically on pull requests or pushes because macOS minutes on this private repo are billed; automatic runs wait on Adam's decision. So a local `xcodebuild build` and `BarnHubTests` run (see Build Commands) are still required before merging. CI doesn't deploy: TestFlight uploads only happen through `./deploy.sh`.

## Key Patterns

- **Router**: 5-tab navigation (Home, Horses, Clients, Schedule, Accounting) with `NavigationPath` per tab
- **Models**: SwiftData `@Model` classes with enum-backed raw string properties (see `Enums.swift`). Every model is listed once in `BarnHubSchema.models` (`ModelContext+Helpers.swift`; `ModelSchemaTests` fails if one is missing) and the container uses `BarnHubSchemaV1` + `BarnHubMigrationPlan`. Before changing a model, freeze V1 and add V2 with a lightweight stage (CloudKit allows only additive changes)
- **Forms and Pro screens**: open add/edit forms with `router.navigate(to:)`, not `NavigationLink(value:)`, so they become sheets on Mac/iPad. Each route enum's exhaustive `isForm` and `requiredProFeature` (`Routes.swift`) decide sheet presentation and Pro gating at the destination
- **Brand colors**: Use `Color.barnGreen` and other brand colors from `Color+Brand.swift`
- **Currency formatting**: Use `Double.asCurrency` extension
- **Date formatting**: Use extensions in `Date+Formatting.swift`
- **Toasts**: Use `.toast()` modifier from `View+Toast.swift` — never `window.alert`
- **Destructive actions**: Use confirmation dialogs — never `window.confirm`
- **Logging**: Use `BarnHubLogger.info/success/warning/error`. Never log names, emails, or other personal data; log counts, types, or flags instead
- **Preview data**: Use `PreviewSampleData.previewContainer` and `-SeedSampleData` launch argument (Debug builds only, like `-screenshotRoute` and `barnhub://screenshot/…`; Release ignores them)
- **Deep links**: The `barnhub` URL scheme is registered in `BarnHub/Info.plist` (iOS/Catalyst) and `BarnHub/Info-macOS.plist` (native macOS); `DeepLinkHandler` handles `barnhub://home|horses|clients|accounting|schedule[/reminders|vet|farrier|…]|supplies|reports|subscription` in all builds. Drive a simulator with `xcrun simctl openurl <udid> barnhub://horses`; iOS asks "Open in BarnHub?" the first time, so tap Open once

## Localization

The app uses **Xcode String Catalogs** (`Localizable.xcstrings`) with English as the source and 8 translations (9 languages in all). Locale is set via `.environment(\.locale)` at the root view in `BarnHubApp.swift`.

### Adding localized strings

1. **In SwiftUI views** — `Text("My String")` auto-lookups via `LocalizedStringKey`. No extra work needed for `Text`, `Label`, `Button`, `.navigationTitle`, `Section` headers, `.confirmationDialog`, and `.alert` titles.

2. **In enums, computed properties, and non-UI code** — use `appLocalized()` (defined in `Locale+App.swift`):
   ```swift
   var displayName: String {
       switch self {
       case .feed: return appLocalized("Feed", comment: "Transaction category")
       }
   }
   ```
   Always return `String` (not `LocalizedStringKey`) so values work in both `Text()` and string interpolation.

3. **Never use** `String(localized:)` directly — it ignores in-app locale changes. Always use `appLocalized()` which passes `locale: .app`.

4. **Never use** `NSLocalizedString` — it's the legacy API.

5. **Date formatting in `Text()`** — use `Text(date, format:)` not `date.formatted()`. The former respects the SwiftUI environment locale; the latter uses the system locale.

### Rules

- **Always use `appLocalized()` for programmatic localized strings** — it reads the user's locale preference and resolves correctly without restart
- **Never store localized strings in SwiftData** — store raw enum values (`rawValue`), compute `displayName` at display time
- **Never cache `DateFormatter` as static** — use `Date.FormatStyle` or create formatters per-call so they respect locale changes
- **`comment:` parameter is required** on all `appLocalized()` calls — it helps translators and auto-populates in the string catalog
- **After adding new strings**, add their keys to `Localizable.xcstrings` with translations for all 8 non-English languages. Building in the Xcode app extracts new keys with state `"new"`, but a command-line `xcodebuild` build does not touch the catalog, so add keys by hand there (next to related keys, without re-sorting the file)
- **Every new user-facing string must be localized immediately** — never add strings without also adding translations for all 8 non-English languages in `Localizable.xcstrings`. This applies to SwiftUI view text (`Text`, `Label`, `Section`, `navigationTitle`, button labels, empty states, toast messages, confirmation dialogs) and programmatic strings via `appLocalized()`

### Supported languages

`en`, `de`, `fr`, `nl`, `sv`, `es-ES`, `es-MX`, `pt-BR`, `it`
