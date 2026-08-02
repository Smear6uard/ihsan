#!/usr/bin/env python3
"""Regenerate ADHKAR_REVIEW.md from the bundled content file.

The review artifact is not written by hand. It is a rendering of
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`,
so a text can never be reviewed in one place and shipped from another.

    python3 docs/adhkar/generate-review.py

`AdhkarReviewArtifactTests` asserts the checked-in document still
covers every item in the content file; if it fails, run this.
"""

from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
CONTENT = ROOT / "Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json"
OUTPUT = ROOT / "ADHKAR_REVIEW.md"

CATEGORY_TITLES = {
    "morning": "Morning set",
    "evening": "Evening set",
    "postPrayer": "After each prayer",
    "sleep": "Before sleep",
    "situational": "Occasioned duas (no surface in this build)",
}

CATEGORY_ORDER = ["morning", "evening", "postPrayer", "sleep", "situational"]

HEADER = """# ADHKĀR — REVIEW REQUEST

**Status: DRAFT — PENDING SCHOLAR REVIEW.**

This document is generated from the app's single content file,
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`
(schema {schema}, content {version}). It is the complete set of
religious text Ihsan is able to display. There is no other source:
no network fetch, no generated text, no fallback strings. The
on-device model never touches any of it.

## What is being asked

Please read each item below and check its box when you are satisfied
with **all four** of:

1. **Arabic** — orthography and tashkeel as transmitted.
2. **Translation** — faithful, not interpretive beyond necessity.
3. **Source** — collection and number correct, and the report sound
   enough to be offered as a daily practice.
4. **Count** — the transmitted repetition, where one is transmitted.

Items whose reference carries a `verify reference` warning were
transcribed with the wording confident but the collection number
uncertain. Those numbers need checking against a printed copy before
anything ships.

## How the app uses this

- Each set is offered only inside its own time window (morning:
  Fajr→sunrise, extending into mid-morning; evening: ʿAṣr→Maghrib,
  optionally into the early night; after-prayer: from a logged
  prayer; before sleep: after ʿIshāʾ is logged). There is no search,
  no browse-all list, no library.
- Items are counted on the app's existing dhikr instrument. Sessions
  are recorded as plain facts — no streaks, no scores, no percentages.
- The occasioned duas at the end are carried in the file and reviewed
  here, but **no surface in this build offers them**. They are
  reviewed now so that a future occasioned surface starts from vetted
  text.

## Editorial decisions taken (please confirm or correct)

- **Honorifics.** The editorial ﷺ that printed compilations insert
  after the Prophet's name inside a duʿāʾ text has been omitted, so
  that only the transmitted words of the duʿāʾ appear. This affects
  *Raḍītu bi'llāhi Rabban*.
- **Verse numbering.** Qurʾānic passages are set as continuous
  recitation without ornate verse markers, since these are recited as
  remembrance rather than read from a muṣḥaf. Pause marks (ۖ ۗ ۚ) are
  kept.
- **Basmala.** The three Quls are given with the basmala, as they are
  recited. Āyat al-Kursī and the closing verses of al-Baqarah are
  given without it, as they are mid-sūrah.
- **Orthography.** Qurʾānic text follows the common printed ʿUthmānī
  form; ḥadīth text follows standard modern orthography with full
  tashkeel. This mixed convention matches how Ḥiṣn al-Muslim and
  similar compilations are typeset.
- **Transliteration** is provided as a pronunciation aid only and is
  collapsible in the app's settings.

## The gate

The app will not show any of this in a release build while the
content file reads `"reviewStatus": "draft"`. `AdhkarAvailability`
enforces it in code, and `AdhkarReviewGateTests` enforces that the
enforcement exists. When this document is signed, the maintainer
changes that one field to `"reviewed"`.

---

"""

FOOTER = """
---

## Reviewer sign-off

- Reviewer: ______________________________________________
- Date: __________________________________________________
- Qualifications / institution: ___________________________
- Notes, corrections, or items to remove:

  ```
  (space for corrections — please mark the item id)
  ```

- [ ] I have read every item above and the content file may be
      marked `reviewed`.

Once signed, set `"reviewStatus": "reviewed"` in
`Packages/IhsanCore/Sources/IhsanCore/Resources/adhkar-content.json`
and bump `contentVersion`.
"""


def render(content: dict) -> str:
    items = content["items"]
    lines = [
        HEADER.format(
            schema=content["schemaVersion"], version=content["contentVersion"]
        )
    ]

    counts = {c: len([i for i in items if i["category"] == c]) for c in CATEGORY_ORDER}
    flagged = [i for i in items if i["source"].get("needsVerification")]

    lines.append("## Contents\n")
    for category in CATEGORY_ORDER:
        lines.append(
            f"- **{CATEGORY_TITLES[category]}** — {counts[category]} items"
        )
    lines.append(f"\n**Total: {len(items)} items.** "
                 f"{len(flagged)} carry a reference to verify.\n")

    for category in CATEGORY_ORDER:
        group = sorted(
            (i for i in items if i["category"] == category),
            key=lambda i: i["order"],
        )
        if not group:
            continue
        lines.append(f"\n## {CATEGORY_TITLES[category]}\n")
        for item in group:
            lines.append(render_item(item))

    lines.append(FOOTER)
    return "\n".join(lines)


def render_item(item: dict) -> str:
    source = item["source"]
    citation = f"{source['collection']} — {source['reference']}"
    if source.get("needsVerification"):
        citation += "  **⚠ verify reference**"

    count = item["repetitions"]
    count_text = "once" if count == 1 else f"×{count}"

    parts = [
        f"### {item['order']}. `{item['id']}`\n",
        f"- [ ] Arabic, translation, source, and count are all correct.\n",
        "> " + item["arabic"] + "\n",
        f"**Transliteration.** {item['transliteration']}\n",
        f"**Translation.** {item['translation']}\n",
        f"**Source.** {citation}\n",
        f"**Count.** {count_text}\n",
    ]
    if item.get("note"):
        parts.append(f"**Occasion.** {item['note']}\n")
    return "\n".join(parts)


def main() -> int:
    content = json.loads(CONTENT.read_text(encoding="utf-8"))
    OUTPUT.write_text(render(content), encoding="utf-8")
    print(f"wrote {OUTPUT.relative_to(ROOT)} — {len(content['items'])} items")
    return 0


if __name__ == "__main__":
    sys.exit(main())
