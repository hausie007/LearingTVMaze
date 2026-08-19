# Speaking the meaning as well as the word

Analysis, not a decision. Written August 2026 against the word lists as they
stand: 3,652 entries across 21 languages.

## The idea

When the learning language is not the child's own, say the word in the learning
language and then its meaning in the UI language. "Perro." … "Pes."

## Is it a good idea

**Yes, narrowly, and it is cheaper than it looks.**

The cost that would normally sink this — recording every word in every language
pair — does not exist. Both recordings already exist. A Czech child learning
Spanish hears `es` say *perro* from the Spanish pack, then `cs` say *pes* from
the Czech pack. Both packs are already built, already shipped, already
approved. Nothing is synthesised and the AAB does not grow.

`SpeechManager` already holds several packs at once and already resolves
fallback per item — the finish recap depends on it, mixing UI-language framing
with learning-language letters in one sentence. The recap already knows whether
the two languages differ; `learning_recap.gd` calls it `show_language` and uses
it to say "in Greek". This feature is one more segment in a queue that already
exists.

**Three things worth arguing about before building it.**

It only ever fires when the learning language differs from the UI language.
Both default to `auto`, so both resolve to the device language and most
installs would never hear it. That is not an objection — the audience for this
is exactly the parent who deliberately set a second language — but it means the
feature is invisible to most users and should not be measured as though it were
not.

The picture already carries the meaning. A four-year-old collecting 🐕 while
hearing *perro* is already forming a direct picture→word link, which is the
association second-language teaching generally wants. Adding *pes* routes the
new word through the child's first language instead, which some evidence says
is the weaker path for young learners. The honest case for it is different: it
confirms comprehension, it lets a parent who does not speak the learning
language follow along, and it is how most families actually talk about a new
word. Worth building, worth not overclaiming.

It lengthens the moment. The finish already speaks a recap. Two more words is
probably fine; it should be measured against a real child rather than assumed.

**The real risk is a wrong pair.** Silence teaches nothing; a wrong translation
teaches something false, and neither the child nor a parent who does not speak
the learning language can catch it. Whatever mapping is built has to be
reviewable, and `verify` has to fail on a broken one.

## What the data actually looks like

There is no mapping between languages today. What exists is accidental
alignment, and it is very uneven:

| Tier | Content | Alignment across languages |
|---|---|---|
| 5–6 | Phrases | **17 of 21 languages are already parallel** — same concept at the same index, same emoji. Only `cs`, `de`, `en`, `he` diverge |
| 1–4 | Single words | Essentially none. Each language chose its own |

The phrase tiers were clearly generated from one template, so `es[5][0]`,
`tr[5][0]`, `vi[5][0]`, `fi[5][0]` are all "hello friends 👋". The word tiers
were not: `tr` tier 1 is vehicles, `fi` tier 1 is forest animals, `cs` tier 1 is
whatever fitted Czech.

**That divergence is correct and must not be flattened.** Words are chosen to
contain the letters of their own alphabet — Czech needs one with Ř, Turkish one
with Ğ — and to fit the tier's length cap. Forcing 21 languages onto one word
list would damage the thing the game is actually for in order to serve a
secondary feature.

Emoji is not a usable key, though it looked like one. It is reused within a
language 17–47 times (Czech has 🐶 on three different words) and only 33–71% of
one language's pictures appear in another's list at all.

**Realistic coverage**, measured by emoji as a rough proxy for concept, single
words only:

| Learning → UI | Words with a shared concept |
|---|---|
| es → en | 71% |
| pt → es | 69% |
| vi → en | 64% |
| sk → cs | 61% |
| el → en | 58% |
| uk → pl | 48% |
| fi → sv | 42% |
| pl → de | 40% |
| tr → de | 33% |

So this is a feature that will work for roughly half of words, not all of them.
That is acceptable if it degrades per word — say nothing extra, exactly as
speech already falls back per item — and unacceptable if it is presented as a
promise.

## How to build it without a rewrite

**One new field.** Give each entry a stable concept id:

```json
{ "id": "dog", "word": "PES", "emoji": "🐶" }
```

Same id in two languages means the same thing. English words make convenient
ids because they are ASCII and readable, not because English is privileged.

That field costs nothing to add. `word_list.gd` `_resolve_entry` copies the
whole dictionary through, so the id lands in `Config.current_word` untouched,
and every consumer that reads `word` and `emoji` carries on unchanged. The
validation snippet in `CLAUDE.md` asserts the fields it needs and ignores
others.

**Then three small pieces:**

1. `WordList.find_by_id(lang, id)` — the reverse lookup. The class already
   loads per language and already falls back when a file is missing.
2. One call at the end of the finish narration: if the UI language differs, if
   the entry has an id, and if the UI language has a word with that id, append
   a segment. `Speech.speak_segments` already takes a list of `{text, lang}`
   and resolves each against its own pack.
3. `verify` learns two checks: every id resolves within its own file, and no id
   appears twice in one language.

No new screen, no new setting. It fires exactly when the two languages differ,
which is already a deliberate choice the parent made. Adding a switch for it
would be a switch for a feature most users cannot see.

**Building the mapping, cheapest first:**

- **Phrases**: 17 languages align by index already, so a script assigns ids by
  position. `cs`, `de`, `en`, `he` need 40 entries each mapped by hand or by
  LLM. Perhaps an hour, and the phrase tiers are where the translation is most
  interesting anyway — a whole sentence in two languages.
- **Words**: no shortcut. An LLM can propose an id per entry file by file, with
  the emoji as a strong hint; a human spot-checks. 3,652 entries sounds worse
  than it is, because it is 147 files of 20–50 and each is independently
  reviewable. This is the same review pattern as the letter names, and the same
  prompt shape would work.
- Entries with no counterpart simply get an id no other language uses. Nothing
  breaks; that word is silent in translation.

## Cheaper ways to raise the educational value

Ordered by value per unit of work, all using recordings that already exist or
nearly so.

**1. Say the letter's sound, not only its name.** The game teaches letter
*names* — "bé", "cé". Reading is built on letter *sounds*. Czech, Slovak and
Polish schools teach the sound first and treat the name as secondary, and a
child who knows only names has to unlearn something to start reading. This is
the biggest educational gap in the game and it is roughly 40 extra recordings
per language, using the pipeline exactly as it stands. It would also need a
decision about which to say when, which is a real pedagogical question rather
than a build task.

**2. Link the letter to a word that starts with it.** On completing KOČKA, say
"K — kočka". Both clips already exist in every pack. Zero new audio, a few
lines of code, and it teaches the alphabetic principle directly — that the
letter shape corresponds to the sound the word starts with. Probably the best
ratio here.

**3. Leave a beat of silence after the word.** A pause long enough for a child
to repeat it. Costs nothing, no audio, no data — a timer. Repetition aloud is
one of the better-evidenced vocabulary mechanisms for this age, and the game
currently gives no room for it.

**4. Group the deck by initial letter.** Deal words so consecutive ones share a
first letter, rather than at random. Pure data ordering, no audio, and it turns
a sequence of unrelated words into a pattern a child can notice.

**5. Syllables.** Speak "ko-čka" as well as "kočka". The machinery now exists —
word boundaries inside a phrase clip are already computed from forced alignment
and played back to a stop — and syllable boundaries are the same problem one
level down. Real work, but not new work.

Of these, **2 and 3 cost almost nothing** and would arrive before the
translation mapping is finished. **1 is the one that would matter most** to a
child actually learning to read, and is the one I would think hardest about.

## If it goes ahead

Order that keeps every step useful on its own:

1. Add `id` to the phrase tiers only, where alignment already exists. Ship the
   translation for phrases. Small, visible, and the phrases are the part where
   hearing both languages is most rewarding.
2. Measure whether children and parents actually like it before mapping 3,000
   single words.
3. Map words tier by tier, easiest pairs first.

Step 1 is perhaps a day including review. Steps 2 and 3 should not start until
step 1 has been heard by a real four-year-old.
