# Native-speaker review prompt

Paste the prompt below into a fresh conversation, replacing `<LANGUAGE>` and
`<LOCALE>`, and attach the files listed for that language. Use a fresh
conversation per language so nothing carries over from another one.

## Which files to attach

| File | What it holds |
|---|---|
| `data/speech/letters_<lang>.json` | Every letter of the alphabet and the name a speaker says for it |
| `data/speech/numbers_<lang>.json` | The words for 1–50 |
| `data/speech/digraphs.json` | Which two-character sequences count as letters, all languages in one file |

Add `data/number_forms.json` only if the language changes the form of a number
after a preposition like "to" — Slavic languages do, Spanish, Portuguese,
French and German do not.

Currently drafted and unreviewed: **es** (`es-ES`), **pt** (`pt-PT`),
**fr** (`fr-FR`), and the older **pl** (`pl-PL`), **sk** (`sk-SK`),
**de** (`de-DE`).

---

## The prompt

> You are reviewing language data for a children's educational game, as a
> native speaker of <LANGUAGE> (<LOCALE>). Answer as a native speaker would,
> not as a linguist writing for other linguists.
>
> **Who hears this.** A four-year-old who cannot read yet, sitting about three
> metres from a television, often with poor speakers. Every entry below will be
> read aloud by a synthetic voice and heard thousands of times. A child who
> learns a letter name wrongly here learns it wrongly for years, and nobody
> will notice, because the adult in the room is usually not listening.
>
> **What the files contain.**
>
> - `letters_*.json` — one entry per letter of the alphabet. `display` is what
>   appears on screen; `spoken` is what the voice says. `spoken` must be the
>   NAME of the letter as recited in the alphabet, not its sound and not a
>   description of its shape.
> - `numbers_*.json` — the words for 1 to 50, as a child counting aloud would
>   say them, one number at a time rather than inside a sentence.
> - `digraphs.json` — for each language, which multi-character sequences are
>   letters of that alphabet. The test is strict: is it a LETTER, listed in the
>   alphabet in its own right? Not merely one sound written with two
>   characters. Czech CH qualifies; German SCH and English TH do not.
>
> **What I need you to check, in this order.**
>
> 1. **Wrong entries.** Any letter name or number word a native speaker would
>    not say. Say what it should be and why.
> 2. **Regional variants.** Where speakers of different countries or
>    generations differ, say so and tell me which one to use for a young child,
>    and whether the other would be understood. Be explicit about which variety
>    this file is written in.
> 3. **Letters that are hard to say alone.** Some letter names are a bare vowel
>    or otherwise trail off when spoken in isolation, and a synthetic voice
>    reads those badly. List them — I record those between their alphabet
>    neighbours instead.
> 4. **Confusable pairs.** Letters whose names sound nearly identical over a
>    television speaker at low volume, where a child could learn one for the
>    other.
> 5. **Anything missing or surplus.** Letters absent from the list, or present
>    but not part of the alphabet.
> 6. **Number words 21–49.** The joining word, hyphenation and any irregular
>    forms. This is where drafts are most often wrong.
>
> **How to answer.**
>
> - A table of every change: file, entry, current value, corrected value, and a
>   one-line reason a non-speaker can follow.
> - Then the corrected JSON for each file, complete and valid, with the same
>   structure and key order. Change only `spoken` values unless a letter itself
>   is wrong.
> - Then a short list of anything you are unsure about, rather than guessing.
>   I would much rather have five confident answers and one open question than
>   six confident-sounding answers.
> - If an entry is already correct, leave it alone and do not comment on it.
>
> **Do not** add pronunciation respellings, IPA, or phonetic hints in the
> `spoken` field. It must be ordinary written <LANGUAGE> that a person could
> read aloud. I have a separate mechanism for phonetic overrides.
