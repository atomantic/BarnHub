# Development Plan

For completed work, see [DONE.md](./DONE.md).

## Next Up

- iPad-optimized sidebar layout with split view

## Future / Ideas

- Home screen widgets for at-a-glance barn stats
- ~~Lesson scheduling / calendar integration~~ (implemented)
- ~~Weight trend chart~~ (implemented)

## Better Swift Audit - 2026-03-28 [COMPLETED via PR #8]

Summary: 71/73 findings fixed across 60 files. PR merged 2026-03-28.

### Remaining (LOW — not auto-remediated)

| File | Primary Category | Reason |
|------|-----------------|--------|
| BarnHubApp.swift | Bugs & Perf | CRITICAL: try! crash |
| WeightChartView.swift | Bugs & Perf | CRITICAL: plotFrame! |
| SyncMonitor.swift | Bugs & Perf | HIGH: missing removeObserver |
| NotificationService.swift | Bugs & Perf | HIGH: hashValue collision |
| HomeView.swift | Bugs & Perf | HIGH: computed properties perf |
| HealthTimelineView.swift | Bugs & Perf | HIGH: events computed perf |
| ClientPaymentHistoryView.swift | Bugs & Perf | HIGH: 4x sort |
| HorseDetailView.swift | Bugs & Perf | MEDIUM: sorts in body |
| ClientDetailView.swift | Bugs & Perf | MEDIUM: sorts + route bug |
| ClientDocumentsView.swift | Bugs & Perf | MEDIUM: photo task race |
| HorseEditView.swift | Bugs & Perf | MEDIUM: photo task race |
| ConfirmationDialog.swift | Platform & SwiftUI | CRITICAL: accessibility bypass |
| Color+Brand.swift | Platform & SwiftUI | HIGH: no dark variants |
| ToastView.swift | Platform & SwiftUI | HIGH: hardcoded colors |
| LessonListView.swift | Platform & SwiftUI | HIGH: color indicator |
| HorseRowView.swift | Platform & SwiftUI | MEDIUM: Color.green + a11y |
| ClientRowView.swift | Platform & SwiftUI | MEDIUM: Color.green |
| SyncIndicatorView.swift | Platform & SwiftUI | LOW |
| StoreService.swift | Security | MEDIUM: hash + UserDefaults |
| Logger.swift | Security | MEDIUM: PII logging |
| BarnHub.entitlements | Security | LOW: aps-environment |
| SettingsView.swift | Code Quality | HIGH: force unwrap URL |
| DataExportService.swift | Code Quality | HIGH: silent try? |
| DataImportService.swift | Code Quality | HIGH: silent try? |
| ToastModifier.swift | Code Quality | MEDIUM: empty catch |
| ContractPDFService.swift | Code Quality | MEDIUM: UIColor |
| InvoicePDFService.swift | Code Quality | MEDIUM: UIColor |
| ContractGeneratorView.swift | Code Quality | MEDIUM: silent write |
| InvoiceGeneratorView.swift | Code Quality | MEDIUM: silent write |
| InvoiceHistoryView.swift | Code Quality | MEDIUM: silent write |
| DataManagementView.swift | Code Quality | MEDIUM: silent try? |
| Date+Formatting.swift | Code Quality | MEDIUM: uncached formatter |
| HorseListView.swift | DRY | nav destination dup |
| AccountingDashboardView.swift | DRY | nav destination dup |
| TransactionListView.swift | DRY | nav destination dup |
| ReminderListView.swift | DRY | nav destination dup |
| BarnNoteListView.swift | DRY | nav destination dup |
| SupplyListView.swift | DRY | nav destination dup |
| VetScheduleView.swift | DRY | duplicate view |
| FarrierScheduleView.swift | DRY | duplicate view |
| BarnDashboardView.swift | DRY | filter chain dup |
| ReportsView.swift | DRY | summaryCard + asShortCurrency |
| PaywallView.swift | DRY | toast state |
| ClientHorsesView.swift | DRY | toast state |
| DeepLinkHandler.swift | Architecture | LOW |
| PreviewSampleData.swift | Architecture | LOW |

- [ ] **[LOW]** `BarnHub.entitlements:6` — aps-environment hardcoded to development
- [ ] **[LOW]** `SettingsView.swift:174` — Secret code uses plain TextField instead of SecureField
- [ ] **[LOW]** `ClientDocumentsView.swift:175` — Temp files without explicit file protection
- [ ] **[LOW]** `BarnHub.entitlements` — Missing default-data-protection entitlement
- [ ] **[LOW]** `DeepLinkHandler.swift:42-46` — Supplies reachable via both Home and Schedule tabs
- [ ] **[LOW]** `PreviewSampleData.swift:8` — Not wrapped in #if DEBUG at file level
- [ ] **[LOW]** `BarnNoteListView.swift:19-39` — String-based note grouping fragile for i18n
