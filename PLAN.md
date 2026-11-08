# Development Plan

For completed work, see [DONE.md](./DONE.md). For localization workflow, see [scripts/LOCALIZATION.md](./scripts/LOCALIZATION.md).

## Next Up

1. **Test coverage for major views** — HomeView and its dashboard widgets, BarnDashboardView (560 LOC), HorseDetailView, ReportsView, InvoiceGeneratorView, ContractGeneratorView are uncovered. Core revenue and dashboard surfaces need regression protection.
2. **Address remaining audit perf items (HIGH/MEDIUM)** — cache computed sorts in HomeView, HealthTimelineView, ClientPaymentHistoryView; resolve photo task races in HorseEditView and ClientDocumentsView.
3. **Refactor oversize views** — extract domain-specific subviews from BarnDashboardView (560 LOC) for testability (HomeView and BarnHubApp.swift were split in #36).
4. **macOS parity test suite** — recent fix-on-fix pattern (sidebar width, empty-state centering, feed entry sheet, form duplicate labels) suggests need for a macOS-specific layout/snapshot test matrix.
5. **Onboarding conversion telemetry** — first-launch sheet ships in 1.6.1; add completion-rate tracking and per-stage drop-off metrics.

## Backlog

- [ ] `ToastView.swift` — replace hardcoded `Color.red` with brand error color
- [ ] `BarnHub.entitlements` — make `aps-environment` build-config dependent (currently hardcoded `development`)
- [ ] `BarnHub.entitlements` — add default-data-protection entitlement
- [ ] `ClientDocumentsView.swift:196` — set `FileProtectionLevel` on temp files (e.g., `.completeUntilFirstUserAuthentication`)
- [ ] `PreviewSampleData.swift` — wrap entire file in `#if DEBUG` (only the UIKit/AppKit imports are conditional today)
- [ ] `ContractPDFService.swift` / `InvoicePDFService.swift` — replace `UIColor` with platform-agnostic `Color` for macOS parity
- [ ] PDF service test coverage — `ContractPDFService` (278 LOC) and `InvoicePDFService` (180 LOC) are revenue-critical and untested
- [ ] `DataManagementView.swift:220` — surface specific CSV import errors (currently generic toast on silent `try?` failure)
- [ ] DRY toast state: `PaywallView`, `ClientHorsesView`

## Competitive Gaps

Verified against competitor public feature/pricing pages on 2026-05-05. Each entry cites the source so we can re-check as competitors evolve.

- [ ] **Multi-user / staff access (CloudKit shared zones)** — Stable Secretary offers customizable staff/provider/owner permissions (stablesecretary.com/features); Barn Manager offers unlimited team users on its plans (barnmanager.com). BarnHub today is single-Apple-ID. Foundational gap for boarding barns with multiple staff in the system simultaneously.
- [ ] **Boarder-facing client portal** — Stable Secretary ships Client Invoice & Booking Portals (stablesecretary.com/features); EquineGenie's clientGenie ($199 add-on) provides remote data entry (equinegenie.com). BarnHub has no logged-in client surface today; PDFs are emailed.
- [ ] **Stripe / card payment processing** — Stable Secretary's Professional tier collects board payments via Stripe inside the app (stablesecretary.com/features). BarnHub records payments but does not process them. Investigate whether StoreKit/Apple Pay or a Stripe SDK integration fits the "no third-party server" privacy model.
- [ ] **QuickBooks Online sync for invoices/transactions** — Barn Manager Pro tier syncs invoices to QuickBooks Online (barnmanager.com). BarnHub already exports CSV; direct QuickBooks API integration would close the gap. Already loosely tracked under "Export to QuickBooks/Xero" below — promote to Backlog when prioritized.
- [ ] **Show / competition tracking module** — EquineGenie has show/race/event tracking (equinegenie.com); Barn Manager has competition scheduling (barnmanager.com). BarnHub has no first-class shows feature; users currently fake it with reminders + notes.
- [ ] **Breeding / foaling records** — EquineGenie's BREEDER tier ($449) is built around stallion books, mare cycles, and foaling logs; Stable Secretary lists breeding records (equinegenie.com, stablesecretary.com/features). BarnHub has no breeding data model. Niche but high-value for breeding operations.
- [ ] **Structured training plans / skill progression** — EquineGenie's TRAINER tier ($399) covers training records (equinegenie.com). BarnHub tracks lessons (date, horse, client, notes) but not multi-stage training programs across many horses.

## Future / Ideas

- Home screen widgets for at-a-glance barn stats
- iPad keyboard shortcuts and command menu
- Apple Watch companion for quick-log feeds and reminders
- Siri Shortcuts for common actions (log feed, mark reminder done)
- Export to QuickBooks/Xero for clients with existing accounting workflows
- RTL layout pass if Arabic or Hebrew added later
