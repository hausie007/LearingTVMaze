#!/usr/bin/env python3
"""
Phase 0-3: Translation CSV cleanup
  - Phase 0: Delete 46 orphaned keys
  - Phase 1: Structural fixes (duplicate rows, missing Greek value)
  - Phase 2: Czech & Slovak diacritics + Honič → Lovec
  - Phase 3: Canonical chaser term consistency across all languages
"""

import csv, io, shutil, os
from datetime import datetime

SRC = "/Users/michalhauzirek/Documents/Bludiste/data/translations.csv"
BAK = SRC + ".bak_" + datetime.now().strftime("%Y%m%d_%H%M%S")

# ── helpers ──────────────────────────────────────────────────────────────────

def col(header, lang):
    return header.index(lang)

# ── Phase 0: orphan keys to delete ───────────────────────────────────────────

ORPHAN_KEYS = {
    "play", "try_normal", "try_numbers", "try_alphabet", "try_words",
    "chaser_suggestion_off", "chaser_suggestion_on", "chaser_suggestion_fast",
    "role_collector", "role_chaser", "role_racer",
    "mp_role_collector_short", "mp_role_chaser_short", "mp_role_racer_short",
    "mp_role_random_collector", "mp_role_rotate_roles",
    "mp_roles_chaser_on", "mp_roles_chaser_off",
    "mp_style_path", "mp_style_next_symbol", "mp_style_race",
    "mp_back", "mp_controller_title",
    "mp_host_setup_title", "mp_host_cancel", "mp_host_start_game", "mp_host_start_now",
    "mp_host_lobby_waiting", "mp_host_lobby_players", "mp_host_player_host",
    "mp_join_existing_controller", "mp_join_setup_title", "mp_join_leave",
    "mp_join_select_host", "mp_join_select_host_required", "mp_join_theme",
    "mp_host_difficulty", "mp_host_theme", "mp_host_max_players", "mp_host_character",
    "mp_host_game_style",
    "mp_multiplayer",
    "style_coming_soon", "style_next_symbol",
    "pickup_nothing", "players_2_only",
    # old short "Lobby" version of mp_host_lobby_title (row 221)
    # handled separately below via seen-key deduplication
}

# ── Phase 1: duplicate key resolution ────────────────────────────────────────
# For duplicate keys we keep the LAST occurrence (the newer/fuller translation).
# mp_host_lobby_title: keep long "Let's Play Together..." (row 375), drop "Lobby" (row 221)
# mp_slot_join_as: keep row 382 (first), drop row 383 (second)
# mp_chaser_get_ready_steps: keep row 386 (first), drop row 387 (second)
KEEP_FIRST = {"mp_slot_join_as", "mp_chaser_get_ready_steps"}
KEEP_LAST  = {"mp_host_lobby_title"}   # keep the longer/translated version

# ── Phase 2+3: targeted cell fixes ───────────────────────────────────────────
# Format: { key: { lang: new_value } }
CELL_FIXES = {
    # ── home_start cs ──
    "home_start": {"cs": "Hrát"},

    # ── mp_role_collector cs diacritics ──
    "mp_role_collector": {
        "cs": "Sběrač",
        # consistency: mp_role_chaser translated in Phase 3 entry below
    },

    # ── mp_role_racer cs diacritics ──
    "mp_role_racer": {"cs": "Závodník"},

    # ── Honič → Lovec (cs + sk) ──
    "mp_role_chaser": {
        "cs": "Lovec",
        "sk": "Lovec",
        # consistency fixes for all untranslated cells handled in Phase 4
        "de": "Verfolger", "es": "Perseguidor", "fr": "Chasseur",
        "pt": "Perseguidor", "vi": "Kẻ đuổi", "tr": "Takipçi",
        "it": "Inseguitore", "pl": "Goniący", "sv": "Jagare",
        "nb": "Jager", "nl": "Achtervolger", "uk": "Переслідувач",
        "fi": "Jahtaaja", "da": "Forfølger", "hu": "Üldöző",
        "ro": "Urmăritor", "el": "Κυνηγός", "he": "רודף",
    },

    "mp_role_collector": {
        "cs": "Sběrač",
        "de": "Sammler", "es": "Recolector", "fr": "Collecteur",
        "pt": "Coletor", "vi": "Người thu thập", "tr": "Toplayıcı",
        "it": "Raccoglitore", "pl": "Zbieracz", "sv": "Samlare",
        "nb": "Samler", "nl": "Verzamelaar", "uk": "Збирач",
        "fi": "Kerääjä", "da": "Samler", "hu": "Gyűjtő",
        "ro": "Colector", "el": "Συλλέκτης", "sk": "Zberač", "he": "אוסף",
    },

    "mp_role_racer": {
        "cs": "Závodník",
        "de": "Rennfahrer", "es": "Corredor", "fr": "Coureur",
        "pt": "Corredor", "vi": "Tay đua", "tr": "Yarışçı",
        "it": "Corridore", "pl": "Zawodnik", "sv": "Racerförare",
        "nb": "Racerfører", "nl": "Racer", "uk": "Гонщик",
        "fi": "Kilpailija", "da": "Racerkører", "hu": "Versenyző",
        "ro": "Concurent", "el": "Αγωνιστής", "sk": "Závodník", "he": "מתחרה",
    },

    "mp_role_swap_roles": {
        "cs": "Vyměnit role",
        "de": "Rollen tauschen", "es": "Cambiar roles", "fr": "Changer les rôles",
        "pt": "Trocar papéis", "vi": "Đổi vai", "tr": "Rolleri değiştir",
        "it": "Scambia ruoli", "pl": "Zamień role", "sv": "Byt roller",
        "nb": "Bytt roller", "nl": "Rollen wisselen", "uk": "Поміняти ролі",
        "fi": "Vaihda roolit", "da": "Skift roller", "hu": "Szerepek cseréje",
        "ro": "Schimbă rolurile", "el": "Αλλαγή ρόλων", "sk": "Vymeniť roly", "he": "החלף תפקידים",
    },

    # ── setting_chaser canonical term ──
    "setting_chaser": {
        "cs": "Lovec:", "sk": "Lovec:",
        "de": "Verfolger:", "fr": "Chasseur:", "it": "Inseguitore:",
        "pl": "Goniący:", "nl": "Achtervolger:", "da": "Forfølger:",
        "tr": "Takipçi:", "vi": "Kẻ đuổi:", "nb": "Jager:",
        "fi": "Jahtaaja:",
        # already consistent: es, pt, sv, uk, hu, ro, el, he — keep
    },

    # ── setting_chaser_delay canonical term ──
    "setting_chaser_delay": {
        "cs": "Zpoždění lovce",
        "sk": "Oneskorenie lovca",
        "de": "Verfolger-Verzögerung",
        "fr": "Délai du chasseur",    # already correct
        "it": "Ritardo dell'inseguitore",
        "pl": "Opóźnienie goniącego",  # already correct
        "tr": "Takipçi gecikmesi",
        "vi": "Độ trễ kẻ đuổi",       # already correct
        "nb": "Jager-forsinkelse",
        "da": "Forfølger-forsinkelse", # already correct form, keep
        "fi": "Jahtaajan viive",
        "nl": "Achtervolger-vertraging", # already correct
    },

    # ── start_vs_chaser cs/sk ──
    "start_vs_chaser": {
        "cs": "Běžec vs Lovec",
        "sk": "Bežec vs Lovec",
    },

    "start_vs_chaser_desc": {
        "cs": "Hráč 2 se stane lovcem!",
        "sk": "Hráč 2 sa stane lovcom!",
    },

    # ── mp_role_desc_collector_chaser cs ──
    "mp_role_desc_collector_chaser": {
        "cs": "Sbírej předměty a doraz do cíle — ale lovec se za chvíli objeví!",
        "sk": "Zbieraj predmety a dostaň sa k východu — ale lovec sa po chvíli objaví!",
    },

    # ── help_slide_6_text cs — replace honič with lovec ──
    "help_slide_6_text": {
        "cs": (
            "Hru si můžeš upravit podle svého.\n"
            "V nastavení jde změnit jak veliké je bludiště, v jakém prostředí se odehrává "
            "i jak rychle tě lovec bude pronásledovat. Můžeš si také zvolit jazyk hry a "
            "v jakém jazyce chceš čísla a písmena číst. Tak s chutí do toho!"
        ),
    },

    # ── trouble_chaser / trouble_no_chaser — translate using canonical terms ──
    "trouble_chaser": {
        "cs": "Lovec", "sk": "Lovec",
        "de": "Verfolger", "es": "Perseguidor", "fr": "Chasseur",
        "pt": "Perseguidor", "vi": "Kẻ đuổi", "tr": "Takipçi",
        "it": "Inseguitore", "pl": "Goniący", "sv": "Jagare",
        "nb": "Jager", "nl": "Achtervolger", "uk": "Переслідувач",
        "fi": "Jahtaaja", "da": "Forfølger", "hu": "Üldöző",
        "ro": "Urmăritor", "el": "Κυνηγός", "he": "רודף",
    },

    "trouble_no_chaser": {
        "cs": "Bez lovce", "sk": "Bez lovca",
        "de": "Ohne Verfolger", "es": "Sin perseguidor", "fr": "Sans chasseur",
        "pt": "Sem perseguidor", "vi": "Không có kẻ đuổi", "tr": "Takipçisiz",
        "it": "Senza inseguitore", "pl": "Bez goniącego", "sv": "Utan jagare",
        "nb": "Uten jager", "nl": "Zonder achtervolger", "uk": "Без переслідувача",
        "fi": "Ilman jahtaajaa", "da": "Uden forfølger", "hu": "Üldöző nélkül",
        "ro": "Fără urmăritor", "el": "Χωρίς κυνηγό", "he": "ללא רודף",
    },

    "setting_trouble": {
        "cs": "Lovec:", "sk": "Lovec:",
        "de": "Verfolger:", "es": "Perseguidor:", "fr": "Chasseur :",
        "pt": "Perseguidor:", "vi": "Kẻ đuổi:", "tr": "Takipçi:",
        "it": "Inseguitore:", "pl": "Goniący:", "sv": "Jagare:",
        "nb": "Jager:", "nl": "Achtervolger:", "uk": "Переслідувач:",
        "fi": "Jahtaaja:", "da": "Forfølger:", "hu": "Üldöző:",
        "ro": "Urmăritor:", "el": "Κυνηγός:", "he": ":רודף",
    },

    # ── setting_head_start ──
    "setting_head_start": {
        "cs": "Náskok:", "sk": "Náskok:",
        "de": "Vorsprung:", "es": "Ventaja:", "fr": "Avance :",
        "pt": "Vantagem:", "vi": "Ưu thế:", "tr": "Avantaj:",
        "it": "Vantaggio:", "pl": "Przewaga:", "sv": "Försprång:",
        "nb": "Forsprang:", "nl": "Voorsprong:", "uk": "Перевага:",
        "fi": "Etumatka:", "da": "Forspring:", "hu": "Előny:",
        "ro": "Avans:", "el": "Προβάδισμα:", "he": ":יתרון התחלתי",
    },

    # ── pickup_none ──
    "pickup_none": {
        "cs": "Bez sbírání", "sk": "Bez zbierania",
        "de": "Ohne Sammeln", "es": "Sin recolección", "fr": "Sans collecte",
        "pt": "Sem coleta", "vi": "Không thu thập", "tr": "Toplama yok",
        "it": "Senza raccolta", "pl": "Bez zbierania", "sv": "Inget samlande",
        "nb": "Ingen samling", "nl": "Niets verzamelen", "uk": "Без збирання",
        "fi": "Ei keräilyä", "da": "Ingen samling", "hu": "Nincs gyűjtés",
        "ro": "Fără colectare", "el": "Χωρίς συλλογή", "he": "ללא איסוף",
    },

    # ── mp_multiplayer_title ──
    "mp_multiplayer_title": {
        "cs": "Více hráčů", "de": "Mehrspieler", "es": "Multijugador",
        "fr": "Multijoueur", "pt": "Multijogador", "vi": "Nhiều người chơi",
        "tr": "Çok oyunculu", "it": "Multigiocatore", "pl": "Wielu graczy",
        "sv": "Flerspelare", "nb": "Flerspiller", "nl": "Meerdere spelers",
        "uk": "Кілька гравців", "fi": "Moninpeli", "da": "Flerspiller",
        "hu": "Többjátékos", "ro": "Multiplayer", "el": "Πολλοί παίκτες",
        "sk": "Viac hráčov", "he": "מספר שחקנים",
    },

    # ── hud_desc_mp_race — add missing Greek ──
    "hud_desc_mp_race": {
        "el": "Αγωνίσου με τους άλλους στο κέντρο του λαβύρινθου!",
    },
}


def apply_fixes(rows, header):
    """Apply CELL_FIXES to matching rows."""
    for row in rows:
        key = row[0] if row else ""
        if key in CELL_FIXES:
            for lang, val in CELL_FIXES[key].items():
                if lang in header:
                    row[col(header, lang)] = val
    return rows


def process_csv():
    shutil.copy2(SRC, BAK)
    print(f"Backup: {BAK}")

    with open(SRC, encoding="utf-8", newline="") as f:
        raw = f.read()
    reader = csv.reader(io.StringIO(raw))
    all_rows = list(reader)

    header = all_rows[0]
    data   = all_rows[1:]

    # ── Phase 0: remove orphans ──────────────────────────────────────────────
    removed_orphans = []
    kept = []
    for row in data:
        if not row or not row[0]:
            continue
        key = row[0]
        if key in ORPHAN_KEYS:
            removed_orphans.append(key)
        else:
            kept.append(row)
    print(f"\nPhase 0 — Removed {len(removed_orphans)} orphan rows:")
    for k in removed_orphans:
        print(f"  - {k}")

    # ── Phase 1: resolve duplicate keys ──────────────────────────────────────
    # For KEEP_FIRST: remove subsequent occurrences
    # For KEEP_LAST (mp_host_lobby_title): remove first occurrence ("Lobby")
    seen = {}
    deduped = []
    removed_dupes = []

    # First pass: find all positions of duplicate keys
    key_positions = {}
    for i, row in enumerate(kept):
        k = row[0]
        key_positions.setdefault(k, []).append(i)

    rows_to_drop = set()
    for k, positions in key_positions.items():
        if len(positions) > 1:
            if k in KEEP_LAST:
                # drop all but the last
                for idx in positions[:-1]:
                    rows_to_drop.add(idx)
                    removed_dupes.append(f"{k} (keeping last, dropping index {idx})")
            else:
                # default KEEP_FIRST: drop all but the first
                for idx in positions[1:]:
                    rows_to_drop.add(idx)
                    removed_dupes.append(f"{k} (keeping first, dropping index {idx})")

    deduped = [row for i, row in enumerate(kept) if i not in rows_to_drop]
    print(f"\nPhase 1 — Removed {len(removed_dupes)} duplicate rows:")
    for d in removed_dupes:
        print(f"  - {d}")

    # ── Phase 2+3: apply cell fixes ──────────────────────────────────────────
    apply_fixes(deduped, header)
    print(f"\nPhase 2+3 — Cell fixes applied for {len(CELL_FIXES)} keys.")

    # ── Write output ─────────────────────────────────────────────────────────
    output = io.StringIO()
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(header)
    writer.writerows(deduped)

    with open(SRC, "w", encoding="utf-8", newline="") as f:
        f.write(output.getvalue())

    print(f"\nDone. {len(deduped)} rows written (was {len(data)}).")
    print(f"Source: {SRC}")


if __name__ == "__main__":
    process_csv()
