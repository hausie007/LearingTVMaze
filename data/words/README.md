# Word Lists Format

The Bludiste app includes a "Words" game mode where players collect letters in order to construct a word out of a predefined list.

Lists are stored as JSON files according to language and difficulty level. They are loaded by the `WordList` (`word_list.gd`) utility class.

## File Naming Convention

`words/words_<lang>_<difficulty>.json`

- `<lang>`: The 2-letter language code (e.g. `en`, `cs`, `vi`).
- `<difficulty>`: An integer from 0 to 6. `0` = Very Easy, `6` = Unbelievable. The tier index matches the game's difficulty level, and therefore the grid size — see `DEVELOPMENT.md` §4 for the length guidance per tier.

If a file for the selected difficulty level is not found, the `WordList` class scans downwards to `0`, then falls back to English (`en`).

## JSON Structure

```json
[
  {
    "word": "CAT",
    "emoji": "🐱"
  },
  {
    "word": "DOG",
    "emoji": "🐶"
  }
]
```

- Words must be grouped as an array of objects.
- Each object requires a `"word"` key (the string text). Case does not matter; it's converted to uppercase for the HUD automatically.
- Each object requires an `"emoji"` key, which provides the visual hint displayed next to the word template on the HUD.
- Spaces, apostrophes and hyphens stay visible in the tracker but are never spawned as collectibles.

## Grapheme markers

Some languages spell one letter with two or three characters — Czech `CH`, Hungarian `CS`/`GY`/`SZ`, Slovak `DZ`, Vietnamese `NGH`. Those must be collected, displayed and spoken as **one** item.

Mark them with square brackets in the `word` value:

```json
{ "word": "MOU[CH]A", "emoji": "🪰" }
```

`MOU[CH]A` spawns five collectibles — `M O U CH A` — and the brackets never appear on screen or reach the speech engine. An unmarked word spawns one collectible per character, exactly as before.

Rules:

- No nesting, no empty groups, at least two characters inside each group.
- Marking is **minimal**: bracket only the multi-character letters, leave everything else alone.
- Whether a language marks a given digraph is a **content decision**, not a rule the code applies. Czech `CH` is a letter of the alphabet, so it is marked. Spanish `CH` was removed from the alphabet in 2010, so it is not. German `SCH` is a sound, not a letter — not marked. When in doubt, ask a native speaker; a wrong marking is as visible as a wrong emoji.
- Watch for false pairs across morpheme boundaries: Polish `MARZNĄĆ` is *mar-znąć*, not *ma-rz-nąć*, and Hungarian `KÖZSÉGHÁZA` is *község-háza*, not *…ö-zs-é…*. Those must stay unmarked.

Currently marked: `cs` only (8 words). `sk`, `hu`, `vi`, `nl` and `pl` still need a native-speaker pass — see `_ideas_/studio_voice_iteration_1_design.md` Part B.
