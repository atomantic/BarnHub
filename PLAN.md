# Development Plan

For completed work, see [DONE.md](./DONE.md).

## Next Up

1. **Boarding agreements & contract templates** — extend InvoicePDFService to generate boarding contracts, liability waivers, and care agreements as shareable PDFs; Pro-only feature
2. **iCloud sync status indicator** — show subtle sync state in the UI so users know if data is up-to-date across devices; handle CloudKit merge conflicts gracefully

## Backlog

- [ ] Extract shared `isNew` / `existingModel` computed properties from edit views into reusable pattern
- [ ] Extract ReportsView inline data aggregation into dedicated computed properties or model
- [ ] Add accessibility labels on decorative images across views

## Future / Ideas

- iPad-optimized sidebar layout with split view
- Home screen widgets for at-a-glance barn stats
- Lesson scheduling / calendar integration
