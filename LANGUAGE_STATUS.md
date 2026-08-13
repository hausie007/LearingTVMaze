# Language status

Where every language stands, from the alphabet to audio playing in the game.

**Generated — do not edit by hand.** `python3 tools/speech/speech_pipeline.py status`
reads the repository and rewrites this file, so it cannot drift from what is
actually there. A checklist ticked by hand is a checklist that lies within a month.

`✓` done  `~` partly  `·` not started  `—` nothing to do

| Lang | Voice | Data | Alphabet | Digraphs | Words checked | Letters+numbers | Word audio | UI speech | In game |
|---|---|---|---|---|---|---|---|---|---|
| **cs** | Jana | ✓ | ✓ +8 word-only | ✓ CH | ✓ 8 marked | ✓ | ✓ 277 | ~ 55/57 | ✓ playing |
| **en** | Nichalia Schwartz | ✓ | ✓ A–Z | ✓ none | ✓ 0 marked | ✓ | ✓ 290 | ✓ 36 | ✓ playing |
| **sk** | · | ~ draft | ✓ +10 word-only | ✓ CH, DZ, DŽ | ✓ 6 marked | · | · 0/147 | · | · |
| **pl** | · | ~ draft | ✓ +3 word-only | ✓ none | ✓ 0 marked | · | · 0/169 | · | · |
| **de** | · | ~ draft | ✓ +4 word-only | ✓ none | ✓ 0 marked | · | · 0/178 | · | · |
| es | · | · | · | · | · | · | · | · | · |
| fr | · | · | · | · | · | · | · | · | · |
| it | · | · | · | · | · | · | · | · | · |
| pt | · | · | · | · | · | · | · | · | · |
| nl | · | · | · | · candidates | · | · | · | · | · |
| sv | · | · | · | — none | — | · | · | · | · |
| da | · | · | · | — none | — | · | · | · | · |
| nb | · | · | · | — none | — | · | · | · | · |
| fi | · | · | · | — none | — | · | · | · | · |
| hu | · | · | · | · candidates | · | · | · | · | · |
| ro | · | · | · | — none | — | · | · | · | · |
| tr | · | · | · | — none | — | · | · | · | · |
| el | · | · | ✓ | — none | — | · | · | · | · |
| uk | · | · | ✓ | — none | — | · | · | · | · |
| vi | · | · | · | · candidates | · | · | · | · | · |
| he | · | · | ✓ | — none | — | · | · | · | · |

Bold means the language is enabled in `data/speech/catalog.json`; the rest are
declared but not being generated.

## What each column means

| Column | Done when |
|---|---|
| Data | `letters_<lang>.json` and `numbers_<lang>.json` exist and are no longer marked DRAFT — a native speaker has read the letter names and the number words |
| Alphabet | The language has an entry in `ALPHABETS` in `game_config.gd`, and in `WORD_ONLY_LETTERS` if its words use letters the alphabet lesson should skip |
| Digraphs | Someone has decided which multi-character sequences are *letters* of this alphabet, recorded in `data/speech/digraphs.json` |
| Words checked | The whole word list has been read for those digraphs and marked, e.g. `MOU[CH]A` |
| Letters+numbers | Every letter and every number 1–50 recorded and approved by a named reviewer |
| Word audio | Every vocabulary word recorded and approved |
| UI speech | The app title, the language names spoken in settings, and the finish-recap framing — recorded in the UI language, which is often not the learning language. Help narration is deliberately excluded |
| In game | `voices/<lang>/` exists and the game plays it |

## Order of work for a new language

1. **Alphabet** into `game_config.gd` — what Letters mode spawns, plus word-only letters.
2. **Digraphs** — is any two-character sequence a letter here? Record the decision either way.
3. **Word list** — mark them, if there were any.
4. **Letter names and number words** — a native speaker, before anything is recorded.
5. **A voice** — native to the language. `voices --language <lang>` lists candidates.
6. **Generate, review, pack.** Letters and numbers first; words are a separate, larger pass.

Steps 1–4 cost nothing and are where the mistakes are cheap. Step 6 is where they
stop being cheap: the Czech pilot spent about 40 cents on synthesis across eight
rounds of review, and the reviewing was the expensive part.
