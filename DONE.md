# Done Log

Completed items archived from PLAN.md. For release notes, see `.changelogs/`.

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

### Deferred Items (Implemented)

- Reports with Swift Charts (was deferred, implemented in enhanced reports)
- CSV import/export for horses, clients, and transactions (was deferred, now available to all users)
- Photo capture for horse profiles (was deferred, now implemented)
