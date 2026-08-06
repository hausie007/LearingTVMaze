# Learning Maze — Google Play compliance checklist & action plan

App: `com.hauzirek.learningmaze` · Version code 76 (1.0.3) · Appeal 9-4212000040896
Audit completed 3 August 2026 against [Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/17122218) and [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159), both retrieved 3 Aug 2026.

**Key:** ✅ verified pass · ⚠️ open, action identified · ❓ not verifiable without an artefact I don't have · ➖ not applicable

---

# PART 1 — Compliance checklist

## A. Play Console requirements

| # | Requirement | Status | Evidence |
|---|---|---|---|
| A1 | Target audience declared | ✅ | "5 and under, 6-8". Spec targets 4+ pre-readers; 5x4 grid "perfect for 4-year-olds" |
| A2 | Multiple age groups only if designed for each | ✅ | No adult band selected. Difficulty scales 5x4 → 36x15 support both bands |
| A3 | Console answers kept current | ✅ | Declarations last edited 4-5 Apr 2026; no functional change since (75→76 is target SDK only) |
| A4 | No misrepresentation in Console | ⚠️ | See B3 — questionnaire accuracy unresolved |

## B. Families Policy Requirements 1-8

### 1 · App content appropriate for children ⚠️

| Element | Status | Notes |
|---|---|---|
| Core gameplay | ✅ | Maze navigation, educational collectibles. No violence, gore, gambling, substances, sexual content, dating or marital advice |
| Failure states | ✅ | No timers, no damage, no game-over. Wall bump = 3px shake + 24ms haptic. Loss screen offers "Try Again" / "Easier" |
| Chaser mechanic | ✅ | Optional, speed-adjustable, deliberately slack, can be a second human player |
| Ratings — 7 of 8 authorities | ✅ | ESRB Everyone · PEGI 3 · USK 0 · ClassInd L · GRAC All ages · IARC 3+ · Russia 3+ |
| Rating — ACB (Australia) | ⚠️ | **PG, descriptor "Mild Crude Humour"** — the sole outlier. Traces to the questionnaire answer at B3a, not to the content itself |
| Bathroom theme | ⚠️ | Opt-in, 1 of 9, not default, absent from store listing. Smiling cartoon poop, toilet, toilet paper, plunger. No defecation, flatulence or vomiting depicted |
| Scary theme | ⚠️ | Opt-in. Dark night-forest background + crooked-tree chaser. Google names "scary, dark settings… backgrounds" for the 5-and-under band. See `themes/scary/THEME_REDESIGN.md` |
| Thieves theme | ⚠️ | **Default theme on fresh install.** Cartoon chase — coin, treasure chest, banana peel. Crime is on no Google violation list. Police baton is the only weapon-adjacent object. See `themes/thiefs/THEME_NOTES.md` |
| Other 6 themes | ❓ | arcade, cars, castle, default, ducks, karkulka reviewed only at asset-listing level. karkulka uses a wolf chaser |
| Vocabulary — 3,654 entries | ✅ | Full review complete. Alcohol 🥃 and weapons 🏹🤺 **eliminated**; 💩 removed. See `data/words/EMOJI_AUDIT_2026-08-03.md` |
| Remaining vocabulary issues | ⚠️ | 1 possible weapon word (`pl STRASZAK`) + 11 word errors. See `data/words/EMOJI_TODO.md` |

### 2 · App functionality ✅
Native Godot 4.6 app. Not a webview, no affiliate traffic.

### 3 · Play Console answers accurate ⚠️ — **the central open item**

| Sub-item | Status | Notes |
|---|---|---|
| 3a — Crude Humor | ⚠️ | Question asks: *"any bodily functions such as belching, flatulence, or vomiting when used for humorous purposes?"* Game has **none** of these — it has a static cartoon poop **character**. Question wording says No; IARC's category description ("whimsical depictions of feces") suggests Yes. **Referred to IARC for a written determination.** Do not change unilaterally |
| 3b — Fear / horror | ❓ | **Never checked.** A Scary theme with a monster chaser ships. If answered No, that is an *under*-declaration |
| 3c — Crime / violence | ❓ | **Never checked.** A cops-and-robbers theme ships as the default |
| 3d — User interaction | ❓ | **Never checked.** 2-4 player local-WiFi multiplayer ships |
| 3e — Data safety | ✅ | "Doesn't collect or share data" — confirmed against source and bundle |
| 3f — Target audience | ✅ | Verified accurate at A1 |
| 3g — Ads declaration | ✅ | "Doesn't contain ads" — no ad code of any kind in the bundle |
| 3h — Advertising ID | ✅ | "Doesn't use advertising ID" — no AD_ID permission, no AAID reference anywhere |

### 4 · Data practices ✅ — verified from the shipped AAB

| Requirement | Status | Evidence |
|---|---|---|
| No AAID transmission | ✅ | Zero matches for `advertising` / `AAID` in source; `export_presets.cfg` declares `advertising_data/collected=false` |
| No AD_ID permission at API 33+ | ✅ | Absent at target SDK 36 |
| No SIM/Build serial, IMEI, IMSI | ✅ | Zero matches for `IMEI`, `IMSI`, `getDeviceId`, `serial` |
| No phone number via TelephonyManager | ✅ | Zero matches; no telephony permission |
| No location permission or precise location | ✅ | No location permission in manifest |
| Bluetooth via CDM | ➖ | No Bluetooth permission |
| **No BSSID / MAC / SSID transmission** | ✅ | Zero matches for `getSSID`, `BSSID`, `getMacAddress`, `WifiManager`. The SSID feature in spec §4.2 was never implemented — and reading SSID requires location permission, which the app does not hold, so it is impossible by construction |
| Discovery packet contents | ✅ | Game config only. `host_name` is a static translated string; `session_id` is `randi()` + tick, regenerated per session |

### 5 · APIs and SDKs ✅

| Check | Result |
|---|---|
| Native libs in AAB | `libc++_shared.so`, `libgodot_android.so` — nothing else |
| Dex signature scan | **No** GMS, Firebase, Crashlytics, AdMob, Facebook, Unity, AppLovin, ironSource, Branch, Adjust, Amplitude, Mixpanel or AppsFlyer |
| Outbound network | No `HTTPRequest`, no `HTTPClient`. Only two user-initiated `OS.shell_open()` calls (privacy policy, own Play listing) |

### 6 · Augmented Reality ➖
No AR.

### 7 · Social apps & features ✅
Clients transmit directional input and a character id. No chat, no text field, no voice, no image sharing, no UGC. Max 4 players, same LAN, no internet transport. **Not a social app or social feature** — no safety reminder or adult-action gate required.

### 8 · Legal compliance (COPPA / GDPR) ✅
No personal data collected, no accounts, no sign-in, no analytics, no advertising identifiers. Privacy policy published. ❓ Privacy policy *text* not yet reviewed.

## C. Ads and Monetization ➖
No ads, no ad SDK, no advertising ID, no interstitials, no rewarded video, no offerwalls, no IAP. The entire section is inapplicable.

## D. Other

| Item | Status | Notes |
|---|---|---|
| Target API level | ✅ | 36 — the reason v76 was submitted |
| Permissions minimal | ✅ | INTERNET (ENet LAN), VIBRATE (haptic). Both justified |
| `android.permission.DUMP` | ✅ | **Not a permission request.** It is the `android:permission` attribute protecting `androidx.profileinstaller.ProfileInstallReceiver` — a hardening measure. Documented so a naive scan doesn't misread it |
| App icon (live) | ✅ | "LM" on a light pastel maze. Bright, cheerful, no characters. No issue |
| Feature graphic (live) | ✅ | "Learning Maze" in colourful lettering on white, **spelled correctly**. No characters. No issue. *(Note: `images/big_banner_1024_500.png` in the repo reads "LEARNI**G** MAZE" — misspelled, but it is not the live asset)* |
| Listing text | ✅ | States "No timers. No pressure. No ads. No in-app purchases. No tracking. No internet connection required." + "No accounts or child profiles." Every claim matches the declarations **and** the bundle audit. The public listing corroborates the Console answers |
| Store screenshots (8) | ⚠️ | **Reviewed 3 Aug — four findings, see S1-S4 below.** This is the artefact category Google named |
| Promo video / trailer | ✅ | **Reviewed 3 Aug — all 31 frames at 0.5s intervals.** 16s. Two children in a living room with a Google TV remote and a phone; gameplay showing "LIGHTNING" being spelled letter by letter; captions *"A fun educational maze game for families" / "Play with a TV remote" / "Use a phone as a controller" / "Learn numbers, letters and words" / "Play alone, race or cooperate"*; end card *"Safe · No Ads · No In-app purchases · No Accounts"*. **No violence, no weapons, no crude humour.** The word "Scary" never appears; the Bathroom theme never appears. **Net positive — evidence in your favour**, not a liability |
| ↳ *correction from the first pass* | ⚠️ | My initial review sampled at 2s and concluded *"the tree chaser never appears."* **That was wrong.** At 0.5s sampling the chaser is visible in the maze as a small magenta sprite, and its icon appears in the pink "Chase" badge in the HUD throughout. It renders at roughly 20px on a 1920px frame — a reviewer is unlikely to read it as a monster — but it is present, and the record should say so |
| ↳ *also newly visible* | — | **Jack-o'-lantern collectibles are prominent and repeated**, carrying the letters (L, H, G) at large size in the centre of the maze. Halloween imagery is more present in the video than the 2s sample suggested. Also visible: a **"Chase in 1" countdown badge**, which corroborates the design claim that the chaser gives the player slack before starting |
| "What's new" text | ⚠️ | Reads "First production release" on an app at v75. Stale. Google's Families policy specifically recommends using this field to announce target-age or feature changes |
| Store listing localizations | ✅ | Developer confirms visually identical, localized text only. English set reviewed |

### Screenshot findings

| # | Finding | Why it matters |
|---|---|---|
| **S1** | The word **"Scary"** is visible in the breadcrumb of screenshot 3 — *"Follow the Trail • Scary • Very Large"* | The theme name appears **in the store listing itself**. A reviewer scanning screenshots of a Families app reads the word "Scary". This substantially raises the value of the retitle in `themes/scary/THEME_REDESIGN.md` |
| **S2** | The **Bathroom theme icon (a toilet)** appears in the theme-selector row of screenshot 8 | **Corrects an earlier finding.** I previously recorded the Bathroom theme as "absent from all store-listing assets". That was wrong — it is represented in the store listing |
| **S3** | The **dark Scary-theme forest is the background of two screenshots** (5 and 8) | The darkest asset in the game is featured twice in the listing. Directly relevant to *"graphics… not appropriate for the selected age group"* |
| **S4** | Screenshot 2 shows a **very large, dense, plain-grey maze** with tiny sprites (Spanish, "APRENDE ALGO NUEVO") | **Downgraded — original assessment was wrong.** This is intentional: the set demonstrates the size range, with a small maze (parchment theme), a medium one (forest theme) and this largest one, matching screenshot 4's claim *"Maze sizes from tiny to huge."* The game targets Smart TVs, where a 36x15 maze is perfectly legible. The design intent is sound and defensible. **Residual, minor:** Play renders screenshots as small thumbnails (~526x296), often on a phone, so at listing size the sprites in this one are near-invisible and the intent doesn't survive the medium. That is a marketing-clarity point, **not a policy issue** — no action required for compliance |

*Also noted, not a policy issue:* screenshot 7 uses a photograph of two children in a living room. Showing children is not prohibited for Families apps; recorded only for completeness.

### S5 — Pattern across the whole listing *(observation, weak evidence)*

With the video now reviewed, the dark forest theme accounts for **2 of 8 screenshots and 100% of the promo video, including the end card**. It is effectively the app's entire marketing identity.

Nothing in it is prohibited, and no single asset is a problem. But for an app declaring **"5 and under"**, the marketing shows exclusively the darkest theme in the game. That is consistent with Google's *"graphics, screenshots, or videos… not appropriate for the selected age group"* — while being far too weak to treat as a finding.

**Practical consequence:** if the Scary theme is relit per `themes/scary/THEME_REDESIGN.md`, re-capturing the video and those two screenshots afterwards would refresh the whole listing at once. If it is not relit, consider re-shooting some marketing on a brighter theme instead — the parchment or ducks theme would change the first impression at a fraction of the cost.

*Minor, probably nothing:* the children in the video and in screenshot 7 look roughly 8-10 — older than either declared band (5-and-under, 6-8). Recorded for completeness; this is not the failure mode Google's "Apps primarily designed for children" section describes, which concerns child-appealing marketing on a **non**-child app.

*Strong assets:* screenshot 6 ("Offline • No ads • No hidden payments • Safe for kids") and screenshot 4 ("Levels from simple to challenging") are exactly right and should be kept.
| Active releases across all tracks | ❓ | Not enumerated. Bundle Explorer shows v75 active on *Internal testing*, v76 on Production — unexplained |
| Teacher Approved | ❓ | Enrolled for review; status and any interaction with this enforcement unknown |

---

## Bottom line

**No Families requirement is affirmatively failed.** Technically the app is exemplary — no SDKs, no trackers, no identifiers, no network calls, no ads, two permissions. Requirements 2, 4, 5, 7 and 8 pass cleanly and are provable from the shipped artefact.

**All four rejection bullets appear satisfied:**

| Google's bullet | Assessment |
|---|---|
| 1. Designed for children or everyone | Satisfied — the spec is unusually strong evidence of deliberate child-directed design |
| 2. App and ad content suitable for children | Satisfied on content; one rating question open with IARC |
| 3. Rated ESRB Everyone or E10+ | Satisfied — ESRB Everyone |
| 4. Uses Families Self-Certified Ads SDK | Satisfied vacuously — no ads exist |

**The live risk is narrow:** whether the content across all nine themes suits the **5-and-under** band, and whether the IARC questionnaire accurately describes that content. Three of the four questionnaire answers that matter have never been examined.

---

# PART 2 — Prioritized action list

## 🔴 P0 — Do before submitting anything

**1. Retrieve all IARC questionnaire answers — fear/horror, crime/violence, user interaction.**
Three answers that bear directly on shipped content have never been checked. If any is under-declared, that is a live Families requirement-3 violation regardless of everything else — and it is the more dangerous direction of error. Nothing else should move until these are known.

**2. Get IARC's written determination on the Crude Humor question.**
Find the IARC certificate email (search `IARC` / `globalratings`) — it carries both a developer contact and a rating appeal link. Ask one narrow question: does a static cartoon poop *character*, with no belching, flatulence or vomiting, warrant Yes on that question? Three outcomes, all useful: they say No and the descriptor clears with written authority; they say Yes and you appeal the ACB PG; or either way you gain a dated answer from the body that owns the rating — a far better exhibit than anything in the appeal thread.

**3. Discard the open questionnaire draft.**
The Console screenshot showed a "Discard changes" control. Do not submit a partial questionnaire while items 1 and 2 are unresolved.

**4. Do not change the crude-humor answer in isolation.**
Correcting one answer downward while another may be under-declared makes the questionnaire less accurate overall. Re-derive the whole thing from all nine themes plus the vocabulary in **one pass**, after 1 and 2.

## 🟠 P1 — Real defects, cheap to fix

**5. ~~Replace screenshot 2~~ — WITHDRAWN, no action needed.**
The large grey maze is deliberate: the three maze screenshots demonstrate the size range from tiny to huge, matching screenshot 4's own claim, and the game targets Smart TVs where that maze size is legible. No policy issue. *(Optional marketing tweak only: at Play's thumbnail size the sprites are hard to see, so the "look how big it gets" point lands less well than intended. Ignore if you disagree — it is a taste call, not compliance.)*

**5b. Remove the word "Scary" from screenshot 3.** *(now the highest-value listing change)* The breadcrumb reads *"Follow the Trail • Scary • Very Large"*. The theme name is visible in the store listing of a Families app. Re-shoot with a different theme selected, or do it after the retitle so the breadcrumb reads "Enchanted Forest".

**5c. Reconsider the dark forest background in screenshots 5 and 8.** The darkest asset in the game appears twice in the listing. Re-shoot on a brighter theme, or leave until after the Scary theme relight and then re-capture.

**5d. Update the "What's new" text.** It still says "First production release" at version 75.

**5e. ~~Review the promo video~~ — DONE, no action needed.** Reviewed 3 Aug. Clean, wholesome, ends with "Safe · No Ads · No In-app purchases · No Accounts". No monster, no "Scary" label, no Bathroom theme. Keep it — it is a defensive asset.

**5f. *(Optional, only if the Scary theme is relit)*** Re-capture the video and screenshots 5 and 8 afterwards, so the listing stops being 100% dark-forest.

---

**The store listing is now fully reviewed.** Icon, feature graphic, all 8 screenshots, all listing text, and the promo video. The only remaining unknowns in the entire audit are the **IARC questionnaire answers** and the **active release tracks**.

**6. Enumerate every active release on every track.**
Production, open, closed and internal testing. Google reviews all active tracks. Bundle Explorer shows v75 active on Internal testing while v76 is on Production, and nobody has explained that.

**7. Retitle the Thieves theme.** → `data/translations.csv`, `theme_thiefs` row, 21 languages.
It is the **default theme on a fresh install** — the first theme name a reviewer sees. One CSV row. Recommended: **Treasure Chase**. Details in `themes/thiefs/THEME_NOTES.md`.

**8. Swap the police baton for a whistle.** `themes/thiefs/t_chaser_0.png`.
Now the only weapon-adjacent object left in the game. One asset.

**9. Check `pl STRASZAK` with a Polish speaker.** `data/words/words_pl_4.json`.
Every other language uses a scarecrow word there; *straszak* commonly means a cap gun. The only possible weapon word left in the vocabulary.

**10. Fix the 11 vocabulary word errors.** See `data/words/EMOJI_TODO.md` §A.
`da LOSOS` is a Czech word in the Danish list; `pl MÓD` and `da BOLT` look like corrupted duplicates that should simply be deleted; three Finnish typos.

## 🟡 P2 — Risk reduction, do if the above doesn't resolve it

**11. Lighten the Scary theme background and soften the tree.** → `themes/scary/THEME_REDESIGN.md`.
The darkest asset in the game, and Google's 5-and-under wording names backgrounds explicitly. Highest-leverage step is relighting `tile4.png`; second is giving the chaser pupils.

**12. Retitle Scary → Enchanted Forest.** `data/translations.csv`, `theme_scary` row.
Do this *after* the art, so the name is accurate rather than cosmetic. Same one-row mechanism as #7.

**13. Review the remaining six themes** against the Age 5-and-under list — arcade, cars, castle, default, ducks, karkulka. Only karkulka has a flagged element so far (wolf chaser). One screenshot each is enough.

**14. Review the privacy policy text** at `sites.google.com/view/learning-maze-privacy-policy` — confirm it loads, and that it accurately states no data collection.

**15. Run Google's own `play-policy-insights` skill** against the source (`github.com/android/skills`). Everything it checks has already passed manually, but a clean report **from Google's own tool** is a materially better exhibit for the appeal than my assertion.

## 🟢 P3 — Quality, no policy bearing

**16.** Fix the 34 emoji/word mismatches in `EMOJI_TODO.md` §B — worst are `tr GÜVE`, `cs VÁŽKA`, `cs KRTEK`.
**17.** Declare `assets.chaser` explicitly in `themes/scary/manifest.json` — the only theme relying on filename fallback.
**18.** Delete unreferenced assets: `themes/scary/pumpkin.png`, `themes/thiefs/t_collectible_money_bag.png`.
**19.** Update the design spec — §4.2 describes SSID auto-detection that was never implemented.

---

## What NOT to do

- **Do not rename any theme folder.** `game_config.gd:427` persists the theme as `dir_name` and `CharacterCatalog` prefixes character IDs with it. Renaming breaks saved preferences and desyncs the multiplayer discovery payload. Retitle via `translations.csv` only.
- **Do not drop "5 and under" from the target audience.** It is the accurate declaration for a game designed for 4-year-old pre-readers. Removing it would be misrepresentation.
- **Do not resubmit a speculative build** to see what happens.
- **Do not argue the yellow highlighting in Google's emails.** It appears in all four screenshots with different coverage each time, including over "As explained in the previous mail" — client-side highlighting, not a Google signal.
- **Do not repeat the Godot-ad-SDK theory.** The dex scan is now definitive: there is no ads SDK of any kind. The Ads bullet in the notice was boilerplate list text, never a finding.

---

## Honest limits of this audit

Verified from the shipped `Bludiste.aab` and full source: permissions, SDKs, native libraries, network behaviour, data practices, social features, discovery payload contents, and all 3,654 vocabulary entries.

**Not verified, because the artefacts were not available:** store-listing assets and localizations, privacy policy text, the full IARC questionnaire answers, active releases across tracks, Teacher Approved status, and six of the nine themes beyond an asset listing.

**And the thing no audit can supply:** Google has still never identified a specific finding. Everything above is derived from reading your app against Google's published criteria. It produces a defensible compliance record and a ranked set of candidate causes — not certainty about what the reviewer actually saw.
