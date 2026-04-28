# Development Plan

For completed work, see [DONE.md](./DONE.md).

## Next Up

_(no items)_

## Localization

Priority targets based on equestrian market size and activity:

| Locale | Language | Notes |
|--------|----------|-------|
| `en` | English | Base locale — already implemented |
| `de` | German | Germany leads globally in dressage and showjumping; strong FEI presence |
| `fr` | French | France has major racing (Prix de l'Arc), eventing, and breeding industries |
| `nl` | Dutch | Netherlands is home to KWPN — one of the world's premier warmblood studbooks |
| `sv` | Swedish | Sweden punches far above its weight in Olympic equestrian sports |
| `es-ES` | Spanish (Spain) | Andalusian/PRE breeding hub; strong traditional horsemanship culture |
| `es-MX` | Spanish (Mexico) | Large horse population; charreada (Mexican rodeo) is the national sport |
| `pt-BR` | Portuguese (Brazil) | Brazil has one of the largest horse populations in the world (~5.5M horses) |
| `it` | Italian | Italy has a significant racing and sport horse industry |

### Translation Workflow (Gemini-assisted)

328 strings in `BarnHub/Localizable.xcstrings`, source language `en`.
Target locales: `de`, `fr`, `nl`, `sv`, `es-ES`, `es-MX`, `pt-BR`, `it`.

**Step 1 — Extract**
```bash
python3 scripts/extract_for_gemini.py
```
Outputs:
- `scripts/strings_for_translation.json` — structured string list
- `scripts/GEMINI_PROMPT.txt` — ready-to-paste Gemini prompt

**Step 2 — Translate**
- Open [gemini.google.com](https://gemini.google.com) (use Gemini 2.5 Pro for best quality)
- Paste the full contents of `scripts/GEMINI_PROMPT.txt`
- Copy the JSON response → save as `scripts/gemini_translations.json`

**Step 3 — Import**
```bash
python3 scripts/import_from_gemini.py
```
Updates `BarnHub/Localizable.xcstrings` in place with all translations.

**Step 4 — Verify & build**
```bash
xcodebuild build -project BarnHub.xcodeproj -scheme BarnHub \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```
Spot-check a few strings in Xcode's String Catalog editor.

### Notes

- 6 pure format-reordering strings (`%.0f %@`, `%@ – %@`, etc.) are copied as-is to all locales — they have no translatable text
- `^[%lld client](inflect: true)` / `^[%lld horse](inflect: true)` — Gemini translates the noun inside the brackets; Apple's grammar engine handles inflection
- `$0` / `$0.00` — currency format placeholders, Gemini will keep them unchanged
- Use `Locale`-aware formatters for currency/weight/date — already done in the app
- Consider RTL layout pass if Arabic (`ar`) or Hebrew (`he`) are added later

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
| ~~StoreService.swift~~ | ~~Security~~ | ~~MEDIUM: hash + UserDefaults~~ (resolved — secret-code flow removed) |
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
- [x] ~~**[LOW]** `SettingsView.swift:174` — Secret code uses plain TextField instead of SecureField~~ (resolved — secret-code flow removed)
- [ ] **[LOW]** `ClientDocumentsView.swift:175` — Temp files without explicit file protection
- [ ] **[LOW]** `BarnHub.entitlements` — Missing default-data-protection entitlement
- [ ] **[LOW]** `DeepLinkHandler.swift:42-46` — Supplies reachable via both Home and Schedule tabs
- [ ] **[LOW]** `PreviewSampleData.swift:8` — Not wrapped in #if DEBUG at file level
- [ ] **[LOW]** `BarnNoteListView.swift:19-39` — String-based note grouping fragile for i18n
