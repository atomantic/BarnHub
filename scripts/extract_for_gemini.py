#!/usr/bin/env python3
"""
Extract strings from Localizable.xcstrings into a JSON file ready for Gemini translation.

Usage:
    python3 scripts/extract_for_gemini.py
    → writes scripts/strings_for_translation.json
    → writes scripts/GEMINI_PROMPT.txt (copy-paste this into Gemini)
"""

import json
import os

XCSTRINGS = os.path.join(os.path.dirname(__file__), "../BarnHub/Localizable.xcstrings")
OUT_JSON = os.path.join(os.path.dirname(__file__), "strings_for_translation.json")
OUT_PROMPT = os.path.join(os.path.dirname(__file__), "GEMINI_PROMPT.txt")

TARGET_LANGUAGES = ["de", "fr", "nl", "sv", "es-ES", "es-MX", "pt-BR", "it", "en-GB", "en-AU"]

# Strings where the key itself is just a format specifier or single char — skip translation
SKIP_KEYS = {
    "%.0f %@",   # pure format string — argument reordering only
    "%@ – %@",   # pure format string
    "%@%lld",    # pure format string
    "%lld",      # pure number
    "Imported %lld records. Errors: %@",   # has explicit en value with reordering
    "Imported %lld records.%@",            # has explicit en value with reordering
    "Version %@ (%@)",                     # has explicit en value with reordering
}

with open(XCSTRINGS) as f:
    data = json.load(f)

strings = data.get("strings", {})
output = []

for key, meta in strings.items():
    if key in SKIP_KEYS:
        continue

    locs = meta.get("localizations", {})
    en_entry = locs.get("en", {})
    en_value = en_entry.get("stringUnit", {}).get("value", key)
    comment = meta.get("comment", "")

    entry = {"key": key, "en": en_value}
    if comment:
        entry["comment"] = comment

    output.append(entry)

payload = {
    "target_languages": TARGET_LANGUAGES,
    "strings": output,
}

with open(OUT_JSON, "w") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)

print(f"Wrote {len(output)} strings to {OUT_JSON}")

# Write the Gemini prompt
prompt = f"""You are a professional translator specializing in mobile app localization for equestrian barn management software.

Translate all strings in the JSON below into these languages: {", ".join(TARGET_LANGUAGES)}

CRITICAL RULES:
1. Preserve ALL format specifiers EXACTLY: %@, %lld, %1$@, %2$@, %1$lld, %2$@, etc.
   - %@ = string placeholder, %lld = integer, %.0f = float
   - Numbered variants like %1$@ allow argument reordering — keep numbering but you MAY reorder them if the grammar of the target language requires it
2. For ^[%lld word](inflect: true) strings (Apple grammar engine): just translate the WORD inside the brackets. Keep the ^ [ ] (inflect: true) syntax exactly.
3. For strings that are inherently English-agnostic (single letters used as chart labels like "A", "B", "C", "D", "M", "V", numbers "0", currency format "$0", "$0.00"), use the SAME value in all languages.
4. en-GB and en-AU are British/Australian English — use appropriate British/Australian spellings (e.g. "colour" not "color", "grey" not "gray") and vocabulary where relevant. Most strings will be identical to US English.
5. Use formal register appropriate for a professional business app.
6. Keep equestrian terms accurate — this is a barn management app for horse owners, riding instructors, and equestrian businesses. Key domain terms: farrier, vet record, boarding, stall, gelding, mare, etc.

Return ONLY a JSON object in this exact format — no markdown, no code fences, no explanation:
{{
  "translations": {{
    "<exact key from input>": {{
      "de": "...",
      "fr": "...",
      "nl": "...",
      "sv": "...",
      "es-ES": "...",
      "es-MX": "...",
      "pt-BR": "...",
      "it": "...",
      "en-GB": "...",
      "en-AU": "..."
    }},
    ...
  }}
}}

Every key from the input must appear in the output. Do not skip any string.

INPUT JSON:
{json.dumps(payload, ensure_ascii=False, indent=2)}
"""

with open(OUT_PROMPT, "w") as f:
    f.write(prompt)

print(f"Wrote Gemini prompt to {OUT_PROMPT}")
print(f"\nNext steps:")
print(f"  1. Open GEMINI_PROMPT.txt and paste into Gemini (gemini.google.com)")
print(f"  2. Copy the JSON response")
print(f"  3. Save it as scripts/gemini_translations.json")
print(f"  4. Run: python3 scripts/import_from_gemini.py")
