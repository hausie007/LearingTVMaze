# Native-speaker review prompt

One language per conversation, always. A reviewer holding two alphabets at once
starts answering from the wrong one, and that is exactly the error nobody
catches later.

## Which files to attach

| File | What it holds |
|---|---|
| `data/speech/letters_<lang>.json` | Every letter of the alphabet and the name a speaker says for it |
| `data/speech/numbers_<lang>.json` | The words for 1–50 |
| `data/speech/digraphs.json` | Which multi-character sequences count as letters — all languages in one file, read only the entry for yours |

Attach `data/number_forms.json` as well **only** for a language that changes a
number's form after a preposition like "to": Czech, Slovak, Polish, Ukrainian,
Greek, Finnish, Hungarian and Turkish do. Spanish, Portuguese, French, German,
Italian, Dutch and the Scandinavian languages do not.

## Waiting for review

| Status | Languages |
|---|---|
| Drafted, never seen by a speaker | `tr` `it` `nl` `ro` `uk` `el` `hu` `sv` `da` `nb` `fi` `vi` `he` |
| Drafted, reviewed by an LLM only | `es` `pt` `fr` |
| Recorded, letter names still marked DRAFT | `sk` `pl` `de` |

Ones with a known open question, worth putting to the reviewer directly:

- **`nl`** — is `IJ` a letter? Left out. School practice and the official
  alphabet disagree, and it capitalises as a pair.
- **`vi`** — are `CH`, `GH`, `GI`, `KH`, `NG`, `NGH`, `NH`, `PH`, `QU`, `TH`,
  `TR` letters? Left undecided. Taught as units in school.
- **`hu`** — `DZS` is three characters and claimed here as one letter.
- **`he`** — the numbers are the feminine forms. Right for a child counting?

---

## The prompt

> You are reviewing language data for a children's educational game, as a
> native speaker of <LANGUAGE> (<LOCALE>) who knows how the alphabet is taught
> to children in school there. Answer as that person, not as a linguist writing
> for linguists.
>
> **Who hears this.** A four-year-old who cannot read yet, sitting about three
> metres from a television, often with poor speakers. Every entry below is read
> aloud by a synthetic voice and heard thousands of times. A child who learns a
> letter name wrongly here learns it wrongly for years, and no one notices,
> because the adult in the room is not listening.
>
> **The data was drafted from general knowledge and has never been checked by a
> speaker.** Assume it is wrong until you have read it. Being told "this is all
> fine" is worth nothing to me; being told which four entries are wrong is
> worth the whole exercise.
>
> **What the files contain.**
>
> - `letters_*.json` — one entry per letter. `display` is what appears on
>   screen; `spoken` is what the voice says. `spoken` must be the NAME of the
>   letter as recited in the alphabet, not its sound and not a description of
>   its shape. A name in square brackets in `display`, like `[CS]`, marks a
>   letter written with more than one character.
> - `numbers_*.json` — the words for 1 to 50, as a child counting aloud says
>   them, one at a time rather than inside a sentence.
> - `digraphs.json` — which multi-character sequences are letters of this
>   alphabet. The test is strict: does it have its own place in the alphabet, is
>   it recited as a letter, does a dictionary give it its own section? Not
>   merely one sound written with two characters. Hungarian CS qualifies;
>   English TH and German SCH do not.
>
> **Check these, in this order.**
>
> 1. **Wrong entries.** Any letter name or number word a speaker would not say.
>    Give the correct form and one line of why.
> 2. **The alphabet itself.** Letters missing, letters present that do not
>    belong, and the order. Say which letters a child is actually taught in
>    school, and whether foreign letters like Q, W, X, Y are taught as part of
>    the alphabet or as an appendix to it.
> 3. **Digraphs.** Whether the decision recorded for this language is right, by
>    the strict test above. If you change it, say what that means for how words
>    are spelled out letter by letter.
> 4. **Names that are hard to say alone.** Some letter names are a bare vowel,
>    or otherwise trail off when spoken in isolation, and a synthetic voice
>    reads those badly. List them — I record those between their alphabet
>    neighbours instead of alone.
> 5. **Confusable pairs.** Letters whose names sound nearly the same through a
>    television speaker at low volume, where a child could learn one for the
>    other.
> 6. **Numbers 11–19 and 21–49.** The joining word, the hyphens, the elisions
>    and any irregular form. This is where drafts are most often wrong, and
>    where a rule that works for 22 fails at 21.
> 7. **Regional and generational variants.** Where speakers differ, say which
>    to use for a young child and whether the other would be understood. Be
>    explicit about which variety the file is written in.
>
> **How to answer.**
>
> - A table of every change: file, entry, current value, corrected value, and a
>   one-line reason a non-speaker can follow.
> - Then the corrected JSON for each file, complete and valid, same structure
>   and key order. Change `spoken` values freely; change `display` or add and
>   remove letters only where the alphabet itself is wrong.
> - Then a short list of what you are unsure about, rather than guessing. Five
>   confident answers and one open question is far more useful to me than six
>   confident-sounding ones.
> - Leave correct entries alone and do not comment on them.
>
> **Do not** put pronunciation respellings, IPA or phonetic hints in `spoken`.
> It must be ordinary written <LANGUAGE> that a person could read aloud. There
> is a separate mechanism for phonetic overrides.
>
> If this language has an open question listed for it above, answer that first
> and explicitly.
