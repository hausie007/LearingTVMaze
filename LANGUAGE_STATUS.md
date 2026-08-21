# Language status

Where every language stands, from the alphabet to audio playing in the game.

**Generated — do not edit by hand.** `python3 tools/speech/speech_pipeline.py status`
reads the repository and rewrites this file, so it cannot drift from what is
actually there. A checklist ticked by hand is a checklist that lies within a month.

`✓` done  `~` partly  `·` not started  `—` nothing to do

| Lang | Voice | Data | Alphabet | Digraphs | Words checked | Letters+numbers | Word audio | UI speech | In game |
|---|---|---|---|---|---|---|---|---|---|
| **cs** | Jana | ✓ | ✓ +8 word-only | ✓ CH | ✓ 8 marked | ✓ | ✓ 277 | ✓ 56 +50 forms | ✓ playing |
| **en** | Nichalia Schwartz | ✓ | ✓ A–Z | ✓ none | ✓ 0 marked | ✓ | ✓ 290 | ✓ 56 | ✓ playing |
| **sk** | Luky Zajo | ~ draft | ✓ +10 word-only | ✓ CH, DZ, DŽ | ✓ 6 marked | ✓ | ✓ 147 | ✓ 57 | ✓ playing |
| **pl** | Pawel | ~ draft | ✓ +3 word-only | ✓ none | ✓ 0 marked | ✓ | ✓ 169 | ✓ 58 | ✓ playing |
| **de** | Alexander - Deep TV Narrator | ~ draft | ✓ +4 word-only | ✓ none | ✓ 0 marked | ✓ | ✓ 178 | ✓ 62 | ✓ playing |
| **es** | Dan | ✓ | ✓ +6 word-only | · candidates | · | · | · 0/207 | · 0/58 | ✓ playing |
| **fr** | Martin Dupont | ✓ | ✓ A–Z | · candidates | · | ✓ | ✓ 182 | ✓ 58 | ✓ playing |
| **it** | David Martin | ~ draft | ✓ | · candidates | · | ✓ | ✓ 171 | ✓ 58 | ✓ playing |
| **pt** | Paulo | ✓ | ✓ A–Z | · candidates | · | ✓ | ✓ 173 | ✓ 58 | ✓ playing |
| **nl** | Ruth | ~ draft | ✓ | · candidates | · | ✓ | ✓ 165 | ✓ 58 | ✓ playing |
| **sv** | Adam Composer | ~ draft | ✓ | — none | — | · | · 0/179 | · 0/59 | · |
| **da** | · | ~ draft | ✓ | — none | — | · | · 0/159 | · 0/59 | · |
| **nb** | · | ~ draft | ✓ | — none | — | · | · 0/168 | · 0/59 | · |
| **fi** | · | ~ draft | ✓ | — none | — | · | · 0/140 | · 0/57 | · |
| **hu** | Aggie | ~ draft | ✓ +4 word-only | · candidates | · | ✓ | ✓ 140 | ✓ 65 | ✓ playing |
| **ro** | Mike L | ~ draft | ✓ | — none | — | ✓ | ✓ 140 | ✓ 59 | ✓ playing |
| **tr** | Fatih Yıldırım | ~ draft | ✓ | — none | — | ✓ | ✓ 170 | ✓ 36 | ✓ playing |
| **el** | Stefanos | ~ draft | ✓ | — none | — | ✓ | ✓ 140 | ✓ 59 | ✓ playing |
| **uk** | Artem Klopotenko | ~ draft | ✓ | — none | — | ✓ | ✓ 140 | ✓ 57 | ✓ playing |
| **vi** | Kiều Linh | ~ draft | ✓ | · candidates | · | ✓ | ✓ 170 | ✓ 58 | ✓ playing |
| **he** | Hebrew Man | ~ draft | ✓ | — none | — | ✓ | ✓ 147 | ✓ 38 | ✓ playing |

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
