# Replacing device TTS with optional pre-generated speech

Status: architecture and production analysis  
Research date: 2026-07-03  
Product baseline: `game_specification_v3.md`, reconciled with the current Godot 4.6 project

## Executive recommendation

ElevenLabs is suitable for this game, including all 21 currently supported languages, but no single older model covers all of them. Eleven v3 covers all 21. Eleven Flash v2.5 covers 20, with Hebrew missing. Eleven Multilingual v2 covers 17, with Hungarian, Norwegian, Vietnamese, and Hebrew missing.

The best first implementation is not to remove TTS. It is to introduce a unified speech service with three user choices:

1. `Off`
2. `Device voice` — the existing operating-system TTS behavior
3. `Studio voice` — use an approved pre-generated clip when one exists, otherwise fall back to device TTS

Existing installations should migrate to `Device voice`, so the update does not unexpectedly change behavior. `Studio voice` should initially be opt-in and can be available for only the languages whose recordings have passed native-speaker review.

For iteration 1, generate and bundle only high-value gameplay speech:

- numbers 1–50;
- every letter/character that can actually be collected;
- every complete vocabulary word or phrase, beginning with one or two pilot languages;
- optionally, complete-word prefixes spoken at spaces in the current solo-game behavior, but only after the core catalog is complete.

Keep help narration, settings previews, boot narration, and dynamically composed finish recaps on device TTS. They are longer, less frequently heard, and substantially more awkward to pre-render without combinatorial growth.

Bundle the approved clips with the app in iteration 1. The current local AAB is about 90 MiB. All 21 languages' high-value speech is estimated to add roughly 18–32 MiB at 22.05 kHz/32 kbps mono MP3, or roughly 27–40 MiB if the optional compound-prefix clips are also included. The resulting whole artifact would still be comfortably below even a conservative comparison with Google Play's 200 MB base-module limit and would give the strongest offline behavior. The actual pilot build must replace these estimates before committing to all 21 languages.

Even when clips are bundled initially, organize them as versioned per-language catalogs. This preserves a later migration to Play Asset Delivery or downloadable language packs without changing gameplay call sites.

The most important prerequisite is a content audit. The current project has alphabet-length and punctuation issues that should not be frozen into thousands of recordings:

- Letter mode is capped at 26 items even though Greek has 24 letters, Hebrew 22, and Ukrainian 33. Large Greek and Hebrew games repeat the final letter, while Ukrainian never reaches its final seven letters.
- Most Latin-script languages currently use plain A–Z rather than their real teaching alphabet.
- Word mode skips spaces only. Apostrophes and hyphens currently become collectible characters and are sent to TTS.
- The `pt` content contains both Portuguese and Brazilian vocabulary, while the UI deliberately shows both flags. English and Spanish also collapse regional variants to two-letter language codes. A recorded voice makes this unresolved accent/variant choice much more audible.

The raw ElevenLabs cost is not the limiting factor. The current high-value catalog is likely below about 55,000 input characters after adding localized number and letter names. At current API list prices, a clean pass is approximately USD 2.75 with Flash or USD 5.50 with Multilingual v2/v3, before prompt scaffolding, rejected takes, and QA reruns. Native review and content correction will cost much more time than synthesis.

## 1. Product constraints that drive the design

The v3 specification establishes the important constraints:

- children aged 4+, including pre-readers;
- Android phones, tablets, Android TV, and Google TV;
- low-powered devices and remote-first navigation;
- 21 UI and learning languages;
- UI language and learning language may differ;
- voice is instructional, not decorative: it teaches number and letter names and reinforces spelling;
- the game should remain usable when device TTS is absent or unreliable;
- play should be frustration-free and must never wait on a network request.

Those constraints rule out runtime ElevenLabs generation. The shipped app must never contain an ElevenLabs API key, must never call the synthesis API during gameplay, and must never require an Internet connection merely to speak the next collectible. ElevenLabs belongs in an offline production pipeline; only finished audio belongs in the game.

## 2. Current implementation and the real speech inventory

### 2.1 Current language and content sources

The current code supports these 21 concrete languages, plus the `auto` sentinel:

`en`, `es`, `fr`, `de`, `it`, `pt`, `pl`, `uk`, `nl`, `tr`, `ro`, `cs`, `hu`, `el`, `sv`, `da`, `fi`, `nb`, `sk`, `he`, `vi`.

The sets in `scripts/game_config.gd`, `project.godot`, the translation CSV, and the word filenames agree.

Current source inventory:

| Source | Current amount | Notes |
|---|---:|---|
| Translation keys | 398 × 21 locales | `data/translations.csv`; it contains quoted embedded newlines, so it must be parsed as real CSV, not line-by-line |
| Vocabulary files | 147 | 21 languages × difficulty 0–6 |
| Vocabulary entries | 3,654 | No exact duplicate word within a language |
| Full-word source characters | 29,804 | Unicode character count before pronunciation overrides |
| Entries containing spaces | 1,055 | These can trigger partial-prefix speech in solo mode |
| Distinct language/text prefixes | 1,583 | 1,466 require new audio after reusing prefixes equal to an existing whole word |
| Distinct whole words plus prefixes | 5,120 | Per-language deduplication |
| Long help texts | 14 × 21 = 294 | About 42,019 source characters |

The checked-in word-list README says difficulty 0–4, but the code and files use 0–6. The speech extractor must follow the runtime and validate all seven tiers.

### 2.2 What is spoken today

The present TTS system speaks more than the obvious collectibles:

| Category | Current behavior | Recommended first-release handling |
|---|---|---|
| Boot warm-up | Speaks the localized app title after the first successful OS voice scan | Keep TTS, but do not warm it up in Studio mode unless a fallback is needed |
| Settings preview | Speaks a localized language display name when UI language or voice state changes | Keep TTS |
| Numbers | Speaks raw values 1–50 in the learning language | Pre-generate; use localized written-out generation text, not bare digits |
| Letter mode | Speaks the collected character | Pre-generate after fixing alphabet rules |
| Word-mode characters | Speaks every collected character in the word language | Reuse the same per-language character clips |
| Solo phrase prefixes | After crossing a space, speaks the accumulated prefix such as “NEW” and later “NEW YORK” | P2; either generate later, leave on TTS, or intentionally remove/change the behavior |
| Completed word/phrase | Speaks the complete vocabulary entry | Pre-generate |
| Finish recap | Builds mixed-language, dynamically composed segmented narration | Keep TTS initially |
| Help | Speaks the body of 14 translated slides | Keep TTS initially |
| Multiplayer race marker | Uses a generated beep, not speech | Leave unchanged |

No current code speaks player names, win/gotcha titles, ordinary HUD goal text, or remote-controller goal text. The specification says the remote controller reads dynamic goal TTS speech, but the current join flow displays the goal and uses haptics without narrating it. That is a material specification/code discrepancy and should be treated as a separate future feature, not silently added to this audio project.

### 2.3 Existing TTS semantics that must be preserved

The current `TTS` autoload does useful work beyond calling `DisplayServer.tts_speak()`:

- it scans installed voices asynchronously;
- it maps the 21 product language codes to installed OS voices;
- the newest request interrupts and replaces older speech;
- it supports ordered segments for finish recaps;
- it uses category-specific rates;
- it avoids blocking the main game loop.

The new recorded-audio layer must preserve the “latest hint wins” behavior. A child collecting two items quickly should hear the newer item, not a backlog of stale speech. Only explicitly segmented narration, such as a future recap, should queue.

### 2.4 Material specification/code discrepancies

| Area | v3 specification | Current code/data | Consequence for this project |
|---|---|---|---|
| Help | Describes a 7-slide narrated tutorial | `help_menu.gd` contains 14 spoken slide bodies | Scope help as 14 × 21 if it is ever recorded; keep it on TTS initially |
| Alphabets | Says Latin, Greek, Hebrew, and Ukrainian layouts are fully supported | Spawning is capped at 26; only three non-Latin alphabets are explicit | Correct the curriculum source before recording |
| Remote controller | Says dynamic goals are read with TTS | Join flow displays goals and uses haptics, without narration | Do not include unimplemented remote-goal speech in the current catalog |
| Word separators | Says spaces are skipped | Exactly U+0020 is skipped; apostrophes and hyphens become pickups | Define separator/grapheme policy before extracting sounds |
| Difficulty documentation | Product has seven levels; runtime reads word tiers 0–6 | `data/words/README.md` still says 0–4 | Pipeline must validate 0–6 and the README should later be corrected |

The Godot 4.6 target, 21-language count, pre-reader audience, UI/learning language split, Android/Google TV focus, and device-TTS architecture otherwise agree with the baseline closely enough for this analysis.

## 3. Content corrections required before synthesis

Generating wrong educational content at scale would be worse than keeping variable TTS. These issues should be resolved first.

### 3.1 Define each teaching alphabet explicitly

`Config.get_alphabet_char()` currently has explicit strings only for Greek, Hebrew, and Ukrainian; all other languages fall back to A–Z. Letter-mode item count is always capped at 26.

Consequences:

- Greek has 24 letters, then repeats Ω for the final two slots on a sufficiently large maze.
- Hebrew has 22 letters, then repeats ת for the final four slots.
- Ukrainian has 33 letters, but only the first 26 can appear.
- Czech, Danish, Spanish, Finnish, French, Hungarian, Norwegian, Polish, Portuguese, Romanian, Slovak, Swedish, Turkish, Vietnamese, and other Latin-script languages do not have an explicit product decision for accented or additional letters.

Create one machine-readable alphabet definition per learning language. Runtime spawning and speech extraction must consume the same source. Each entry should include at least:

- stable character ID;
- display grapheme;
- order;
- localized letter name as generation text;
- optional pronunciation/IPA override;
- whether it is included in standalone Letter mode, Word mode, or both.

Do not infer a language's teaching alphabet by collecting every character found in its word lists. The word corpus is still valuable as a union check: it currently contains 642 language-specific letter characters and exposes characters that standalone alphabets may omit. After unioning the currently configured alphabets with actual word letters and excluding punctuation, there are approximately 697 language/character clips to cover.

### 3.2 Decide whether the game teaches letter names or phonemes

The current behavior effectively asks TTS to pronounce an isolated grapheme. For an educational product, this is underspecified. “The letter name” and “the sound this letter makes in this word” are not interchangeable, and phonemes are context-dependent.

The conservative first-release decision is:

- Letter mode and word-character pickups use the locale's conventional letter name.
- Completed words use natural word pronunciation.
- Contextual phonics are out of scope until the product has explicit curriculum rules.

Store `display_text` separately from `spoken_text`; never assume that sending the visible glyph is sufficient.

### 3.3 Resolve punctuation as a collectible

The current word spawner excludes only U+0020 spaces. At least 19 entries contain obvious ASCII apostrophes or hyphens, and Ukrainian also contains a modifier-letter apostrophe. Examples occur in French, Hebrew, Hungarian, Italian, Portuguese, Romanian, and Ukrainian.

Recommended rule:

- retain apostrophes and hyphens in the displayed word and whole-word recording;
- do not spawn them as collectible items;
- render them as fixed separators in the tracker;
- do not create “apostrophe” or “hyphen” voice clips unless a later curriculum explicitly teaches punctuation.

This needs an explicit allow/skip policy, not a simplistic Unicode `is_letter` test, because the Ukrainian modifier-letter apostrophe is categorized differently from ASCII punctuation.

### 3.4 Choose regional language variants

The current two-letter codes hide audible choices:

- `en` shows both UK and US flags;
- `es` shows Spain and Mexico;
- `pt` shows Portugal and Brazil, while its vocabulary currently mixes entries associated with both variants, such as `TREM`, `COMBOIO`, and `SUMO DE FRUTA`;
- `nb` means Norwegian Bokmål, whereas ElevenLabs documents generic Norwegian and its API language forcing uses `no`.

Before choosing voices, decide whether each of these is:

- one declared product variant, such as `en-GB`, `es-ES`, or `pt-PT`;
- deliberately region-neutral content with a chosen reference accent;
- or multiple separately downloadable variants.

For iteration 1, one declared reference variant per two-letter product code is simplest. Record the full BCP-47 locale in speech metadata even if the game continues to expose a two-letter selector.

### 3.5 Review the vocabulary before paying for audio

All current word strings are NFC-normalized and free from tabs, newlines, and non-breaking spaces, which is a good baseline. A native reviewer should still check vocabulary, spelling, capitalization, regional consistency, child appropriateness, and phrase naturalness before synthesis. Audio makes errors more expensive and more conspicuous.

## 4. ElevenLabs suitability

### 4.1 Language coverage

According to the current official [ElevenLabs model documentation](https://elevenlabs.io/docs/overview/models):

| Game locale | Language | Multilingual v2 | Flash v2.5 | Eleven v3 |
|---|---|---:|---:|---:|
| en | English | yes | yes | yes |
| cs | Czech | yes | yes | yes |
| de | German | yes | yes | yes |
| es | Spanish | yes | yes | yes |
| fr | French | yes | yes | yes |
| pt | Portuguese | yes | yes | yes |
| vi | Vietnamese | no | yes | yes |
| tr | Turkish | yes | yes | yes |
| it | Italian | yes | yes | yes |
| pl | Polish | yes | yes | yes |
| sv | Swedish | yes | yes | yes |
| nb | Norwegian Bokmål | no | yes* | yes* |
| nl | Dutch | yes | yes | yes |
| uk | Ukrainian | yes | yes | yes |
| fi | Finnish | yes | yes | yes |
| da | Danish | yes | yes | yes |
| hu | Hungarian | no | yes | yes |
| ro | Romanian | yes | yes | yes |
| el | Greek | yes | yes | yes |
| sk | Slovak | yes | yes | yes |
| he | Hebrew | no | no | yes |

`*` ElevenLabs documents generic Norwegian. Map the product's `nb` to API language code `no` when required, but validate Bokmål pronunciation and vocabulary with a native reviewer.

Coverage totals:

- Multilingual v2: 17/21;
- Flash v2.5: 20/21;
- Eleven v3: 21/21.

Do not use deprecated v1 TTS models. ElevenLabs currently says `eleven_monolingual_v1` and `eleven_multilingual_v1` are being removed on 2026-07-09; this pipeline should query model capability and pin only current model IDs.

### 4.2 Recommended model strategy

There is no benefit to forcing one model across every language. Runtime latency does not matter because synthesis happens offline.

Recommended starting matrix:

- Use Multilingual v2 as the quality/stability baseline for its 17 covered game languages.
- A/B-test Flash v2.5 against Eleven v3 for Hungarian, Norwegian, and Vietnamese.
- Use Eleven v3 for Hebrew, then accept the language only after native review.
- Also A/B-test v3 for any language or short utterance where Multilingual v2 fails pronunciation.

Reasons:

- ElevenLabs describes Multilingual v2 as its stable, natural multilingual model.
- Flash is half the current per-character API price and is designed for bulk/interactive use, but its number normalization is weaker.
- v3 has the widest coverage and native IPA support across 70+ languages, but ElevenLabs also describes it as more variable in consistency. That matters for isolated letters and short words.

Always spell number generation text out in the target locale instead of sending `"17"`. The [ElevenLabs TTS best-practices guide](https://elevenlabs.io/docs/overview/capabilities/text-to-speech/best-practices) specifically warns that smaller Flash models can normalize numbers incorrectly. This pipeline knows the intended cardinal reading, so it should not delegate that decision to a model.

For Flash and v3, pass the supported ISO 639-1 `language_code` to the [create-speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert). The API documentation says `language_code` is not supported by Multilingual v2, so model selection and a language-trained voice are especially important there.

### 4.3 Pronunciation control

The required hierarchy is:

1. curated locale-specific `spoken_text`;
2. a voice trained in or selected for the target language/accent;
3. pronunciation alias or dictionary rule for exceptions;
4. v3 IPA for stubborn cases;
5. native-speaker approval of the resulting audio.

Eleven v3 accepts IPA wrapped in slashes across its supported languages, but ElevenLabs documents only 80–90% pronunciation consistency. It is a useful control, not a substitute for listening.

Pronunciation dictionaries can be versioned and referenced by the API. Store dictionary ID and version in every affected generation record. Alias substitutions are the portable fallback for models that do not support non-English phoneme behavior. The official [pronunciation dictionary guide](https://elevenlabs.io/docs/eleven-api/guides/how-to/text-to-speech/pronunciation-dictionaries) documents up to three dictionary locators per request.

Single characters are a special risk. An A/B pilot should compare:

- one request per character, using explicit letter-name `spoken_text` or IPA;
- one longer, carefully paced “recording sheet” per locale/category using the [with-timestamps endpoint](https://elevenlabs.io/docs/api-reference/text-to-speech/convert-with-timestamps), then splitting clips from returned alignment.

The default pipeline should remain one logical clip per request because it makes review, regeneration, caching, and replacement safer. Recording sheets should be an opt-in workaround only if a model produces poor isolated-token prosody; splitting must be verified for bleed, pauses, and encoder boundaries.

### 4.4 Voice selection

Prefer a warm, calm, adult educational voice for each locale. A consistent character and energy across languages is more valuable than forcing one identical voice with a foreign accent across all 21.

Official ElevenLabs guidance says all voices can be used across supported languages, but a voice trained for the target language/accent gives the most natural result. Therefore:

- choose and QA per locale;
- keep pace and perceived age consistent across the voice family;
- avoid an overly dramatic character voice for isolated educational items;
- avoid cloning a child's voice;
- record voice ID, model, full locale, settings, and best-effort seed.

For long-term continuity, prefer an owned Voice Design voice, an appropriately licensed owned clone, or one of the new default voices ElevenLabs says will remain available in perpetuity. Community Voice Library owners can withdraw future access, sometimes immediately if they chose no notice period. Already generated paid outputs remain usable, but a removed voice makes later vocabulary additions sound different. The current [Voice Library documentation](https://elevenlabs.io/docs/eleven-creative/voices/voice-library) and [voice overview](https://elevenlabs.io/docs/overview/capabilities/voices) should be rechecked when selecting production voices; older default voices are currently scheduled to expire on 2026-12-31.

### 4.5 Commercial use and offline redistribution

This is a product/technical reading, not legal advice.

ElevenLabs currently states that:

- output generated during a paid subscription may be used commercially and indefinitely;
- free-plan output is not appropriate for this commercial game and has attribution restrictions;
- beta-service output cannot be used commercially or in production;
- downloaded output may be used outside the service, subject to the terms and prohibited-use policy;
- paid generated TTS does not require playback-time API calls.

That makes bundling paid, non-beta generated speech in the game for offline playback appear suitable. Use a paid plan, preserve invoices/subscription evidence, and keep an immutable generation ledger for every shipped clip. Relevant official references are [Can I publish generated content?](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform), the [EEA terms](https://elevenlabs.io/terms-of-use-eu), and the [Voice Library Addendum](https://elevenlabs.io/vla).

Recheck the terms, model status, selected voice status, and pricing immediately before the production generation run. They are changing quickly.

## 5. Scope and priorities

### 5.1 Proposed priority tiers

| Priority | Content | Approximate current scope | Release policy |
|---|---|---:|---|
| P0 | Numbers 1–50 | 1,050 locale/number clips | Required for a language marked Studio-complete |
| P0 | Collectible characters | About 697 after alphabet/word union and punctuation resolution | Required |
| P1 | Complete words/phrases | 3,654 | Required by selected difficulty tiers; generate easier tiers first during rollout |
| P2 | Solo accumulated prefixes at spaces | 1,583 semantic clips; about 1,466 new audio assets after reuse | Optional; TTS fallback or behavior change is acceptable initially |
| P3 | Finish recap framing | Dynamic templates and mixed-language compositions | Device TTS initially |
| P4 | Help, boot title, language preview | 294 long help clips plus small UI items | Device TTS initially |

P0 + P1 is approximately 5,401 semantic recordings with the corrected character union. P2 raises the unique audio-spec count to roughly 6,867 after reusing identical whole-word audio.

### 5.2 Language rollout order

Do not generate all 21 languages before proving the pipeline and runtime integration.

Recommended rollout:

1. one Latin-script pilot with a readily available native reviewer;
2. one non-English pilot with diacritics;
3. one non-Latin script;
4. Vietnamese, because its word corpus currently contains 72 distinct letters/diacritics;
5. Hebrew with v3;
6. remaining languages in product/market priority order.

English and Czech would be practical initial pilots if they match business priorities and native review is available, but the pipeline must not hardcode that assumption.

Within a language, generate in this order:

1. numbers;
2. standalone alphabet and word-mode character union;
3. vocabulary difficulty 0;
4. difficulties 1–6;
5. optional phrase prefixes.

This makes partial Studio coverage useful early while keeping the coverage report honest.

## 6. Runtime architecture in Godot

### 6.1 Introduce one speech broker

Direct calls to `TTS.speak()` currently exist in solo gameplay, multiplayer gameplay, help, settings, and finish recap. Adding recorded playback separately at each call site would create inconsistent fallback and missed behavior.

Introduce a `SpeechManager` autoload as the only application-facing speech API. Keep the current `TTS` singleton as its device-TTS backend during the first refactor.

Conceptual API:

```gdscript
Speech.speak_key(
    "learning.number.12",
    "cs",
    "12", # TTS fallback text
    {"interrupt": true, "rate": 0.85}
)
```

For words:

```gdscript
Speech.speak_key(
    "learning.word.apple.full",
    "en",
    "APPLE",
    {"interrupt": true, "rate": 0.70}
)
```

Resolution order in `Studio voice` mode:

```text
approved recorded clip for exact semantic key and language
    -> device TTS using existing text/rate/language behavior
        -> silence plus a diagnostic/status signal
```

The maze must never pause or wait for speech.

### 6.2 Settings model

Replace the current persisted `voice_hints: bool` with an enum-like value:

- `OFF`
- `DEVICE_TTS`
- `STUDIO_PREFERRED`

Migration:

- existing `voice_hints = false` → `OFF`;
- existing `voice_hints = true` → `DEVICE_TTS`;
- no automatic network download and no silent default change.

The current settings screen disables voice hints unless both UI and learning languages have installed OS voices. That rule must change. Studio gameplay may be available for the learning language even when UI/help TTS is absent. Availability should be reported separately:

- Studio gameplay coverage for the selected learning language;
- device TTS availability for learning fallback;
- device TTS availability for UI/help narration;
- optional pack download state if dynamic delivery is added later.

Parent-facing text can call the option “Studio voice” or “Natural voice”; the technical fact that it was AI-generated belongs in documentation/privacy information, not necessarily in a child's primary selector label.

### 6.3 Playback behavior

Use one always-alive, non-positional `AudioStreamPlayer` on a dedicated `Voice` audio bus:

- `max_polyphony = 1`;
- a new ordinary hint stops the previous clip;
- only explicit multi-segment requests queue;
- no looping;
- prefetch the next expected collectible and the current round's completed word;
- keep only a small 8–32 clip LRU if manual caching proves useful;
- do not preload a language or all languages into RAM.

There is no existing dedicated audio bus or prerecorded-audio system. A `Voice` bus allows independent hint volume, mute, and future music ducking.

Godot notes that audio starts on the next audio-thread mix chunk and TV processing can add output latency. Remove source/encoder leading silence, prefetch predictable clips, and measure pickup-to-audible onset on the oldest target Chromecast/TV. Do not promise zero latency.

### 6.4 Semantic keys, not filenames or raw text

Examples:

- `learning.number.001`
- `learning.char.u0041`
- `learning.word.apple.full`
- `learning.word.good_night.prefix.2`
- `ui.help.help_card_01_text`

The manifest is already namespaced by language, so the English and Czech pronunciations of U+0041 resolve to different audio. Keep content kind in the key; an English letter “A” should not accidentally alias the spoken article “a” unless the generation specifications are deliberately identical and approved.

Do not use visible Unicode or localized text directly as a filename. Use a safe content hash for the file and keep human-readable text in the manifest.

The current word JSON records have only `word` and `emoji`. Add a stable immutable `id` to make word keys survive spelling corrections. Optional fields should include `spoken_text` and a pronunciation reference. For a no-schema-change pilot, derive an ID from normalized language + text, understanding that a text correction creates a new identity.

### 6.5 Per-language runtime manifest

Illustrative authoring/runtime record:

```json
{
  "key": "learning.number.012",
  "lang": "en",
  "locale": "en-GB",
  "category": "number",
  "priority": 0,
  "display_text": "12",
  "spoken_text": "twelve",
  "asset": "clips/7f/7f47f13c9f2a.mp3",
  "duration_ms": 724,
  "codec": "mp3",
  "sample_rate": 22050,
  "channels": 1,
  "bitrate_kbps": 32,
  "sha256": "...",
  "generation_spec_hash": "...",
  "review_status": "approved"
}
```

Pack-level metadata should include:

- schema version;
- pack ID and pack version;
- language and full locale;
- minimum app/catalog version;
- voice profile/version;
- item counts by priority and category;
- total bytes;
- pack hash/signature if downloaded;
- coverage state.

Runtime manifests should contain only approved outputs. Draft/rejected status and provider request metadata belong in the production ledger, not the shipped game.

## 7. Audio format, quality, and size

### 7.1 Recommended production format

Recommended master/archive:

- ElevenLabs `pcm_22050`, 16-bit mono, where the chosen paid tier/model permits it;
- keep masters and request metadata outside exported Godot resources;
- trim, level, and QA the PCM before one lossy encode.

Recommended shipped format:

- individual mono MP3 files;
- 22.05 kHz;
- 32 kbps as the first candidate;
- no loop;
- measured duration stored in the manifest.

Why MP3:

- Godot 4.6 supports imported and runtime-loaded MP3 directly;
- Godot's own audio guidance says voice can generally be mono and around 22 kHz;
- only one voice clip plays at once, so compressed decoding is low-risk even on weak hardware;
- MP3 has low per-file/container overhead for thousands of small clips;
- ElevenLabs offers `mp3_22050_32` directly if the pipeline needs a simpler fallback;
- individual clips permit exact replacement and QA without seek-boundary/audio-sprite problems.

Quality gate:

- A/B 22.05 kHz/32 kbps against 44.1 kHz/64 kbps on a phone, the oldest target Chromecast/Google TV, and poor television speakers.
- Pay particular attention to sibilants, final consonants, Vietnamese tones, short Hebrew/Greek/Ukrainian letter names, and encoder onset.
- If 32 kbps audibly fails, move the whole catalog to 44.1 kHz/64 kbps or use a manifest-supported higher-quality exception only after confirming that mixed encodings do not complicate maintenance.

Do not ship WAV; it wastes storage. Do not ship ElevenLabs Opus output unless Godot support changes: Godot 4.6's runtime loader supports Ogg Vorbis, not arbitrary Ogg Opus. Ogg Vorbis remains a technically valid alternative, but for this specific catalog MP3's small-file behavior, direct support, and lower implementation risk are preferable.

Official references: [ElevenLabs output formats](https://help.elevenlabs.io/hc/en-us/articles/15754340124305-What-audio-formats-do-you-support), [Godot audio import guidance](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_audio_samples.html), and [Godot runtime audio loading](https://docs.godotengine.org/en/4.6/tutorials/io/runtime_file_loading_and_saving.html).

### 7.2 Post-processing targets

Use the same deterministic processing chain for every clip:

1. decode/read PCM master;
2. trim excessive leading and trailing silence without removing soft consonants;
3. add a very short fade to prevent clicks;
4. normalize the voice family consistently, initially testing approximately -18 to -16 LUFS with true peak no higher than -1 dBTP;
5. encode mono MP3;
6. measure actual duration, loudness, peaks, sample rate, channels, and hash;
7. reject clips outside limits.

Short utterances make integrated loudness measurements unstable, so use one consistent batch policy and listening tests rather than independently maximizing every clip. The goal is consistent perceived level, not maximum loudness.

### 7.3 Size estimate

The basic payload formula is:

```text
bytes = bitrate_bits_per_second × total_seconds / 8
```

One hour is approximately:

- 14.4 MB at 32 kbps;
- 28.8 MB at 64 kbps.

A conservative corpus model using about 0.9 s per full word/phrase, 0.7 s per number, and 0.55 s per character produces roughly 72–74 minutes for P0 + P1. At 32 kbps, audio payload is about 17 MiB; several thousand MP3/container/archive entries add several more MiB. Hence the practical estimate of 18–32 MiB. Optional phrase prefixes may add roughly another 9 MiB centrally.

These are planning estimates only. The pilot report must record:

- total generated seconds;
- final compressed bytes by language/category;
- Godot import/export overhead;
- final AAB/APK delta;
- on-device installed-size delta;
- peak runtime memory during rapid playback.

## 8. Bundling versus dynamic language packs

### 8.1 Recommendation for iteration 1: bundle the clips

The workspace currently contains an approximately 90 MiB AAB and 118 MiB APK. They may not exactly match the live store build, so treat them as local baselines. The AAB already places Godot resources in an install-time asset module, and `export_presets.cfg` exports all resources. Adding final clips under `res://` will therefore bundle them and keep them offline.

Google Play currently permits a 200 MB compressed base module and supports larger games through asset delivery; it evaluates the base, generated splits, and asset packs separately. An estimated 110–130 MiB total AAB is still comfortably small by either a conservative whole-artifact comparison or the actual module rules. More importantly, bundling avoids:

- download UI and child/parent consent flow;
- pack availability races after app updates;
- missing Play Store support on sideloaded TV devices;
- an Android plugin and Gradle asset-pack maintenance;
- a CDN, signing, and pack-update service;
- first-play failure with no network.

Iteration 1 should therefore bundle its approved pilot languages. After all-language audio exists, bundle all P0/P1 languages if the measured increase remains around 30 MiB and the final AAB has comfortable headroom. Do not bundle long help narration merely because the 200 MB limit allows it.

### 8.2 Keep a per-language pack boundary anyway

Suggested bundled layout:

```text
res://voices/
  en/
    manifest.json
    clips/...
  cs/
    manifest.json
    clips/...
```

The resolver should load only the selected learning language's manifest and clips. This does not save installation storage when everything is bundled, but it keeps RAM low and allows the same logical catalog to become an external pack later.

### 8.3 If dynamic delivery becomes worthwhile

Trigger a delivery redesign if measured speech grows beyond the agreed storage budget, the full build approaches store limits, or additional narrated content materially expands the corpus.

#### Google Play Asset Delivery

For the Android/Google TV baseline, use one on-demand pack per language, not fast-follow:

- on-demand downloads only the language the user selected;
- fast-follow would eventually download every language and defeat the storage goal;
- once downloaded, playback is offline;
- Google Play hosts, patches, and serves the packs;
- sounds are valid PAD assets.

PAD is feasible but not turnkey in this Godot project. It requires Gradle asset-pack modules and a Godot Android plugin wrapping `AssetPackManager`. The app must query pack location every launch, treat pack contents as read-only, handle cancellation and deletion, and fall back to TTS while a pack is absent or being updated. Real delivery must be tested through Play's bundle/internal-sharing flow; a standalone APK cannot faithfully test it.

The [Play Asset Delivery documentation](https://developer.android.com/guide/playcore/asset-delivery) describes install-time, fast-follow, and on-demand behavior. It also warns that fast-follow/on-demand paths can move or disappear and that packs can be temporarily unavailable after an app update.

A language pack can contain a versioned Godot PCK, mounted with `ProjectSettings.load_resource_pack()`. Godot does not provide an unload API, so do not delete or replace a mounted pack during the same process. Relevant references are [exporting PCKs](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_pcks.html) and [Godot Android plugins](https://docs.godotengine.org/en/4.6/tutorials/platform/android/android_plugin.html).

#### Self-hosted packs

A signed/versioned PCK or ZIP downloaded to `user://voice_packs/` is the cross-platform alternative. It works on Android, iOS, and non-Play distribution and permits audio updates independently of a store release, but adds CDN, security, integrity, compatibility, bandwidth, retention, and privacy-policy responsibilities.

If used:

- download to `.part`;
- verify expected byte count and SHA-256 plus a signed manifest;
- atomically rename only after validation;
- retain the previous known-good version until the new one mounts successfully;
- use persistent app storage, not evictable cache;
- never execute code from a voice pack;
- show size and require an explicit download action;
- continue offline after download;
- fall back to device TTS when unavailable.

For the currently estimated 20–30 MiB total core catalog, this is not justified in iteration 1.

## 9. Repeatable inventory and generation pipeline

### 9.1 Principle: extraction and generation must be separate

Running an inventory script must never spend ElevenLabs credits. Use distinct stages:

```text
source validation
  -> desired inventory
    -> missing/stale plan and cost report
      -> explicit generation command
        -> processing and QA
          -> approved runtime packs
```

### 9.2 Proposed source files

```text
data/speech/
  catalog.json          # categories, priority, fallback, number range, explicit translation keys
  alphabets.json        # shared runtime/build alphabet and spoken-name definitions
  voice_profiles.json   # voice/model/settings by locale; no API key
  pronunciations/       # human-reviewed spoken text / IPA / provider dictionary references

tools/speech/
  speech_pipeline.py
  requirements.txt

build/speech/           # ignored build output
  desired.jsonl
  plan.json
  review.csv
  reports/

voice_masters/          # outside exported resources or hidden by .gdignore
  raw/
  processed/
  generation_ledger.jsonl

voices/                 # final pack source only
  <lang>/manifest.json
  <lang>/clips/...
```

The exact paths can change, but generated masters and provider metadata must not accidentally enter the AAB.

### 9.3 Declarative catalog rules

Do not attempt to discover speech solely by regex-scanning `TTS.speak()` calls. Dynamic strings, templates, and runtime conditions make that unreliable.

`catalog.json` should explicitly define:

- numbers 1–50;
- the shared alphabet source;
- union of allowed collectible word graphemes;
- full entries from every `words_<lang>_<difficulty>.json`;
- optional prefix generation policy;
- an explicit allowlist of help or recap translation keys if those tiers are later enabled;
- priority and fallback policy for each category.

All gameplay code should eventually call typed `SpeechManager` categories. CI can then reject new direct `TTS.speak()` calls outside the TTS backend and tests.

### 9.4 Extractor

`speech_pipeline.py extract` should:

1. parse `data/translations.csv` with an RFC-4180-capable CSV parser;
2. compare language sets across Config, project translations, CSV headers, alphabets, voice profiles, and word filenames;
3. require all 21 × 7 word files unless a deliberate catalog change says otherwise;
4. normalize source text to NFC and canonical whitespace;
5. validate stable IDs and duplicate IDs/text;
6. enforce punctuation/grapheme policy;
7. enumerate numbers, characters, full words, and optional prefixes;
8. attach source references, category, priority, difficulty, display text, and generation text;
9. emit deterministically sorted `desired.jsonl`.

JSONL is preferable for the desired/generation ledger because it is append-friendly, streamable, diffable, and easy to resume. A compact per-language JSON object is better for runtime lookup.

### 9.5 Generation specification hash

Each desired record needs a hash of canonical JSON containing every input that can affect audio:

- normalized `spoken_text` or exact prompted text;
- product language and full generation locale;
- provider;
- model ID;
- voice ID/version;
- language code sent to the API;
- all voice settings;
- best-effort seed;
- pronunciation dictionary IDs and versions;
- output/master format;
- pipeline processing version.

```text
generation_spec_hash = SHA-256(canonical_generation_spec_json)
```

Changing a word, voice, model, pronunciation, bitrate, or processing algorithm automatically marks the old asset stale. Multiple semantic keys may point to one content-addressed asset only when the complete generation spec hash is identical.

### 9.6 Planner

`speech_pipeline.py plan` compares desired records with the ledger, files, runtime manifests, and hashes. It should emit:

- missing;
- stale;
- invalid/corrupt;
- generated but not reviewed;
- rejected;
- approved;
- orphaned assets;
- counts and characters by language/model/category/priority;
- estimated synthesis cost;
- estimated output duration and size.

Required filters:

- `--language`;
- `--priority`;
- `--category`;
- `--max-characters` or cost guard;
- `--dry-run`;
- `--check` for CI.

No network call occurs in `extract`, `plan`, `coverage`, or `verify`.

### 9.7 Generator

`speech_pipeline.py generate` should:

- require a scoped TTS-only API key from environment/secret storage;
- never accept or write the key into a project file;
- process only missing/stale selected records;
- default to one logical clip per request;
- use bounded concurrency below the account tier's limit;
- back off with jitter for 429 and transient 5xx responses;
- save response/request/history ID and billed-character metadata;
- write output to a temporary path;
- validate that an audio response is decodable and non-empty;
- atomically move it into the content-addressed cache;
- update the ledger only after durable success;
- never overwrite an approved output in place.

ElevenLabs' current TTS concurrency limits vary by plan. Read them from configuration rather than maximizing parallel requests. There is no bulk endpoint that makes characters free. Batching unrelated words complicates QA and regeneration and should not be the default.

The website's free-regeneration feature does not apply to API calls. The official [quota article](https://help.elevenlabs.io/hc/en-us/articles/13313274666769-Do-I-use-quota-on-every-generation) explicitly limits free regenerations to the website. Budget every API rerun.

### 9.8 Processor and verifier

Use `ffmpeg`/`ffprobe` or equivalent deterministic tooling for:

- trim/fade;
- loudness and true-peak checks;
- mono conversion and sample-rate validation;
- MP3 encoding;
- duration measurement;
- decode test;
- waveform/silence statistics.

`verify` should fail if:

- a language declared Studio-complete lacks P0/P1 keys;
- a manifest points to a missing or wrong-hash file;
- a clip is stereo, wrong rate/codec, silent, clipped, or implausibly long/short;
- source hashes no longer match current content;
- a runtime manifest contains unapproved output;
- a new direct gameplay TTS call bypasses `SpeechManager`.

## 10. Credit and cost efficiency

Current [ElevenAPI pricing](https://elevenlabs.io/pricing/api), which must be rechecked before generation, is approximately:

- Flash/Turbo: USD 0.05 per 1,000 characters;
- Multilingual v2/v3: USD 0.10 per 1,000 characters.

Current corpus facts:

- complete word/phrase text: 29,804 characters;
- whole words plus deduplicated prefix assets: about 41,065 characters;
- number display strings 1–50 across 21 languages: 1,911 characters, although correct written-out `spoken_text` will be longer;
- corrected letter-name generation text will also be longer than the visible 697 graphemes.

A reasonable high-value one-pass estimate is below about 55,000 generation characters:

- roughly USD 2.75 if all could use Flash;
- roughly USD 5.50 if all used Multilingual v2/v3;
- realistically a small mixed amount between those values before retries and prompt scaffolding.

Cost controls that matter:

- validate text before generating;
- content-address every complete generation specification;
- run dry-run cost reports;
- impose per-run character/cost caps;
- generate by priority and language;
- never regenerate an approved unchanged asset;
- use the smallest API concurrency that finishes comfortably;
- keep raw masters so changing the shipping bitrate does not require resynthesis;
- preserve rejected outputs and notes so the same bad setup is not repeated;
- regenerate only the failed logical clip, not a concatenated batch;
- separate synthesis changes from audio-encoding changes.

Because synthesis is cheap at this corpus size, do not sacrifice educational correctness to save a few dollars. A native reviewer rejecting one systematic mistake before a 21-language run is the largest real saving.

## 11. Quality assurance

### 11.1 Automated checks

For every clip:

- file exists and SHA-256 matches;
- decoder can read it;
- mono, expected sample rate/codec/bitrate;
- duration within category bounds;
- no digital clipping;
- acceptable leading/trailing silence;
- plausible loudness/peak;
- no unexpected extra speech where automated alignment or transcription can detect it.

Automatic speech recognition may catch omitted or additional words, but it cannot certify an isolated letter name, accent, tone, or child-appropriate delivery.

### 11.2 Human native-speaker review

Every language needs a reviewer for P0/P1. Review should record:

- correct letter name, including diacritics;
- correct cardinal number;
- correct word/phrase pronunciation;
- expected regional accent and vocabulary;
- no English-language bleed or spelling-out mistake;
- consistent voice identity, warmth, pace, and energy;
- clean beginning/end without lost consonants;
- comfortable level against game sounds;
- pass/reject/notes/reviewer/date.

For alphabet and number sets, require a second focused review because a systematic error affects many game sessions.

### 11.3 Device/game tests

Test at least:

- oldest supported Chromecast/Google TV class device;
- low-end Android phone/tablet;
- current phone;
- a device without the selected OS TTS voice;
- device fully offline;
- UI and learning languages different;
- rapid consecutive pickups and interruption;
- app pause/resume and scene changes;
- corrupted/missing manifest in a development build;
- language changes before and during a session;
- Studio language available, partially available, and absent;
- AAB install/update storage behavior.

Measure audible onset latency, memory, frame time, and build/install size rather than relying only on desktop playback.

## 12. Suggested implementation phases

### Phase 0 — content decisions and corrections

- choose reference regional variants;
- decide letter names versus phonics;
- create shared alphabet data and fix length handling;
- decide punctuation behavior;
- decide whether solo accumulated-prefix speech remains;
- add stable IDs to vocabulary entries or approve a temporary hash-ID strategy;
- arrange native reviewers.

Exit criterion: extractor can enumerate a correct, reviewable desired catalog without calling ElevenLabs.

### Phase 1 — inventory and pipeline, no runtime change

- create declarative catalog, alphabets, voice profiles, and pronunciation overrides;
- implement `extract`, `plan`, `coverage`, and `verify`;
- produce a dry-run report for all 21 languages;
- select pilot language(s), voices, models, and settings;
- generate small representative A/B samples only.

Representative sample per pilot language:

- 10 numbers including teens/tens;
- 10 common and difficult letters;
- accented letters;
- 10 short words;
- 5 long words;
- 5 multi-word phrases;
- punctuation-containing display phrases;
- at least one deliberately difficult pronunciation.

Exit criterion: native reviewers approve a voice/model/settings profile and the device codec test.

### Phase 2 — bundled pilot and hybrid runtime

- implement `SpeechManager` and the settings migration;
- add the dedicated Voice bus/player;
- route all existing TTS call sites through the broker;
- bundle approved P0/P1 audio for pilot languages;
- preserve TTS fallback for every missing key/category/language;
- suppress unnecessary OS TTS warm-up in Studio mode;
- add offline, interruption, and coverage tests.

Exit criterion: pilot language gameplay works fully offline with recorded numbers, characters, and full words; unsupported languages behave exactly as before through TTS.

### Phase 3 — production rollout

- generate languages in reviewed batches;
- publish coverage/size/cost reports;
- native-review every P0/P1 clip;
- bundle approved packs;
- measure final AAB and installed size;
- update store/privacy/support material if needed.

Exit criterion: every language advertised as Studio-capable has complete approved P0/P1 coverage and deterministic fallback.

### Phase 4 — optional expansion

- decide P2 phrase-prefix behavior;
- consider recorded recap framing only after a mixed-audio queue design;
- consider long help narration only if user research justifies the size/review cost;
- add PAD/self-hosted packs only if measured storage or update needs justify them.

## 13. Acceptance criteria for the first shipped iteration

- Device TTS remains available and is the migration default.
- Studio voice can be enabled independently.
- Studio voice may support only declared languages without disabling TTS for the rest.
- Gameplay never calls ElevenLabs and contains no ElevenLabs secret.
- A supported Studio language plays approved prerecorded numbers, collectible characters, and completed words/phrases offline.
- Missing/unapproved clips fall back to the correct device TTS language and rate.
- A new request interrupts an obsolete hint.
- Help and dynamic recaps still use device TTS.
- All shipped clips have generation, licensing, hash, processing, and human-review records.
- CI detects new or changed source content and reports missing/stale audio without spending credits.
- The AAB/install-size delta and playback latency are measured on target hardware.

## 14. Decisions still needed from the product owner

These are the important questions not fully determined by the current product or code:

1. Which reference variants should `en`, `es`, and `pt` use? Is `nb` explicitly Bokmål?
2. Should Letter/Word pickups teach conventional letter names only, or eventually phonics?
3. Should apostrophes/hyphens remain visible but non-collectible?
4. Should the current solo accumulated-prefix narration remain, change to the just-completed lexical word, or be removed?
5. Which languages are pilot and launch priorities?
6. Who can provide native-speaker educational review for each language?
7. Is one voice persona per language acceptable, or is one cross-language brand voice a hard requirement?
8. Should Studio voice remain opt-in forever, or become the default for new installations after QA?
9. What maximum AAB and installed-size increase is acceptable?
10. Is Google Play/Android the only dynamic-delivery target, or must future iOS/non-Play builds share the same downloadable packs?
11. May recorded packs update only with app releases, or is independent content updating a requirement?
12. Should parents see an explicit “AI-generated voice” label in settings/store material?

None of these blocks building the extraction and dry-run planning tooling, but regional variant, alphabet, punctuation, letter-name, and prefix decisions should be settled before full synthesis.

## 15. Final decision summary

- Use ElevenLabs as an offline production service, never a gameplay dependency.
- Preserve TTS and add `Studio preferred` with per-item fallback.
- Use Multilingual v2 where it passes native QA, A/B Flash/v3 for Hungarian/Norwegian/Vietnamese, and v3 for Hebrew.
- Select a native/accent-appropriate educational voice per locale and preserve voice/provider licensing evidence.
- Fix alphabet lengths, locale alphabets, punctuation, and regional language variants before generation.
- Generate P0 numbers/characters and P1 complete words first; keep long help and dynamic recaps on TTS.
- Ship individual 22.05 kHz/32 kbps mono MP3 clips after PCM-based processing and device A/B tests; move to 44.1 kHz/64 kbps only if the quality gate requires it.
- Bundle pilot and likely all core-language audio in iteration 1; defer on-demand delivery until measured size justifies it.
- Organize everything behind semantic keys and per-language versioned manifests so bundling can later become PAD or downloadable PCK packs.
- Build an idempotent extraction/plan/generate/process/verify pipeline with content hashes, dry-run cost reporting, scoped secrets, and native-speaker approval.

## 16. Primary external references

ElevenLabs:

- [Models and supported languages](https://elevenlabs.io/docs/overview/models)
- [Text-to-Speech overview, voice and output guidance](https://elevenlabs.io/docs/overview/capabilities/text-to-speech)
- [Create speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert)
- [Create speech with timestamps](https://elevenlabs.io/docs/api-reference/text-to-speech/convert-with-timestamps)
- [TTS best practices and pronunciation](https://elevenlabs.io/docs/overview/capabilities/text-to-speech/best-practices)
- [Pronunciation dictionaries](https://elevenlabs.io/docs/eleven-api/guides/how-to/text-to-speech/pronunciation-dictionaries)
- [API pricing](https://elevenlabs.io/pricing/api)
- [TTS concurrency limits](https://help.elevenlabs.io/hc/en-us/articles/14312733311761-How-many-Text-to-Speech-requests-can-I-make-and-can-I-increase-it)
- [API versus website regeneration charging](https://help.elevenlabs.io/hc/en-us/articles/13313274666769-Do-I-use-quota-on-every-generation)
- [Voice Library availability and notice periods](https://elevenlabs.io/docs/eleven-creative/voices/voice-library)
- [Commercial publishing guidance](https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform)
- [EEA terms](https://elevenlabs.io/terms-of-use-eu)

Godot/Android:

- [Godot 4.6 importing audio samples](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_audio_samples.html)
- [Godot runtime audio loading](https://docs.godotengine.org/en/4.6/tutorials/io/runtime_file_loading_and_saving.html)
- [Godot AudioStreamMP3](https://docs.godotengine.org/en/4.6/classes/class_audiostreammp3.html)
- [Godot PCK export and mounting](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_pcks.html)
- [Godot Android plugins](https://docs.godotengine.org/en/4.6/tutorials/platform/android/android_plugin.html)
- [Google Play Asset Delivery](https://developer.android.com/guide/playcore/asset-delivery)
- [Android App Bundle size limits](https://developer.android.com/guide/app-bundle/faq)
