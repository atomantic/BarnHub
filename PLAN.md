# Development Plan

For completed work, see [DONE.md](./DONE.md).

## Next Up

1. **Local push notifications for reminders** — schedule UserNotifications for overdue reminders, vet appointments, and farrier visits so barn managers get alerts when not in the app; morning summary notification for today's tasks
2. **Boarding agreements & contract templates** — extend InvoicePDFService to generate boarding contracts, liability waivers, and care agreements as shareable PDFs; Pro-only feature
3. **iCloud sync status indicator** — show subtle sync state in the UI so users know if data is up-to-date across devices; handle CloudKit merge conflicts gracefully

## Backlog

- [ ] Fix `URL+App.swift` force unwraps — fatalError on static URLs will crash in production if strings are malformed; use safe computed properties
- [ ] Fix `try?` on `Task.sleep` in ToastModifier (lines 34, 56) — suppresses cancellation errors; use `try await` with proper cancellation handling
- [ ] Fix hardcoded `.system(size:)` fonts in ReportsView and ClientsUpgradeView — use semantic fonts or `@ScaledMetric` for Dynamic Type support
- [ ] Extract shared save() helper from 5+ edit views (~30 lines of duplicated insert-or-update boilerplate each)
- [ ] Extract shared `isNew` / `existingModel` computed properties from edit views into reusable pattern
- [ ] Unify VetScheduleView / FarrierScheduleView near-identical row builders into shared component
- [ ] Optimize ReminderListView triple-filter into single categorized pass
- [ ] Fix StoreService untracked background Tasks — add deinit cancellation for `updateTask` and `setupTask`
- [ ] Fix redundant array allocation in ClientDetailView
- [ ] Extract ReportsView inline data aggregation into dedicated computed properties or model
- [ ] Add icon alongside color for TransactionRowView and SupplyListView status indicators (accessibility)
- [ ] Strengthen weak tests: testReminderNextOccurrence (verify actual dates), testCurrencyFormatting (exact equality), testTransactionEnums (test custom logic not language features)
- [ ] Add accessibility labels on decorative images across views

## Future / Ideas

- iPad-optimized sidebar layout with split view
- Home screen widgets for at-a-glance barn stats
- Lesson scheduling / calendar integration
