# Done Log

Completed items archived from PLAN.md. For release notes, see `CHANGELOG.md`.

## 2026-04-28

- Replan audit verified backlog — confirmed-done: `NotificationService` hashValue (default Hashable safe), `DataExportService`/`DataImportService` silent failures (no silent `try?` left), `ToastModifier` empty catch (handles `CancellationError`), `VetScheduleView`/`FarrierScheduleView` DRY (extracted `ScheduleRecordRow`), `Date+Formatting` uncached formatter (`compactFormatter` cached); pruned stale `BarnDashboardView`/`ReportsView` summaryCard DRY (only `ReportsView` uses those helpers)
- iPad/macOS sidebar layout — NavigationSplitView with hierarchical sub-page links, selected sub-item highlighting, sidebar width tuned for label fit
- Localization complete for all 8 target locales (de, fr, nl, sv, es-ES, es-MX, pt-BR, it) — full coverage in `Localizable.xcstrings`; reactive in-app language switching
- Localization workflow documentation moved to [scripts/LOCALIZATION.md](./scripts/LOCALIZATION.md)
- Onboarding flow (1.6.1) — 5-stage first-launch sheet (welcome → notifications → first horse → clients → Pro offer)
- Cross-platform Pro purchase (StoreKit) — iOS + macOS parity
- macOS dashboard home + first-launch sheet
- macOS App Store screenshot automation, single-launch URL-event capture, sales-focused captures
- Calendar view replaces schedule dashboard with Day/Week/Month toggle and unified Add Event dropdown
- Equine dentist visit tracking and scheduling
- Horse documents, gender field, and feed planning system (with sheets, wide layout, inline product creation)
- iPad dashboard layout with summary widgets on home screen
- Two-column horse form
- Better Swift Audit follow-up fixes (continuation of 2026-03-28 PR #8):
  - `BarnHubApp.swift` — replaced `try!` with safe in-memory container fallback
  - `WeightChartView.swift` — removed `plotFrame!` force unwrap
  - `SyncMonitor.swift` — added `removeObserver` in deinit
  - `ConfirmationDialog.swift` — accessibility traits (`.isModal`, `.contain`, sort priority)
  - `Color+Brand.swift` — explicit dark-mode variants via `Color(light:dark:)`
  - `Logger.swift` — `privacy: .private` on all PII fields
  - `SettingsView.swift` — replaced URL force-unwrap with safe `if let url`
  - `BarnNoteListView.swift` — calendar-based grouping with `appLocalized()` instead of fragile string compare
  - `DeepLinkHandler.swift` — Supplies single-route disambiguation (Home only)
  - DRY nav destinations — centralized via `.withRouteDestinations()` extension in BarnHubApp.swift
  - StoreService — secret-code flow removed, hash + UserDefaults concern resolved
- macOS-target fixes — encryption compliance, sidebar width, empty-state centering, feed entry sheet rendering, form number-field duplicate label
- App Store rejection resolution (1.6.0) — macOS code-signing and iOS signing gaps

## 2026-03-28

- iCloud sync with CloudKit — enabled automatic cloud sync via SwiftData, added SyncMonitor service to track sync events, sync status indicator in Home toolbar, and sync details in Settings

## 2026-03-25

- Archived all completed phases and audit fixes during replan

### Phases 1-9 (Complete)

- Phase 1: Project scaffold, SwiftData models, and data layer
- Phase 2: 5-tab navigation with NavigationPath, deep linking, and shared components
- Phase 3: Horse and client CRUD with edit views, search, and filtering
- Phase 4: Accounting system with transactions, reports, supplies, reminders, and barn management
- Phase 5: CI/CD pipeline with GitHub Actions and TestFlight deployment
- Phase 6: BarnHub Pro freemium subscription with StoreKit 2, paywall, and feature gating
- Phase 7: Live dashboard with at-a-glance stats, overdue alerts, and today's schedule preview
- Phase 8: Client invoice generation with PDF renderer, share sheet, and invoice history
- Phase 9: Horse health timeline with unified vet/farrier/weight view, filtering, and quick-add

### Better Swift Audit Fixes (2026-03-18)

- Replaced DispatchQueue.main.asyncAfter dismiss pattern with Task-based approach across 7 edit views
- Replaced .onAppear with .task for loadExisting in edit views
- Added icon+color status indicators in HorseRowView and ClientRowView (accessibility fix)
- HomeView converted to semantic fonts (.title, .headline)
- Extracted ToastState struct to reduce toast boilerplate
- AppearanceManager UserDefaults key confirmed namespaced (net.shadowpuppet.BarnBook.appearanceMode)
- Added test suites: DeepLinkHandlerTests, RouterTests, DateFormattingTests, InvoiceTests, TimelineEventTests, WeightEntryTests

### Backlog Fixes (2026-03-25)

- Simplified URL+App.swift static URLs — removed fatalError, switched to static let
- Fixed Task.sleep cancellation handling in ToastModifier — replaced try? with do/catch
- Replaced hardcoded .system(size: 48) font in ReportsView with semantic .largeTitle
- Extracted showAndDismiss helper in ToastState — DRY'd save-dismiss pattern across 7 edit views
- Added income/expense direction icons in TransactionRowView (accessibility)
- Added severity icons and "Out"/"Low" text labels in SupplyListView stock badges (accessibility)
- Extracted shared ScheduleRecordRow component from VetScheduleView and FarrierScheduleView
- Confirmed ReminderListView already uses single-pass categorization (not a triple-filter)
- Confirmed ClientDetailView intermediate array is necessary (used for both display and count)
- Confirmed StoreService already has deinit task cancellation
- Confirmed ClientsUpgradeView already uses @ScaledMetric for Dynamic Type
- Confirmed tests already strengthened: reminder dates, currency exact equality, displayName logic

### Deferred Items (Implemented)

- Reports with Swift Charts (was deferred, implemented in enhanced reports)
- CSV import/export for horses, clients, and transactions (was deferred, now available to all users)
- Photo capture for horse profiles (was deferred, now implemented)
