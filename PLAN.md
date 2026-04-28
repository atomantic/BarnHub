# Development Plan

For completed work, see [DONE.md](./DONE.md). For localization workflow, see [scripts/LOCALIZATION.md](./scripts/LOCALIZATION.md).

## Next Up

1. **Test coverage for major views** — HomeView (1014 LOC), BarnDashboardView (560 LOC), HorseDetailView, ReportsView, InvoiceGeneratorView, ContractGeneratorView are uncovered. Core revenue and dashboard surfaces need regression protection.
2. **Address remaining audit perf items (HIGH/MEDIUM)** — cache computed sorts in HomeView, HealthTimelineView, ClientPaymentHistoryView; resolve photo task races in HorseEditView and ClientDocumentsView.
3. **Refactor oversize views** — extract domain-specific subviews from HomeView (1014 LOC), BarnHubApp.swift (915 LOC), BarnDashboardView (560 LOC) for testability.
4. **macOS parity test suite** — recent fix-on-fix pattern (sidebar width, empty-state centering, feed entry sheet, form duplicate labels) suggests need for a macOS-specific layout/snapshot test matrix.
5. **Onboarding conversion telemetry** — first-launch sheet ships in 1.6.1; add completion-rate tracking and per-stage drop-off metrics.

## Backlog

- [ ] Verify `NotificationService.swift` hashValue collision is safe (audit flagged HIGH; default Hashable in use)
- [ ] `ToastView.swift` — replace hardcoded `Color.red` with brand error color
- [ ] `BarnHub.entitlements` — make `aps-environment` build-config dependent (currently hardcoded `development`)
- [ ] `BarnHub.entitlements` — add default-data-protection entitlement
- [ ] `ClientDocumentsView.swift:196` — set `FileProtectionLevel` on temp files (e.g., `.completeUntilFirstUserAuthentication`)
- [ ] `PreviewSampleData.swift` — wrap entire file in `#if DEBUG`
- [ ] `DataExportService.swift` / `DataImportService.swift` — surface silent `try?` failures via toast
- [ ] `ContractPDFService.swift` / `InvoicePDFService.swift` — replace `UIColor` with platform-agnostic `Color` for macOS parity
- [ ] `ToastModifier.swift` — replace empty catch with logged error
- [ ] `Date+Formatting.swift` — uncached formatter performance pass
- [ ] DRY duplicate views: `VetScheduleView` / `FarrierScheduleView` share more than just the row component
- [ ] DRY filter chains: `BarnDashboardView`, `ReportsView` (`summaryCard` + `asShortCurrency`)
- [ ] DRY toast state: `PaywallView`, `ClientHorsesView`

## Future / Ideas

- Home screen widgets for at-a-glance barn stats
- iPad keyboard shortcuts and command menu
- Apple Watch companion for quick-log feeds and reminders
- Siri Shortcuts for common actions (log feed, mark reminder done)
- Export to QuickBooks/Xero for clients with existing accounting workflows
- RTL layout pass if Arabic or Hebrew added later
