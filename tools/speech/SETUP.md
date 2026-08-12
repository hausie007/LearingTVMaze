# ElevenLabs setup — account, key, and choosing a voice

Written for someone who has never used ElevenLabs. Everything here happens
**outside** the game: the app never calls a speech API, never contains a key, and
works offline. See `_ideas_/studio_voice_iteration_1_design.md` for why.

Figures checked 2026-08-12 against <https://elevenlabs.io/pricing/api>. Recheck
before you pay for anything.

---

## 1. How much this actually costs

Iteration 1 is **1,103 characters of speech in total** — 607 Czech, 496 English.
That is not a typo. Letter names and the numbers one to fifty are short.

| | |
|---|---|
| List price, Multilingual v2/v3 | $0.10 per 1,000 characters |
| List price, Flash/Turbo | $0.05 per 1,000 characters |
| Iteration 1, one clean pass | **about 11 cents** |
| Iteration 1 with twenty retakes of everything | still under $3 |
| All 21 languages, numbers and letters | roughly $0.60–1.20 |

So cost is not a constraint and should never drive a decision here. What costs
real money is a native reviewer's time, and what costs more than that is
shipping forty-two wrong Czech letter names to children.

The pipeline still reports and caps spending, because an accident with a script
in a loop is a different kind of risk from a budget.

## 2. Pick a plan

You need a **paid** plan. The free tier does not grant commercial rights and
attaches attribution conditions, neither of which suits a published game.

| Plan | Price | Multilingual characters included |
|---|---|---|
| Free | — | not usable here — no commercial licence |
| **Starter** | **$6/month** | **60,000** |
| Creator | $22/month ($11 first month) | 220,000 |

**Starter is the recommendation.** Its 60,000 monthly characters are roughly
fifty times what iteration 1 needs, and it clears the commercial-rights bar.
Creator is worth it only if you later record all 3,652 vocabulary words with
retakes, and even then you can upgrade for one month and drop back.

Audio you generate under a paid plan stays yours to use commercially,
indefinitely, including after you cancel. Keep the invoices — they are the
evidence that the clips in the AAB were licensed, which is the sort of thing a
compliance question asks for years later.

Two things to be aware of before you commit:

- ElevenLabs takes a broad licence to use content submitted to the service.
  That is unremarkable for synthesised speech from a public word list, but it is
  a reason not to feed it anything private.
- Pure AI output has no copyright protection in the US, so the clips are yours
  to use but not yours to stop anyone else from generating. Irrelevant for
  letter names; worth knowing.

## 3. Create the account and the key

1. Sign up at <https://elevenlabs.io/app/sign-up>.
2. Subscribe to Starter.
3. Go to <https://elevenlabs.io/app/settings/api-keys> and create a key.
   - Name it something like `learning-maze-tts`.
   - **Restrict it to Text to Speech** if the scope selector offers it. The key
     never needs to do anything else, and a narrow key limits the damage if it
     leaks.
   - Copy it now; it is shown once.

Then put it in your shell environment — **never in a file inside this repo**:

```bash
# ~/.zshrc
export ELEVENLABS_API_KEY='sk_...'
```

```bash
source ~/.zshrc
python3 tools/speech/speech_pipeline.py doctor    # should show the key as set
```

`speech_pipeline.py verify` scans the repository for anything key-shaped and
fails the build if it finds one, so a slip is caught before it is committed —
but the scan is a safety net, not a licence to be casual. If a key does leak,
revoke it in the dashboard; that is instant and free.

## 4. Choose a voice

This is the part that actually matters, and it is a listening decision, not a
technical one.

### What the game needs

The voice is a teacher, not a narrator. It says single letters and single
numbers to a four-year-old sitting three metres from a television, often with
mediocre speakers, and it says the same forty-two things thousands of times.

Look for, in order:

1. **Native to the language.** A voice trained on Czech for Czech. Any voice can
   speak any language, but an English-trained voice reading *chá* will sound
   like an English speaker attempting Czech, and children learning to read are
   exactly the audience who cannot afford that.
2. **Warm, calm, adult.** Not a performer. Not breathy. Nothing that sounds like
   an advertisement.
3. **Clear final consonants.** Czech letter names live or die on this — *bé*,
   *cé*, *dé*, *gé* have to be distinguishable at low volume through a TV.
4. **Even pace, no drama.** A voice with strong stylistic swing is worse here,
   because isolated single-syllable utterances give the model almost no context
   and it will improvise.
5. **Boring on the thousandth listen.** Character is a liability at this
   repetition rate. So is anything cute.

Avoid: child voices (both for tone and because cloning children's voices is a
line this project should not go near), heavily accented regional voices unless
that accent is the declared reference, and anything labelled for advertising or
storytelling drama.

### Where to look

The dashboard is easier than the API for browsing, because you can hear
candidates immediately:

- **Voice Library** — <https://elevenlabs.io/app/voice-library>, filter by
  language and by use case "narration" or "informative educational". Play the
  samples.
- **Voice Design** — describe the voice you want and generate one. The advantage
  is that you *own* it, which matters: a Voice Library contributor can withdraw
  their voice, and if that happens after you ship, the words you add next year
  will not match the letters you shipped this year.

Once you have candidates, the pipeline can list them with their IDs:

```bash
python3 tools/speech/speech_pipeline.py voices --language cs --language en
```

That call is read-only and costs nothing.

### Same voice for both languages, or one each?

One warm voice per language, kept similar in age and pace, beats one voice
speaking both languages with an accent in one of them. Consistency of
*character* across languages is what matters to a child, not identity of timbre.

### Record the choice

Fill in `data/speech/voice_profiles.json`:

```json
"cs-CZ": {
  "voice_id": "...",
  "voice_name": "...",
  "voice_source": "owned_design",
  "model_id": "eleven_multilingual_v2"
}
```

`voice_source` matters later. Prefer `owned_design` or `owned_clone` over
`library` for the reason above.

## 5. The A/B test before you commit (Phase 3)

Do not generate 168 clips against an unheard voice. Generate about twenty,
listen on a television, and only then commit.

```bash
python3 tools/speech/speech_pipeline.py extract
python3 tools/speech/speech_pipeline.py plan --language cs
python3 tools/speech/speech_pipeline.py generate --language cs --limit 12 --confirm
python3 tools/speech/speech_pipeline.py process --language cs
python3 tools/speech/speech_pipeline.py listen --language cs
open build/speech/listen_cs-CZ/index.html
```

That last page is where the judgement happens: it plays each clip next to the
letter it belongs to, so you are checking a recording against its meaning rather
than against a filename.

What to listen for specifically:

| Language | Test | Failure looks like |
|---|---|---|
| cs | `Ř` — *eř* | a plain rolled R, or an English "err" |
| cs | `CH` — *chá* | "tsehah", or the letters spelled out |
| cs | `Ě` — *e s háčkem* | the description read as a sentence rather than a name |
| cs | `Ů` / `Ú` | the two long U names sounding identical |
| cs | 21, 33, 47 | wrong compound, or a stumble at the word join |
| en | `M` / `N`, `E` / `I` | indistinguishable at TV volume |
| en | `G` — *jee* | "gee" with a hard G |
| en | 13 / 30, 14 / 40 | the classic teen/ten confusion |

If Multilingual v2 fails on Czech, switch that profile to `eleven_v3` and set
`language_code` to `"cs"`, then regenerate. The pipeline treats a model change
as a new take automatically — the old clips go stale rather than silently
mixing with the new ones.

Also A/B the shipped bitrate at this point, on the oldest television you
support, before 168 clips are encoded at 32 kbps.

## 6. What must not happen

- No API key in the repo, in `voice_profiles.json`, in a commit, or in the AAB.
- No network call from the game. Ever. The clips ship inside the app.
- No clip reaches a pack without a named native reviewer approving that exact
  take. `pack` enforces this; do not work around it.
- `voice_masters/` never enters the build. Both a `.gdignore` and a `.gitignore`
  entry guard it, and `verify` checks both are still there.

The app's whole compliance position rests on having no SDKs, no accounts and no
server calls. Pre-generated audio keeps that intact precisely because the
provider is a build-time tool, like the compiler. Keeping it that way is not
optional.
