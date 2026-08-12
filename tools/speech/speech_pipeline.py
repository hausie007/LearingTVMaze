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
import csv
import hashlib
import json
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

        for category in lspec["categories"]:
            cspec = cat["categories"][category]
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
                seen = set()
                items = []
                for letter in doc["letters"]:
                    lid = letter["id"]
                    if not re.fullmatch(r"[a-z0-9_]+", lid):
                        raise Fail(f"{rel(source)}: letter id '{lid}' must be lowercase ascii/underscore")
                    if lid in seen:
                        raise Fail(f"{rel(source)}: duplicate letter id '{lid}'")
                    seen.add(lid)
                    items.append((cspec["key_format"].format(id=lid),
                                  letter["display"], letter["spoken"]))
            else:
                raise Fail(f"unknown category '{category}' in catalog.json")

            for key, display, spoken in items:
                spoken = nfc(overrides.get(key, {}).get("spoken", spoken))
                if not spoken:
                    raise Fail(f"{key} ({locale}) has empty spoken text")

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
                    "synthesis_mode": profile.get("synthesis_mode", "single"),
                    "sheet": profile.get("sheet") if profile.get("synthesis_mode") == "sheet" else None,
                }
                spec_hash = canonical_hash(spec)
                render_hash = canonical_hash({
                    "spec": spec_hash,
                    "processing": cat["processing"],
                    "ship_format": cat["ship_format"],
                })

                records.append({
                    "key": key,
                    "lang": lang,
                    "locale": locale,
                    "category": category,
                    "priority": cspec["priority"],
                    "display_text": display,
                    "spoken_text": spoken,
                    "spec_hash": spec_hash,
                    "render_hash": render_hash,
                    "source": rel(source),
                    "voice_configured": bool(profile.get("voice_id")),
                })

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
        if profiles[r["locale"]].get("synthesis_mode") != "sheet":
            continue
        ident = (r["locale"], r["category"])
        if ident in sheet_groups:
            continue
        members = [x for x in all_records
                   if x["locale"] == ident[0] and x["category"] == ident[1]]
        if any(m["status"] == "missing" for m in members) or args.force:
            sheet_groups[ident] = members

    todo = [r for r in records if r["status"] == "missing"
            and profiles[r["locale"]].get("synthesis_mode") != "sheet"]
    if args.limit:
        todo = todo[:args.limit]
    if not todo and not sheet_groups:
        info("Nothing to generate.")
        return 0
    if sheet_groups and (args.limit or args.key):
        warn("--limit and --key do not apply to sheet mode; a sheet is recorded whole")

    sheet_chars = sum(len(sheet_text(profiles[loc], chunk)[0])
                      for (loc, _c), grp in sheet_groups.items()
                      for chunk in sheet_chunks(profiles[loc], grp))
    chars = sum(len(r["spoken_text"]) for r in todo) + sheet_chars
    budget = args.max_characters if args.max_characters is not None else guards["max_characters_per_run"]
    prices = cat["pricing_usd_per_1k_chars"]
    est = 0.0
    for r in todo:
        price = prices.get(profiles[r["locale"]]["model_id"])
        est += len(r["spoken_text"]) / 1000.0 * (price or 0)
    for (loc, _cat), grp in sheet_groups.items():
        price = prices.get(profiles[loc]["model_id"])
        for chunk in sheet_chunks(profiles[loc], grp):
            est += len(sheet_text(profiles[loc], chunk)[0]) / 1000.0 * (price or 0)

    clip_total = len(todo) + sum(len(g) for g in sheet_groups.values())
    info(f"{clip_total} clips, {chars} characters, estimated ~USD {est:.2f}")
    for (loc, cat_), grp in sorted(sheet_groups.items()):
        n = len(sheet_chunks(profiles[loc], grp))
        info(f"  sheet  {loc}/{cat_}  {len(grp)} items in {n} request(s)")
    for r in todo[:8]:
        info(f"  {r['key']:24s} {r['locale']}  {r['spoken_text']!r}")
    if len(todo) > 8:
        info(f"  … and {len(todo) - 8} more")

    if chars > budget:
        raise Fail(
            f"{chars} characters exceeds the budget of {budget}. "
            "Narrow with --language/--category/--limit, or raise it deliberately with --max-characters."
        )
    if args.dry_run or not args.confirm:
        info("")
        info("Dry run — nothing was generated and nothing was billed.")
        info("Add --confirm to actually synthesise.")
        return 0

    key = api_key()
    ok = failed = 0

    if sheet_groups:
        ok, failed = generate_sheets(key, cat, profiles, sheet_groups, args)

    for i, r in enumerate(todo, 1):
        profile = profiles[r["locale"]]
        info(f"[{i}/{len(todo)}] {r['key']}  {r['spoken_text']!r}")
        try:
            audio, request_id = tts_request(key, profile, r["spoken_text"])
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
    """Build the sheet and record where each item sits inside it."""
    sheet = profile.get("sheet") or {}
    sep = sheet.get("separator", ". ")
    preamble = sheet.get("preamble", "")

    text = f"{preamble}{sep}" if preamble else ""
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


def cut_sheet(audio: bytes, alignment: dict, text: str, spans: list, cat: dict, profile: dict):
    """Slice the sheet into one master per item, by character alignment.

    The audio is raw signed 16-bit PCM, so a cut is a byte offset — no decoding,
    no re-encoding, and the boundary is exactly where the API said it was.
    """
    chars = alignment.get("characters") or []
    starts = alignment.get("character_start_times_seconds") or []
    ends = alignment.get("character_end_times_seconds") or []
    if not (len(chars) == len(starts) == len(ends)):
        raise Fail("alignment arrays disagree in length")
    if "".join(chars) != text:
        raise Fail(
            "the alignment does not match the text that was sent, so cuts would "
            "land in the wrong place. Nothing was saved; the master is still billed."
        )

    fmt = cat["master_format"]
    frame = (fmt["bits"] // 8) * fmt["channels"]
    rate = fmt["sample_rate"]
    total = len(audio) // frame

    sheet = profile.get("sheet") or {}
    lead = sheet.get("guard_lead_ms", 40) / 1000.0
    tail = sheet.get("guard_tail_ms", 90) / 1000.0

    cuts = []
    for start, end in spans:
        t0 = max(starts[start] - lead, 0.0)
        t1 = min(ends[end - 1] + tail, total / rate)
        a = max(int(t0 * rate), 0) * frame
        b = min(int(t1 * rate), total) * frame
        if b <= a:
            raise Fail("the alignment produced an empty segment")
        cuts.append(audio[a:b])
    return cuts


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
        info(f"sheet {locale}/{category}: {len(group)} items, {len(text)} characters")
        info(f"  {text[:110]}{'…' if len(text) > 110 else ''}")
        try:
            audio, alignment, request_id = tts_sheet_request(key, profile, text)
            cuts = cut_sheet(audio, alignment, text, spans, cat, profile)
        except Fail as exc:
            warn(str(exc))
            failed += len(group)
            continue

        for r, chunk in zip(group, cuts):
            write_atomic(master_path(r["spec_hash"]), chunk)
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


def tts_request(key: str, profile: dict, text: str):
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


def process_one(master: Path, out: Path, cat: dict) -> dict:
    """Trim, level, fade and encode. Deterministic: same input, same output."""
    p = cat["processing"]
    fmt = cat["master_format"]
    ship = cat["ship_format"]

    src = ["-f", "s16le", "-ar", str(fmt["sample_rate"]), "-ac", str(fmt["channels"]), "-i", str(master)]

    with tempfile.TemporaryDirectory() as tmpdir:
        trimmed = Path(tmpdir) / "trimmed.wav"
        thr = f"{p['trim_silence_db']}dB"
        trim = (f"silenceremove=start_periods=1:start_silence=0:start_threshold={thr},"
                f"areverse,"
                f"silenceremove=start_periods=1:start_silence=0:start_threshold={thr},"
                f"areverse,"
                f"adelay={p['keep_lead_ms']}:all=1,"
                f"apad=pad_dur={p['keep_tail_ms'] / 1000.0}")
        res = run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"] + src +
                  ["-af", trim, str(trimmed)])
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
        "duration_ms": int(round(final_duration * 1000)),
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "mean_dbfs": mean_db,
        "peak_dbfs": peak_db,
        "gain_db": gain,
    }


def cmd_process(args) -> int:
    ensure_guards()
    require_ffmpeg()
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
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
        try:
            meta = process_one(master, out, cat)
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
        info(f"[{i}/{len(todo)}] {r['key']:24s} {meta['duration_ms']:5d}ms  "
             f"{meta['bytes']:6d}B  {meta['gain_db']:+5.1f}dB{flag}")
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
  verdicts[CLIPS[cur].key] = status;
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
    csv += [c.key, c.spec_hash, verdicts[c.key], who, today, notes[c.key] || ""].map(esc).join(",") + "\\n";
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


def cmd_listen(args) -> int:
    cat = load_catalog()
    records = load_desired()
    if args.language:
        records = [r for r in records if r["lang"] in args.language]
    classify(records)

    ready = [r for r in records if r["status"] in ("unreviewed", "rejected", "approved")]
    if args.pending:
        ready = [r for r in ready if r["status"] != "approved"]
    if not ready:
        raise Fail("no processed clips to listen to — run `generate` and `process` first")

    for locale in sorted({r["locale"] for r in ready}):
        rows = [r for r in ready if r["locale"] == locale]
        rows.sort(key=lambda r: (r["category"], r["key"]))
        folder = BUILD / f"listen_{locale}"
        if folder.exists():
            shutil.rmtree(folder)
        folder.mkdir(parents=True)

        clips = []
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
            clips.append({
                "key": r["key"], "spec_hash": r["spec_hash"],
                "display": r["display_text"], "spoken": r["spoken_text"],
                "file": dest.name, "duration_ms": duration, "flag": flag,
            })

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
                locale = next((r["locale"] for r in records if r["key"] == row["key"]), None)
                if locale is None:
                    warn(f"{row['key']} is not in the current catalog — skipped")
                    continue
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
        with out.open("w", encoding="utf-8", newline="") as fh:
            writer = csv.writer(fh)
            writer.writerow(REVIEW_FIELDS + ["display_text", "spoken_text", "clip"])
            for r in sorted(rows, key=lambda x: x["key"]):
                writer.writerow([r["key"], r["spec_hash"], "", "", "", "",
                                 r["display_text"], r["spoken_text"], r["clip"]])
        info(f"{locale}: {len(rows)} clips -> {rel(out)}")
    info("")
    info("Fill in the status column (approved / rejected), then:")
    info("  speech_pipeline.py review --import build/speech/review_<locale>.csv")
    return 0


# --------------------------------------------------------------------------
# pack
# --------------------------------------------------------------------------

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

        items = {}
        for r in approved:
            src = processed_path(r["render_hash"])
            data = src.read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            asset = f"clips/{digest[:2]}/{digest[:12]}.mp3"
            write_atomic(pack_dir / asset, data)
            items[r["key"]] = {
                "asset": asset,
                "duration_ms": int(round(probe_duration(src) * 1000)) if shutil.which("ffprobe") else 0,
                "sha256": digest,
                "display_text": r["display_text"],
                "spoken_text": r["spoken_text"],
            }

        coverage, counts = {}, {}
        for category in cat["languages"][lang]["categories"]:
            wanted = [r for r in per if r["category"] == category]
            got = [r for r in approved if r["category"] == category]
            counts[category] = len(got)
            coverage[category] = ("complete" if len(got) == len(wanted) and wanted
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

SECRET_PATTERNS = [
    re.compile(r"\bsk_[0-9a-f]{32,}\b"),
    re.compile(r"xi-api-key\s*[:=]\s*[\"'][^\"'{$]{8,}"),
    re.compile(r"ELEVENLABS_API_KEY\s*=\s*[\"'][^\"'{$]{8,}"),
]

SECRET_SKIP_DIRS = {".git", ".godot", "build", "voice_masters", "android", "_unused_assets", "node_modules"}
SECRET_SUFFIXES = {".gd", ".py", ".json", ".cfg", ".md", ".csv", ".sh", ".txt", ".tres", ".godot", ".yml", ".yaml"}


def parse_gd_alphabets() -> dict:
    """Pull the ALPHABETS const out of game_config.gd without running Godot."""
    if not GAME_CONFIG.exists():
        return {}
    text = GAME_CONFIG.read_text(encoding="utf-8")
    match = re.search(r"const\s+ALPHABETS\s*:\s*Dictionary\s*=\s*\{(.*?)\n\}", text, re.S)
    if not match:
        return {}
    out = {}
    for lang, alphabet in re.findall(r'"([a-z]{2})"\s*:\s*"([^"]*)"', match.group(1)):
        out[lang] = alphabet
    return out


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

    # 3. The speech alphabet and the game's alphabet must be the same letters,
    #    in the same order. This is the check that keeps a clip mapped to the
    #    right pickup.
    gd_alphabets = parse_gd_alphabets()
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled"):
            continue
        letters_file = SPEECH_SRC / f"letters_{lang}.json"
        if not letters_file.exists():
            errors.append(f"{lang} is enabled but {letters_file.name} is missing")
            continue
        doc = read_json(letters_file)
        declared = doc.get("alphabet_string", "")
        problem = grapheme_validate(declared)
        check(errors, not problem, f"{letters_file.name}: alphabet_string — {problem}")
        split = grapheme_split(declared)
        displays = [l["display"] for l in doc["letters"]]
        if split != displays:
            where = next((i for i, (a, b) in enumerate(zip(split, displays)) if a != b),
                         min(len(split), len(displays)))
            errors.append(
                f"{letters_file.name}: alphabet_string has {len(split)} letters, the letters "
                f"array has {len(displays)}; they first differ at position {where} — "
                f"alphabet_string says {split[where] if where < len(split) else '(end)'!r}, "
                f"letters says {displays[where] if where < len(displays) else '(end)'!r}")
        gd_alphabet = gd_alphabets.get(lang)
        if gd_alphabet is None:
            check(errors, declared == "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                  f"{lang}: game_config.gd has no ALPHABETS entry, so the game uses plain A-Z, "
                  f"but {letters_file.name} declares something else")
        else:
            check(errors, gd_alphabet == declared,
                  f"{lang}: game_config.gd alphabet and {letters_file.name} alphabet_string differ")
        for letter in doc["letters"]:
            check(errors, bool(letter.get("spoken", "").strip()),
                  f"{letters_file.name}: {letter.get('id')} has no spoken text")
            if letter.get("spoken", "").strip() == letter.get("display", ""):
                warnings.append(f"{letters_file.name}: {letter['id']} spoken text is just the glyph "
                                f"{letter['display']!r} — the engine will guess")

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

    # 5. Profiles carry no secret, and the repo carries no key.
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

    # 6. Build outputs must not be exportable into the AAB.
    for folder in (MASTERS, BUILD.parent):
        if folder.exists():
            check(errors, (folder / ".gdignore").exists(),
                  f"{rel(folder)} has no .gdignore — Godot would import and export it")

    # 7. Shipped manifests must be internally consistent.
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

    # 8. Phase 5 gate: gameplay must go through SpeechManager, not TTS directly.
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
    line(bool(key), f"${var}", f"set, {len(key)} chars" if key else "not set — only `generate`/`voices` need it")

    info("")
    info("Sources")
    for path in (CATALOG, VOICE_PROFILES):
        line(path.exists(), rel(path))
    for lang, spec in cat["languages"].items():
        if not spec.get("enabled"):
            continue
        for category in spec["categories"]:
            source = SPEECH_SRC / cat["categories"][category]["source"].format(lang=lang)
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

def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        prog="speech_pipeline.py",
        description="Studio Voice build pipeline. Only `generate` spends money.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__.split("Requires")[0].strip().splitlines()[-4:] and
        "typical run:\n"
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
    sp.set_defaults(func=cmd_generate)

    sp = sub.add_parser("process", help="trim, level, encode masters to shipping MP3")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--force", action="store_true", help="re-encode clips that already exist")
    sp.set_defaults(func=cmd_process)

    sp = sub.add_parser("listen", help="named copies of the clips + a page to review them in")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--pending", action="store_true", help="skip clips already approved")
    sp.set_defaults(func=cmd_listen)

    sp = sub.add_parser("review", help="export a review sheet, or import the verdicts")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--import", dest="import_file", metavar="CSV",
                    help="merge a filled-in sheet into data/speech/reviews/")
    sp.set_defaults(func=cmd_review)

    sp = sub.add_parser("pack", help="write res://voices/<lang>/ from approved clips")
    sp.add_argument("--language", "-l", action="append", metavar="LANG")
    sp.add_argument("--pack-version", type=int, default=1)
    sp.set_defaults(func=cmd_pack)

    sp = sub.add_parser("verify", help="CI gate — sources, hashes, manifests, secrets")
    sp.add_argument("--strict", action="store_true",
                    help="also fail on direct TTS.speak() calls (turn on in Phase 5)")
    sp.set_defaults(func=cmd_verify)

    args = parser.parse_args(argv)
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
