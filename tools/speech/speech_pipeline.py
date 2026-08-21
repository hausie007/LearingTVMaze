#!/usr/bin/env python3
"""
Studio Voice build pipeline — Learning Maze.

Turns the declared speech catalog into approved, shipped audio clips:

    extract -> plan -> generate -> process -> review -> pack -> verify

Only `generate` and `voices` touch the network. Only `generate` spends money,
and it refuses to do so without an explicit --confirm and a character budget.
Everything else is safe to run in CI, offline, as often as you like.

The pipeline is idempotent. Every stage compares hashes and does only the work
that is actually missing, so re-running it costs nothing and never overwrites an
approved clip in place.

    python3 tools/speech/speech_pipeline.py doctor
    python3 tools/speech/speech_pipeline.py extract
    python3 tools/speech/speech_pipeline.py plan --language cs

Requires Python 3.8+ and, for `process` only, ffmpeg/ffprobe on PATH.
No third-party packages, by design: this runs on a fresh machine years from now.

See tools/speech/README.md for the workflow and tools/speech/SETUP.md for
getting an ElevenLabs account and choosing a voice.
"""

from __future__ import annotations

import argparse
import array
import csv
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unicodedata
from pathlib import Path

# --------------------------------------------------------------------------
# Paths
# --------------------------------------------------------------------------

REPO = Path(__file__).resolve().parents[2]

SPEECH_SRC = REPO / "data" / "speech"
CATALOG = SPEECH_SRC / "catalog.json"
VOICE_PROFILES = SPEECH_SRC / "voice_profiles.json"
PRONUNCIATIONS = SPEECH_SRC / "pronunciations"
REVIEWS = SPEECH_SRC / "reviews"

BUILD = REPO / "build" / "speech"
DESIRED = BUILD / "desired.jsonl"
PLAN_JSON = BUILD / "plan.json"

MASTERS = REPO / "voice_masters"
MASTERS_RAW = MASTERS / "raw"
MASTERS_PROCESSED = MASTERS / "processed"
LEDGER = MASTERS / "generation_ledger.jsonl"

PACKS = REPO / "voices"

WORDS = REPO / "data" / "words"
GAME_CONFIG = REPO / "scripts" / "game_config.gd"
TRANSLATIONS = REPO / "data" / "translations.csv"
PROJECT_GODOT = REPO / "project.godot"

API_BASE = "https://api.elevenlabs.io/v1"


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------

class Fail(Exception):
    """A condition the user must fix. Printed without a traceback."""


def nfc(text: str) -> str:
    """Normalise so that two spellings of the same accented letter hash alike."""
    return unicodedata.normalize("NFC", text).strip()


def canonical_hash(obj) -> str:
    blob = json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def maybe_json(path: Path) -> dict:
    """Read a JSON file, or nothing if it is not there or is unreadable.

    For the files that are absent as a matter of course: a boundary sidecar
    before its clip has been re-encoded, an audit verdict before the check has
    run. Their absence is a state, not a failure, and treating it as one
    stopped a whole language mid-run.
    """
    if not path.exists():
        return {}
    try:
        return read_json(path) or {}
    except (Fail, ValueError, OSError):
        return {}


def read_json(path: Path):
    if not path.exists():
        raise Fail(f"missing file: {path.relative_to(REPO)}")
    try:
        with path.open(encoding="utf-8") as fh:
            return json.load(fh)
    except json.JSONDecodeError as exc:
        raise Fail(f"{path.relative_to(REPO)} is not valid JSON: {exc}")


def write_atomic(path: Path, data: bytes) -> None:
    """Write via a temp file in the same directory, then rename.

    A half-written clip that looks complete is worse than no clip, because the
    hash check would pass on a truncated file if it were hashed after the fact.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".part")
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def ensure_guards() -> None:
    """Create build/ and voice_masters/ with a .gdignore already in place.

    Godot imports anything under the project root, and an imported 50 MB of
    masters would be exported into the AAB. The guard has to exist before the
    folder has contents, not after someone notices.
    """
    for folder in (MASTERS, BUILD.parent):
        folder.mkdir(parents=True, exist_ok=True)
        guard = folder / ".gdignore"
        if not guard.exists():
            guard.touch()


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO))
    except ValueError:
        return str(path)


def info(msg: str = "") -> None:
    print(msg)


def warn(msg: str) -> None:
    print(f"  warning: {msg}")


# --------------------------------------------------------------------------
# Grapheme markers — the Python twin of scripts/grapheme_text.gd
# --------------------------------------------------------------------------
#
# Kept deliberately short and kept in step by hand. `verify` re-checks the
# alphabet strings against game_config.gd, which is what would catch a drift.

OPEN, CLOSE = "[", "]"


def grapheme_split(marked: str):
    out, i, n = [], 0, len(marked)
    while i < n:
        ch = marked[i]
        if ch == OPEN:
            close_at = marked.find(CLOSE, i + 1)
            if close_at == -1:
                out.extend(list(marked[i + 1:]))
                break
            group = marked[i + 1:close_at]
            if group:
                out.append(group)
            i = close_at + 1
        elif ch == CLOSE:
            i += 1
        else:
            out.append(ch)
            i += 1
    return out


def grapheme_strip(marked: str) -> str:
    return marked.replace(OPEN, "").replace(CLOSE, "")


def grapheme_validate(marked: str) -> str:
    depth, start, glen = 0, -1, 0
    for i, ch in enumerate(marked):
        if ch == OPEN:
            if depth:
                return f"nested '{OPEN}' at {i}"
            depth, start, glen = 1, i, 0
        elif ch == CLOSE:
            if not depth:
                return f"unmatched '{CLOSE}' at {i}"
            if glen < 2:
                return f"group at {start} must contain at least 2 characters"
            depth = 0
        elif depth:
            glen += 1
    if depth:
        return f"unclosed '{OPEN}' at {start}"
    return ""


# --------------------------------------------------------------------------
# Sources
# --------------------------------------------------------------------------

def load_catalog() -> dict:
    cat = read_json(CATALOG)
    if cat.get("schema_version") != 1:
        raise Fail(f"catalog.json schema_version {cat.get('schema_version')} is not supported")
    return cat


def load_profiles() -> dict:
    doc = read_json(VOICE_PROFILES)
    return doc.get("profiles", {})


def load_overrides(locale: str) -> dict:
    path = PRONUNCIATIONS / f"{locale}.json"
    if not path.exists():
        return {}
    doc = read_json(path)
    return doc.get("overrides", {})


def enabled_languages(cat: dict, only=None):
    langs = []
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled"):
            continue
        if only and lang not in only:
            continue
        langs.append(lang)
    if only:
        unknown = [l for l in only if l not in cat["languages"]]
        if unknown:
            raise Fail(f"not in catalog.json: {', '.join(unknown)}")
        disabled = [l for l in only if l in cat["languages"] and l not in langs]
        if disabled:
            raise Fail(
                f"{', '.join(disabled)} is disabled in catalog.json. "
                "Add its numbers_<lang>.json and letters_<lang>.json, then set enabled: true."
            )
    return sorted(langs)


# --------------------------------------------------------------------------
# extract
# --------------------------------------------------------------------------

def word_slug(word: str) -> str:
    """A stable ASCII id for a vocabulary word.

    Keys are not filenames — clips are content-addressed — but a key that
    survives a grep, a CSV and a spreadsheet is worth more than one that carries
    diacritics through five tools unscathed.
    """
    folded = unicodedata.normalize("NFKD", word.lower())
    folded = "".join(c for c in folded if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]+", "_", folded).strip("_")


def word_items(cat: dict, lang: str, cspec: dict):
    """Every vocabulary word for a language, across all difficulty tiers.

    Only the `word` field is read. The emoji is a picture hint on screen and has
    no business in a recording; nothing here ever sees it.
    """
    folder = REPO / cspec["source_dir"]
    files = sorted(folder.glob(cspec["source_glob"].format(lang=lang)))
    if not files:
        raise Fail(f"no word files for {lang} in {rel(folder)}")

    found = {}
    for path in files:
        for entry in read_json(path):
            marked = entry.get("word", "")
            problem = grapheme_validate(marked)
            if problem:
                raise Fail(f"{path.name}: {marked!r} — {problem}")
            # Markers are an authoring device for the maze; speech never sees
            # them, and neither does the identity of the word.
            display = nfc(grapheme_strip(marked))
            if not display:
                raise Fail(f"{path.name}: empty word entry")
            if display in found:
                raise Fail(f"{display!r} appears in both {found[display][1]} and {path.name}")
            found[display] = (marked, path.name)

    # Two words can fold to one ASCII slug — Czech KOS and KOŠ both give "kos".
    # Rather than let the second silently win, or number them by whichever file
    # was read first, disambiguate with a short digest of the word itself. It is
    # stable, and it only appears where it is actually needed.
    slugs = {}
    for display in sorted(found):
        slugs.setdefault(word_slug(display), []).append(display)

    # The mid-phrase narration speaks what has been spelled so far: THIS, then
    # THIS IS, then THIS IS GOOD. Those partials are not recorded.
    #
    # They were, once — as separate clips — and it was the wrong shape. Each
    # partial was its own reading, so the phrase changed character as the child
    # collected it, which is exactly the sort of inconsistency a four-year-old
    # notices. The full recording is played and stopped at a word boundary
    # instead: one performance, revealed a word at a time. `align` supplies the
    # boundaries; nothing extra is synthesised.
    items = []
    for slug, group in sorted(slugs.items()):
        for display in group:
            ident = slug if len(group) == 1 else (
                f"{slug}_{hashlib.sha256(display.encode('utf-8')).hexdigest()[:4]}")
            # Lowercasing is a remedy for one failure — an all-capitals word
            # invites the model to spell it out — and it is the wrong remedy for
            # a script where the two cases do not carry the same information.
            # Greek writes no stress accent in capitals, so a word list stored
            # in capitals has none to lose, and lowercasing it produces text no
            # Greek reader would write: 'μελι' for 'μέλι'. Whether that or the
            # capitals read better is a question for the ear, per language, so
            # the language may say. Default stays lower for everyone else.
            case = cat["languages"].get(lang, {}).get("case", cspec.get("case"))
            spoken = display.lower() if case == "lower" else display
            items.append((cspec["key_format"].format(id=ident), display, spoken,
                          rel(REPO / cspec["source_dir"] / found[display][1])))
    items.sort(key=lambda x: x[0])
    return items


def load_retakes(lang: str) -> dict:
    """Per-key retake counters. Bumping one asks for that clip to be redone.

    A retake is recorded on its own, never inside a sheet. Sheets buy
    consistency at the price of a cutting step, and when a clip is being redone
    it is usually the cutting that went wrong — Czech sheet 7 had an inter-item
    pause shorter than a pause inside one of its phrases, which no single
    threshold can resolve. One request for one clip has no boundaries to find
    and so cannot get them wrong.
    """
    path = SPEECH_SRC / "retakes.json"
    if not path.exists():
        return {}
    doc = read_json(path)
    return doc.get("languages", {}).get(lang, {})


def retake_context(entry: dict):
    """How an isolated retake is given a run-up, if it needs one.

    A clip recorded alone arrives cold: the first Czech retake of BUDOVA opened
    at -8 dBFS in its very first frame, the /b/ already under way, where a sheet
    take of the same voice opens at -89 and rises into the word.

    Two ways to fix that. `previous_text` asks the provider to behave as though
    it had just said something — elegant, and eleven_v3 rejects it outright
    ("not yet supported with the 'eleven_v3' model"). So the fallback is a
    carrier: speak a throwaway word first, then the real one, and keep only the
    second. That is a two-item sheet, which is the one sheet size whose cutting
    is never ambiguous — a single long gap in the middle and nothing else to
    confuse.
    """
    context = {k: entry[k] for k in ("previous_text", "next_text") if entry.get(k)}
    for k in ("carrier_before", "carrier_after"):
        if entry.get(k):
            context[k] = list(entry[k])
        elif entry.get(k) is not None and int(entry.get("n", 0)) > 0:
            # An empty list is an answer, not an absence: it says "record this
            # one with nothing either side of it". It has to reach make_record,
            # because that is where a category's own carriers are put back when
            # the retake named none — and then the retake tests the opposite of
            # what it asked for. Romanian is the case that needed it: that voice
            # runs a list of short letter names together with no gap — 15 items
            # in 7.4s yielding three detectable sounds — so wrapping a retake in
            # carriers cut it against a reading that cannot be cut, which is the
            # fault the retake was undoing. Set it only where that is true: a
            # token read with no context at all invites the model to interpret
            # it rather than say it, and Romanian 'ics' duly came back as four
            # syllables with the letter spelled out.
            # Guarded on n so an entry that is not actually asking for a retake
            # cannot put a context key into a normal record's spec hash.
            context[k] = []
    return context or None


def number_form_items(cat: dict, lang: str, cspec: dict):
    """Numbers in the case a sentence puts them in, where that differs.

    Only recorded where the inflected form is not the citation form already —
    English 'to fifty' is the plain number, so English records nothing here and
    Czech records most of fifty.
    """
    path = REPO / cspec["source"]
    if not path.exists():
        return []
    doc = read_json(path)
    entry = doc.get("languages", {}).get(lang, {})
    plain = read_json(SPEECH_SRC / f"numbers_{lang}.json") if (SPEECH_SRC / f"numbers_{lang}.json").exists() else {"numbers": []}
    citation = {str(n["value"]): nfc(n["spoken"]) for n in plain.get("numbers", [])}

    items = []
    for case, values in entry.items():
        if case == "review" or not isinstance(values, dict):
            continue
        for value, text in sorted(values.items(), key=lambda kv: int(kv[0])):
            text = nfc(text)
            if not text or text == citation.get(value):
                continue
            items.append((cspec["key_format"].format(case=case, value=int(value)), text, text))
    return items


def ui_items(cat: dict, lang: str, cspec: dict):
    """Every fixed piece of UI the game speaks, in one language.

    Templates are split on their %s placeholders, because that is what the
    runtime does: the recap speaks "You counted to", then the number, then
    whatever follows, as separate segments. Recording the fragments therefore
    needs no change to how the recap is built.

    Fragments that repeat across templates are recorded once — "You spelled the
    word" is both its own key and the opening of another — since resolution is
    by text.
    """
    doc = read_json(SPEECH_SRC / cspec["source"])
    with TRANSLATIONS.open(encoding="utf-8", newline="") as fh:
        rows = list(csv.reader(fh))
    header = rows[0]
    if lang not in header:
        raise Fail(f"translations.csv has no column for {lang}")
    column = header.index(lang)
    text_for = {r[0]: r[column] for r in rows[1:] if r and len(r) > column}

    items, seen = [], {}
    for key in doc["keys"]:
        template = text_for.get(key, "").strip()
        if not template:
            warn(f"translations.csv has no {lang} text for {key} — skipped")
            continue
        for index, fragment in enumerate(template.split("%s")):
            fragment = nfc(fragment.strip(" \t\n,.:;"))
            if len(fragment) < 2:
                continue
            if fragment in seen:
                continue
            seen[fragment] = True
            items.append((f"ui.{key}.{index}", fragment, fragment))
    return items


def category_settings(profile: dict, category: str) -> dict:
    """Per-category synthesis settings, where a category needs different ones.

    Interface fragments are the case that forced this. They are short function
    words — "do", "v", "písmeno" — and a sheet of them has gaps no larger than
    the gaps inside them, which is the one situation sheet cutting cannot
    survive. The first Czech UI sheet merged two and then shifted every cut
    after it by one, ending in a silent clip.
    """
    return (profile.get("categories") or {}).get(category, {})


def category_mode(cat: dict, profile: dict, category: str) -> str:
    """How a category is recorded, with the catalog getting the final say.

    The rule belongs to the category, not to the voice. It was a per-profile
    override at first, and German then arrived without it: its UI fragments
    were sheet-cut, one cut slipped, and every clip after it held the next
    one's words. The catalog now carries the default so a new language cannot
    be added without it, and a profile may still override for a voice that
    genuinely needs something else.
    """
    settings = category_settings(profile, category)
    return settings.get("synthesis_mode",
                        cat["categories"].get(category, {}).get("synthesis_mode",
                            profile.get("synthesis_mode", "single")))


def categories_for(cat: dict, lang: str, lspec: dict) -> list:
    """What a language records. Everything it can, unless it says otherwise.

    This used to be an explicit list per language, and German shipped without
    "ui" in it — so its title, its menu language names and its recap framing
    quietly fell back to the device voice, and nobody could see why. A list
    that must be remembered is a list that will be forgotten. The default is
    now everything the language has the data for; naming categories explicitly
    still works, for a language deliberately kept to letters and numbers.
    """
    if lspec.get("categories"):
        return lspec["categories"]
    out = []
    for name, cspec in cat["categories"].items():
        if name == "number_form":
            # Only where the language actually inflects. English "to fifty" is
            # the plain number already, so there is nothing to record.
            forms = read_json(REPO / "data" / "number_forms.json")
            if not (forms.get("languages", {}).get(lang, {}).get("to")):
                continue
        out.append(name)
    return out


def make_record(cat, profile, lang, locale, category, cspec, key, display, spoken, source,
                retake: int = 0, context: dict = None) -> dict:
    if not spoken:
        raise Fail(f"{key} ({locale}) has empty spoken text")
    settings = category_settings(profile, category)
    mode = category_mode(cat, profile, category)
    # Carriers on a normal take come from the category, and only where the
    # category is recorded one request at a time — inside a sheet the
    # neighbouring items already give each reading a run-up.
    if not retake and (settings.get("carrier_before") or settings.get("carrier_after")):
        context = context or {}
        for field in ("carrier_before", "carrier_after"):
            if settings.get(field) and field not in context:
                context[field] = list(settings[field])

    # A retake is always a single request with nothing either side of it, so it
    # is the take that most needs the run-up — whatever category it belongs to.
    # Slovak 'há' came back as a clipped 'ha' eight times, and 'španielčina'
    # cut off at the end, both for want of a word to lean on. An explicit
    # --carrier still wins: it is already in the context by the time this runs.
    # …but only for the categories whose items are too short to stand alone.
    # A letter name or a UI fragment trails off with nothing after it; a whole
    # word does not, and wrapping one in carriers means cutting it back out of
    # a three-item reading — which clipped 'letadýlko' and 'mrkvička' down to
    # their last syllable. The carrier is a remedy for shortness, and applying
    # it where there is no shortness introduced the fault it was meant to cure.
    if retake and category in (cat.get("retake_carrier_categories") or ["char", "ui"]):
        context = context or {}
        # A retake that names any carrier has named all of them. Asking for a
        # follower and no leader used to leave the category's own leader in
        # place, so the retake tested the opposite of what it said — Turkish
        # "ile" came back as the word after it, twice.
        explicit = any(f in context for f in ("carrier_before", "carrier_after"))
        if not explicit:
            fallback = profile.get("retake_carriers") or {}
            for field in ("carrier_before", "carrier_after"):
                value = settings.get(field) or fallback.get(field)
                if value:
                    context[field] = list(value)

    spec = {
        "provider": profile["provider"],
        "spoken_text": spoken,
        "locale": locale,
        "model_id": profile["model_id"],
        "language_code": profile.get("language_code"),
        "voice_id": profile.get("voice_id"),
        "voice_profile_version": profile.get("version", 1),
        "settings": profile.get("settings", {}),
        "seed": profile.get("seed"),
        "pronunciation_dictionaries": profile.get("pronunciation_dictionaries", []),
        "output_format": profile.get("output_format"),
        "master_format": cat["master_format"],
        "synthesis_mode": mode,
        "sheet": profile.get("sheet") if mode == "sheet" else None,
    }
    if context and not retake:
        spec["context"] = context
    if retake:
        # Only ever added when there is a retake, so that asking for one clip to
        # be redone cannot disturb the hash — and therefore the approval — of
        # any other clip. A retake is recorded alone, so its spec says so.
        spec["retake"] = retake
        spec["synthesis_mode"] = "single"
        spec["sheet"] = None
        # Conditioning text is not spoken, but it changes how the clip is
        # delivered, so it belongs in the hash like any other input.
        if context:
            spec["context"] = context
    spec_hash = canonical_hash(spec)
    return {
        "key": key,
        "lang": lang,
        "locale": locale,
        "category": category,
        "priority": cspec["priority"],
        "display_text": display,
        "spoken_text": spoken,
        "spec_hash": spec_hash,
        "render_hash": canonical_hash({
            "spec": spec_hash,
            "processing": cat["processing"],
            "ship_format": cat["ship_format"],
        }),
        "source": source,
        "retake": retake,
        "synthesis_mode": "single" if retake else mode,
        "context": context or None,
        "voice_configured": bool(profile.get("voice_id")),
    }


def build_records(cat: dict, profiles: dict, langs) -> list:
    """Enumerate every clip the game wants, with the hashes that identify it.

    Two hashes, not one:

      spec_hash   — everything that decides how the *synthesised master* sounds.
                    Text, locale, model, voice, settings, seed, dictionaries.
      render_hash — spec_hash plus the processing chain and the shipped codec.

    Splitting them means changing the shipped bitrate re-encodes from the
    archived master and costs nothing, while changing a word or a voice
    correctly forces a paid regeneration.
    """
    records = []

    for lang in langs:
        lspec = cat["languages"][lang]
        locale = lspec["locale"]
        profile = profiles.get(locale)
        if profile is None:
            raise Fail(f"voice_profiles.json has no profile for {locale} (language {lang})")
        overrides = load_overrides(locale)
        retakes = load_retakes(lang)

        for category in categories_for(cat, lang, lspec):
            cspec = cat["categories"][category]

            if category == "number_form":
                for key, display, spoken in number_form_items(cat, lang, cspec):
                    spoken = nfc(overrides.get(key, {}).get("spoken", spoken))
                    records.append(make_record(cat, profile, lang, locale, category, cspec,
                                               key, display, spoken, "data/number_forms.json",
                                               int(retakes.get(key, {}).get("n", 0)),
                                               retake_context(retakes.get(key, {}))))
                continue

            if category == "ui":
                for key, display, spoken in ui_items(cat, lang, cspec):
                    spoken = nfc(overrides.get(key, {}).get("spoken", spoken))
                    records.append(make_record(cat, profile, lang, locale, category, cspec,
                                               key, display, spoken, rel(TRANSLATIONS),
                                               int(retakes.get(key, {}).get("n", 0)),
                                               retake_context(retakes.get(key, {}))))
                continue

            if category == "word":
                for key, display, spoken, origin in word_items(cat, lang, cspec):
                    spoken = nfc(overrides.get(key, {}).get("spoken", spoken))
                    records.append(make_record(cat, profile, lang, locale, category, cspec,
                                               key, display, spoken, origin,
                                               int(retakes.get(key, {}).get("n", 0)),
                                               retake_context(retakes.get(key, {}))))
                continue

            source = SPEECH_SRC / cspec["source"].format(lang=lang)
            doc = read_json(source)

            if doc.get("lang") != lang:
                raise Fail(f"{rel(source)} declares lang '{doc.get('lang')}', expected '{lang}'")
            if doc.get("locale") != locale:
                raise Fail(
                    f"{rel(source)} declares locale '{doc.get('locale')}', "
                    f"but catalog.json says {locale}"
                )

            if category == "number":
                lo, hi = cspec["range"]
                by_value = {int(n["value"]): n for n in doc["numbers"]}
                gap = [v for v in range(lo, hi + 1) if v not in by_value]
                if gap:
                    raise Fail(f"{rel(source)} is missing numbers: {gap[:10]}")
                items = [(cspec["key_format"].format(value=v), by_value[v]["display"],
                          by_value[v]["spoken"]) for v in range(lo, hi + 1)]
            elif category == "char":
                spawned, extra = language_letters(lang)
                names = {}
                seen = set()
                for letter in doc["letters"]:
                    lid = letter["id"]
                    if not re.fullmatch(r"[a-z0-9_]+", lid):
                        raise Fail(f"{rel(source)}: letter id '{lid}' must be lowercase ascii/underscore")
                    if lid in seen:
                        raise Fail(f"{rel(source)}: duplicate letter id '{lid}'")
                    seen.add(lid)
                    if letter["display"] in names:
                        raise Fail(f"{rel(source)}: two entries for {letter['display']!r}")
                    names[letter["display"]] = letter
                items = []
                for display in spawned + extra:
                    letter = names.get(display)
                    if letter is None:
                        raise Fail(f"{rel(source)} has no entry for {display!r}, which "
                                   f"game_config.gd says {lang} uses")
                    items.append((cspec["key_format"].format(id=letter["id"]),
                                  display, letter["spoken"]))
                unused = [d for d in names if d not in spawned + extra]
                if unused:
                    raise Fail(f"{rel(source)} names letters {lang} does not use: "
                               f"{', '.join(unused)} — add them to game_config.gd or remove them")
            else:
                raise Fail(f"unknown category '{category}' in catalog.json")

            for key, display, spoken in items:
                spoken = nfc(overrides.get(key, {}).get("spoken", spoken))
                records.append(make_record(cat, profile, lang, locale, category, cspec,
                                           key, display, spoken, rel(source),
                                           int(retakes.get(key, {}).get("n", 0)),
                                           retake_context(retakes.get(key, {}))))

    records.sort(key=lambda r: (r["lang"], r["category"], r["key"]))

    seen = set()
    for r in records:
        ident = (r["lang"], r["key"])
        if ident in seen:
            raise Fail(f"duplicate key {r['key']} for {r['lang']}")
        seen.add(ident)

    return records


def cmd_extract(args) -> int:
    ensure_guards()
    cat = load_catalog()
    profiles = load_profiles()
    langs = enabled_languages(cat, args.language)
    records = build_records(cat, profiles, langs)

    BUILD.mkdir(parents=True, exist_ok=True)
    with DESIRED.open("w", encoding="utf-8") as fh:
        for r in records:
            fh.write(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n")

    info(f"{len(records)} records -> {rel(DESIRED)}")
    for lang in langs:
        per = [r for r in records if r["lang"] == lang]
        by_cat = {}
        for r in per:
            by_cat[r["category"]] = by_cat.get(r["category"], 0) + 1
        chars = sum(len(r["spoken_text"]) for r in per)
        detail = ", ".join(f"{k} {v}" for k, v in sorted(by_cat.items()))
        info(f"  {lang}  {len(per):4d}  ({detail})  {chars} characters")
    return 0


def load_desired() -> list:
    if not DESIRED.exists():
        raise Fail("no build/speech/desired.jsonl — run `extract` first")
    out = []
    with DESIRED.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


# --------------------------------------------------------------------------
# Ledger, masters, reviews
# --------------------------------------------------------------------------

def master_path(spec_hash: str) -> Path:
    return MASTERS_RAW / spec_hash[:2] / f"{spec_hash}.pcm"


def processed_path(render_hash: str) -> Path:
    return MASTERS_PROCESSED / render_hash[:2] / f"{render_hash}.mp3"


def load_ledger() -> dict:
    """spec_hash -> newest ledger entry. Append-only file, last entry wins."""
    out = {}
    if not LEDGER.exists():
        return out
    with LEDGER.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            out[entry["spec_hash"]] = entry
    return out


def append_ledger(entry: dict) -> None:
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    with LEDGER.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False, sort_keys=True) + "\n")


REVIEW_FIELDS = ["key", "spec_hash", "status", "reviewer", "date", "notes"]


def review_path(locale: str) -> Path:
    return REVIEWS / f"{locale}.csv"


def load_reviews(locale: str) -> dict:
    """(key, spec_hash) -> row. Approval is tied to the exact take reviewed."""
    path = review_path(locale)
    if not path.exists():
        return {}
    out = {}
    with path.open(encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            if not row.get("key"):
                continue
            out[(row["key"], row.get("spec_hash", ""))] = row
    return out


def save_reviews(locale: str, rows: list) -> None:
    path = review_path(locale)
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = sorted(rows, key=lambda r: r["key"])
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=REVIEW_FIELDS)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in REVIEW_FIELDS})


# --------------------------------------------------------------------------
# plan
# --------------------------------------------------------------------------

STATUS_ORDER = ["unconfigured", "missing", "generated", "rejected", "unreviewed", "approved"]


def classify(records: list) -> list:
    ledger = load_ledger()
    reviews_by_locale = {}

    for r in records:
        locale = r["locale"]
        if locale not in reviews_by_locale:
            reviews_by_locale[locale] = load_reviews(locale)
        review = reviews_by_locale[locale].get((r["key"], r["spec_hash"]))

        master = master_path(r["spec_hash"])
        clip = processed_path(r["render_hash"])

        if not r["voice_configured"]:
            status = "unconfigured"
        elif not master.exists() and r["spec_hash"] not in ledger:
            status = "missing"
        elif not clip.exists():
            status = "generated"
        elif review and review.get("status", "").lower() == "rejected":
            status = "rejected"
        elif review and review.get("status", "").lower() == "approved":
            status = "approved"
        else:
            status = "unreviewed"

        r["status"] = status
        r["master"] = rel(master)
        r["clip"] = rel(clip)
    return records


def find_orphans(records: list) -> list:
    """Files on disk that nothing in the catalog wants any more."""
    wanted_masters = {master_path(r["spec_hash"]) for r in records}
    wanted_clips = {processed_path(r["render_hash"]) for r in records}
    orphans = []
    for root, wanted, suffix in ((MASTERS_RAW, wanted_masters, ".pcm"),
                                 (MASTERS_PROCESSED, wanted_clips, ".mp3")):
        if not root.exists():
            continue
        for path in sorted(root.rglob(f"*{suffix}")):
            if path not in wanted:
                orphans.append(rel(path))
    return orphans


def estimate_cost(cat: dict, records: list) -> dict:
    prices = cat["pricing_usd_per_1k_chars"]
    profiles = load_profiles()
    total_chars, total_usd = 0, 0.0
    by_lang = {}
    for r in records:
        chars = len(r["spoken_text"])
        model = profiles.get(r["locale"], {}).get("model_id", "")
        price = prices.get(model)
        usd = (chars / 1000.0) * price if isinstance(price, (int, float)) else 0.0
        total_chars += chars
        total_usd += usd
        acc = by_lang.setdefault(r["lang"], {"records": 0, "characters": 0, "usd": 0.0, "model": model})
        acc["records"] += 1
        acc["characters"] += chars
        acc["usd"] += usd
    return {"characters": total_chars, "usd": round(total_usd, 4), "by_language": by_lang}


def cmd_plan(args) -> int:
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    if args.category:
        records = [r for r in records if r["category"] in args.category]
    if args.priority is not None:
        records = [r for r in records if r["priority"] <= args.priority]
    if not records:
        raise Fail("no records matched those filters")

    classify(records)
    counts = {s: 0 for s in STATUS_ORDER}
    for r in records:
        counts[r["status"]] += 1

    to_generate = [r for r in records if r["status"] == "missing"]
    cost = estimate_cost(cat, to_generate)
    orphans = find_orphans(load_desired())

    info(f"{len(records)} records")
    for status in STATUS_ORDER:
        if counts[status]:
            info(f"  {status:12s} {counts[status]:5d}")
    if orphans:
        info(f"  {'orphaned':12s} {len(orphans):5d}  (files no longer wanted; nothing is deleted automatically)")

    drafts = sorted({r["lang"] for r in records if _source_is_draft(r["lang"])})
    if drafts:
        info("")
        info(f"  DRAFT source data: {', '.join(drafts)} — letter and number names in these")
        info("  languages have not been read by a native speaker yet.")

    if counts["unconfigured"]:
        info("")
        info("  No voice_id set yet for at least one locale. Fill it in data/speech/voice_profiles.json —")
        info("  `speech_pipeline.py voices --language cs` lists candidates. See tools/speech/SETUP.md.")

    if to_generate:
        info("")
        info(f"To generate: {len(to_generate)} clips, {cost['characters']} characters")
        for lang, acc in sorted(cost["by_language"].items()):
            info(f"  {lang}  {acc['records']:4d} clips  {acc['characters']:6d} chars  "
                 f"~USD {acc['usd']:.2f}  ({acc['model']})")
        info(f"  estimated total ~USD {cost['usd']:.2f}"
             f"   (list price at {cat['pricing_usd_per_1k_chars'].get('checked_on','?')}; recheck before a production run)")
    else:
        info("")
        info("Nothing to generate.")

    BUILD.mkdir(parents=True, exist_ok=True)
    payload = {
        "generated_on": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "counts": counts,
        "cost_estimate": cost,
        "orphans": orphans,
        "records": records,
    }
    PLAN_JSON.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    info("")
    info(f"-> {rel(PLAN_JSON)}")

    if args.estimate_all:
        estimate_all_languages(cat, records)
    return 0


def estimate_all_languages(cat: dict, records: list) -> None:
    """Extrapolate the whole-programme cost from the languages that exist.

    This is an extrapolation and says so. A real figure for the other 19
    languages needs their letters_/numbers_ files, which need a native speaker;
    the point of the number is to answer 'is cost a constraint?' — it is not.
    """
    if not records:
        return
    per_record = sum(len(r["spoken_text"]) for r in records) / len(records)
    per_lang = len(records) / len({r["lang"] for r in records})
    total_langs = len(cat["languages"])
    chars = per_record * per_lang * total_langs
    prices = cat["pricing_usd_per_1k_chars"]
    lo = chars / 1000.0 * prices["eleven_flash_v2_5"]
    hi = chars / 1000.0 * prices["eleven_multilingual_v2"]
    info("")
    info(f"Extrapolated to all {total_langs} languages, numbers and letters only:")
    info(f"  ~{int(per_lang)} clips/language, ~{chars:,.0f} characters, ~USD {lo:.2f}–{hi:.2f}")
    info("  Extrapolated from the enabled languages. Words (P1) are not included.")


# --------------------------------------------------------------------------
# voices  (network, read-only, spends no credits)
# --------------------------------------------------------------------------

def api_key(required: bool = True):
    cat = load_catalog()
    var = cat.get("api_key_env", "ELEVENLABS_API_KEY")
    key = os.environ.get(var, "").strip()
    if not key and required:
        raise Fail(
            f"{var} is not set in the environment.\n"
            f"  export {var}='sk_...'   (do not put it in any file in this repo)\n"
            "  See tools/speech/SETUP.md."
        )
    return key


def api_get(path: str, key: str):
    import urllib.error
    import urllib.request
    req = urllib.request.Request(f"{API_BASE}{path}", headers={"xi-api-key": key})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")[:400]
        raise Fail(f"ElevenLabs GET {path} failed: {exc.code} {body}")
    except urllib.error.URLError as exc:
        raise Fail(f"could not reach ElevenLabs: {exc.reason}")


def cmd_voices(args) -> int:
    key = api_key()

    info("Voices already in your account")
    info("-" * 78)
    mine = api_get("/voices", key).get("voices", [])
    if not mine:
        info("  (none yet)")
    for v in mine:
        labels = v.get("labels") or {}
        desc = ", ".join(f"{k}={val}" for k, val in sorted(labels.items()) if val)
        info(f"  {v.get('voice_id','')}  {v.get('name','')[:28]:28s}  {desc[:60]}")

    if args.language:
        for lang in args.language:
            info("")
            info(f"Shared library, language={lang}, calm/narration voices")
            info("-" * 78)
            try:
                shared = api_get(f"/shared-voices?page_size=25&language={lang}", key).get("voices", [])
            except Fail as exc:
                warn(str(exc))
                continue
            if not shared:
                info("  (nothing returned — try the website's Voice Library filters instead)")
            for v in shared:
                info(f"  {v.get('voice_id','')}  {v.get('name','')[:24]:24s}  "
                     f"{v.get('accent','')or'-':10s} {v.get('age','')or'-':8s} "
                     f"{v.get('use_case','') or v.get('category','') or ''}")

    info("")
    info("Put the chosen voice_id into data/speech/voice_profiles.json, then run `plan`.")
    info("Prefer a voice you own (Voice Design or a licensed clone) or a perpetual default —")
    info("a Voice Library owner can withdraw a voice, and then later clips will not match.")
    return 0


# --------------------------------------------------------------------------
# generate  (network, SPENDS CREDITS)
# --------------------------------------------------------------------------

def generate_with_carrier(key: str, profile: dict, record: dict, cat: dict):
    """Record a clip preceded and/or followed by throwaway words, keep the middle."""
    context = record["context"]
    before = context.get("carrier_before") or []
    after = context.get("carrier_after") or []
    group = ([{"spoken_text": w} for w in before]
             + [{"spoken_text": record["spoken_text"]}]
             + [{"spoken_text": w} for w in after])

    text, spans = sheet_text(profile, group)
    audio, alignment, request_id = tts_sheet_request(key, profile, text)
    cuts, _offsets = cut_sheet(audio, alignment, text, spans, cat, profile)
    return cuts[len(before)], request_id, text


def _source_is_draft(lang: str) -> bool:
    for name in (f"letters_{lang}.json", f"numbers_{lang}.json"):
        path = SPEECH_SRC / name
        if path.exists() and "DRAFT" in str(read_json(path).get("source_review", "")).upper():
            return True
    forms = REPO / "data" / "number_forms.json"
    if forms.exists():
        entry = read_json(forms).get("languages", {}).get(lang, {})
        if "DRAFT" in str(entry.get("review", "")).upper():
            return True
    return False


def cmd_generate(args) -> int:
    ensure_guards()
    cat = load_catalog()
    profiles = load_profiles()
    guards = cat["generate_guards"]
    records = load_desired()

    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    if args.category:
        records = [r for r in records if r["category"] in args.category]
    if args.key:
        records = [r for r in records if r["key"] in args.key]
    classify(records)

    unconfigured = {r["locale"] for r in records if r["status"] == "unconfigured"}
    if unconfigured:
        raise Fail(f"no voice_id set for {', '.join(sorted(unconfigured))} — see tools/speech/SETUP.md")

    # Sheet groups are all-or-nothing: you cannot cut one letter out of a sheet
    # that was never recorded. If any member is missing, the whole group is
    # re-read, which is also what keeps the group sounding like one take.
    all_records = classify(load_desired())
    sheet_groups = {}
    for r in records:
        if r.get("synthesis_mode") != "sheet" or r.get("retake"):
            continue
        ident = (r["locale"], r["category"])
        if ident in sheet_groups:
            continue
        members = [x for x in all_records
                   if x["locale"] == ident[0] and x["category"] == ident[1]
                   and x.get("synthesis_mode") == "sheet" and not x.get("retake")]
        # Only what is actually missing goes into the sheet.
        #
        # This used to re-read the whole category whenever one member was
        # absent, on the reasoning that a sheet must be read whole. That
        # confused two things: a sheet must be *cut* whole, but there is no
        # need for it to contain everything the category has. Adding 65 phrase
        # prefixes was about to re-record all 342 Czech words — 31 cents
        # instead of 6, and 277 approvals to re-check for no reason.
        #
        # Sheets are already chunked into sixteens, so a new chunk is no less
        # consistent than the chunk boundaries the pack already has.
        wanted = members if args.force else [m for m in members if m["status"] == "missing"]
        if wanted:
            sheet_groups[ident] = wanted

    todo = [r for r in records if r["status"] == "missing"
            and (r.get("retake") or r.get("synthesis_mode") != "sheet")]
    if args.limit:
        todo = todo[:args.limit]
    if not todo and not sheet_groups:
        info("Nothing to generate.")
        return 0
    if sheet_groups and (args.limit or args.key):
        warn("--limit and --key do not apply to sheet mode; a sheet is recorded whole")

    sheet_chars = 0
    cached_sheets = 0
    missing_sheets = 0
    for (loc, _c), grp in sheet_groups.items():
        for chunk in sheet_chunks(profiles[loc], grp):
            body = sheet_text(profiles[loc], chunk)[0]
            if load_sheet(profiles[loc], body):
                cached_sheets += 1
            elif not args.cached_only:
                sheet_chars += len(body)
            else:
                missing_sheets += 1
    chars = sum(len(r["spoken_text"]) for r in todo) + sheet_chars
    budget = args.max_characters if args.max_characters is not None else guards["max_characters_per_run"]
    prices = cat["pricing_usd_per_1k_chars"]
    est = 0.0
    for r in todo:
        price = prices.get(profiles[r["locale"]]["model_id"])
        billed = len(r["spoken_text"])
        context = r.get("context") or {}
        for word in (context.get("carrier_before") or []) + (context.get("carrier_after") or []):
            billed += len(word) + 2      # the carrier is spoken, so it is paid for
        est += billed / 1000.0 * (price or 0)
    for (loc, _cat), grp in sheet_groups.items():
        price = prices.get(profiles[loc]["model_id"])
        for chunk in sheet_chunks(profiles[loc], grp):
            body = sheet_text(profiles[loc], chunk)[0]
            if not load_sheet(profiles[loc], body) and not args.cached_only:
                est += len(body) / 1000.0 * (price or 0)

    clip_total = len(todo) + sum(len(g) for g in sheet_groups.values())
    info(f"{clip_total} clips, {chars} characters, estimated ~USD {est:.2f}")
    for (loc, cat_), grp in sorted(sheet_groups.items()):
        n = len(sheet_chunks(profiles[loc], grp))
        info(f"  sheet  {loc}/{cat_}  {len(grp)} items in {n} sheet(s)")
    if cached_sheets:
        info(f"  {cached_sheets} sheet(s) already stored — re-cut locally, nothing billed")
    if missing_sheets:
        info(f"  {missing_sheets} sheet(s) not stored — skipped; `generate` would have to record them")
    for r in todo[:8]:
        info(f"  {r['key']:24s} {r['locale']}  {r['spoken_text']!r}")
    if len(todo) > 8:
        info(f"  … and {len(todo) - 8} more")

    if chars > budget:
        raise Fail(
            f"{chars} characters exceeds the budget of {budget}. "
            "Narrow with --language/--category/--limit, or raise it deliberately with --max-characters."
        )
    billable = chars > 0
    # Draft source data is the expensive mistake: wrong letter names are only
    # discovered after they have been generated, reviewed and rejected.
    drafts = sorted({r["lang"] for r in todo + [x for g in sheet_groups.values() for x in g]
                     if _source_is_draft(r["lang"])})
    if drafts:
        info("")
        for lang in drafts:
            warn(f"{lang} letter or number names are still marked DRAFT — a native speaker "
                 "should read them before you pay to record them")

    if args.dry_run or (billable and not args.confirm):
        info("")
        if billable:
            info("Dry run — nothing was generated and nothing was billed.")
            info("Add --confirm to actually synthesise.")
        else:
            info("Nothing to buy; re-run without --dry-run to re-cut from stored sheets.")
        return 0

    key = api_key(required=billable)
    ok = failed = 0

    if sheet_groups:
        ok, failed = generate_sheets(key, cat, profiles, sheet_groups, args)

    for i, r in enumerate(todo, 1):
        profile = profiles[r["locale"]]
        info(f"[{i}/{len(todo)}] {r['key']}  {r['spoken_text']!r}")
        carrier = (r.get("context") or {}).get("carrier_before") or \
                  (r.get("context") or {}).get("carrier_after")
        try:
            if carrier:
                audio, request_id, spoken_sheet = generate_with_carrier(key, profile, r, cat)
                info(f"        recorded inside {spoken_sheet!r}, kept only the middle")
            else:
                audio, request_id = tts_request(key, profile, r["spoken_text"], r.get("context"))
        except Fail as exc:
            failed += 1
            warn(str(exc))
            continue

        if len(audio) < 1000:
            failed += 1
            warn(f"{r['key']}: response was only {len(audio)} bytes — not saved")
            continue

        write_atomic(master_path(r["spec_hash"]), audio)
        append_ledger({
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "key": r["key"], "lang": r["lang"], "locale": r["locale"],
            "category": r["category"], "spec_hash": r["spec_hash"],
            "provider": profile["provider"], "model_id": profile["model_id"],
            "voice_id": profile["voice_id"], "voice_profile_version": profile.get("version", 1),
            "spoken_text": r["spoken_text"], "billed_characters": len(r["spoken_text"]),
            "request_id": request_id, "master": rel(master_path(r["spec_hash"])),
            "master_bytes": len(audio), "status": "generated",
        })
        ok += 1
        time.sleep(args.delay)

    info("")
    info(f"generated {ok}, failed {failed}. Next: `process`, then listen.")
    return 1 if failed else 0


# --------------------------------------------------------------------------
# Recording sheets
# --------------------------------------------------------------------------
#
# One request per letter gives the model two characters of context and nothing
# else, so it re-invents the delivery every time: the same voice arrives as a
# different person, an isolated vowel comes out emotive, and the language
# detector guesses per request.
#
# A sheet asks for the whole alphabet in one breath, then cuts it up using the
# character alignment the API returns. One performance, one register, one
# language decision.

def sheet_text(profile: dict, group: list):
    """Build the sheet and record where each item sits inside it.

    A category may override the sheet settings. Only one thing has needed it so
    far and it needed it badly: Portuguese names its A "á", one short vowel
    sitting first in the sheet with nothing in front of it, and the cutter kept
    returning an empty first item because there was no silence to cut at. A
    preamble fixes that — but the profile's sheet settings are shared with the
    word sheets, and changing them there would throw away every word already
    recorded for the sake of one letter.
    """
    sheet = dict(profile.get("sheet") or {})
    # Carrier readings are assembled as bare {spoken_text} entries rather than
    # records, so there is not always a category to look up — and a carrier
    # group must not inherit a preamble anyway, it is already its own run-up.
    category = next((r.get("category") for r in group if r.get("category")), "")
    if category:
        sheet.update((category_settings(profile, category).get("sheet") or {}))
    sep = sheet.get("separator", ". ")
    preamble = sheet.get("preamble", "")
    if preamble:
        # The cutter solves the sheet for exactly len(spans) sounds. A preamble
        # is a sound it is never told about, so every cut lands one item late:
        # Portuguese A came back saying "olá", B said "á", C said "bê". The
        # field looked supported and was not. Refuse it rather than let it
        # shift a whole alphabet silently.
        raise Fail(
            "sheet.preamble is not supported: the cutter is not told about it "
            "and every cut lands one item late. Use a longer separator to force "
            "a pause, or record the category one item at a time with carriers."
        )

    text = ""
    spans = []
    for i, r in enumerate(group):
        start = len(text)
        text += r["spoken_text"]
        spans.append((start, len(text)))
        if i < len(group) - 1:
            text += sep
    trailer = sheet.get("trailer", "")
    if trailer:
        text += sep + trailer
    return text, spans


def tts_sheet_request(key: str, profile: dict, text: str):
    """POST to the with-timestamps endpoint; return (pcm bytes, alignment, id)."""
    import urllib.error
    import urllib.request

    payload = {
        "text": text,
        "model_id": profile["model_id"],
        "voice_settings": profile.get("settings", {}),
    }
    if profile.get("language_code"):
        payload["language_code"] = profile["language_code"]
    if profile.get("seed") is not None:
        payload["seed"] = profile["seed"]
    if profile.get("pronunciation_dictionaries"):
        payload["pronunciation_dictionary_locators"] = profile["pronunciation_dictionaries"]

    url = (f"{API_BASE}/text-to-speech/{profile['voice_id']}/with-timestamps"
           f"?output_format={profile.get('output_format', 'pcm_22050')}")
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"xi-api-key": key, "Content-Type": "application/json"},
        method="POST",
    )

    delay = 2.0
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                doc = json.loads(resp.read().decode("utf-8"))
                request_id = resp.headers.get("request-id", "")
                break
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", "replace")[:300]
            if exc.code in (429, 500, 502, 503, 504) and attempt < 4:
                warn(f"HTTP {exc.code}, retrying in {delay:.1f}s")
                time.sleep(delay)
                delay *= 2
                continue
            raise Fail(f"HTTP {exc.code}: {body}")
        except urllib.error.URLError as exc:
            if attempt < 4:
                time.sleep(delay)
                delay *= 2
                continue
            raise Fail(f"network error: {exc.reason}")
    else:
        raise Fail("exhausted retries")

    import base64
    audio = base64.b64decode(doc["audio_base64"])
    alignment = doc.get("alignment") or doc.get("normalized_alignment")
    if not alignment:
        raise Fail("the API returned no alignment, so the sheet cannot be cut")
    return audio, alignment, request_id


def frame_levels(samples, rate: int, frame_ms: int = 10):
    """Short-time RMS in dBFS, one value per frame."""
    step = max(int(rate * frame_ms / 1000), 1)
    out = []
    for i in range(0, len(samples) - step + 1, step):
        acc = 0
        for s in samples[i:i + step]:
            acc += s * s
        v = math.sqrt(acc / step)
        out.append(20 * math.log10(v / 32768.0) if v > 0 else -99.0)
    return out, step


def segment_for_gap(runs, levels, min_gap_frames: int, min_len_frames: int):
    """Merge runs separated by less than min_gap, then reach into the soft edges."""
    merged = []
    for run in runs:
        if merged and run[0] - merged[-1][1] <= min_gap_frames:
            merged[-1][1] = run[1]
        else:
            merged.append(list(run))

    peak = max(levels) if levels else -99.0
    soft = max(peak - 48.0, -65.0)

    # Reaching out to a soft onset or decay must not reach into the neighbour.
    # The floor is the previous segment's edge *after* it was extended, not
    # before: clamping both sides against pre-extension bounds still lets two
    # segments grow towards each other across a wide gap and overlap in it.
    fixed = [(s[0], s[1]) for s in merged]
    for i, seg in enumerate(merged):
        floor = merged[i - 1][1] + 1 if i > 0 else 0
        ceiling = fixed[i + 1][0] - 1 if i < len(merged) - 1 else len(levels) - 1
        while seg[0] > floor and levels[seg[0] - 1] >= soft:
            seg[0] -= 1
        while seg[1] < ceiling and levels[seg[1] + 1] >= soft:
            seg[1] += 1

    return [s for s in merged if s[1] - s[0] + 1 >= min_len_frames]


def runs_above(levels, threshold: float):
    runs, i = [], 0
    while i < len(levels):
        if levels[i] >= threshold:
            j = i
            while j < len(levels) and levels[j] >= threshold:
                j += 1
            runs.append([i, j - 1])
            i = j
        else:
            i += 1
    return runs


def split_by_quietest(levels, spans, starts, ends, step: int, rate: int, min_len_frames: int):
    """Force exactly one segment per item by cutting at the quietest point between them.

    The last-resort path, and it cannot fail the way nearest-segment matching
    could: that could hand the same sound to two items, which is how a letter
    ends up containing its neighbour. Here the boundaries are strictly ordered
    by construction, so every item gets its own piece of the sheet.

    Alignment is used only to say roughly where the gap between two items is.
    Locating a *gap* is a much easier job than locating a sound, and it is the
    one thing the alignment has been reliable at.
    """
    total = len(levels)
    edges = [0]
    for i in range(1, len(spans)):
        gap_start = ends[spans[i - 1][1] - 1]
        gap_end = starts[spans[i][0]]
        lo = max(int((min(gap_start, gap_end) - 0.20) * rate / step), edges[-1] + 1)
        hi = min(int((max(gap_start, gap_end) + 0.20) * rate / step), total - 1)
        if hi > lo:
            window = levels[lo:hi + 1]
            edge = lo + window.index(min(window))
        else:
            edge = lo
        # Strictly increasing, always. Everything downstream depends on it.
        edges.append(min(max(edge, edges[-1] + 1), total - 1))
    edges.append(total)

    segments = []
    for i in range(len(spans)):
        lo, hi = edges[i], edges[i + 1] - 1
        piece = levels[lo:hi + 1]
        if not piece:
            segments.append([lo, max(lo, hi)])
            continue
        peak = max(piece)
        thr = max(peak - 35.0, -55.0)
        inner = runs_above(piece, thr)
        inner = [r for r in inner if r[1] - r[0] + 1 >= min_len_frames] or inner
        if inner:
            seg = [lo + inner[0][0], lo + inner[-1][1]]
            soft = max(peak - 48.0, -65.0)
            while seg[0] > lo and levels[seg[0] - 1] >= soft:
                seg[0] -= 1
            while seg[1] < hi and levels[seg[1] + 1] >= soft:
                seg[1] += 1
            segments.append(seg)
        else:
            segments.append([lo, hi])
    return segments


def solve_segments(levels, want: int, frame_ms: int, min_len_frames: int):
    """Choose the silence threshold that yields exactly the expected item count.

    A fixed threshold cannot work for both jobs at once. It has to be long
    enough that the pause inside 'dvacet jedna' or 'ú s čárkou' does not split
    one item in two, and short enough that the pause between two items does
    separate them — and those two gaps overlap across sheets and voices.

    Since the number of items on the sheet is known exactly, the threshold is
    not something to guess. Sweep it, keep the values that produce the right
    count, and take the middle of that range: the setting furthest from either
    failure.
    """
    peak = max(levels) if levels else -99.0

    # Sweep the loudness threshold as well as the gap. One dimension is not
    # enough: a quiet item disappears at a strict threshold, and two items run
    # together at a lax one, and which happens depends on the sheet.
    best = None
    for drop in (25.0, 30.0, 35.0, 40.0, 45.0):
        runs = runs_above(levels, max(peak - drop, -60.0))
        if not runs:
            continue
        working = []
        for gap_ms in range(40, 601, 10):
            segs = segment_for_gap(runs, levels, max(int(gap_ms / frame_ms), 1), min_len_frames)
            if len(segs) == want:
                working.append(gap_ms)
        if not working:
            continue

        # Widest contiguous run of thresholds that works — the setting furthest
        # from either failure, rather than one that only just happens to fit.
        best_run, run_now = [], [working[0]]
        for prev, cur in zip(working, working[1:]):
            if cur - prev <= 10:
                run_now.append(cur)
            else:
                best_run = run_now if len(run_now) > len(best_run) else best_run
                run_now = [cur]
        best_run = run_now if len(run_now) > len(best_run) else best_run

        if best is None or len(best_run) > best[0]:
            best = (len(best_run), drop, best_run[len(best_run) // 2], runs)

    if best is None:
        return None, None
    _, drop, gap_ms, runs = best
    segs = segment_for_gap(runs, levels, max(int(gap_ms / frame_ms), 1), min_len_frames)
    return segs, gap_ms


def speech_segments(levels, min_gap_frames: int, min_len_frames: int):
    """Every run of speech in the sheet, split at real silence.

    Locating each item inside its own alignment window was the previous
    approach and it failed in a way worth remembering: the reported end time of
    the *previous* item lands early, so a window bounded by it began inside the
    previous word, and the cutter locked onto that. Hence "too long pause at the
    beginning", and sometimes a fragment of the letter before.

    Segmenting the whole sheet at once avoids the problem entirely. The
    separator leaves real silence between items, and silence is not a matter of
    opinion.
    """
    peak = max(levels) if levels else -99.0
    strong = max(peak - 35.0, -55.0)
    soft = max(peak - 48.0, -65.0)

    runs = []
    i = 0
    while i < len(levels):
        if levels[i] >= strong:
            j = i
            while j < len(levels) and levels[j] >= strong:
                j += 1
            runs.append([i, j - 1])
            i = j
        else:
            i += 1

    # A stop consonant inside a word is silence too. Anything shorter than the
    # gap the separator produces belongs to the item on either side of it.
    merged = []
    for run in runs:
        if merged and run[0] - merged[-1][1] <= min_gap_frames:
            merged[-1][1] = run[1]
        else:
            merged.append(run)

    # Reach out to the soft onset and decay that sit below the speech threshold.
    for seg in merged:
        while seg[0] > 0 and levels[seg[0] - 1] >= soft:
            seg[0] -= 1
        while seg[1] < len(levels) - 1 and levels[seg[1] + 1] >= soft:
            seg[1] += 1

    return [s for s in merged if s[1] - s[0] + 1 >= min_len_frames]


def assign_segments(segments, spans, starts, ends, step: int, rate: int):
    """Match detected segments to catalog items, in order.

    The common case is that the counts agree and the mapping is the obvious
    one. When they do not, alignment decides which segment belongs to which
    item — imperfect, but it only has to be better than guessing, and the
    caller warns so a human listens.
    """
    if len(segments) == len(spans):
        return segments, None

    chosen = []
    for start, end in spans:
        middle = (starts[start] + ends[end - 1]) / 2.0
        best = min(segments,
                   key=lambda s: abs(((s[0] + s[1]) / 2.0) * step / rate - middle))
        chosen.append(best)
    return chosen, (f"the sheet split into {len(segments)} sounds but the catalog "
                    f"expects {len(spans)} items — cuts were matched by alignment "
                    f"instead, so listen to this group carefully")


def cut_sheet(audio: bytes, alignment: dict, text: str, spans: list, cat: dict, profile: dict):
    """Slice the sheet into one master per item.

    Alignment says roughly where each item is; the waveform says exactly where
    it begins and ends. Cutting on the alignment alone clipped final vowels —
    'dvacet tři' ended with its last 30ms still at -13 dBFS — and occasionally
    started after the onset, which is what 'beginning is weirdly cropped' was.

    The audio is raw signed 16-bit PCM, so a cut is a byte offset. Nothing is
    decoded and nothing is re-encoded.
    """
    chars = alignment.get("characters") or []
    starts = alignment.get("character_start_times_seconds") or []
    ends = alignment.get("character_end_times_seconds") or []
    if not (len(chars) == len(starts) == len(ends)):
        raise Fail("alignment arrays disagree in length")
    if "".join(chars) != text:
        raise Fail(
            "the alignment does not match the text that was sent, so cuts would "
            "land in the wrong place. Nothing was saved; the sheet is still billed."
        )

    fmt = cat["master_format"]
    frame = (fmt["bits"] // 8) * fmt["channels"]
    rate = fmt["sample_rate"]

    samples = array.array("h")
    samples.frombytes(audio[:len(audio) - len(audio) % frame])
    duration = len(samples) / rate
    levels, step = frame_levels(samples, rate)

    sheet = profile.get("sheet") or {}
    lead = sheet.get("guard_lead_ms", 30) / 1000.0
    tail = sheet.get("guard_tail_ms", 120) / 1000.0
    min_gap = sheet.get("min_gap_ms", 180) / 1000.0
    min_len = sheet.get("min_sound_ms", 60) / 1000.0

    min_len_frames = max(int(min_len * rate / step), 1)
    segments, gap_ms = solve_segments(levels, len(spans), 1000 * step // rate, min_len_frames)

    if segments is None:
        warn("no silence threshold separates this sheet into exactly "
             f"{len(spans)} items; cutting at the quietest point between each pair instead")
        chosen = split_by_quietest(levels, spans, starts, ends, step, rate, min_len_frames)
    else:
        chosen = segments
        if gap_ms is not None and abs(gap_ms - min_gap * 1000) > 200:
            info(f"  (silence threshold solved to {gap_ms} ms for this sheet)")
        if gap_ms is not None and gap_ms >= 400:
            # Matching the item count is only correct if the reading contains
            # exactly that many sounds. When the model throws in an extra one —
            # a repeat, a stray syllable — the solver can only reach the right
            # count by merging it into a neighbour, and it does that by raising
            # the threshold. An unusually high threshold is therefore the
            # symptom of a bad take rather than of a bad cut.
            warn(f"this sheet needed a {gap_ms} ms silence threshold, well above the usual "
                 "300-ish; that usually means the reading contains an extra sound which has "
                 "been merged into a neighbouring item. Listen to the long clips in this group.")

    # However they were produced, the segments must be ordered and disjoint. This is
    # the invariant that stops one item containing a piece of its neighbour.
    for prev, cur in zip(chosen, chosen[1:]):
        if cur[0] <= prev[1]:
            raise Fail("the cutter produced overlapping segments — refusing to save")

    cuts, offsets = [], []
    for i, seg in enumerate(chosen):
        a = seg[0] * step / rate - lead
        b = (seg[1] + 1) * step / rate + tail

        # Padding may never cross into a neighbouring sound. Halving the real
        # silence gap is the bound, so a generous guard can be set without any
        # risk of bleed — it simply gets trimmed back where the gap is short.
        if i > 0:
            prev_end = (chosen[i - 1][1] + 1) * step / rate
            a = max(a, (prev_end + seg[0] * step / rate) / 2.0)
        if i < len(chosen) - 1:
            next_start = chosen[i + 1][0] * step / rate
            b = min(b, ((seg[1] + 1) * step / rate + next_start) / 2.0)

        a = max(min(a, duration), 0.0)
        b = max(min(b, duration), 0.0)
        if b - a < 0.05:
            raise Fail(f"item {i + 1} of the sheet came out empty — refusing to save a bad cut")
        cuts.append(audio[int(a * rate) * frame:int(b * rate) * frame])
        offsets.append(a)

    return cuts, offsets


def sheet_synth_hash(profile: dict, text: str) -> str:
    """Identifies a *reading* — everything the provider needs to produce it.

    Deliberately excludes the guards and search window, which only decide where
    the knife falls afterwards. That is the whole point: boundary tuning is then
    a local operation on stored audio, not another paid request.
    """
    return canonical_hash({
        "text": text,
        "voice_id": profile.get("voice_id"),
        "model_id": profile.get("model_id"),
        "language_code": profile.get("language_code"),
        "settings": profile.get("settings", {}),
        "seed": profile.get("seed"),
        "pronunciation_dictionaries": profile.get("pronunciation_dictionaries", []),
        "output_format": profile.get("output_format"),
    })


def sheet_paths(digest: str):
    folder = MASTERS / "sheets" / digest[:2]
    return folder / f"{digest}.pcm", folder / f"{digest}.json"


def load_sheet(profile: dict, text: str):
    pcm, meta = sheet_paths(sheet_synth_hash(profile, text))
    if not (pcm.exists() and meta.exists()):
        return None
    doc = json.loads(meta.read_text(encoding="utf-8"))
    return pcm.read_bytes(), doc["alignment"], doc.get("request_id", "")


def save_sheet(profile: dict, text: str, audio: bytes, alignment: dict, request_id: str) -> None:
    digest = sheet_synth_hash(profile, text)
    pcm, meta = sheet_paths(digest)
    write_atomic(pcm, audio)
    meta.write_text(json.dumps({
        "sheet_hash": digest,
        "recorded_on": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "request_id": request_id,
        "text": text,
        "voice_id": profile.get("voice_id"),
        "model_id": profile.get("model_id"),
        "language_code": profile.get("language_code"),
        "settings": profile.get("settings", {}),
        "seed": profile.get("seed"),
        "alignment": alignment,
    }, ensure_ascii=False), encoding="utf-8")


def sheet_chunks(profile: dict, group: list):
    """Split a group into sheets small enough to stay energetic.

    Fifty numbers in one breath invites the model to drift or trail off toward
    the end. A fixed seed and one voice make sheet-to-sheet variation far
    smaller than the item-to-item variation this is replacing, so chunking
    costs much less consistency than it buys.
    """
    size = (profile.get("sheet") or {}).get("max_items_per_sheet", 16)
    if size <= 0 or len(group) <= size:
        return [group]
    # Evenly sized, not "as many full sheets as fit and a stub at the end".
    # A two-item final sheet is a different performance from a sixteen-item one,
    # and it would be the one holding the last two letters of the alphabet.
    count = -(-len(group) // size)
    base, extra = divmod(len(group), count)
    chunks, at = [], 0
    for i in range(count):
        take = base + (1 if i < extra else 0)
        chunks.append(group[at:at + take])
        at += take
    return chunks


def generate_sheets(key: str, cat: dict, profiles: dict, groups: dict, args) -> tuple:
    ok = failed = 0
    expanded = []
    for (locale, category), group in sorted(groups.items()):
        for n, chunk in enumerate(sheet_chunks(profiles[locale], group), 1):
            expanded.append(((locale, f"{category} {n}"), chunk))

    for (locale, category), group in expanded:
        profile = profiles[locale]
        text, spans = sheet_text(profile, group)
        cached = load_sheet(profile, text)

        info(f"sheet {locale}/{category}: {len(group)} items, {len(text)} characters"
             + ("  [stored, re-cutting for free]" if cached else ""))
        if not cached and not args.cached_only:
            info(f"  {text[:110]}{'…' if len(text) > 110 else ''}")

        try:
            if cached:
                audio, alignment, request_id = cached
            elif args.cached_only:
                warn(f"no stored sheet for {locale}/{category} — `recut` will not call the API")
                failed += len(group)
                continue
            else:
                audio, alignment, request_id = tts_sheet_request(key, profile, text)
                save_sheet(profile, text, audio, alignment, request_id)
            cuts, _offsets = cut_sheet(audio, alignment, text, spans, cat, profile)
        except Fail as exc:
            warn(str(exc))
            failed += len(group)
            continue

        for r, chunk in zip(group, cuts):
            # A sheet has to be read whole, but that does not mean everything
            # in it should be written. A member whose master already exists was
            # very likely approved from it, and overwriting that would leave the
            # approval attached to audio nobody heard — the spec hash does not
            # change, because nothing about the request changed.
            existing = master_path(r["spec_hash"])
            if existing.exists() and not args.force:
                continue
            write_atomic(existing, chunk)
            append_ledger({
                "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                "key": r["key"], "lang": r["lang"], "locale": r["locale"],
                "category": r["category"], "spec_hash": r["spec_hash"],
                "provider": profile["provider"], "model_id": profile["model_id"],
                "voice_id": profile["voice_id"], "voice_profile_version": profile.get("version", 1),
                "spoken_text": r["spoken_text"],
                "billed_characters": len(text) if r is group[0] else 0,
                "request_id": request_id, "master": rel(master_path(r["spec_hash"])),
                "master_bytes": len(chunk), "status": "generated",
                "synthesis_mode": "sheet", "sheet_group": f"{locale}/{category}",
            })
            ok += 1
        info(f"  cut into {len(cuts)} masters")
    return ok, failed


def tts_request(key: str, profile: dict, text: str, context: dict = None):
    import urllib.error
    import urllib.request

    payload = {
        "text": text,
        "model_id": profile["model_id"],
        "voice_settings": profile.get("settings", {}),
    }
    if profile.get("language_code"):
        payload["language_code"] = profile["language_code"]
    if profile.get("seed") is not None:
        payload["seed"] = profile["seed"]
    if profile.get("pronunciation_dictionaries"):
        payload["pronunciation_dictionary_locators"] = profile["pronunciation_dictionaries"]
    for field in ("previous_text", "next_text"):
        if (context or {}).get(field):
            payload[field] = context[field]

    url = (f"{API_BASE}/text-to-speech/{profile['voice_id']}"
           f"?output_format={profile.get('output_format', 'pcm_22050')}")
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/*"},
        method="POST",
    )

    delay = 2.0
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return resp.read(), resp.headers.get("request-id", "")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", "replace")[:300]
            if exc.code in (429, 500, 502, 503, 504) and attempt < 4:
                sleep_for = delay + (os.getpid() % 7) / 10.0   # a little jitter
                warn(f"HTTP {exc.code}, retrying in {sleep_for:.1f}s")
                time.sleep(sleep_for)
                delay *= 2
                continue
            raise Fail(f"HTTP {exc.code}: {body}")
        except urllib.error.URLError as exc:
            if attempt < 4:
                time.sleep(delay)
                delay *= 2
                continue
            raise Fail(f"network error: {exc.reason}")
    raise Fail("exhausted retries")


# --------------------------------------------------------------------------
# process  (ffmpeg; no network)
# --------------------------------------------------------------------------

def require_ffmpeg() -> None:
    for tool in ("ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            raise Fail(f"{tool} is not on PATH. macOS: brew install ffmpeg")


def run(cmd: list) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def probe_duration(path: Path) -> float:
    res = run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
               "-of", "default=nw=1:nk=1", str(path)])
    try:
        return float(res.stdout.strip())
    except ValueError:
        return 0.0


def measure_levels(path: Path):
    """Mean and peak level in dBFS via volumedetect. (None, None) if silent.

    volumedetect works on any length, which is the whole reason it is used
    instead of an R128 measurement.
    """
    res = run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect",
               "-f", "null", "-"])
    mean = re.search(r"mean_volume:\s*(-?\d+(?:\.\d+)?) dB", res.stderr)
    peak = re.search(r"max_volume:\s*(-?\d+(?:\.\d+)?) dB", res.stderr)
    if not mean or not peak:
        return None, None
    return float(mean.group(1)), float(peak.group(1))


def cap_internal_silence(pcm: bytes, cat: dict):
    """Shorten pauses *inside* a clip, without touching its ends.

    A model asked for "ocean wave" may leave a second and a half between the
    two words. That is not a cutting error — the pause is genuinely in the
    recording — but a child waiting on it hears a clip that has finished.

    Only silence with sound on both sides is shortened, so a leading or
    trailing pause is left for the trimmer, and a clip with nothing to shorten
    comes back byte-identical.

    Returns the audio and the spans it removed, in source time. A phrase that
    the game plays only part of needs its word boundaries mapped through this
    edit, and guessing afterwards is how a consonant gets clipped.
    """
    cap_ms = cat["processing"].get("max_internal_silence_ms")
    if not cap_ms:
        return pcm, []

    fmt = cat["master_format"]
    rate = fmt["sample_rate"]
    frame = (fmt["bits"] // 8) * fmt["channels"]
    samples = array.array("h")
    samples.frombytes(pcm[:len(pcm) - len(pcm) % frame])
    levels, step = frame_levels(samples, rate)
    if not levels:
        return pcm, []

    peak = max(levels)
    sound = runs_above(levels, max(peak - 40.0, -55.0))
    if len(sound) < 2:
        return pcm, []

    cap_frames = max(int(cap_ms / (1000 * step / rate)), 1)
    keep, at = [], 0
    for before, after in zip(sound, sound[1:]):
        gap = after[0] - before[1] - 1
        if gap <= cap_frames:
            continue
        # Keep half the cap either side of the cut, so the join stays in
        # silence and no consonant is clipped by it.
        cut_from = before[1] + 1 + cap_frames // 2
        cut_to = after[0] - cap_frames // 2
        keep.append((at, cut_from))
        at = cut_to
    if not keep:
        return pcm, []
    keep.append((at, len(levels) + 1))

    out = bytearray()
    removed = []
    previous_end = 0
    for lo, hi in keep:
        if lo > previous_end:
            removed.append((previous_end * step / rate, lo * step / rate))
        out += pcm[lo * step * frame:min(hi * step * frame, len(pcm))]
        previous_end = hi
    return bytes(out), removed


def lead_silence(pcm: bytes, cat: dict) -> float:
    """How much quiet the trim will take off the front, in seconds."""
    fmt = cat["master_format"]
    samples = array.array("h")
    samples.frombytes(pcm[:len(pcm) - len(pcm) % 2])
    if sys.byteorder == "big":
        samples.byteswap()
    floor = 32768.0 * (10 ** (cat["processing"]["trim_silence_db"] / 20.0))
    for i, v in enumerate(samples):
        if abs(v) >= floor:
            return i / float(fmt["sample_rate"] * fmt["channels"])
    return 0.0


def process_one(master: Path, out: Path, cat: dict, boundaries=None, trim: bool = True) -> dict:
    """Trim, level, fade and encode. Deterministic: same input, same output."""
    p = cat["processing"]
    fmt = cat["master_format"]
    ship = cat["ship_format"]

    with tempfile.TemporaryDirectory() as tmpdir:
        raw, removed = cap_internal_silence(master.read_bytes(), cat)
        staged = Path(tmpdir) / "master.pcm"
        staged.write_bytes(raw)

        src = ["-f", "s16le", "-ar", str(fmt["sample_rate"]),
               "-ac", str(fmt["channels"]), "-i", str(staged)]
        trimmed = Path(tmpdir) / "trimmed.wav"
        thr = f"{p['trim_silence_db']}dB"
        trim_chain = (f"silenceremove=start_periods=1:start_silence=0:start_threshold={thr},"
                f"areverse,"
                f"silenceremove=start_periods=1:start_silence=0:start_threshold={thr},"
                f"areverse,"
                f"adelay={p['keep_lead_ms']}:all=1,"
                f"apad=pad_dur={p['keep_tail_ms'] / 1000.0}")
        if not trim:
            trim_chain = "anull"

        # Move each boundary onto the shipped clip's timeline.
        #
        # Two edits shift it, and both are measurable rather than guessed:
        # the silence capping reports the spans it removed, and the trim drops
        # the lead silence then puts keep_lead_ms back. Levelling, fades and
        # resampling all leave the timeline alone. The predicted duration is
        # checked against the encoded file below, which is what would catch
        # this model being wrong.
        holds, fades = [], []
        if boundaries:
            lead = lead_silence(raw, cat) if trim else 0.0
            offset = lead - (p["keep_lead_ms"] / 1000.0 if trim else 0.0)

            def onto_clip(at: float) -> float:
                shift = sum(min(at, hi) - lo for lo, hi in removed if lo < at)
                return max(at - shift - offset, 0.0)

            for hold, until in boundaries:
                # Both ends go through the same mapping, so a fade that spanned
                # a shortened pause comes out shortened too rather than running
                # on into the next word.
                a, b = onto_clip(hold), onto_clip(until)
                holds.append(a)
                fades.append(max(b - a, 0.0))
        res = run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"] + src +
                  ["-af", trim_chain, str(trimmed)])
        if res.returncode != 0:
            raise Fail(f"trim failed for {rel(master)}: {res.stderr.strip()[:300]}")

        duration = probe_duration(trimmed)
        if duration <= 0.05:
            raise Fail(f"{rel(master)} is silent after trimming")

        # Levelling: RMS, not EBU R128.
        #
        # loudnorm is the obvious choice and the wrong one here. Integrated
        # loudness needs a window these clips do not have — a Czech letter name
        # like "bé" is under 400ms, and loudnorm returns -inf for it, which then
        # fails as an input to its own second pass.
        #
        # Mean RMS with a peak ceiling works at any length, is deterministic,
        # and gives a more consistent *batch* than per-clip R128 would: one
        # target for the whole voice family rather than each clip maximised
        # against itself. Consistency is what matters when a child hears these
        # forty-two clips back to back.
        mean_db, peak_db = measure_levels(trimmed)
        if mean_db is None:
            raise Fail(f"{rel(master)} has no measurable signal")

        gain = p["target_rms_dbfs"] - mean_db
        headroom = p["peak_ceiling_dbfs"] - peak_db
        gain = min(gain, headroom)          # never clip, even if that leaves it quiet

        fade = p["fade_ms"] / 1000.0
        chain = (f"volume={gain:.2f}dB,"
                 f"afade=t=in:st=0:d={fade},"
                 f"afade=t=out:st={max(duration - fade, 0):.4f}:d={fade},"
                 f"aresample={ship['sample_rate']}")

        encoded = Path(tmpdir) / "out.mp3"
        res = run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(trimmed),
                   "-af", chain, "-ac", str(ship["channels"]),
                   "-b:a", f"{ship['bitrate_kbps']}k", "-map_metadata", "-1",
                   "-write_xing", "0", str(encoded)])
        if res.returncode != 0:
            raise Fail(f"encode failed for {rel(master)}: {res.stderr.strip()[:300]}")

        data = encoded.read_bytes()
        final_duration = probe_duration(encoded)

    write_atomic(out, data)
    return {
        "word_ends_ms": [int(round(t * 1000)) for t in holds],
        "word_fade_ms": [int(round(t * 1000)) for t in fades],
        "duration_ms": int(round(final_duration * 1000)),
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "mean_dbfs": mean_db,
        "peak_dbfs": peak_db,
        "gain_db": gain,
    }


def cmd_recut(args) -> int:
    """Re-cut every stored sheet with the current guards. Free, and repeatable.

    This is the loop that boundary tuning should live in: change guard_lead_ms
    or guard_tail_ms, recut, process, listen. No request, no credit, no waiting.
    """
    args.key = None
    args.limit = None
    args.confirm = True
    args.dry_run = False
    args.delay = 0
    args.force = True
    args.cached_only = True
    args.max_characters = None
    return cmd_generate(args)


_LOSS_BASELINE: dict = {}

def loss_gate(records: list, locale: str, cat: dict, folder) -> float:
    """How badly a clip may fit its text before it is doubted, for this locale.

    Relative, because the number is not comparable between languages. Greek's
    best alignment scores worse than every other language's median — 2.50
    against 0.09 to 0.78 — while getting the word count right every time, in
    every language measured. A fixed threshold therefore rejected all 41 Greek
    phrases and kept none, which is not a quality judgement, it is a unit
    mismatch.

    So the gate is a multiple of what this locale normally achieves, with a
    floor so that a locale which aligns almost perfectly does not start
    rejecting clips for being slightly less perfect.
    """
    if locale in _LOSS_BASELINE:
        return _LOSS_BASELINE[locale]
    p = cat["processing"]
    losses = []
    for r in records:
        if r["locale"] != locale:
            continue
        path = folder(r)
        if path.exists():
            value = maybe_json(path).get("loss")
            if value is not None:
                losses.append(float(value))
    floor = p.get("loss_floor", 0.8)
    factor = p.get("loss_factor", 3.0)
    if not losses:
        _LOSS_BASELINE[locale] = floor
        return floor
    losses.sort()
    median = losses[len(losses) // 2]
    _LOSS_BASELINE[locale] = max(floor, median * factor)
    return _LOSS_BASELINE[locale]


def alignment_path(spec_hash: str) -> Path:
    folder = MASTERS / "alignments" / spec_hash[:2]
    return folder / f"{spec_hash}.json"


def force_align(key: str, pcm: bytes, text: str, cat: dict) -> dict:
    """Ask the provider where each word sits in audio it did not just make.

    The sheet's own alignment cannot answer this. It is accurate at the ends of
    a sheet and drifts in the middle — measured at over a second on a
    twenty-second sheet, which is not a rounding error but a different answer.
    Forced alignment is given one short clip and its text, so there is nothing
    for it to drift against, and it returns a loss to say how sure it is.
    """
    import urllib.error
    import urllib.request

    fmt = cat["master_format"]
    wav = wav_header(len(pcm), fmt) + pcm
    boundary = "----speechpipeline" + hashlib.sha256(pcm[:64]).hexdigest()[:16]
    parts = []
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
                 f'filename="clip.wav"\r\nContent-Type: audio/wav\r\n\r\n'.encode("utf-8"))
    parts.append(wav)
    parts.append(f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="text"'
                 f'\r\n\r\n{text}\r\n--{boundary}--\r\n'.encode("utf-8"))
    body = b"".join(parts)

    req = urllib.request.Request(
        f"{API_BASE}/forced-alignment", data=body,
        headers={"xi-api-key": key,
                 "Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST")
    delay = 2.0
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", "replace")[:300]
            if exc.code in (429, 500, 502, 503, 504) and attempt < 4:
                warn(f"HTTP {exc.code}, retrying in {delay:.1f}s")
                time.sleep(delay); delay *= 2; continue
            if exc.code == 401 and "forced_alignment" in detail:
                raise Fail(
                    "this API key lacks the 'Forced Alignment' permission. A key's "
                    "permissions cannot be changed after it is created, so make a new "
                    "one granting Text to Speech, Voices, Voice Library and Forced "
                    "Alignment together — see tools/speech/SETUP.md.")
            raise Fail(f"HTTP {exc.code}: {detail}")
        except urllib.error.URLError as exc:
            if attempt < 4:
                time.sleep(delay); delay *= 2; continue
            raise Fail(f"network error: {exc.reason}")
    raise Fail("exhausted retries")


def wav_header(data_len: int, fmt: dict) -> bytes:
    import struct
    rate, ch, bits = fmt["sample_rate"], fmt["channels"], fmt["bits"]
    byte_rate = rate * ch * bits // 8
    return (b"RIFF" + struct.pack("<I", 36 + data_len) + b"WAVEfmt " +
            struct.pack("<IHHIIHH", 16, 1, ch, rate, byte_rate, ch * bits // 8, bits) +
            b"data" + struct.pack("<I", data_len))


def phrase_boundaries(record: dict, profiles: dict, cat: dict):
    """Where to hold each word until, and how long to fade after it.

    Two numbers per boundary, not one. The word is played whole at full volume
    up to the hold point, and only then does the clip fade — fading *into* the
    boundary is what made every word sound cut a syllable short.

    The hold point runs a little past the aligner's end of the word. Aligners
    mark the vowel, not the release that follows it, and the gap the aligner
    reports before the next word is real speech time: a median 40 ms here. The
    hold takes that gap, capped, so a long pause is not sat through.
    """
    words = record["spoken_text"].split()
    if len(words) < 2:
        return []
    path = alignment_path(record["spec_hash"])
    if not path.exists():
        return []
    doc = read_json(path)
    got = [w for w in doc.get("words", []) if w.get("text", "").strip()]
    if len(got) != len(words):
        return []
    limit = loss_gate(load_desired(), record["locale"], cat,
                      lambda r: alignment_path(r["spec_hash"]))
    if doc.get("loss", 0.0) > limit:
        return []

    p = cat["processing"]
    reach = p.get("boundary_reach_ms", 120) / 1000.0
    share = p.get("boundary_hold_share", 0.5)
    fade_min = p.get("boundary_fade_min_ms", 12) / 1000.0
    fade_max = p.get("boundary_fade_ms", 40) / 1000.0
    pairs = []
    for cur, nxt in zip(got, got[1:]):
        end = float(cur["end"])
        # The hold and the fade together stay inside the pause before the next
        # word. Spending the whole pause on the hold and then fading on top of
        # it put the fade over the next word, which was audible as a hint of
        # the letter to come. Half the pause is held, the rest is the fade.
        budget = min(max(float(nxt["start"]) - end, 0.0), reach)
        hold = end + budget * share
        fade = min(max(budget * (1.0 - share), fade_min), fade_max)
        pairs.append((hold, hold + fade))
    return pairs


def cmd_align(args) -> int:
    """Fetch word boundaries for the phrases already recorded.

    Reads the archived masters and sends each with its own text. Nothing is
    synthesised, so no clip changes and no approval is disturbed — the result
    is only a set of timestamps, cached next to the audio.
    """
    ensure_guards()
    cat = load_catalog()
    profiles = load_profiles()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)

    todo = [r for r in records
            if r["category"] == "word" and len(r["spoken_text"].split()) > 1
            and r["status"] in ("generated", "unreviewed", "approved")
            and master_path(r["spec_hash"]).exists()
            and (args.force or not alignment_path(r["spec_hash"]).exists())]
    if not todo:
        info("Every phrase already has its word boundaries.")
        return 0

    todo.sort(key=lambda r: r["key"])
    if args.limit:
        todo = todo[:args.limit]

    rate = cat["master_format"]["sample_rate"]
    seconds = sum(master_path(r["spec_hash"]).stat().st_size / 2.0 / rate for r in todo)
    price = cat.get("pricing_usd_per_hour_audio", {}).get("forced_alignment", 0.40)
    info(f"{len(todo)} phrases, {seconds / 60:.1f} min of audio, about "
         f"${seconds / 3600 * price:.3f}. Forced alignment is billed by audio "
         f"duration at the speech-to-text rate; nothing is synthesised, so no "
         f"clip changes and no approval is disturbed.")
    if not args.confirm:
        info("Re-run with --confirm to do it. Add --limit N to try a few first.")
        return 0

    key = api_key()
    done = skipped = failed = 0
    limit = cat["processing"].get("alignment_max_loss", 1.0)
    for i, r in enumerate(todo, 1):
        try:
            doc = force_align(key, master_path(r["spec_hash"]).read_bytes(),
                              r["spoken_text"], cat)
        except Fail as exc:
            if "permission" in str(exc):
                raise
            warn(f"{r['key']}: {exc}")
            failed += 1
            continue
        path = alignment_path(r["spec_hash"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"text": r["spoken_text"],
                                    "words": doc.get("words", []),
                                    "loss": doc.get("loss", 0.0)},
                                   ensure_ascii=False, indent=1), encoding="utf-8")
        loss = doc.get("loss", 0.0)
        mark = ""
        if loss > limit:
            mark = f"  loss {loss:.2f} above {limit} — will not be used"
            skipped += 1
        info(f"[{i}/{len(todo)}] {r['display_text']:28s} {loss:.3f}{mark}")
        done += 1
    info(f"Aligned {done}, unusable {skipped}, failed {failed}. "
         f"Run `process --force --category word` to fold the timings into the clips.")
    return 1 if failed else 0


def cmd_process(args) -> int:
    ensure_guards()
    require_ffmpeg()
    cat = load_catalog()
    profiles = load_profiles()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    if args.category:
        records = [r for r in records if r["category"] in args.category]
    if getattr(args, "key", None):
        needle = args.key.lower()
        records = [r for r in records
                   if needle in r["key"].lower() or needle in r["display_text"].lower()]
    classify(records)

    todo = [r for r in records if r["status"] == "generated" or (args.force and r["status"] in ("unreviewed", "approved"))]
    if not todo:
        info("Nothing to process.")
        return 0

    done = failed = 0
    for i, r in enumerate(todo, 1):
        master = master_path(r["spec_hash"])
        out = processed_path(r["render_hash"])
        if not master.exists():
            warn(f"{r['key']}: master missing, run `generate` first")
            failed += 1
            continue
        word_ends = phrase_boundaries(r, profiles, cat) if r["category"] == "word" else []
        try:
            meta = process_one(master, out, cat, word_ends)
        except Fail as exc:
            warn(str(exc))
            failed += 1
            continue

        bounds = cat["categories"][r["category"]]["duration_ms"]
        flags = []
        if not (bounds["min"] <= meta["duration_ms"] <= bounds["max"]):
            flags.append(f"{meta['duration_ms']}ms outside {bounds['min']}-{bounds['max']}ms")
        if meta["gain_db"] < cat["processing"]["target_rms_dbfs"] - meta["mean_dbfs"] - 0.5:
            flags.append("peak-limited, quieter than target")
        if meta["gain_db"] > 12.0:
            # The provider hands back wildly inconsistent levels for isolated
            # short utterances — 20 dB between two letters of the same alphabet
            # is normal. Levelling fixes the loudness but lifts the noise floor
            # with it, so a take this quiet is worth hearing before it is kept.
            flags.append(f"quiet take, boosted {meta['gain_db']:+.1f}dB — listen for hiss")
        flag = ("  <-- " + "; ".join(flags)) if flags else ""
        if meta["word_ends_ms"]:
            side = processed_path(r["render_hash"]).with_suffix(".json")
            # Atomically, like the clip beside it. A run killed mid-write left
            # a zero-byte sidecar that then failed to parse on every later read.
            write_atomic(side, json.dumps({"word_ends_ms": meta["word_ends_ms"],
                                           "word_fade_ms": meta["word_fade_ms"]}).encode("utf-8"))
        info(f"[{i}/{len(todo)}] {r['key']:24s} {meta['duration_ms']:5d}ms  "
             f"{meta['bytes']:6d}B  {meta['gain_db']:+5.1f}dB{flag}"
             + (f"  words end at {meta['word_ends_ms']}" if meta["word_ends_ms"] else ""))
        done += 1

    info("")
    info(f"processed {done}, failed {failed}")
    if done:
        info(f"Clips are in {rel(MASTERS_PROCESSED)}. Listen to them, then run `review`.")
    return 1 if failed else 0


# --------------------------------------------------------------------------
# listen — a human-readable copy of the clips, plus a page to review them in
# --------------------------------------------------------------------------
#
# Shipped clips are content-addressed (clips/c8/c81f3a….mp3) so that "a" and "A"
# cannot collide on a case-insensitive filesystem and so that no Android path
# ever contains a non-ASCII character. That is right for the pack and hopeless
# for a person: nobody can review a folder of hex.
#
# `listen` makes a throwaway copy under build/, named for what it says, with a
# page that plays them in order and records the verdicts.

LISTEN_PAGE = """<!DOCTYPE html>
<html lang="en">
<meta charset="utf-8">
<title>__TITLE__</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
         margin: 0 auto; padding: 24px; max-width: 860px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .sub { opacity: .65; margin-bottom: 20px; font-size: 14px; }
  .bar { position: sticky; top: 0; padding: 12px 0; margin-bottom: 8px;
         background: Canvas; border-bottom: 1px solid rgba(128,128,128,.3);
         display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
  input[type=text] { font: inherit; padding: 6px 8px; border-radius: 6px;
                     border: 1px solid rgba(128,128,128,.5); background: Canvas; color: inherit; }
  button { font: inherit; padding: 6px 12px; border-radius: 6px; cursor: pointer;
           border: 1px solid rgba(128,128,128,.5); background: Canvas; color: inherit; }
  button.primary { background: #2563eb; color: #fff; border-color: #2563eb; }
  .count { margin-left: auto; opacity: .7; font-size: 14px; }
  table { border-collapse: collapse; width: 100%; }
  td, th { padding: 8px 6px; border-bottom: 1px solid rgba(128,128,128,.2); text-align: left;
           vertical-align: middle; }
  th { font-size: 13px; opacity: .7; font-weight: 600; }
  tr.cur { background: rgba(37,99,235,.10); }
  tr.approved td.v { color: #16a34a; font-weight: 600; }
  tr.rejected td.v { color: #dc2626; font-weight: 600; }
  .glyph { font-size: 22px; font-weight: 700; }
  .spoken { font-size: 17px; }
  .meta { font-size: 12px; opacity: .6; }
  .flag { color: #b45309; font-size: 12px; }
  .play { width: 40px; text-align: center; }
  .note { width: 150px; }
  kbd { font: 12px ui-monospace, monospace; border: 1px solid rgba(128,128,128,.5);
        border-radius: 4px; padding: 1px 5px; }
</style>

<h1>__TITLE__</h1>
<div class="sub">
  Click a row to hear it. <kbd>space</kbd> replay &nbsp; <kbd>A</kbd> approve &nbsp;
  <kbd>R</kbd> reject &nbsp; <kbd>↑</kbd><kbd>↓</kbd> move.
  Listen on the television if you can, not on a laptop.
</div>

<div class="bar">
  <label>Reviewer <input type="text" id="reviewer" placeholder="your name" size="18"></label>
  <button id="playall">Play all</button>
  <button class="primary" id="export">Download verdicts CSV</button>
  <span class="count" id="count"></span>
</div>

<table>
  <thead><tr>
    <th></th><th>Shows</th><th>Says</th><th>Sounds like</th><th></th><th>Note</th>
  </tr></thead>
  <tbody id="rows"></tbody>
</table>

<script>
const CLIPS = __DATA__;
const LOCALE = "__LOCALE__";
let cur = 0;
const verdicts = {};
try { Object.assign(verdicts, JSON.parse(localStorage.getItem("lm_" + LOCALE) || "{}")); } catch (e) {}
const notes = {};
try { Object.assign(notes, JSON.parse(localStorage.getItem("lm_n_" + LOCALE) || "{}")); } catch (e) {}

const audio = new Audio();
const tbody = document.getElementById("rows");

function save() {
  try {
    localStorage.setItem("lm_" + LOCALE, JSON.stringify(verdicts));
    localStorage.setItem("lm_n_" + LOCALE, JSON.stringify(notes));
  } catch (e) {}
}

function render() {
  tbody.innerHTML = "";
  CLIPS.forEach((c, i) => {
    const tr = document.createElement("tr");
    tr.className = (i === cur ? "cur " : "") + (verdicts[c.key] || "");
    tr.onclick = (ev) => { if (ev.target.tagName !== "INPUT") { cur = i; play(); render(); } };
    tr.innerHTML =
      '<td class="play">▶</td>' +
      '<td class="glyph">' + c.display + '</td>' +
      '<td class="spoken">' + c.spoken + '</td>' +
      '<td class="meta">' + c.duration_ms + ' ms' +
        (c.flag ? '<br><span class="flag">' + c.flag + '</span>' : '') + '</td>' +
      '<td class="v">' + (verdicts[c.key] === "approved" ? "approved"
                        : verdicts[c.key] === "rejected" ? "rejected" : "") + '</td>' +
      '<td><input type="text" class="note" data-k="' + c.key + '" value="' +
          (notes[c.key] || "").replace(/"/g, "&quot;") + '" placeholder="what was wrong"></td>';
    tbody.appendChild(tr);
  });
  tbody.querySelectorAll("input.note").forEach(inp => {
    inp.oninput = () => { notes[inp.dataset.k] = inp.value; save(); };
  });
  const done = CLIPS.filter(c => verdicts[c.key]).length;
  document.getElementById("count").textContent =
    done + " of " + CLIPS.length + " decided" +
    (done === CLIPS.length ? " — export the CSV" : "");
  const row = tbody.children[cur];
  if (row) row.scrollIntoView({ block: "nearest" });
}

function play() { audio.src = CLIPS[cur].file; audio.play().catch(() => {}); }

function decide(status) {
  const key = CLIPS[cur].key;
  verdicts[key] = status;
  // Approving clears the note. The note is why the clip was doubted, and the
  // audit writes one in before you ever hear it — so approving means you
  // disagree with it, and leaving it behind would export a reason next to a
  // verdict that contradicts it.
  if (status === "approved") delete notes[key];
  save();
  if (cur < CLIPS.length - 1) { cur++; play(); }
  render();
}

document.onkeydown = (e) => {
  if (e.target.tagName === "INPUT") return;
  if (e.key === " ") { e.preventDefault(); play(); }
  else if (e.key.toLowerCase() === "a") decide("approved");
  else if (e.key.toLowerCase() === "r") decide("rejected");
  else if (e.key === "ArrowDown") { e.preventDefault(); cur = Math.min(cur + 1, CLIPS.length - 1); play(); render(); }
  else if (e.key === "ArrowUp") { e.preventDefault(); cur = Math.max(cur - 1, 0); play(); render(); }
};

document.getElementById("playall").onclick = () => {
  cur = 0; play(); render();
  audio.onended = () => {
    if (cur < CLIPS.length - 1) { cur++; play(); render(); } else { audio.onended = null; }
  };
};

document.getElementById("export").onclick = () => {
  const who = document.getElementById("reviewer").value.trim();
  const today = new Date().toISOString().slice(0, 10);
  const esc = (s) => '"' + String(s == null ? "" : s).replace(/"/g, '""') + '"';
  let csv = "key,spec_hash,status,reviewer,date,notes\\n";
  CLIPS.forEach(c => {
    if (!verdicts[c.key]) return;
    const note = verdicts[c.key] === "approved" ? "" : (notes[c.key] || "");
    csv += [c.key, c.spec_hash, verdicts[c.key], who, today, note].map(esc).join(",") + "\\n";
  });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv" }));
  a.download = "review_" + LOCALE + ".csv";
  a.click();
};

render();
</script>
</html>
"""


def flag_clips(clips, measured, rate: int) -> None:
    """Point the reviewer at the clips most likely to be wrong.

    Two signals, both cheap and both learned from earlier rounds. A clip
    holding more separate sounds than its text has words is the signature of a
    neighbour bleeding in. And a clip much longer than others with the same
    amount of text is either padded with silence or carrying something it
    should not — compared against its own length group, because a three-letter
    word is not three-sevenths of a seven-letter one.
    """
    by_length = {}
    for idx, record, duration in measured:
        if duration:
            by_length.setdefault(len(record["spoken_text"]), []).append(duration)
    typical = {n: sorted(v)[len(v) // 2] for n, v in by_length.items() if len(v) >= 3}

    for idx, record, duration in measured:
        master = master_path(record["spec_hash"])
        notes = []
        if master.exists():
            samples = array.array("h")
            raw = master.read_bytes()
            samples.frombytes(raw[:len(raw) - len(raw) % 2])
            levels, step = frame_levels(samples, rate)
            if levels:
                segs = segment_for_gap(runs_above(levels, max(max(levels) - 35.0, -55.0)),
                                       levels, max(int(0.18 * rate / step), 1),
                                       max(int(0.05 * rate / step), 1))
                words = len(record["spoken_text"].split())
                if len(segs) > words:
                    notes.append(f"{len(segs)} sounds for {words} word(s) — check for a neighbour")
                if segs and segs[0][0] * step / rate > 0.20:
                    notes.append(f"{segs[0][0] * step / rate:.2f}s of silence first")

        expected = typical.get(len(record["spoken_text"]))
        if expected and duration > expected * 1.6:
            notes.append("much longer than others this size")

        if notes:
            existing = clips[idx].get("flag") or ""
            clips[idx]["flag"] = "; ".join(([existing] if existing else []) + notes)


def cmd_prune(args) -> int:
    """Delete archived audio nothing asks for any more.

    Two very different piles, so they are treated differently. A processed clip
    is an encoding of a master and costs nothing but seconds to remake, so it
    goes. A master was paid for, and once deleted the only way back is to buy
    it again — those are listed with the words they say and removed only when
    asked for by name.
    """
    cat = load_catalog()
    records = load_desired()
    live_specs = {r["spec_hash"] for r in records}
    live_renders = {r["render_hash"] for r in records}

    ledger = {}
    if LEDGER.exists():
        for row in LEDGER.read_text(encoding="utf-8").splitlines():
            if row.strip():
                entry = json.loads(row)
                ledger[entry["spec_hash"]] = entry

    def orphans(folder: Path, keep: set, suffix: str) -> list:
        return [p for p in sorted(folder.rglob(f"*{suffix}"))
                if p.stem not in keep]

    stale_clips = orphans(MASTERS_PROCESSED, live_renders, ".mp3")
    stale_side = [p.with_suffix(".json") for p in stale_clips if p.with_suffix(".json").exists()]
    stale_masters = orphans(MASTERS_RAW, live_specs, ".pcm")

    def size(paths):
        return sum(p.stat().st_size for p in paths) / 1024.0

    info(f"{len(stale_clips)} processed clips no longer referenced ({size(stale_clips):.0f} KB). "
         f"These re-encode from the masters for free.")
    info(f"{len(stale_masters)} masters no longer referenced ({size(stale_masters):.0f} KB). "
         f"These cost money to replace.")
    if stale_masters:
        info("")
        shown = 0
        for p in stale_masters:
            entry = ledger.get(p.stem)
            what = f"{entry['lang']} {entry['spoken_text']!r}" if entry else "not in the ledger"
            info(f"  {what}")
            shown += 1
            if shown >= 20 and len(stale_masters) > 20:
                info(f"  … and {len(stale_masters) - shown} more")
                break

    if not args.confirm:
        info("")
        info("Nothing deleted. Re-run with --confirm for the processed clips, "
             "and --confirm --masters to include the masters.")
        return 0

    gone = 0
    for p in stale_clips + stale_side:
        p.unlink()
        gone += 1
    if args.masters:
        for p in stale_masters:
            alignment = alignment_path(p.stem)
            if alignment.exists():
                alignment.unlink()
            p.unlink()
            gone += 1
    for folder in (MASTERS_PROCESSED, MASTERS_RAW):
        for sub in sorted(folder.glob("*")):
            if sub.is_dir() and not any(sub.iterdir()):
                sub.rmdir()
    info(f"Deleted {gone} file(s).")
    if not args.masters and stale_masters:
        info(f"Kept {len(stale_masters)} masters. Add --masters to remove those too.")
    return 0


def cmd_phrases(args) -> int:
    """Write out each stage of a phrase, so the boundaries can be judged by ear.

    This is the only check that counts. A boundary table looks right whether or
    not it lands between the words; the way to know is to hear THIS, then THIS
    IS, then THIS IS GOOD, and notice whether any of them clips a syllable.
    """
    require_ffmpeg()
    cat = load_catalog()
    profiles = load_profiles()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)

    rows = []
    for r in records:
        if r["category"] != "word" or len(r["spoken_text"].split()) < 2:
            continue
        ends = phrase_boundaries(r, profiles, cat)
        if ends and processed_path(r["render_hash"]).exists():
            rows.append((r, ends))
    if not rows:
        # Three different situations reached this one error, and only two of
        # them are actually a missing step.
        wanted = [r for r in records
                  if r["category"] == "word" and len(r["spoken_text"].split()) > 1]
        aligned = [r for r in wanted if alignment_path(r["spec_hash"]).exists()]
        usable = [r for r in aligned if phrase_boundaries(r, profiles, cat)]
        if not aligned:
            raise Fail("no phrase has word boundaries yet — run `align --confirm` "
                       "and then `process --force --category word`")
        if usable:
            raise Fail(f"{len(usable)} phrase(s) have usable boundaries but no encoded clip "
                       "to apply them to — run `process --force --category word`")
        # Aligned, but nothing meets the loss bar. That is a quality result, not
        # an unfinished step, and the game already copes: a phrase without
        # boundaries is played whole and simply not narrated word by word — see
        # processing.alignment_note in catalog.json. Failing here stopped `next`
        # one step before it built the review page, so a language whose phrases
        # align badly could not be listened to at all. Listening is the only
        # thing that can say whether the clips are any good, and it is exactly
        # what a language in this state needs most. Greek is how this was found.
        limit = cat["processing"].get("alignment_max_loss", 1.0)
        worst = sorted(maybe_json(alignment_path(r["spec_hash"])).get("loss", 0.0)
                       for r in aligned)
        warn(f"{len(aligned)} phrase(s) are aligned but none fit well enough to cut "
             f"(best loss {worst[0]:.2f}, alignment_max_loss is {limit}). Those phrases "
             f"will be played whole instead of word by word; the clips themselves are "
             f"unaffected. Carry on and listen to them.")
        return 0
    rows.sort(key=lambda x: x[0]["key"])
    if args.limit:
        rows = rows[:args.limit]

    # Per locale, like the listening pages. One shared folder meant looking at
    # German overwrote Czech, and the page gave no clue which language it was
    # showing — you had to remember what you last ran.
    locales = sorted({r["locale"] for r, _ in rows})
    folder = BUILD / "phrases" / (locales[0] if len(locales) == 1 else "all")
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)

    listed = []
    for i, (r, ends) in enumerate(rows, 1):
        src = processed_path(r["render_hash"])
        meta = maybe_json(src.with_suffix(".json"))
        stops = meta.get("word_ends_ms", [])
        fades = meta.get("word_fade_ms", [])
        words = r["display_text"].split()
        stages = []
        for n, stop_ms in enumerate(stops, 1):
            name = f"{i:03d}_{word_slug(r['display_text'])}_{n}.mp3"
            fade_s = (fades[n - 1] if n <= len(fades) else 40) / 1000.0
            hold_s = stop_ms / 1000.0
            # The fade starts where the word ends. Starting it earlier — which
            # is what this did at first — quietens the last syllable and makes
            # every stage sound clipped.
            res = run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src),
                       "-t", f"{hold_s + fade_s:.3f}", "-af",
                       f"afade=t=out:st={hold_s:.3f}:d={max(fade_s, 0.01):.3f}",
                       str(folder / name)])
            if res.returncode == 0:
                stages.append((" ".join(words[:n]), name, stop_ms))
        full = f"{i:03d}_{word_slug(r['display_text'])}_full.mp3"
        shutil.copyfile(src, folder / full)
        stages.append((r["display_text"], full, 0))
        listed.append((r, stages))

    write_phrase_page(folder / "index.html", listed)
    info(f"-> {rel(folder / 'index.html')}  ({len(listed)} phrases)")
    info("Listen to each stage in turn. A stage that clips a syllable or runs "
         "into the next word means that phrase's alignment is wrong; note the "
         "phrase and it can be dropped or re-aligned individually.")
    return 0


def write_phrase_page(path: Path, listed: list) -> None:
    """The page says which language it is showing, because a page that does not
    is a page you have to remember the provenance of."""
    langs = ", ".join(sorted({r["locale"] for r, _ in listed}))
    parts = [f"<!doctype html><meta charset='utf-8'><title>Phrase boundaries — {langs}</title>",
             "<style>body{font:15px/1.5 system-ui;margin:2rem;max-width:52rem}"
             "h2{margin:1.6rem 0 .3rem;font-size:1rem}"
             "div{display:flex;align-items:center;gap:.6rem;margin:.15rem 0}"
             "span{min-width:16rem}audio{height:2rem}em{color:#777;font-style:normal}"
             "</style>",
             f"<h1>Phrase boundaries — {langs}</h1><p>Each row is what the child hears after "
             "collecting that many words. It should end cleanly on a word.</p>"]
    for r, stages in listed:
        parts.append(f"<h2>{r['display_text']} <em>{r['lang']}</em></h2>")
        for text, name, stop_ms in stages:
            at = f"<em>{stop_ms} ms</em>" if stop_ms else "<em>full</em>"
            parts.append(f"<div><span>{text}</span>"
                         f"<audio controls preload=none src='{name}'></audio>{at}</div>")
    path.write_text("\n".join(parts), encoding="utf-8")


def cmd_listen(args) -> int:
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)

    if args.category:
        records = [r for r in records if r["category"] in args.category]
    ready = [r for r in records if r["status"] in ("unreviewed", "rejected", "approved")]
    if args.pending:
        ready = [r for r in ready if r["status"] != "approved"]

    # A clip asked for and quietly absent is worse than an error. Say which,
    # and say what would produce it.
    waiting = {}
    for r in records:
        if r["status"] in ("missing", "generated", "unconfigured"):
            waiting.setdefault(r["status"], []).append(r)
    for status, group in sorted(waiting.items()):
        needs = {"missing": "`generate`", "generated": "`process`",
                 "unconfigured": "a voice_id in voice_profiles.json"}[status]
        names = ", ".join(sorted(x["display_text"] for x in group)[:6])
        warn(f"{len(group)} clip(s) not on the page because they are {status} "
             f"— run {needs}: {names}{' …' if len(group) > 6 else ''}")

    if not ready:
        raise Fail("no processed clips to listen to — run `generate` and `process` first")

    for locale in sorted({r["locale"] for r in ready}):
        rows = [r for r in ready if r["locale"] == locale]
        rows.sort(key=lambda r: (r["category"], r["key"]))
        suffix = ("_" + "_".join(sorted(args.category))) if args.category else ""
        folder = BUILD / "listen" / f"{locale}{suffix}"
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True)

        clips, measured = [], []
        for i, r in enumerate(rows, 1):
            src = processed_path(r["render_hash"])
            if not src.exists():
                continue
            # Numbered so the order is the alphabet's, and so that "a" and "A"
            # cannot collide on a case-insensitive filesystem.
            slug = r["key"].rsplit(".", 1)[-1]
            dest = folder / f"{i:03d}_{slug}.mp3"
            shutil.copy2(src, dest)

            duration = int(round(probe_duration(src) * 1000)) if shutil.which("ffprobe") else 0
            bounds = cat["categories"][r["category"]]["duration_ms"]
            flag = ""
            if duration and not (bounds["min"] <= duration <= bounds["max"]):
                flag = "unusual length"
            measured.append((len(clips), r, duration))
            clips.append({
                "key": r["key"], "spec_hash": r["spec_hash"],
                "display": r["display_text"], "spoken": r["spoken_text"],
                "file": dest.name, "duration_ms": duration, "flag": flag,
            })

        flag_clips(clips, measured, rate=cat["master_format"]["sample_rate"])

        page = (LISTEN_PAGE
                .replace("__TITLE__", f"Studio Voice review — {locale}")
                .replace("__LOCALE__", locale)
                .replace("__DATA__", json.dumps(clips, ensure_ascii=False, indent=1)))
        (folder / "index.html").write_text(page, encoding="utf-8")

        info(f"{locale}: {len(clips)} clips -> {rel(folder)}")
        info(f"  open {rel(folder / 'index.html')}")

    info("")
    info("Listen, decide, then download the CSV from the page and run:")
    info("  speech_pipeline.py review --import ~/Downloads/review_<locale>.csv")
    return 0


# --------------------------------------------------------------------------
# review
# --------------------------------------------------------------------------

def cmd_review(args) -> int:
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    if getattr(args, "category", None) and not args.import_file:
        records = [r for r in records if r["category"] in args.category]
    classify(records)

    if args.import_file:
        path = Path(args.import_file)
        if not path.exists():
            raise Fail(f"no such file: {path}")
        merged = {}
        with path.open(encoding="utf-8", newline="") as fh:
            for row in csv.DictReader(fh):
                if not row.get("key") or not row.get("status"):
                    continue
                status = row["status"].strip().lower()
                if status not in ("approved", "rejected", "pending", ""):
                    raise Fail(f"{row['key']}: status must be approved, rejected or pending")
                if status in ("", "pending"):
                    continue
                # By spec_hash, not by key. learning.char.a exists in every
                # language, so matching on the key alone files an English
                # review under whichever language happens to come first — which
                # is exactly what happened, and it silently emptied the English
                # record while polluting the Czech one.
                match = next((r for r in records if r["spec_hash"] == row.get("spec_hash")), None)
                if match is None:
                    match = next((r for r in records if r["key"] == row["key"]
                                  and (not args.language or r["lang"] in args.language)), None)
                    if match is not None and not args.language:
                        candidates = {r["locale"] for r in records if r["key"] == row["key"]}
                        if len(candidates) > 1:
                            raise Fail(
                                f"{row['key']} exists in {', '.join(sorted(candidates))} and the "
                                "row carries no spec_hash — re-export the sheet, or say which "
                                "with --language")
                if match is None:
                    warn(f"{row['key']} is not in the current catalog — skipped")
                    continue
                locale = match["locale"]
                merged.setdefault(locale, []).append({
                    "key": row["key"], "spec_hash": row.get("spec_hash", ""),
                    "status": status, "reviewer": row.get("reviewer", ""),
                    "date": row.get("date", "") or time.strftime("%Y-%m-%d"),
                    "notes": row.get("notes", ""),
                })
        for locale, rows in merged.items():
            existing = load_reviews(locale)
            for row in rows:
                existing[(row["key"], row["spec_hash"])] = row
            save_reviews(locale, list(existing.values()))
            info(f"{locale}: {len(rows)} decisions -> {rel(review_path(locale))}")
        return 0

    # export
    pending = [r for r in records if r["status"] in ("unreviewed", "rejected")]
    if not pending:
        info("Nothing awaiting review.")
        return 0
    BUILD.mkdir(parents=True, exist_ok=True)
    by_locale = {}
    for r in pending:
        by_locale.setdefault(r["locale"], []).append(r)
    for locale, rows in by_locale.items():
        out = BUILD / f"review_{locale}.csv"
        # Anything `audit` doubted comes first and arrives already marked
        # rejected with the reason in the notes, so the tedious part — hunting
        # for the broken one among a hundred good ones — is done. A blank
        # status still means nobody has judged it.
        def suspicion(r):
            path = audit_path(r["render_hash"])
            return read_json(path) if path.exists() else None

        marked = 0
        with out.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow(REVIEW_FIELDS + ["display_text", "spoken_text", "clip"])
            ordered = sorted(rows, key=lambda x: (not (suspicion(x) or {}).get("suspect"),
                                                  x["key"]))
            for r in ordered:
                doubt = suspicion(r) or {}
                status = "rejected" if doubt.get("suspect") else ""
                marked += 1 if status else 0
                writer.writerow([r["key"], r["spec_hash"], status, "", "",
                                 doubt.get("why", ""),
                                 r["display_text"], r["spoken_text"], r["clip"]])
        info(f"{locale}: {len(rows)} clips -> {rel(out)}"
             + (f"  ({marked} pre-marked rejected by audit)" if marked else ""))
    info("")
    info("Fill in the status column (approved / rejected), then:")
    info("  speech_pipeline.py review --import build/speech/review_<locale>.csv")
    return 0


# --------------------------------------------------------------------------
# pack
# --------------------------------------------------------------------------

def cmd_retake(args) -> int:
    """Ask for specific clips to be recorded again, alone.

    The alternative — re-recording the sheet they came from — would replace
    fifteen clips somebody has already listened to in order to fix one. This
    changes only the named keys, and only their hashes, so every other approval
    stands.
    """
    records = load_desired()
    known = {(r["lang"], r["key"]) for r in records}

    path = SPEECH_SRC / "retakes.json"
    doc = read_json(path) if path.exists() else {"schema_version": 1, "languages": {}}
    doc.setdefault("languages", {})

    if args.rejected:
        wanted = []
        for r in records:
            if args.language and r["lang"] not in args.language:
                continue
            review = load_reviews(r["locale"]).get((r["key"], r["spec_hash"]))
            if review and review.get("status") == "rejected":
                wanted.append((r["lang"], r["key"], review.get("notes", "")))
    else:
        wanted = []
        for key in args.key or []:
            matches = [r for r in records if r["key"] == key
                       and (not args.language or r["lang"] in args.language)]
            if not matches:
                raise Fail(f"{key} is not in the catalog"
                           + (" for that language" if args.language else ""))
            if len(matches) > 1:
                raise Fail(f"{key} exists in {', '.join(sorted(m['lang'] for m in matches))}"
                           " — say which with --language")
            wanted.append((matches[0]["lang"], key, args.reason or ""))

    if not wanted:
        info("Nothing to retake.")
        return 0

    for lang, key, reason in wanted:
        if (lang, key) not in known:
            raise Fail(f"{key} is not in the catalog for {lang}")
        entry = doc["languages"].setdefault(lang, {}).setdefault(key, {"n": 0})
        entry["n"] = int(entry.get("n", 0)) + 1
        entry["reason"] = reason or entry.get("reason", "")
        # Each retake states its own conditions. Carriers used to survive from
        # the attempt before, so asking for a follower and no leader silently
        # kept the leader — and the retake that was meant to test 'nothing in
        # front of it' tested nothing of the kind.
        for field in ("carrier_before", "carrier_after", "previous_text", "next_text"):
            entry.pop(field, None)
        if args.no_carrier:
            # An empty list is the existing way to say "nothing either side" —
            # see retake_context. The carrier is a remedy for a short item read
            # first or last, and its price is a cut; when the cut is what keeps
            # failing, removing it is the condition left to try.
            entry["carrier_before"] = []
            entry["carrier_after"] = []
        if args.previous_text:
            entry["previous_text"] = args.previous_text
        if args.carrier:
            entry["carrier_before"] = list(args.carrier)
            entry.pop("previous_text", None)
        if args.carrier_after:
            entry["carrier_after"] = list(args.carrier_after)
            entry.pop("next_text", None)
        entry["asked_on"] = time.strftime("%Y-%m-%d")
        info(f"  {lang} {key}  -> take {entry['n']}" + (f"  ({reason})" if reason else ""))

    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    info("")
    info(f"{len(wanted)} clip(s) staged in {rel(path)}, one request each.")
    if args.carrier or args.carrier_after:
        around = " and ".join(filter(None, [
            f"after {', '.join(args.carrier)}" if args.carrier else "",
            f"before {', '.join(args.carrier_after)}" if args.carrier_after else ""]))
        info(f"Each is recorded {around}; those words are then discarded.")
        info("Being neither first nor last is the position a sheet item is read best in.")
    else:
        info("No sheet, and therefore no cutting. Next: extract, then generate.")
    return 0


def cmd_pack(args) -> int:
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)

    langs = sorted({r["lang"] for r in records})
    for lang in langs:
        per = [r for r in records if r["lang"] == lang]
        approved = [r for r in per if r["status"] == "approved"]
        if not approved:
            info(f"{lang}: no approved clips, no pack written")
            continue

        pack_dir = PACKS / lang
        clips_dir = pack_dir / "clips"
        if clips_dir.exists():
            shutil.rmtree(clips_dir)

        # Every clip has to be there before anything is written. Removing the
        # clips directory and then failing partway leaves the previous
        # manifest pointing at files that no longer exist — which is what
        # Romanian shipped with, 72 of its 280 entries pointing at nothing.
        absent = [r for r in approved if not processed_path(r["render_hash"]).exists()]
        if absent:
            raise Fail(
                f"{lang}: {len(absent)} approved clip(s) have not been encoded, so the "
                f"pack would reference files that do not exist. Run "
                f"`process --language {lang}` first. First few: "
                + ", ".join(r["key"] for r in absent[:5]))

        items = {}
        for r in approved:
            src = processed_path(r["render_hash"])
            data = src.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            asset = f"clips/{digest[:2]}/{digest[:12]}.mp3"
            write_atomic(pack_dir / asset, data)
            side = processed_path(r["render_hash"]).with_suffix(".json")
            side_doc = maybe_json(side)
            items[r["key"]] = {
                "asset": asset,
                "word_ends_ms": side_doc.get("word_ends_ms", []),
                "word_fade_ms": side_doc.get("word_fade_ms", []),
                "duration_ms": int(round(probe_duration(src) * 1000)) if shutil.which("ffprobe") else 0,
                "sha256": digest,
                "display_text": r["display_text"],
                "spoken_text": r["spoken_text"],
            }

        broken = [k for k, v in items.items() if not (pack_dir / v["asset"]).exists()]
        if broken:
            raise Fail(f"{lang}: {len(broken)} clip(s) did not reach {rel(pack_dir)} — "
                       f"refusing to write a manifest that lies about what shipped")

        coverage, counts = {}, {}
        for category in categories_for(cat, lang, cat["languages"][lang]):
            wanted = [r for r in per if r["category"] == category]
            got = [r for r in approved if r["category"] == category]
            counts[category] = len(got)
            if not wanted:
                # The language declares the category and needs nothing in it —
                # English inflects no numbers, so it has no number_form clips to
                # be missing. That is not the same as a gap, and a pack should
                # not read as incomplete because of it.
                coverage[category] = "not_needed"
            else:
                coverage[category] = ("complete" if len(got) == len(wanted)
                                      else "partial" if got else "none")

        manifest = {
            "schema_version": 1,
            "pack_version": args.pack_version,
            "lang": lang,
            "locale": per[0]["locale"],
            "voice_profile": f"{per[0]['locale']}@{load_profiles()[per[0]['locale']].get('version', 1)}",
            "coverage": coverage,
            "counts": counts,
            "items": dict(sorted(items.items())),
        }
        (pack_dir / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=False) + "\n",
            encoding="utf-8")
        info(f"{lang}: {len(items)} clips, coverage {coverage} -> {rel(pack_dir)}")
    return 0


# --------------------------------------------------------------------------
# verify  (CI gate; no network)
# --------------------------------------------------------------------------

## Must match UI_TRIM in speech_manager.gd exactly.
UI_TRIM_RE = re.compile(r"^[\s,.:;]+|[\s,.:;]+$")

SECRET_PATTERNS = [
    re.compile(r"\bsk_[0-9a-f]{32,}\b"),
    re.compile(r"xi-api-key\s*[:=]\s*[\"'][^\"'{$]{8,}"),
    re.compile(r"ELEVENLABS_API_KEY\s*=\s*[\"'][^\"'{$]{8,}"),
]

SECRET_SKIP_DIRS = {".git", ".godot", "build", "voice_masters", "android", "_unused_assets", "node_modules"}
SECRET_SUFFIXES = {".gd", ".py", ".json", ".cfg", ".md", ".csv", ".sh", ".txt", ".tres", ".godot", ".yml", ".yaml"}


def parse_gd_table(name: str) -> dict:
    """Read one of game_config.gd's letter tables without running Godot.

    The game and the pipeline need the same answer to "which letters does this
    language have", and the game cannot read data/speech. So game_config.gd is
    the single definition and this reads it, rather than keeping a second copy
    here and asserting the two agree.
    """
    if not GAME_CONFIG.exists():
        return {}
    text = GAME_CONFIG.read_text(encoding="utf-8")
    match = re.search(r"const\s+%s\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}" % name, text, re.S)
    if not match:
        return {}
    return dict(re.findall(r'"([a-z]{2})"\s*:\s*"([^"]*)"', match.group(1)))


LATIN_BASIC = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def language_letters(lang: str):
    """Every letter this language records, in order: alphabet first, then the
    letters that only ever turn up inside words."""
    alphabets = parse_gd_table("ALPHABETS")
    word_only = parse_gd_table("WORD_ONLY_LETTERS")
    if not alphabets and not word_only:
        raise Fail("could not read ALPHABETS from scripts/game_config.gd")
    spawned = grapheme_split(alphabets.get(lang, LATIN_BASIC))
    extra = grapheme_split(word_only.get(lang, ""))
    return spawned, extra


def check(errors: list, condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def cmd_verify(args) -> int:
    errors, warnings = [], []
    cat = load_catalog()
    profiles = load_profiles()

    # 1. Language sets agree across every place that lists languages.
    gd = GAME_CONFIG.read_text(encoding="utf-8") if GAME_CONFIG.exists() else ""
    match = re.search(r"const\s+SUPPORTED_LANGS[^=]*=\s*\[(.*?)\]", gd, re.S)
    supported = set(re.findall(r'"([a-z]{2})"', match.group(1))) if match else set()
    catalog_langs = set(cat["languages"])
    check(errors, not (catalog_langs - supported),
          f"catalog.json lists languages the game does not support: {sorted(catalog_langs - supported)}")
    check(warnings, not (supported - catalog_langs),
          f"supported languages absent from catalog.json: {sorted(supported - catalog_langs)}")

    if TRANSLATIONS.exists():
        with TRANSLATIONS.open(encoding="utf-8", newline="") as fh:
            header = next(csv.reader(fh))
        csv_langs = {h.strip() for h in header[1:] if h.strip()}
        check(errors, csv_langs == supported,
              f"translations.csv languages differ from SUPPORTED_LANGS: "
              f"{sorted(csv_langs ^ supported)}")

    if PROJECT_GODOT.exists():
        godot_langs = set(re.findall(r"translations\.([a-z]{2})\.translation",
                                     PROJECT_GODOT.read_text(encoding="utf-8")))
        check(errors, godot_langs == supported,
              f"project.godot translations differ from SUPPORTED_LANGS: "
              f"{sorted(godot_langs ^ supported)}")

    word_langs = {p.name.split("_")[1] for p in WORDS.glob("words_*_*.json")}
    check(errors, word_langs == supported,
          f"word files differ from SUPPORTED_LANGS: {sorted(word_langs ^ supported)}")
    for lang in sorted(word_langs):
        tiers = {int(p.stem.rsplit("_", 1)[1]) for p in WORDS.glob(f"words_{lang}_*.json")}
        check(errors, tiers == set(range(7)),
              f"words_{lang}_* has tiers {sorted(tiers)}, expected 0-6")

    # 2. Word files: valid markers, and no duplicates once markers are stripped.
    total = 0
    for path in sorted(WORDS.glob("words_*.json")):
        entries = read_json(path)
        total += len(entries)
        seen = {}
        for entry in entries:
            word = entry.get("word", "")
            check(errors, bool(entry.get("emoji")), f"{path.name}: {word!r} has no emoji")
            problem = grapheme_validate(word)
            check(errors, not problem, f"{path.name}: {word!r} — {problem}")
            bare = grapheme_strip(word)
            if bare in seen:
                warnings.append(f"{path.name}: {word!r} duplicates {seen[bare]!r} once markers are stripped")
            seen[bare] = word

    # 3. Every letter game_config.gd says a language uses must have a name
    #    here, and nothing may name a letter the language does not use. There is
    #    no longer a second copy of the alphabet to compare against — this file
    #    supplies pronunciations and game_config.gd supplies the letters.
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled") or "char" not in spec.get("categories", []):
            continue
        letters_file = SPEECH_SRC / f"letters_{lang}.json"
        if not letters_file.exists():
            errors.append(f"{lang} is enabled but {letters_file.name} is missing")
            continue
        doc = read_json(letters_file)
        spawned, extra = language_letters(lang)
        named = {l["display"]: l for l in doc["letters"]}

        for display in spawned + extra:
            if display not in named:
                errors.append(f"{letters_file.name} has no entry for {display!r}, "
                              f"which game_config.gd says {lang} uses")
        for display in named:
            if display not in spawned + extra:
                errors.append(f"{letters_file.name} names {display!r}, which is in neither "
                              f"ALPHABETS nor WORD_ONLY_LETTERS for {lang}")

        for letter in doc["letters"]:
            check(errors, bool(letter.get("spoken", "").strip()),
                  f"{letters_file.name}: {letter.get('id')} has no spoken text")
            if letter.get("spoken", "").strip() == letter.get("display", ""):
                warnings.append(f"{letters_file.name}: {letter['id']} spoken text is just the "
                                f"glyph {letter['display']!r} — the engine will guess")

    # 4. Numbers.
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled") or "number" not in spec.get("categories", []):
            continue
        path = SPEECH_SRC / f"numbers_{lang}.json"
        if not path.exists():
            errors.append(f"{lang} is enabled but {path.name} is missing")
            continue
        doc = read_json(path)
        lo, hi = cat["categories"]["number"]["range"]
        values = {int(n["value"]) for n in doc["numbers"]}
        check(errors, values >= set(range(lo, hi + 1)),
              f"{path.name} is missing {sorted(set(range(lo, hi + 1)) - values)[:10]}")
        for n in doc["numbers"]:
            check(errors, not n["spoken"].strip().isdigit(),
                  f"{path.name}: {n['value']} spoken text is digits — write the word out")

    # 5. Every fragment the recap will actually speak must match something the
    #    catalog recorded. The two derive from the same templates but strip
    #    differently — the runtime only trims whitespace, the catalog trims
    #    punctuation too — and a mismatch is silent: the clip exists, is packed,
    #    and is never played.
    # The runtime trims in GDScript and the catalog trims in Python. Nothing
    # here can execute the former, so at least assert the two name the same
    # characters — that divergence is what let ", you counted to" miss a clip
    # recorded as "you counted to", silently, in English menus only.
    manager = REPO / "scripts" / "speech_manager.gd"
    expected_trim = set(" \t\n,.:;")
    if manager.exists():
        found = re.search(r'const\s+UI_TRIM\s*:?=\s*"([^"]*)"', manager.read_text(encoding="utf-8"))
        if not found:
            errors.append("speech_manager.gd has no UI_TRIM — the runtime and the catalog "
                          "must agree on what punctuation is ignored")
        else:
            literal = found.group(1).replace("\\t", "\t").replace("\\n", "\n")
            if set(literal) != expected_trim:
                errors.append(
                    "speech_manager.gd UI_TRIM is %r but the catalog trims %r — they must match"
                    % (sorted(set(literal)), sorted(expected_trim)))

    ui_doc = SPEECH_SRC / "ui_speech.json"
    if ui_doc.exists() and TRANSLATIONS.exists():
        with TRANSLATIONS.open(encoding="utf-8", newline="") as fh:
            trows = list(csv.reader(fh))
        theader = trows[0]
        wanted = read_json(ui_doc)["keys"]
        for lang, spec in cat["languages"].items():
            if not spec.get("enabled") or "ui" not in spec.get("categories", []):
                continue
            if lang not in theader:
                continue
            col = theader.index(lang)
            text_for = {r[0]: r[col] for r in trows[1:] if r and len(r) > col}
            recorded = {UI_TRIM_RE.sub("", f).upper()
                        for key in wanted
                        for f in text_for.get(key, "").split("%s")
                        if len(UI_TRIM_RE.sub("", f)) >= 2}
            for key in wanted:
                if not key.startswith("recap"):
                    continue
                for fragment in text_for.get(key, "").split("%s"):
                    spoken = fragment.strip()          # what learning_recap emits
                    if len(spoken) < 2:
                        continue
                    if UI_TRIM_RE.sub("", spoken).upper() not in recorded:
                        errors.append(
                            f"{lang}: the recap will speak {spoken!r} (from {key}) and no clip "
                            "matches it — the runtime and the catalog disagree about trimming")

    # 6. A review file must only contain verdicts for its own locale.
    known = {}
    try:
        for r in load_desired():
            known[r["spec_hash"]] = r["locale"]
    except Fail:
        known = {}
    if known:
        for path in sorted(REVIEWS.glob("*.csv")):
            locale = path.stem
            with path.open(encoding="utf-8", newline="") as fh:
                for row in csv.DictReader(fh):
                    owner = known.get(row.get("spec_hash", ""))
                    if owner and owner != locale:
                        errors.append(f"{rel(path)} contains a verdict for {owner} "
                                      f"({row.get('key')}) — reviews must not cross locales")
                        break

    # 7. Profiles carry no secret, and the repo carries no key.
    for locale, profile in profiles.items():
        for field in ("api_key", "xi_api_key", "key", "token"):
            check(errors, field not in profile,
                  f"voice_profiles.json[{locale}] contains a '{field}' field — keys live in the environment")
    for path in REPO.rglob("*"):
        if not path.is_file() or path.suffix not in SECRET_SUFFIXES:
            continue
        if any(part in SECRET_SKIP_DIRS for part in path.parts):
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for pattern in SECRET_PATTERNS:
            if pattern.search(text):
                errors.append(f"{rel(path)} looks like it contains an API key")
                break

    # 8. Build inputs and outputs must not be exportable into the AAB.
    #    data/speech is pipeline input the game never reads — and Godot will
    #    happily import a review CSV as a translation if left to itself.
    for folder in (MASTERS, BUILD.parent, SPEECH_SRC):
        if folder.exists():
            check(errors, (folder / ".gdignore").exists(),
                  f"{rel(folder)} has no .gdignore — Godot would import and export it")

    # 9. Shipped manifests must be internally consistent.
    for manifest_path in sorted(PACKS.glob("*/manifest.json")):
        manifest = read_json(manifest_path)
        pack_dir = manifest_path.parent
        for key, item in manifest["items"].items():
            asset = pack_dir / item["asset"]
            if not asset.exists():
                errors.append(f"{rel(manifest_path)}: {key} points at a missing file")
                continue
            check(errors, sha256_file(asset) == item["sha256"],
                  f"{rel(manifest_path)}: {key} hash mismatch — the file changed after packing")

    # 10. Phase 5 gate: gameplay must go through SpeechManager, not TTS directly.
    if args.strict:
        allowed = {"scripts/tts_manager.gd", "scripts/speech_manager.gd"}
        for path in sorted((REPO / "scripts").rglob("*.gd")):
            if rel(path) in allowed:
                continue
            text = path.read_text(encoding="utf-8")
            if re.search(r"\bTTS\.(speak|speak_segments|warm_up)\b", text):
                errors.append(f"{rel(path)} calls TTS directly — route it through SpeechManager")

    info(f"{total} word entries across {len(list(WORDS.glob('words_*.json')))} files checked")
    for message in warnings:
        warn(message)
    if errors:
        info("")
        for message in errors:
            info(f"  FAIL  {message}")
        info("")
        info(f"{len(errors)} problem(s)")
        return 1
    info(f"verify OK ({len(warnings)} warning(s))")
    return 0


# --------------------------------------------------------------------------
# doctor
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# status
# --------------------------------------------------------------------------

STATUS_FILE = REPO / "LANGUAGE_STATUS.md"

STATUS_STEPS = [
    ("data", "Data"),
    ("alphabet", "Alphabet"),
    ("digraphs", "Digraphs"),
    ("corpus", "Words checked"),
    ("core", "Letters+numbers"),
    ("words", "Word audio"),
    ("ui", "UI speech"),
    ("game", "In game"),
]


def language_status(cat: dict) -> list:
    """Work out where every language actually stands, from the repo itself.

    Generated rather than maintained: a checklist that has to be ticked by hand
    is a checklist that lies within a month.
    """
    profiles = load_profiles()
    alphabets = parse_gd_table("ALPHABETS")
    word_only = parse_gd_table("WORD_ONLY_LETTERS")
    digraphs = read_json(SPEECH_SRC / "digraphs.json") if (SPEECH_SRC / "digraphs.json").exists() else {}
    dg_langs = digraphs.get("languages", {})
    dg_none = set(digraphs.get("not_applicable", {}).get("languages", []))

    try:
        desired = load_desired()
    except Fail:
        desired = []
    classify(desired)

    rows = []
    for lang, spec in cat["languages"].items():
        locale = spec["locale"]
        mine = [r for r in desired if r["lang"] == lang]
        by_cat = {}
        for r in mine:
            acc = by_cat.setdefault(r["category"], {"n": 0, "ok": 0})
            acc["n"] += 1
            acc["ok"] += 1 if r["status"] == "approved" else 0

        declared = categories_for(cat, lang, spec)

        def phase(name):
            acc = by_cat.get(name)
            if not acc or not acc["n"]:
                return "·", ""
            if acc["ok"] == acc["n"]:
                return "✓", f"{acc['ok']}"
            if acc["ok"]:
                return "~", f"{acc['ok']}/{acc['n']}"
            return "·", f"0/{acc['n']}"

        letters = SPEECH_SRC / f"letters_{lang}.json"
        numbers = SPEECH_SRC / f"numbers_{lang}.json"
        draft = _source_is_draft(lang)
        if letters.exists() and numbers.exists():
            data = ("~", "draft") if draft else ("✓", "")
        else:
            data = ("·", "")

        alphabet = ("✓", "") if lang in alphabets else (
            ("✓", "A–Z") if letters.exists() else ("·", ""))
        if lang in word_only:
            alphabet = ("✓", f"+{len(grapheme_split(word_only[lang]))} word-only")

        entry = dg_langs.get(lang, {})
        if lang in dg_none:
            digraph_state = ("—", "none")
            corpus = ("—", "")
        elif entry.get("decided"):
            marks = entry.get("letters", [])
            digraph_state = ("✓", ", ".join(marks) if marks else "none")
            corpus = ("✓", f"{entry.get('marked_words', 0)} marked") \
                if entry.get("corpus_reviewed") else ("·", "")
        elif entry:
            # Candidates found and nobody has ruled yet — not the same as none.
            digraph_state = ("·", "candidates")
            corpus = ("·", "")
        else:
            digraph_state = ("·", "")
            corpus = ("·", "")

        core_char, core_char_n = phase("char")
        core_num, _ = phase("number")
        core = ("✓", "") if core_char == "✓" and core_num == "✓" else (
            ("~", core_char_n) if (core_char != "·" or core_num != "·") and mine else ("·", ""))
        if not spec.get("enabled"):
            core = ("·", "")

        words = phase("word")
        if "word" not in declared:
            words = ("·", "")

        ui = phase("ui")
        if "ui" not in declared:
            ui = ("·", "")
        forms = phase("number_form")
        if "number_form" in declared and forms == ("·", ""):
            # Declared and empty: this language inflects nothing here.
            ui = ("✓", f"{ui[1]} +0 forms".strip()) if ui[0] == "✓" else ui
        elif forms[0] == "✓":
            ui = ("✓", f"{ui[1]} +{forms[1]} forms".strip()) if ui[0] == "✓" else ui

        pack = PACKS / lang / "manifest.json"
        if pack.exists():
            cover = read_json(pack).get("coverage", {})
            complete = all(str(v) in ("complete", "not_needed") for v in cover.values())
            game = ("✓", "playing") if complete else ("~", "partial")
        else:
            game = ("·", "")

        voice = profiles.get(locale, {}).get("voice_name") or (
            "chosen" if profiles.get(locale, {}).get("voice_id") else "")

        rows.append({
            "lang": lang, "locale": locale, "enabled": bool(spec.get("enabled")),
            "voice": voice,
            "data": data, "alphabet": alphabet, "digraphs": digraph_state,
            "corpus": corpus, "core": core, "words": words,
            "ui": ui, "game": game,
        })
    return rows


def cmd_audit(args) -> int:
    """Check every clip against the words it was supposed to say.

    Forced alignment does not just place words in time; it reports how badly
    the audio fits the text it was given. A clip holding the wrong words fits
    badly, so this catches the failures that have actually reached review here:
    a sheet cut that slipped and left every clip holding the next one's words,
    a cropped ending, a fragment merged into its neighbour. Those were all
    found by a human listening to a hundred files, which is the tedious part.

    It is not a substitute for listening. It cannot hear a French 'chá' in a
    Czech alphabet — the words are right there, only the accent is wrong. It
    narrows what has to be listened to sceptically, and it never approves
    anything on its own.
    """
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)
    todo = [r for r in records if r["status"] in ("unreviewed", "rejected", "approved")
            and processed_path(r["render_hash"]).exists()
            and (args.force or not audit_path(r["render_hash"]).exists())]

    rate = cat["master_format"]["sample_rate"]
    secs = sum(master_path(r["spec_hash"]).stat().st_size / 2.0 / rate
               for r in todo if master_path(r["spec_hash"]).exists())
    price = cat.get("pricing_usd_per_hour_audio", {}).get("forced_alignment", 0.40)
    info(f"{len(todo)} clips to check, {secs / 60:.1f} min of audio, about "
         f"${secs / 3600 * price:.3f}. Nothing is synthesised.")
    if not todo:
        return 0
    if not args.confirm:
        info("Re-run with --confirm.")
        return 0

    key = api_key()
    checked = flagged = 0
    for i, r in enumerate(todo, 1):
        try:
            doc = force_align(key, master_path(r["spec_hash"]).read_bytes(),
                              r["spoken_text"], cat)
        except Fail as exc:
            if "permission" in str(exc):
                raise
            warn(f"{r['key']}: {exc}")
            continue
        verdict = audit_verdict(doc, r, cat)
        path = audit_path(r["render_hash"])
        path.parent.mkdir(parents=True, exist_ok=True)
        write_atomic(path, json.dumps(verdict, ensure_ascii=False).encode("utf-8"))
        checked += 1
        if verdict["suspect"]:
            flagged += 1
            info(f"  ? {r['display_text']:28s} {verdict['why']}")
    info(f"\nChecked {checked}, flagged {flagged}. The flagged ones are listed "
         f"first on the review page and start marked rejected; the rest start "
         f"blank and still need your ears.")
    return 0


def audit_path(render_hash: str) -> Path:
    return MASTERS / "audits" / render_hash[:2] / f"{render_hash}.json"


def audit_verdict(doc: dict, record: dict, cat: dict, limit: float = 0.0) -> dict:
    """Turn an alignment into a suspicion, with a reason a human can check."""
    limit = limit or cat["processing"].get("audit_max_loss", 0.5)
    words = [w for w in doc.get("words", []) if w.get("text", "").strip()]
    expected = record["spoken_text"].split()
    loss = float(doc.get("loss", 0.0))
    why = ""
    if len(words) != len(expected):
        why = f"aligner heard {len(words)} words, the text has {len(expected)}"
    elif loss > limit:
        why = f"fits the text poorly (loss {loss:.2f} over {limit})"
    return {"loss": loss, "words": len(words), "expected": len(expected),
            "suspect": bool(why), "why": why}


def cmd_next(args) -> int:
    """One language, start to finish. Look, or do.

    Without --go it reports and stops. With --go it runs the whole chain up to
    the point where a human has to listen, spending at most --budget. Every
    step that costs money says what it cost and counts against that budget, so
    there is one decision to make instead of five prompts to answer.
    """
    lang = args.language
    cat = load_catalog()
    if lang not in cat["languages"]:
        raise Fail(f"unknown language {lang!r}. Known: {', '.join(sorted(cat['languages']))}")

    # A language declared but not enabled is a config flag, not a decision the
    # person running this needs to be stopped by. Enabling costs nothing, is
    # one line to undo, and this command refuses to spend anything without
    # --go anyway — so it enables and says so, rather than failing with an
    # instruction to go and edit JSON.
    if not cat["languages"][lang].get("enabled"):
        doc = read_json(CATALOG)
        doc["languages"][lang]["enabled"] = True
        write_atomic(CATALOG, (json.dumps(doc, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))
        cat = load_catalog()
        info(f"Enabled {lang} in {rel(CATALOG)} — it was declared but switched off. "
             f"Set \"enabled\": false there to undo.")
    budget = args.budget if args.go else 0.0
    spent = [0.0]

    ran = []

    def step(name: str, argv: list):
        info(f"\n--- {name} ---")
        ran.append(tuple(argv))
        parsed = build_parser().parse_args(argv)
        return parsed.func(parsed)

    def afford(what: str, cost: float, argv: list) -> bool:
        """Spend, if --go was given and the budget covers it. Otherwise say so."""
        if not args.go:
            info(f"\nNEXT: {what} — about ${cost:.2f}")
            info(f"  python3 {rel(Path(__file__))} next {lang} --go --budget {max(cost * 1.5, 0.50):.2f}")
            return False
        if spent[0] + cost > budget:
            info(f"\nSTOPPED: {what} would cost about ${cost:.2f} and only "
                 f"${budget - spent[0]:.2f} of the ${budget:.2f} budget is left.")
            info(f"  python3 {rel(Path(__file__))} next {lang} --go --budget {spent[0] + cost * 1.5:.2f}")
            return False
        spent[0] += cost
        step(what, argv + ["--confirm"])
        return True

    def state():
        records = [r for r in load_desired() if r["lang"] == lang]
        if not records:
            raise Fail(f"{lang} is not enabled in data/speech/catalog.json")
        return classify(records)

    step("reading the word lists", ["extract"])
    profiles = load_profiles()
    rate = cat["master_format"]["sample_rate"]
    align_price = cat.get("pricing_usd_per_hour_audio", {}).get("forced_alignment", 0.40)

    seen = None
    for _ in range(8):        # each pass completes one stage; 8 is more than enough
        records = state()
        counts = {}
        for r in records:
            counts[r["status"]] = counts.get(r["status"], 0) + 1
        info(f"\n{lang}: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))

        # A stage that runs twice and changes nothing has failed, and running it
        # again will fail the same way. Judged on the stage as well as the
        # counts: encoding a hundred clips moves none of them out of
        # "unreviewed", so counts alone called honest work a loop and stopped
        # one step short of the review page.
        signature = (tuple(sorted(counts.items())), ran[-1] if ran else None)
        if signature == seen and ran:
            warn("that stage changed nothing, so it will not be retried. "
                 "The messages above say why it could not finish.")
            return 1
        seen = signature

        if counts.get("unconfigured"):
            info(f"\nNEXT: this language has no voice yet. Listen to candidates, put the "
                 f"voice_id in data/speech/voice_profiles.json, then run this again.")
            info(f"  python3 {rel(Path(__file__))} voices --language {lang}")
            return 0

        # A clip you rejected is a clip to record again. That needed a separate
        # verb nobody could be expected to know about, so a rejection sat there
        # looking like unfinished review instead of pending work.
        # Encoding comes before spending. Czech sat unprocessed because four
        # clips needed re-recording, and the paid step was checked first — so
        # a few cents of work blocked several hundred clips of free work.
        if counts.get("generated"):
            step(f"encoding {counts['generated']} clips", ["process", "--language", lang])
            continue

        if counts.get("rejected"):
            step(f"queueing {counts['rejected']} rejected clips for a fresh take",
                 ["retake", "--language", lang, "--rejected"])
            # A retake changes what the clip is, so the list has to be rebuilt
            # before the next pass can see it as missing.
            step("re-reading the word lists", ["extract"])
            continue

        if counts.get("missing"):
            chars = sum(len(r["spoken_text"]) for r in records if r["status"] == "missing")
            cost = chars / 1000.0 * cat["pricing_usd_per_1k_chars"].get("eleven_v3", 0.1)
            if not afford(f"record {counts['missing']} clips", cost,
                          ["generate", "--language", lang]):
                return 0
            continue

        phrases = [r for r in records
                   if r["category"] == "word" and len(r["spoken_text"].split()) > 1]
        unaligned = [r for r in phrases if not alignment_path(r["spec_hash"]).exists()]
        if unaligned:
            secs = sum(master_path(r["spec_hash"]).stat().st_size / 2.0 / rate
                       for r in unaligned if master_path(r["spec_hash"]).exists())
            if not afford(f"find word boundaries in {len(unaligned)} phrases",
                          secs / 3600 * align_price, ["align", "--language", lang]):
                return 0
            continue

        # A boundary only reaches the game once its clip is re-encoded.
        # A clip whose timings have not been folded in yet has no sidecar at
        # all, which is the normal state right after `align` — not an error.
        stale = [r for r in phrases if phrase_boundaries(r, profiles, cat)
                 and not maybe_json(processed_path(r["render_hash"]).with_suffix(".json")
                                    ).get("word_ends_ms")]
        if stale:
            step(f"folding word timings into {len(stale)} clips",
                 ["process", "--force", "--language", lang, "--category", "word"])
            continue

        waiting = [r for r in records if r["status"] in ("unreviewed", "rejected")]
        unchecked = [r for r in waiting if not audit_path(r["render_hash"]).exists()]
        if unchecked:
            secs = sum(master_path(r["spec_hash"]).stat().st_size / 2.0 / rate
                       for r in unchecked if master_path(r["spec_hash"]).exists())
            if not afford(f"check {len(unchecked)} clips say the right words",
                          secs / 3600 * align_price, ["audit", "--language", lang]):
                return 0
            continue

        if waiting:
            if phrases:
                step("phrase boundaries", ["phrases", "--language", lang])
            step("building the review page", ["listen", "--language", lang, "--pending"])
            step("building the review sheet", ["review", "--language", lang])
            suspect = sum(1 for r in waiting
                          if maybe_json(audit_path(r["render_hash"])).get("suspect"))
            info(f"\nYOUR TURN: {len(waiting)} clips to sign off. {suspect} are already "
                 f"marked rejected because they do not say what they should; the rest "
                 f"need your ears.")
            info(f"  open build/speech/listen/{records[0]['locale']}/index.html")
            info(f"  then: python3 {rel(Path(__file__))} review "
                 f"--import build/speech/review_{records[0]['locale']}.csv")
            if spent[0]:
                info(f"\nSpent about ${spent[0]:.2f}.")
            return 0

        step("packing", ["pack", "--language", lang])
        if spent[0]:
            info(f"\nSpent about ${spent[0]:.2f}.")
        info(f"\n{lang} is done: recorded, checked, approved and playing in the game.")
        return 0

    warn("stopped after 8 stages without finishing — something is looping")
    return 1


def cmd_status(args) -> int:
    cat = load_catalog()
    rows = language_status(cat)
    active = [r for r in rows if r["enabled"]]
    resting = [r for r in rows if not r["enabled"]]

    def cell(pair):
        mark, note = pair
        return f"{mark} {note}".strip() if note else mark

    lines = []
    lines.append("# Language status")
    lines.append("")
    lines.append("Where every language stands, from the alphabet to audio playing in the game.")
    lines.append("")
    lines.append("**Generated — do not edit by hand.** `python3 tools/speech/speech_pipeline.py status`")
    lines.append("reads the repository and rewrites this file, so it cannot drift from what is")
    lines.append("actually there. A checklist ticked by hand is a checklist that lies within a month.")
    lines.append("")
    lines.append("`✓` done  `~` partly  `·` not started  `—` nothing to do")
    lines.append("")

    header = "| Lang | Voice | " + " | ".join(label for _, label in STATUS_STEPS) + " |"
    lines.append(header)
    lines.append("|" + "---|" * (len(STATUS_STEPS) + 2))
    for r in active + resting:
        cells = [cell(r[key]) for key, _ in STATUS_STEPS]
        name = f"**{r['lang']}**" if r["enabled"] else r["lang"]
        lines.append(f"| {name} | {r['voice'] or '·'} | " + " | ".join(cells) + " |")
    lines.append("")
    lines.append("Bold means the language is enabled in `data/speech/catalog.json`; the rest are")
    lines.append("declared but not being generated.")
    lines.append("")
    lines.append("## What each column means")
    lines.append("")
    lines.append("| Column | Done when |")
    lines.append("|---|---|")
    lines.append("| Data | `letters_<lang>.json` and `numbers_<lang>.json` exist and are no longer marked DRAFT — a native speaker has read the letter names and the number words |")
    lines.append("| Alphabet | The language has an entry in `ALPHABETS` in `game_config.gd`, and in `WORD_ONLY_LETTERS` if its words use letters the alphabet lesson should skip |")
    lines.append("| Digraphs | Someone has decided which multi-character sequences are *letters* of this alphabet, recorded in `data/speech/digraphs.json` |")
    lines.append("| Words checked | The whole word list has been read for those digraphs and marked, e.g. `MOU[CH]A` |")
    lines.append("| Letters+numbers | Every letter and every number 1–50 recorded and approved by a named reviewer |")
    lines.append("| Word audio | Every vocabulary word recorded and approved |")
    lines.append("| UI speech | The app title, the language names spoken in settings, and the finish-recap framing — recorded in the UI language, which is often not the learning language. Help narration is deliberately excluded |")
    lines.append("| In game | `voices/<lang>/` exists and the game plays it |")
    lines.append("")
    lines.append("## Order of work for a new language")
    lines.append("")
    lines.append("1. **Alphabet** into `game_config.gd` — what Letters mode spawns, plus word-only letters.")
    lines.append("2. **Digraphs** — is any two-character sequence a letter here? Record the decision either way.")
    lines.append("3. **Word list** — mark them, if there were any.")
    lines.append("4. **Letter names and number words** — a native speaker, before anything is recorded.")
    lines.append("5. **A voice** — native to the language. `voices --language <lang>` lists candidates.")
    lines.append("6. **Generate, review, pack.** Letters and numbers first; words are a separate, larger pass.")
    lines.append("")
    lines.append("Steps 1–4 cost nothing and are where the mistakes are cheap. Step 6 is where they")
    lines.append("stop being cheap: the Czech pilot spent about 40 cents on synthesis across eight")
    lines.append("rounds of review, and the reviewing was the expensive part.")
    lines.append("")

    text = "\n".join(lines)
    if args.check:
        current = STATUS_FILE.read_text(encoding="utf-8") if STATUS_FILE.exists() else ""
        if current.strip() != text.strip():
            raise Fail(f"{rel(STATUS_FILE)} is out of date — run `speech_pipeline.py status`")
        info(f"{rel(STATUS_FILE)} is up to date")
        return 0

    STATUS_FILE.write_text(text, encoding="utf-8")
    info(f"-> {rel(STATUS_FILE)}")
    info("")

    # A grid of bare marks with no headings is a puzzle, not a report. The
    # columns are named down the side, once, and each language is a column
    # under its own name — eight steps read better vertically than as eight
    # unlabelled glyphs in a row.
    width = max(len(label) for _, label in STATUS_STEPS) + 2
    info(" " * width + "  ".join(f"{r['lang']:>3s}" for r in active))
    for key, label in STATUS_STEPS:
        cells = "  ".join(f"{r[key][0]:>3s}" for r in active)
        info(f"{label:<{width}}{cells}")
    info("")
    info("  ✓ done    ~ partly    · not started")
    info("")
    for r in active:
        notes = [f"{label} ({r[key][1]})" for key, label in STATUS_STEPS if r[key][1]]
        if notes:
            info(f"  {r['lang']}: " + "; ".join(notes))
    info(f"\n  What each row means: {rel(STATUS_FILE)}")
    return 0


def cmd_doctor(args) -> int:
    def line(ok, label, detail=""):
        info(f"  {'ok  ' if ok else 'MISS'}  {label:34s} {detail}")

    info("Environment")
    line(sys.version_info >= (3, 8), "python >= 3.8", sys.version.split()[0])
    line(shutil.which("ffmpeg") is not None, "ffmpeg (needed by `process`)",
         shutil.which("ffmpeg") or "brew install ffmpeg")
    line(shutil.which("ffprobe") is not None, "ffprobe", shutil.which("ffprobe") or "")

    cat = load_catalog()
    var = cat.get("api_key_env", "ELEVENLABS_API_KEY")
    key = os.environ.get(var, "")
    line(bool(key), f"${var}", f"set, {len(key)} chars" if key else "not set — `generate`, `voices` and `align` need it")

    info("")
    info("Sources")
    for path in (CATALOG, VOICE_PROFILES):
        line(path.exists(), rel(path))
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled"):
            continue
        for category in categories_for(cat, lang, spec):
            cspec = cat["categories"][category]
            if "source" not in cspec:
                # A category can name a directory of files instead of one file
                # — the vocabulary is 147 of them. Nothing to check here.
                continue
            source = SPEECH_SRC / cspec["source"].format(lang=lang)
            line(source.exists(), rel(source))

    info("")
    info("Voice profiles")
    for locale, profile in load_profiles().items():
        line(bool(profile.get("voice_id")), locale,
             f"{profile.get('voice_name') or 'voice_id not set yet'}  ({profile.get('model_id')})")

    info("")
    info("Guards")
    for folder in (MASTERS, BUILD.parent):
        line(not folder.exists() or (folder / ".gdignore").exists(),
             f"{rel(folder)}/.gdignore", "" if folder.exists() else "(folder not created yet)")
    gitignore = (REPO / ".gitignore").read_text(encoding="utf-8") if (REPO / ".gitignore").exists() else ""
    line("voice_masters" in gitignore, ".gitignore covers voice_masters/")
    line("build/" in gitignore, ".gitignore covers build/")

    info("")
    info("Next: extract -> plan -> (SETUP.md: account + voice) -> generate --confirm -> process -> review -> pack")
    return 0


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="speech_pipeline.py",
        description="Studio Voice build pipeline. Only `generate` spends money.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Requires")[0].strip().splitlines()[-4:] and
        "start here:\n"
        "  next <lang>     one language: do the free steps, say what is next\n"
        "\n"
        "the individual steps, in the order `next` runs them:\n"
        "  doctor          check the machine and the config\n"
        "  extract         enumerate every clip the catalog wants\n"
        "  plan            what is missing, and what it would cost\n"
        "  voices          list candidate voices (network, no credits)\n"
        "  generate        synthesise (network, SPENDS CREDITS, needs --confirm)\n"
        "  process         trim, level and encode to shipping MP3\n"
        "  review          export a review sheet, then import the verdicts\n"
        "  pack            write res://voices/<lang>/ from approved clips\n"
        "  verify          CI gate; run it before every commit\n",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    def add_filters(sp, keys=False):
        sp.add_argument("--language", "-l", action="append", metavar="LANG",
                        help="restrict to a language; repeatable")
        sp.add_argument("--category", "-c", action="append", metavar="CAT",
                        help="number | char; repeatable")
        if keys:
            sp.add_argument("--key", "-k", action="append", metavar="KEY",
                            help="one exact semantic key; repeatable")

    sp = sub.add_parser("doctor", help="check tools, config and guards")
    sp.set_defaults(func=cmd_doctor)

    sp = sub.add_parser("extract", help="enumerate wanted clips -> build/speech/desired.jsonl")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.set_defaults(func=cmd_extract)

    sp = sub.add_parser("plan", help="diff wanted against what exists; estimate cost")
    add_filters(sp)
    sp.add_argument("--priority", "-p", type=int, help="include priority <= N")
    sp.add_argument("--estimate-all", action="store_true",
                    help="extrapolate the cost of all catalog languages")
    sp.set_defaults(func=cmd_plan)

    sp = sub.add_parser("voices", help="list account and library voices (network, no credits)")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.set_defaults(func=cmd_voices)

    sp = sub.add_parser("generate", help="synthesise missing clips (network, SPENDS CREDITS)")
    add_filters(sp, keys=True)
    sp.add_argument("--confirm", action="store_true", help="actually spend credits")
    sp.add_argument("--dry-run", action="store_true", help="force a dry run")
    sp.add_argument("--limit", type=int, help="at most N clips this run")
    sp.add_argument("--max-characters", type=int, help="override the budget in catalog.json")
    sp.add_argument("--delay", type=float, default=0.4, help="seconds between requests (default 0.4)")
    sp.add_argument("--force", action="store_true",
                    help="re-record sheet groups even when nothing is missing")
    sp.set_defaults(func=cmd_generate, cached_only=False)

    sp = sub.add_parser("recut", help="re-derive masters from stored sheets (no network, no cost)")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--category", "-c", action="append", metavar="CAT")
    sp.set_defaults(func=cmd_recut)

    sp = sub.add_parser("align", help="fetch word boundaries for recorded phrases (no synthesis)")
    sp.add_argument("--language", action="append")
    sp.add_argument("--force", action="store_true", help="re-align phrases that already have timings")
    sp.add_argument("--limit", type=int, help="only the first N, for a trial run")
    sp.add_argument("--confirm", action="store_true", help="actually call the API")
    sp.set_defaults(func=cmd_align)

    sp = sub.add_parser("process", help="trim, level, encode masters to shipping MP3")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--category", "-c", action="append", metavar="CAT",
                    help="number | char | word; repeatable")
    sp.add_argument("--force", action="store_true", help="re-encode clips that already exist")
    sp.add_argument("--key", help="only clips whose key or text contains this")
    sp.set_defaults(func=cmd_process)

    sp = sub.add_parser("prune", help="delete archived audio nothing asks for any more")
    sp.add_argument("--masters", action="store_true", help="also delete orphaned masters (paid for)")
    sp.add_argument("--confirm", action="store_true")
    sp.set_defaults(func=cmd_prune)

    sp = sub.add_parser("audit", help="check clips against the words they should say")
    sp.add_argument("--language", action="append")
    sp.add_argument("--force", action="store_true")
    sp.add_argument("--confirm", action="store_true")
    sp.set_defaults(func=cmd_audit)

    sp = sub.add_parser("phrases", help="hear each stage of a phrase, to check the boundaries")
    sp.add_argument("--language", action="append")
    sp.add_argument("--limit", type=int)
    sp.set_defaults(func=cmd_phrases)

    sp = sub.add_parser("listen", help="named copies of the clips + a page to review them in")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--category", "-c", action="append", metavar="CAT",
                    help="number | char | word; repeatable")
    sp.add_argument("--pending", action="store_true", help="skip clips already approved")
    sp.set_defaults(func=cmd_listen)

    sp = sub.add_parser("review", help="export a review sheet, or import the verdicts")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--category", "-c", action="append", metavar="CAT")
    sp.add_argument("--import", dest="import_file", metavar="CSV",
                    help="merge a filled-in sheet into data/speech/reviews/")
    sp.set_defaults(func=cmd_review)

    sp = sub.add_parser("retake", help="record specific clips again, one request each")
    sp.add_argument("--key", "-k", action="append", metavar="KEY", help="repeatable")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--rejected", action="store_true",
                    help="every clip currently marked rejected")
    sp.add_argument("--reason", help="recorded alongside the counter")
    sp.add_argument("--previous-text", metavar="TEXT",
                    help="text the model behaves as though it just said (not supported by "
                         "eleven_v3 — use --carrier there)")
    sp.add_argument("--carrier", action="append", metavar="WORD",
                    help="throwaway word spoken before the clip and then discarded, so the "
                         "take has a run-up; repeatable")
    sp.add_argument("--no-carrier", action="store_true",
                    help="record it alone, with nothing either side and nothing to cut")
    sp.add_argument("--carrier-after", action="append", metavar="WORD",
                    help="throwaway word spoken after the clip, so it is not the last thing "
                         "read — a reading trails off at its end; repeatable")
    sp.set_defaults(func=cmd_retake)

    sp = sub.add_parser("pack", help="write res://voices/<lang>/ from approved clips")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--pack-version", type=int, default=1)
    sp.set_defaults(func=cmd_pack)

    sp = sub.add_parser("next", help="START HERE: one language, what to do next")
    sp.add_argument("language", help="cs, en, de, sk, pl …")
    sp.add_argument("--go", action="store_true",
                    help="actually do it, instead of reporting what is next")
    sp.add_argument("--budget", type=float, default=1.00, metavar="USD",
                    help="most this run may spend, in dollars (default 1.00)")
    sp.set_defaults(func=cmd_next)

    sp = sub.add_parser("status", help="regenerate LANGUAGE_STATUS.md from the repository")
    sp.add_argument("--check", action="store_true",
                    help="fail if the file is out of date instead of rewriting it")
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("verify", help="CI gate — sources, hashes, manifests, secrets")
    sp.add_argument("--strict", action="store_true",
                    help="also fail on direct TTS.speak() calls (turn on in Phase 5)")
    sp.set_defaults(func=cmd_verify)

    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except Fail as exc:
        print(f"\nerror: {exc}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print("\ninterrupted", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
