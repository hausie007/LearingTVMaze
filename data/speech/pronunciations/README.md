# Pronunciation overrides

Per-locale corrections applied to the generation text **after** it is read from
`letters_<lang>.json` or `numbers_<lang>.json`, and before it is hashed and sent
to the provider.

One file per locale, named `<locale>.json`. A locale with no corrections needs
no file.

```json
{
  "schema_version": 1,
  "locale": "cs-CZ",
  "overrides": {
    "learning.char.r_caron": {
      "spoken": "eř",
      "reason": "v2 read 'er' as a plain R; the háček has to be in the name",
      "added_by": "…",
      "added_on": "2026-08-20"
    }
  }
}
```

An override is keyed by the semantic key, so it survives a change to the source
file's ordering.

## Order of escalation

Reach for these in order, and stop as soon as the clip is right:

1. Fix the `spoken` text in `letters_*.json` / `numbers_*.json` — if the text is
   wrong for every voice, it belongs in the source, not in an override.
2. An override here — the text is right in general but this voice or model reads
   it wrong.
3. A different voice or model for the locale, in `voice_profiles.json`.
4. IPA between slashes, `/ˈxaː/` — Eleven v3 only, and only about 80–90%
   consistent. Useful, not a guarantee.
5. A provider pronunciation dictionary — record its id **and version** in the
   locale's profile, because both feed the generation spec hash.

Never leave a clip that a native reviewer rejected in place because the fix is
awkward. The letters and numbers are heard in every single session.

## Effect on regeneration

Adding, changing or removing an override changes the generation spec hash of the
affected keys, which marks exactly those clips stale. Nothing regenerates
implicitly — `plan` reports them, and `generate` only touches what you select.
