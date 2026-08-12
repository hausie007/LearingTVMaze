# Learning Maze — project context

Educational maze game for pre-readers. Godot 4.6 · GDScript · Android, Android TV, Google TV.
Package `com.hauzirek.learningmaze`.

## Read these first

- **[`coding_rules.md`](coding_rules.md)** — GDScript conventions, D-pad navigation, UI utilities, file organisation. Read before writing any code.
- **[`DEVELOPMENT.md`](DEVELOPMENT.md)** — who the game is for, game mechanics, the theme and vocabulary systems, content and policy rules, release process.

## The short version

The player is a **four-year-old who cannot read**, on a **TV with a D-pad**. Nothing may depend on reading, nothing may punish, nothing may frighten.

The app has **no ads, no analytics, no third-party SDKs, no accounts, no network calls to any server, and two permissions**. That posture is the project's strongest asset and is what keeps its Google Play Families record clean.

## Things that are easy to get wrong

- **Never rename a theme folder.** `game_config.gd` persists it as `dir_name`, character IDs are prefixed with it, and it travels in the multiplayer discovery payload. Retitle via the `theme_<folder>` row in `data/translations.csv` instead.
- **Resolve theme assets through `theme_loader.gd`, never by listing the folder.** Superseded art accumulates, and the single texture and the frame list are used by different screens.
- **Tier-0 words are capped at 6 letters.** The 5×4 grid guarantees only six usable path cells.
- **Never remove the in-app privacy policy link.** It is mandatory in the app *and* in Play Console.
- **Every user-visible string goes through `tr()`**, with the key in `data/translations.csv`.
- **Adding an SDK, accounts, chat, purchases, a server, or the location permission** requires updating `PRIVACY_POLICY.md`, the Data safety declaration and the IARC questionnaire before it ships.

## Validate word-list changes

```bash
cd data/words && python3 -c "
import json,glob,re
t=0
for f in sorted(glob.glob('words_*.json')):
    d=json.load(open(f,encoding='utf-8')); t+=len(d)
    for e in d:
        assert 'word' in e and 'emoji' in e and e['emoji'], (f,e)
        w=e['word']
        assert w.count('[')==w.count(']'), ('unbalanced markers',f,w)
        assert not re.search(r'\[[^\]]*\[|\][^\[]*\]',w), ('nested markers',f,w)
        for g in re.findall(r'\[([^\]]*)\]',w):
            assert len(g)>=2, ('group needs 2+ chars',f,w)
print('OK', len(glob.glob('words_*.json')), 'files,', t, 'entries')"
```

Expected: `OK 147 files, 3652 entries`.

`[CH]` marks one letter spelled with two characters — see `data/words/README.md`. Strip markers before any length, duplicate or emoji comparison, or `MOU[CH]A` and `MOUCHA` will look like different words.

## Compliance

`COMPLIANCE_CHECKLIST.md` is the current Google Play compliance record, written for an external reader. Update it whenever content changes.
