# BarnHub - iOS Barn Management App

## Status: Phase 1-5 Implementation In Progress

## Tech Stack
- SwiftUI + iOS 17+
- SwiftData with CloudKit (automatic iCloud sync)
- GitHub Actions for CI/CD to TestFlight

## Apple Developer
- Team: ShadowPuppet, LLC (TYQ32QCF6K)
- Bundle ID: net.shadowpuppet.BarnBook
- iCloud Container: iCloud.net.shadowpuppet.BarnBook

## Phases
- [x] Phase 1: Project Scaffold & Data Models
- [x] Phase 2: Navigation & Shared Components
- [x] Phase 3: Horse & Client CRUD
- [x] Phase 4: Accounting & Barn Management
- [x] Phase 5: CI/CD & TestFlight
- [x] Phase 6: BarnHub Pro Freemium Subscription

## Better Swift Audit - 2026-03-18

Summary: 32 findings across 25 files. 0 shared utilities to extract.
Platforms: iOS (Mac Catalyst) | Deployment targets: iOS 17.0+

### Security & Secrets
No actionable findings. Supply chain, credentials, and data protection all clean.

### Code Quality
- [ ] **[HIGH]** `BarnHub/Extensions/URL+App.swift:4-5` - Force unwraps on static URLs — Fix: guard or use computed property
- [ ] **[MEDIUM]** `BarnHub/Views/*/EditView.swift` (7 files) - DispatchQueue.main.asyncAfter dismiss pattern — Fix: remove delay, let toast auto-dismiss
- [ ] **[MEDIUM]** `BarnHub/Views/Components/ToastModifier.swift:21` - try? on Task.sleep suppresses cancellation

### DRY & YAGNI
- [ ] **[HIGH]** 13 views repeat 3-property toast state pattern — Fix: extract ToastState struct
- [ ] **[HIGH]** 5 edit views repeat ~30-line save() boilerplate — Fix: extract shared save helper
- [ ] **[MEDIUM]** 5 edit views repeat `isNew` and `existingModel` computed properties
- [ ] **[MEDIUM]** VetScheduleView/FarrierScheduleView near-identical row builders
- [ ] **[MEDIUM]** HorseRowView/ClientRowView identical status indicator pattern

### Architecture & SOLID
- [ ] **[MEDIUM]** ReportsView inline data aggregation — Fix: extract to computed properties (acceptable for now)
- [ ] **[MEDIUM]** ReminderListView triple-filter on same query — Fix: single categorized pass

### Bugs, Performance & Error Handling
- [ ] **[HIGH]** StoreService:26-29 — Untracked background Task in init, cannot be cancelled
- [ ] **[MEDIUM]** ClientDetailView:136 — Redundant array allocation

### Platform Coverage & SwiftUI Patterns
- [ ] **[HIGH]** Multiple views use hardcoded `.system(size:)` fonts — Fix: use semantic fonts or @ScaledMetric
- [ ] **[HIGH]** Color-only status indicators (HorseRowView, ClientRowView, TransactionRowView, SupplyListView) — Fix: add icon alongside color
- [ ] **[MEDIUM]** 5 edit views use .onAppear for loadExisting — Fix: replace with .task
- [ ] **[MEDIUM]** AppearanceManager UserDefaults key not namespaced
- [ ] **[LOW]** Various accessibility label gaps on decorative images

### Test Quality & Coverage
- [ ] **[CRITICAL][MISSING]** No tests for DeepLinkHandler, Router
- [ ] **[HIGH][WEAK]** testReminderNextOccurrence only checks non-nil
- [ ] **[HIGH][WEAK]** testCurrencyFormatting only checks substring
- [ ] **[MEDIUM][VACUOUS]** testTransactionEnums re-tests language feature
- [ ] **[MEDIUM][MISSING]** No tests for Date+Formatting extensions

### File Ownership Map
| File | Primary Category | Reason |
|------|-----------------|--------|
| URL+App.swift | code-quality | Force unwrap fix |
| ToastModifier.swift | dry | Toast state extraction |
| ToastView.swift | dry | Toast state extraction |
| View+Toast.swift | dry | Toast state extraction |
| HorseEditView.swift | dry | Save pattern + toast state |
| ClientEditView.swift | dry | Save pattern + toast state |
| TransactionEditView.swift | dry | Save pattern + toast state |
| ReminderEditView.swift | dry | Save pattern + toast state |
| SupplyEditView.swift | dry | Save pattern + toast state |
| VetRecordEditView.swift | dry | Save pattern + toast state |
| FarrierVisitEditView.swift | dry | Save pattern + toast state |
| HorseRowView.swift | platform-swiftui | Status indicator + accessibility |
| ClientRowView.swift | platform-swiftui | Status indicator + accessibility |
| TransactionRowView.swift | platform-swiftui | Accessibility color indicators |
| SupplyListView.swift | platform-swiftui | Stock status accessibility |
| ClientsUpgradeView.swift | platform-swiftui | @ScaledMetric font |
| ProBadgeView.swift | platform-swiftui | Semantic font |
| HomeView.swift | platform-swiftui | Semantic fonts |
| PaywallView.swift | platform-swiftui | Font sizing |
| StoreService.swift | bugs-perf | Untracked Task |
| ClientDetailView.swift | bugs-perf | Redundant allocation |
| ReminderListView.swift | architecture | Triple-filter optimization |
| AppearanceManager.swift | platform-swiftui | Namespaced key |
| BarnHubTests.swift | tests | Strengthen weak tests |
| DeepLinkHandler.swift | tests | Needs test coverage |
| Router.swift | tests | Needs test coverage |
| Date+Formatting.swift | tests | Needs test coverage |

## Phase 7: Live Dashboard with Quick Stats & Overdue Alerts

The HomeView is currently just a grid of navigation tiles. Transform it into a real operational dashboard that surfaces the information a barn manager needs first thing in the morning.

- [x] **At-a-glance stats bar** — active horse count, active client count, and this month's net balance, shown as compact cards below the header
- [x] **Overdue alerts section** — red-flagged list of overdue reminders, past-due vet appointments, and past-due farrier visits with quick-tap to the relevant record
- [x] **Today's schedule preview** — upcoming reminders and appointments due today/tomorrow, collapsed to top 3 with "See all" link to the Schedule tab
- [x] Pull data via `@Query` with date predicates so the dashboard is always live

## Phase 8: Client Invoice Generation & Sharing

The accounting system tracks transactions but barn managers have no way to bill clients. Add PDF invoice generation and sharing so they can send professional invoices directly from the app.

- [x] **Invoice date range picker** — on ClientDetailView, add "Generate Invoice" button that opens a sheet to select a date range
- [x] **PDF renderer** — generate a clean PDF with barn name/logo, client info, line-item transactions for the period, and a total due
- [x] **Share sheet integration** — use `ShareLink` to email/message/AirDrop the generated PDF
- [x] **Invoice history** — persist generated invoices (date range, total, PDF data) as a new `Invoice` SwiftData model linked to the client so they can be re-sent or referenced later
- [x] Pro-only feature gated behind `FeatureGate`

## Phase 9: Horse Health Timeline

Vet records and farrier visits are tracked separately, but there's no unified view of a horse's complete care history. Add a chronological health timeline to HorseDetailView.

- [x] **Timeline view** — unified chronological list on HorseDetailView showing vet visits, farrier visits, weight changes, and medical note updates as color-coded entries
- [x] **Event type icons & color coding** — vet (cross icon, blue), farrier (hammer icon, orange), weight log (scale icon, green)
- [x] **Weight tracking model** — add a `WeightEntry` SwiftData model (date + weight) linked to Horse, keeping the single `weight` field updated to latest
- [x] **Quick-add from timeline** — tap "+" on the timeline to add any event type without navigating away from the horse's profile
- [x] **Filterable** — toggle event types on/off to focus on specific care categories

## Deferred
- Photo capture for horse profiles
- Local notifications for reminders
- Reports with Swift Charts
- Lesson scheduling / calendar
- CSV import/export (available to all users)
- iPad-optimized sidebar layout
- Home screen widgets
