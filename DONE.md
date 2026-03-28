# Done Log

Completed items archived from PLAN.md. For release notes, see `.changelogs/`.

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
