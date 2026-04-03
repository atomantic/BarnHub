#!/usr/bin/env python3
"""
Import Gemini translations into Localizable.xcstrings.

Usage:
    python3 scripts/import_from_gemini.py
    → reads  scripts/gemini_translations.json
    → writes BarnHub/Localizable.xcstrings (in place)
"""

import json
import os
import sys

XCSTRINGS = os.path.join(os.path.dirname(__file__), "../BarnHub/Localizable.xcstrings")
IN_JSON = os.path.join(os.path.dirname(__file__), "gemini_translations.json")

# Pure format/positional strings that had explicit en values — handle separately
# key -> en value to preserve (these were skipped during extraction)
EXPLICIT_EN_STRINGS = {
    "%.0f %@": "%1$.0f %2$@",
    "%@ – %@": "%1$@ – %2$@",
    "%@%lld": "%1$@%2$lld",
    "Imported %lld records. Errors: %@": "Imported %1$lld records. Errors: %2$@",
    "Imported %lld records.%@": "Imported %1$lld records.%2$@",
    "Version %@ (%@)": "Version %1$@ (%2$@)",
}

if not os.path.exists(IN_JSON):
    print(f"ERROR: {IN_JSON} not found.")
    print("Paste Gemini's JSON response into that file, then re-run this script.")
    sys.exit(1)

with open(IN_JSON) as f:
    gemini_data = json.load(f)

translations = gemini_data.get("translations", {})

with open(XCSTRINGS) as f:
    xcstrings = json.load(f)

strings = xcstrings.setdefault("strings", {})

missing = []
applied = 0
skipped = 0

for key, lang_map in translations.items():
    if key not in strings:
        missing.append(key)
        continue

    entry = strings[key]
    locs = entry.setdefault("localizations", {})

    for lang, value in lang_map.items():
        if not value or not value.strip():
            skipped += 1
            continue
        locs[lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value,
            }
        }
        applied += 1

# For the skipped explicit-en strings, copy en value to all target languages
# (they're format-only so the value is the same across all languages)
target_langs = [
    "de", "fr", "nl", "sv", "es-ES", "es-MX", "pt-BR", "it", "en-GB", "en-AU"
]
for key, en_value in EXPLICIT_EN_STRINGS.items():
    if key not in strings:
        continue
    entry = strings[key]
    locs = entry.setdefault("localizations", {})
    for lang in target_langs:
        if lang not in locs:
            locs[lang] = {
                "stringUnit": {
                    "state": "translated",
                    "value": en_value,
                }
            }
            applied += 1

with open(XCSTRINGS, "w") as f:
    json.dump(xcstrings, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Applied {applied} translations")
if skipped:
    print(f"Skipped {skipped} empty values")
if missing:
    print(f"WARNING: {len(missing)} keys from Gemini not found in xcstrings:")
    for k in missing:
        print(f"  - {repr(k)}")
print(f"\nDone — {XCSTRINGS} updated.")
print("Open Xcode to verify, then build.")
