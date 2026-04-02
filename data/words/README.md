# Word Lists Format

The Bludiste app includes a "Words" game mode where players collect letters in order to construct a word out of a predefined list.

Lists are stored as JSON files according to language and difficulty level. They are loaded by the `WordList` (`word_list.gd`) utility class.

## File Naming Convention

`words/words_<lang>_<difficulty>.json`

- `<lang>`: The 2-letter language code (e.g. `en`, `cs`, `vi`).
- `<difficulty>`: An integer from 0 to 4. `0` = Very Easy, `4` = Very Hard.

If a file for the selected difficulty level is not found, the `WordList` class will attempt to fall back to difficulty `0` or then to English (`en`).

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
- Each object requires a `"word"` key (the string text). Case does not matter; it's converted to uppercase for the HUD automatically. Spaces inside the word are skipped by the collectible spawner logic.
- Each object requires an `"emoji"` key, which provides the visual hint displayed next to the word template on the HUD.
