# Learning Maze — Google Play compliance checklist

App: `com.hauzirek.learningmaze` · Godot 4.6 · target SDK 36
Working tree at version code 76 (1.0.3); **must be bumped to 77 before submission**
Appeal 9-4212000040896

**Audit re-run 7 August 2026**, replacing the 3 August version. Verified against policy text retrieved the same day:

- [Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335)
- [User Data](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159)

**Key:** ✅ verified pass · ⚠️ open risk, action identified · ❗ new finding this pass · ❓ not verifiable without an artefact not available here · ➖ not applicable

> **Context that has not changed.** Version 76 was rejected on 25 July 2026 under *Families Policy Requirements: Families Program Eligibility*. **Google has still never identified a specific finding.** Everything below is derived from reading the app against Google's published criteria. It produces a defensible record and a ranked set of candidate causes — not certainty about what the reviewer saw.

---

## 0. What changed since the 3 August audit

Eleven commits. Items closed:

| Was | Now |
|---|---|
| Theme titled "Scary" | **Autumn Forest** in all 21 locales |
| Theme titled "Thieves" (default on fresh install) | **Treasure Chase** in all 21 locales |
| Police officer holding a black baton | Holding a **whistle** |
| Chaser tree with hollow eye sockets and a jagged mouth | **Round eyes with pupils, small rounded mouth**. Silhouette IoU 1.0000 against the original, so the promo video still matches |
| Scary palette `wall #D670FF`, `glow 0.6` | `#A88BFF`, `glow 0.45` |
| `pl STRASZAK` (cap gun) | `PSZENICA` — resolved by cross-language evidence, not guesswork |
| 11 further vocabulary word errors | Corrected; 2 corrupted duplicates deleted |
| `assets.chaser` undeclared in the scary manifest | Declared |
| Spec claimed WiFi SSID auto-detection | Claim removed — never implemented, impossible without location permission |
| 2.3 MB of unreferenced art inside `themes/` | Removed; `export_filter=all_resources` would have shipped it |

Vocabulary is now **147 files, 3652 entries** (was 3654; two deletions).

**A deliberate reversal:** the relit "Enchanted Forest" background, rabbit chaser and toadstool collectible were built, measured and then **reverted**. The promo video already shows the original theme and reshooting it is expensive. The art is recoverable from commit `e645e84`. Consequence: the background, cobwebs and jack-o'-lantern in this theme are **knowingly retained**, and the theme name was changed from "Enchanted Forest" to **"Autumn Forest"** so the title matches the art that stayed rather than describing art that was abandoned.

---

# PART 1 — Checklist

## A. Play Console requirements

| # | Requirement | Status | Evidence |
|---|---|---|---|
| A1 | Target audience declared | ✅ | "5 and under, 6-8". Accurate: designed for 4+ pre-readers |
| A2 | Multiple age groups only if designed for each | ✅ | No adult band. Difficulty scales 5×4 → 36×15 |
| A3 | Console answers current | ⚠️ | Content has now changed materially (two theme names, two sprites). Re-check the questionnaire before submitting |
| A4 | No misrepresentation | ⚠️ | Depends on B3, still the central open item |

## B. Families Policy Requirements 1–8

### 1 · App content appropriate for children ⚠️

**All nine themes have now been reviewed at sprite level.** The 3 August audit reviewed six of them only as an asset listing. Doing it properly changed the picture.

| Theme | Chaser | Assessment |
|---|---|---|
| default | Orange one-eyed monster | ✅ Cute, smiling, no menace |
| ducks | Fox | ✅ Friendly cartoon, no bared teeth |
| thiefs → *Treasure Chase* | Police officer | ✅ **Fixed this session** — whistle replaces baton |
| scary → *Autumn Forest* | Crooked tree | ✅ **Fixed this session** — round eyes, rounded mouth |
| poop → *Bathroom* | Angry plunger | ⚠️ Cross expression but comic. See B3a |
| karkulka | Wolf | ⚠️ ❗ **Snarling, bared teeth, angry yellow eyes.** Classic fairy-tale framing, but this is "scary animal" imagery under the 5-and-under wording |
| castle | Three-headed dragon | ⚠️ ❗ Cartoon and fairly benign, but three heads with open mouths |
| **cars** | **Snarling police car** | ⚠️ ❗ **The most menacing asset in the game.** Bared sharp teeth, narrowed angry eyes, red-lit smoky background baked into the sprite |
| arcade | Red ghost | ⚠️ ❗ Benign as imagery — but see D7, IP exposure |

**❗ Two findings that contradict the previous audit:**

**1. The police baton was *not* the only weapon in the game.** The `castle` theme's **player sprite is a knight holding a drawn sword** (`themes/castle/c_player.png`). Google's Age 5-and-under list names weapons explicitly. The baton is fixed; the sword is not, and it is on a *player* character rather than a chaser, so a child sees it constantly while playing that theme.

**2. The most menacing asset is in `cars`, not `scary`.** The entire remediation effort has focused on the Scary theme. But `themes/cars/chaser_1.png` is a snarling police car with bared sharp teeth, angry eyes and a dark red-lit smoky scene baked in. On the Age 5-and-under criterion — *"scary, dark settings or characters"* — it is a stronger match than the tree ever was, and it was never examined. It is also **technically defective**: 53.4% of the sprite is fully opaque against 35–47% for every other chaser, confirming the background is painted in rather than transparent, so it renders as a dark block in the maze.

| Element | Status | Notes |
|---|---|---|
| Core gameplay | ✅ | Maze navigation, educational collectibles. No violence, gore, gambling, substances, sexual content |
| Failure states | ✅ | No timers, no damage, no game-over. Wall bump = 3px shake + 24ms haptic |
| Chaser mechanic | ✅ | Optional, speed-adjustable, slack, can be a second human player |
| Ratings — 7 of 8 authorities | ✅ | ESRB Everyone · PEGI 3 · USK 0 · ClassInd L · GRAC All ages · IARC 3+ · Russia 3+ |
| Rating — ACB (Australia) | ⚠️ | PG, "Mild Crude Humour" — sole outlier, traces to B3a |
| Vocabulary — 3652 entries | ✅ | Re-swept this pass. **Zero** alcohol, tobacco, drug, violence, injury, romantic or religious emoji |
| ↳ ❗ Halloween thread | ⚠️ | `HALLOWEEN` is a **vocabulary word in 6 languages** (da, en, es, fr, nl, sv), all with 🎃, plus 🎃 for pumpkin in cs and es — **8 entries**. Combined with the jack-o'-lantern collectible that is being retained, the app teaches Halloween as vocabulary while a theme displays it |
| ↳ ❗ Spiders | ⚠️ | 🕷 in 12 languages, plus 🕸 ×2 and 🦇 ×1. "Think scary animals" is Google's phrasing. Mitigation: spiders appear in every children's picture dictionary, and the Bathroom-adjacent trap sprite is a *smiling* spider |
| ↳ ❗ Clown | ⚠️ | `en FUNNY CLOWN` 🤡. Clowns are a documented childhood fear trigger. "Funny" framing mitigates |
| ↳ Shield / dice | ✅ | `he אביר` 🛡 is defensive armour, not a weapon. `cs HRA` 🎲 is a game piece, not gambling. Neither is a finding |

### 2 · App functionality ✅
Native Godot app. Not a webview, no affiliate traffic. Verified: **no webview of any kind** in the codebase.

### 3 · Play Console answers accurate ⚠️ — **still the central open item**

Unchanged from 3 August, and unchanged for a reason: these need Console access.

| Sub-item | Status | Notes |
|---|---|---|
| 3a — Crude Humor | ⚠️ | Answered Yes, tier 2. Game has no belching, flatulence or vomiting — it has a static cartoon poop *character*. Referred to IARC. **Do not change unilaterally** |
| 3b — Fear / horror | ❓ | **Never checked.** Now more pressing: a snarling wolf, a snarling police car and a dragon all ship |
| 3c — Crime / violence | ❓ | **Never checked.** A cops-and-robbers theme and a sword-carrying knight ship |
| 3d — User interaction | ❓ | **Never checked.** 2–4 player local-WiFi multiplayer ships |
| 3e — Data safety | ✅ | "Doesn't collect or share data" — confirmed against source |
| 3f — Target audience | ✅ | Verified at A1 |
| 3g — Ads declaration | ✅ | No ad code of any kind |
| 3h — Advertising ID | ✅ | No AD_ID permission, no AAID reference |

### 4 · Data practices ✅ — re-verified from source this pass

| Requirement | Status | Evidence (grep over `scripts/`, 7 Aug) |
|---|---|---|
| No AAID transmission | ✅ | 0 hits for `advertising`/`AAID`/`AD_ID` |
| No AD_ID permission at API 33+ | ✅ | Absent at target SDK 36 |
| No SIM/Build serial, IMEI, IMSI | ✅ | 0 hits |
| No phone number via TelephonyManager | ✅ | 0 hits |
| No location permission | ✅ | Not in export config |
| Bluetooth via CDM | ➖ | No Bluetooth permission |
| No BSSID / MAC / SSID | ✅ | 0 hits for `getSSID`, `BSSID`, `getMacAddress`, `WifiManager`. Impossible by construction — reading SSID needs location permission, which the app does not hold |
| Discovery packet contents | ✅ | Game config only; `session_id` is `randi()` + tick, per session |

### 5 · APIs and SDKs ✅

| Check | Result |
|---|---|
| Outbound network | **0** `HTTPRequest`, **0** `HTTPClient`. Only 3 user-initiated `OS.shell_open()` calls |
| Third-party SDK references | **0** hits for firebase / crashlytics / admob / analytics |
| The 3 shell_open calls | Privacy policy URL, `market://` for own listing, Play Store URL for own listing. All in `settings_menu.gd`, all user-initiated |

*Note: the AAB-level dex scan from 3 August (no GMS, Firebase, Crashlytics, AdMob, Facebook, Unity) should be re-run on the v77 bundle before submission — see P0-4.*

### 6 · Augmented Reality ➖ · 7 · Social apps & features ✅

Clients transmit directional input and a character ID. No chat, no text entry, no voice, no images, no UGC. Max 4 players, same LAN, no internet transport. **Not a social app or social feature.**

*Forward-looking:* Google's announced Families change effective **26 August 2026** prohibits anonymous chat apps from targeting children. **Not applicable** — no chat exists.

### 8 · Legal compliance (COPPA / GDPR) ✅
No personal data, no accounts, no sign-in, no analytics, no advertising identifiers.

## C. Ads and Monetization ➖
No ads, ad SDK, advertising ID, interstitials, rewarded video, offerwalls or IAP. Section inapplicable.

## D. Other

| # | Item | Status | Notes |
|---|---|---|---|
| D1 | Target API level | ✅ | 36 |
| D2 | Permissions minimal | ✅ | `INTERNET` (ENet LAN), `VIBRATE` (haptic). Only two enabled in `export_presets.cfg` |
| D3 | `android.permission.DUMP` | ✅ | **Not a permission request** — it is the `android:permission` attribute protecting `androidx.profileinstaller.ProfileInstallReceiver`. Documented so a naive scan doesn't misread it |
| D4 | **Privacy policy in-app** | ✅ | **Mandatory and satisfied.** The User Data policy requires "a privacy policy link in the designated field within Play Console, **and** a privacy policy link or text within the app itself". Settings has a Privacy Policy button → `OS.shell_open`. **Do not remove it** |
| D5 | ↳ parental gate for that link | ✅ | **Not required.** The current Families Policy Requirements contain no parental-gate rule for outbound links; "adult action" appears only in the Social Features clause. The blanket rule was from the retired Designed for Families programme |
| D6 | "Rate the game" button | ✅ | Not required by any policy, but not a violation. Clearly labelled, in Settings, not disguised as content |
| D7 | ❗ **Arcade theme IP exposure** | ⚠️ | The arcade theme is a recognisable **Pac-Man** pastiche — yellow wedge player, coloured ghost chaser, dot collectibles. **Not a Families issue**, but Play's Intellectual Property / Impersonation policies are a separate surface that this audit had never considered. Bandai Namco actively enforces. Worth a deliberate decision |
| D8 | ❗ Castle collectible broken | ⚠️ | `themes/castle/manifest.json` sets `collectible.image` to `"shield_new"` — no file extension. `_try_load` does a literal `path_join`, so it returns null and the collectible renders with **no sprite**. `shield_new.png` exists, as do `c_collectible_shield_0/1.png` |
| D9 | ❗ Tier-0 collectible collision | ⚠️ | Simulating the maze generator 20,000× per grid size: the 5×4 grid yields only 6 usable path cells in ~20% of runs, but tier 0 contains 7-letter words (`ARKADAŞ`, `AURINKO`). When they coincide, two letters spawn on one cell. Affects Very Easy only |
| D10 | `themes/scary/start.png` missing | ✅ | Declared in the manifest but the file does not exist. Degrades gracefully — every call site null-checks. Cosmetic only |
| D11 | App icon (live) | ✅ | "LM" on a light pastel maze. No characters |
| D12 | Feature graphic (live) | ✅ | Correctly spelled. *(`images/big_banner_1024_500.png` in the repo reads "LEARNI**G** MAZE" — not the live asset. Do not upload it)* |
| D13 | Listing text | ✅ | Claims match the declarations and the bundle |
| D14 | Store screenshots | ⚠️ | Screenshot 3 breadcrumb still reads **"Scary"**. See P1-1 |
| D15 | Promo video | ✅ | Reviewed 3 Aug, all 31 frames. Wholesome; end card "Safe · No Ads · No In-app purchases · No Accounts". **Being retained deliberately** — the chaser fix was engineered to keep it valid |
| D16 | "What's new" | ⚠️ | Still "First production release" at v75. Draft text prepared |
| D17 | Active releases across tracks | ❓ | Not enumerated. Bundle Explorer showed v75 on Internal testing, v76 on Production |
| D18 | Teacher Approved | ❓ | Status unknown |

---

## Bottom line

**No Families requirement is affirmatively failed.** Requirements 2, 4, 5, 7 and 8 pass cleanly and are provable from source. Technically the app remains exemplary: two permissions, zero SDKs, zero trackers, zero identifiers, zero network calls, no ads.

**All four rejection bullets appear satisfied**, as before.

**What this pass changes:** the previous audit's residual risk was concentrated in the Scary theme and the IARC questionnaire. The Scary-theme items are now either fixed or knowingly accepted. But reviewing the other six themes properly surfaced **three risks of comparable or greater weight that had never been looked at** — the snarling car in `cars`, the sword in `castle`, and the Pac-Man pastiche in `arcade`.

The honest summary: **the app is in better shape than on 3 August, and the map of what remains is larger than it was.** That is what a real audit does.

---

# PART 2 — Prioritised actions

## 🔴 P0 — before submitting anything

**1. Retrieve the three unchecked IARC answers** — fear/horror, crime/violence, user interaction. Unchanged as the top item, and now more pressing: a snarling wolf, a snarling police car, a dragon and a sword-carrying knight all ship. Under-declaration is the dangerous direction of error.

**2. Get IARC's written determination on the Crude Humor question.** One narrow question: does a static cartoon poop *character*, with no belching, flatulence or vomiting, warrant Yes? Any answer is useful, and it comes from the body that owns the rating.

**3. Do not change any single questionnaire answer in isolation.** Re-derive the whole thing from all nine themes plus the vocabulary in one pass, after 1 and 2.

**4. Bump to version code 77** (name 1.0.4), keep target SDK 36, and re-run the AAB verification script from the build spec. Expect permissions `INTERNET`, `VIBRATE`, `DUMP`; libs `libc++_shared.so`, `libgodot_android.so`; SDKs `NONE`.

**5. Enumerate every active release on every track** before submitting. Google reviews all active tracks.

## 🟠 P1 — cheap, real risk reduction

**1. Re-shoot screenshot 3.** The breadcrumb reads *"Follow the Trail • Scary • Very Large"*. The word is now wrong as well as risky — the theme is called Autumn Forest. This is one screenshot, not the video.

**2. Update "What's new."** Draft prepared; deliberately does not name the theme rename, since framing a presentation change as a remedy implies there was something to remedy.

**3. ❗ Decide on the `cars` chaser.** The most menacing asset in the game, never previously examined. The cheapest fix is the same surgical approach used on the tree: soften the eyes and remove the bared teeth, leaving the silhouette intact. Its baked-in background should be cut to transparency regardless — that is a straight defect.

**4. ❗ Decide on the `castle` knight's sword.** A weapon on a *player* sprite, visible continuously while that theme is active. Cheapest options: swap for a shield (already in the folder), a banner, or a torch.

**5. ❗ Decide on the `karkulka` wolf.** Bared teeth and angry eyes. The same eyes-and-mouth treatment that fixed the tree would work, and the fairy-tale context is a genuine mitigation.

## 🟡 P2 — worth a decision, not urgent

**6. ❗ Decide on the arcade theme's Pac-Man resemblance.** An IP question, not a Families one. Recolouring the ghost and changing the player from a wedge to a distinct character would remove the exposure cheaply.

**7. ❗ Review the Halloween vocabulary thread.** `HALLOWEEN` in 6 languages with 🎃, plus 🎃 for pumpkin in cs and es. Defensible as cultural vocabulary. But the app currently teaches Halloween while displaying a jack-o'-lantern in a theme called *Autumn Forest*, and that combination is easier to question than either alone.

**8. Fix the castle collectible** (D8) — add the missing `.png` extension, or point it at the intended `c_collectible_shield_*.png`.

**9. Cap tier-0 word length at 6 letters** (D9), or make the spawner fall back to a shorter word when letters exceed available path cells.

**10. Review the privacy policy text** at `sites.google.com/view/learning-maze-privacy-policy` — confirm it loads, names the developer and the app, and states no data collection. The User Data policy requires it to be non-editable, non-geofenced, and not a PDF.

**11. Run Google's own `play-policy-insights` skill** against the source. A clean report from Google's tool is a better exhibit than any assertion in this document.

## 🟢 P3 — quality, no policy bearing

**12.** 34 emoji/word mismatches in `EMOJI_TODO.md` §B — worst are `tr GÜVE`, `cs VÁŽKA`, `cs KRTEK`.
**13.** Remove the dead `start` declaration from `themes/scary/manifest.json` (D10).
**14.** Consider re-shooting screenshots 5 and 8 on a brighter theme — the dark forest is 2 of 8 screenshots and 100% of the video.

---

## What NOT to do

- **Do not rename any theme folder.** `game_config.gd` persists `dir_name`, `CharacterCatalog` prefixes character IDs with it, and `player_controller.gd:112` keys the player legibility outline off `"scary"`. Retitle via `translations.csv` only.
- **Do not remove the in-app privacy policy link.** It is a hard requirement (D4). Removing it would create the first affirmative violation in an app that currently has none.
- **Do not drop "5 and under."** It is accurate for a game designed for 4-year-old pre-readers; removing it would be misrepresentation.
- **Do not name the theme "Halloween Forest."** Considered and rejected: the Age 5-and-under criteria are written entirely in terms of what an app *depicts*, so a name cannot mitigate content — but it can attract attention. The same page warns that listing marketing elements are read as evidence about target audience.
- **Do not resubmit a speculative build.**
- **Do not repeat the Godot-ad-SDK theory.** The dex scan was definitive.
- **Do not argue the yellow highlighting in Google's emails.** Client-side, not a Google signal.

---

## Honest limits of this audit

**Verified from source this pass:** permissions, export configuration, network behaviour, SDK references, data practices, all 3652 vocabulary entries against nine categories of policy-relevant emoji and a multi-language weapon/violence word list, all nine themes at sprite level, the maze generator's collectible-placement behaviour under simulation, and every claim this document makes about the code.

**Not verified, because the artefacts are not available here:** the IARC questionnaire answers, active releases across tracks, Teacher Approved status, the privacy policy text, the live store listing assets, and the v77 AAB (which does not exist yet).

**Method note:** the 3 August audit recorded six of nine themes as reviewed "only at asset-listing level". Every significant new finding in this document came from looking at those sprites. Where a previous conclusion is now contradicted — specifically *"the police baton is the only weapon-adjacent object in the game"* — the contradiction is marked ❗ rather than quietly corrected.
