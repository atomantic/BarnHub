# Localization Workflow (Gemini-assisted)

The app uses Xcode String Catalogs (`BarnHub/Localizable.xcstrings`) with English as the source language and 8 target locales:

| Locale | Language |
|--------|----------|
| `de` | German |
| `fr` | French |
| `nl` | Dutch |
| `sv` | Swedish |
| `es-ES` | Spanish (Spain) |
| `es-MX` | Spanish (Mexico) |
| `pt-BR` | Portuguese (Brazil) |
| `it` | Italian |

## Bulk-translate via Gemini

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

## Notes

- Pure format-reordering strings (`%.0f %@`, `%@ – %@`, etc.) are copied as-is to all locales — they have no translatable text
- `^[%lld client](inflect: true)` / `^[%lld horse](inflect: true)` — Gemini translates the noun inside the brackets; Apple's grammar engine handles inflection
- `$0` / `$0.00` — currency format placeholders, Gemini will keep them unchanged
- Use `Locale`-aware formatters for currency/weight/date — already done in the app
- Consider RTL layout pass if Arabic (`ar`) or Hebrew (`he`) are added later
