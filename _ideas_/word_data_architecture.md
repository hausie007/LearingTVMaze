# One list per language, selected by length

Analysis, not a decision. Companion to `word_translation.md`. Measured against
the corpus as it stands: 3,652 entries, 21 languages, 147 files.

## Would 100% coverage work

**No. It triples the corpus to serve the tail.**

Counting distinct pictures as a rough proxy for distinct concepts:

| | |
|---|---|
| Distinct concepts across all languages | **492** |
| Concepts present in all 21 languages | **13** |
| Concepts present in exactly one language | **143** |
| Entries today | 3,652 (average 173 per language) |
| Entries needed for every language to have every concept | **+7,369** (251–382 each) |

So the corpus goes from 3,652 to about 11,000, and most of that work buys the
long tail: 143 concepts that exactly one language wanted. Those are not
oversights. Finnish has reindeer and snowmen because Finnish children have
reindeer and snowmen; Czech has words nobody else has because Czech needed a
word containing Ř. Translating the tail into twenty other languages produces
vocabulary no one chose for that language, selected to satisfy a symmetry the
child cannot perceive.

Two costs make it worse than the entry count suggests.

**Review.** Synthesis for 7,369 clips is about five dollars — irrelevant. But
they all have to be *listened to*. That is roughly 350 extra clips per
language, on top of the ~300 that already take a careful pass, and this session
showed what that costs in practice.

**Size.** `voices/` is 31 MB for eight languages today. At current word counts
all 21 languages come to roughly 80 MB. At full coverage, roughly 225 MB —
against a game whose entire appeal includes being small, offline and
unobtrusive.

**What to do instead: a curated shared core.** Pick the concepts that are
genuinely universal to a four-year-old — animals, food, family, weather,
vehicles, colours — get those to 100% in all 21 languages, and leave each
language its own tail. The 67 concepts already present in 15+ languages are the
obvious seed; 120–150 total would be a strong core. That is roughly +1,500
entries rather than +7,400, and every one of them earns its place.

## Length is the argument for the new architecture

This is the finding that decides it. Using tiers 5–6, where 17 languages
already hold the same concept at the same index, so the same idea can be
compared across languages:

**The same concept varies by a median of 8 letters between languages, and by up
to 16.**

```
"smile and be happy"   sv  LE OCH VAR GLAD              12 letters
                       pl  UŚMIECHNIJ SIĘ I BĄDŹ SZCZĘŚLIWY   28

"playful dog"          sk  HRAVÝ PES                     8
                       el  ΠΑΙΧΝΙΔΙΑΡΙΚΟΣ ΣΚΥΛΟΣ        20
```

A concept therefore **cannot have a fixed tier across languages**. "Playful
dog" belongs in an early tier in Slovak and a late one in Greek. Any shared
concept set forces per-language tier assignment, and doing that by hand across
21 languages is exactly the kind of bookkeeping that rots.

The current tiers are already a loose proxy for length rather than a real
partition:

| Tier | Entries | Shortest | Median | Longest | Documented typical |
|---|---|---|---|---|---|
| 0 | 502 | 2 | 3 | 6 | 2–4 |
| 1 | 521 | 3 | 4 | 10 | 3–7 |
| 2 | 495 | 2 | 5 | 11 | 3–7 |
| 3 | 492 | 2 | 7 | 14 | 6–12 |
| 4 | 802 | 2 | 9 | 18 | 6–12 |
| 5 | 420 | 4 | 11 | 20 | 11–20 |
| 6 | 420 | 9 | 16 | 28 | 11–20 |

**15% of entries already sit outside their own tier's documented range**, and
tier 2 holds words from 2 to 11 letters. Selecting by length would be more
accurate than the tiers are now, not less.

## The proposed schema

One file per language, `data/words/words_<lang>.json`:

```json
{
  "schema_version": 2,
  "lang": "cs",
  "words": [
    { "id": "dog",  "word": "PES",      "emoji": "🐶", "tags": ["animals", "pets"] },
    { "id": "fly",  "word": "MOU[CH]A", "emoji": "🪰", "tags": ["animals"] }
  ]
}
```

**Do not store the length.** Compute it at load, grapheme-aware and ignoring
spaces, the same place grapheme markers are already resolved. Stored derived
data drifts from its source, and this repository has been bitten three times by
two components disagreeing about one string. A length field would be a fourth.

`id` is the concept key from `word_translation.md`; the two changes want the
same field and should be done together rather than migrating the corpus twice.

`tags` cost nothing to add now and are what a category picker would later read.

## Selection

`get_random_word(lang, difficulty, tags)`:

1. Take the length band for the difficulty — the table above, tightened to the
   documented typical ranges rather than the accidental spread.
2. Filter by tags if any are chosen.
3. Shuffle-bag from what remains, exactly as now.
4. Degrade in a fixed order when the pool is too small: widen the band, then
   drop the tags, then fall back to English. Never silently return nothing.

That last point matters more with tags than without: a category plus a narrow
band could easily leave four words in a small language, and four words is a
worse experience than a wider band.

## Does it fit the current architecture

**Yes, and the blast radius is unusually small.**

- `word_list.gd` is 98 lines and is the only loader.
- `get_random_word` has exactly **two** call sites: `collectible_spawner.gd`
  and the multiplayer race builder.
- No word is currently listed in two tiers of the same language, so the merge
  is clean — the data is in better shape than the schema is.
- The speech pipeline finds words through `source_glob` in `catalog.json`; one
  line changes.
- `verify` counts 147 files and 3,652 entries; those numbers move.
- Multiplayer is unaffected in principle: the host picks the word and drives the
  layout, so selection stays on one side.

The migration is mechanical: read 147 files, write 21. The risky part is not
the code, it is that **tier is not purely length**. A tier also encodes how
familiar a word is — SLON and MĚSÍC are both short, but one is a picture-book
animal and the other is abstract. Pure length selection would hand a
three-year-old whatever short word came up. Keep the original tier as an
optional `tier` hint and use it to break ties within a band, so nothing that is
currently well-paced becomes badly paced.

**Do this before adding concepts, not after.** Migrating 3,652 entries is a
morning; migrating 11,000 is not.

## Categories and packs

**Categories are a good idea and the data is the cheap half.** Tags cost
nothing. The expensive half is the picker, and it has a hard constraint: the
child cannot read. "Emergency services" has to be a picture — 🚑 🚒 👮 — not a
word, and a set of category tiles is a new screen with D-pad navigation, focus
handling and its own translations. Build the tags now, the picker when it is
worth a screen.

Two content cautions. A category is only playable if it has enough words at the
right length in that language, so tags need a coverage check in `verify` or
children will meet the same four words repeatedly. And categories invite themes
the content rules already exclude — emergency services is fine, but it sits
next to weapons and injury, which are explicitly out.

**Packs work naturally with one file per language** — an extra file merged at
load, or a `pack` field on each entry. Two limits are worth stating before
anyone gets attached to the idea:

- **They must ship inside the AAB.** Downloading a pack means a network call,
  and the app makes none. That posture is the project's strongest asset and is
  what keeps the Play Families record clean; a content download would need the
  privacy policy, the Data safety declaration and the IARC questionnaire
  revisited.
- **They cannot be sold**, for the same reason — purchases are on the same list
  as accounts, chat and SDKs.

So packs mean seasonal or thematic word sets shipped with the app, chosen by a
picture. That is still worth having; it just is not a store.

## What I would do, in order

1. **Migrate the schema** — 147 files to 21, `id` and `tags` fields added,
   length computed at load, tier kept as a hint. A morning's work on data that
   is already clean.
2. **Define the shared core** — 120–150 universal concepts, seeded from the 67
   already in 15+ languages.
3. **Fill the core** language by language, reviewing as you go. ~1,500 entries.
4. **Translation feature** on top, which by then has real coverage to work with.
5. **Category picker** only once the tags have proved useful in testing.

Steps 1 and 2 are worth doing even if the translation feature is never built:
they make every future language cheaper to add and every existing one easier to
review.
