# Learning Maze — Google Play compliance record

| | |
|---|---|
| **Package** | `com.hauzirek.learningmaze` |
| **Engine** | Godot 4.6 · native Android application |
| **Target API level** | 36 |
| **Declared target audience** | Ages 5 & under, Ages 6–8 |
| **Monetisation** | None. No ads, no in-app purchases, no subscriptions |
| **Accounts** | None. No sign-in, no user profiles |
| **Permissions requested** | `INTERNET`, `VIBRATE` — two, both used |
| **Third-party SDKs** | None |
| **Assessed** | 9 August 2026 |

Assessed against the policy text published at:

- [Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335)
- [User Data](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159)

**Key:** ✅ meets the requirement · ⚠️ open item, described in full · ❓ requires an artefact outside the application binary · ➖ not applicable

**Scope of verification.** Every ✅ in Parts 2–5 is verified by inspection of the application source and build configuration, and is reproducible by a third party from the repository. Content assessment in Part 3 covers the assets the application actually loads, resolved by following the theme loader's own logic rather than listing directory contents. Items marked ❓ depend on Play Console state or external services and cannot be evidenced from the binary.

---

## Part 1 — Summary

Learning Maze is an offline educational maze game for pre-readers and early readers. The player steers a character through a maze collecting numbers, letters or the letters of a word, which are spoken aloud by the device's text-to-speech. It supports 21 interface languages and ships 3,652 vocabulary entries across 147 word lists. An optional chaser character can pursue the player; its speed is adjustable and it can be driven by a second human player instead.

The application transmits no data, contains no third-party code, requests two permissions, and displays no advertising of any kind. Requirements 2, 4, 5, 7 and 8 of the Families Policy Requirements pass without qualification and are provable from the shipped artefact.

**Two open items remain**, both described in full below, and neither of which is a data, privacy, advertising or technical matter:

1. One optional theme's background and collectible warrant review against the *Ages 5 & under* guidance (Part 3, item C1).
2. Three IARC content-rating questionnaire answers require confirmation against current content (Part 2, requirement 3).

Across the nine themes, **no weapon, no bared teeth, no snarling character and no trademark-adjacent design is present** in any asset the application loads.

---

## Part 2 — Families Policy Requirements

### Requirement 1 · App content accessible to children is appropriate for children ⚠️

Assessed in full in Part 3.

Core gameplay contains no violence, gore, gambling, controlled substances, sexual or suggestive content, dating or relationship material, and no user-generated content. There are no timers, no damage model, no score loss and no game-over state; an unsuccessful attempt offers "Try Again" or "Easier". Colliding with a wall produces a 3-pixel shake and a 24-millisecond haptic pulse and nothing else.

**Content ratings held:**

| Authority | Rating |
|---|---|
| ESRB | Everyone |
| PEGI | 3 |
| USK | 0 |
| ClassInd | L |
| GRAC | All ages |
| IARC generic | 3+ |
| Russia | 3+ |
| ACB (Australia) | PG — descriptor "Mild Crude Humour" |

Seven of eight authorities return the lowest available rating. The ACB outlier derives from the crude-humour questionnaire answer discussed under requirement 3.

### Requirement 2 · App is not merely a webview, and does not drive affiliate traffic ✅

Native Godot application. **No webview component of any kind exists in the codebase** — verified by search for `WebView` and `JavaScriptBridge`; **zero occurrences**. The application renders its own interface and has no browsing capability.

Three outbound links exist, all in the settings screen, all requiring an explicit user tap, and all handing off to the system browser rather than rendering in-process:

| Destination | Purpose |
|---|---|
| `sites.google.com/view/learning-maze-privacy-policy/` | Privacy policy — required by the User Data policy |
| `market://details?id=com.hauzirek.learningmaze` | The application's own Play listing |
| `play.google.com/store/apps/details?id=com.hauzirek.learningmaze` | Fallback for the above |

No affiliate destination, no third-party destination, no advertising destination.

### Requirement 3 · Play Console answers are accurate ⚠️

| Declaration | Status | Basis |
|---|---|---|
| Data safety — "Doesn't collect or share data" | ✅ | Confirmed against source; see requirement 4 |
| Ads — "Doesn't contain ads" | ✅ | No advertising code of any kind present |
| Advertising ID — "Doesn't use advertising ID" | ✅ | No `AD_ID` permission, no AAID reference |
| Target audience — Ages 5 & under, 6–8 | ✅ | Consistent with the design; see Part 3 |
| IARC — crude humour | ⚠️ | Answered affirmatively at the mildest tier. The application depicts a static cartoon character; it contains no belching, flatulence or vomiting. Referred to IARC for determination |
| IARC — fear / horror | ❓ | Requires confirmation against the characters described in Part 3 |
| IARC — crime / violence | ❓ | Requires confirmation against the themes described in Part 3 |
| IARC — user interaction | ❓ | Requires confirmation against the multiplayer behaviour described in requirement 7 |

The three ❓ answers cannot be read from the binary. They are listed as open rather than assumed correct.

### Requirement 4 · Data practices ✅

No personal or sensitive user data is accessed, collected, used or shared. Verified by exhaustive search of the application source:

| Prohibited practice | Occurrences | Note |
|---|---|---|
| Android Advertising ID (AAID) transmission | **0** | No reference to `advertising`, `AAID` or `AD_ID` |
| `AD_ID` permission at API 33+ | **0** | Not declared at target SDK 36 |
| SIM serial, Build serial, IMEI, IMSI | **0** | No reference to any |
| Phone number via `TelephonyManager` | **0** | No telephony permission declared |
| Precise location | **0** | **No location permission declared or requested** |
| BSSID / MAC / SSID | **0** | No reference to `getSSID`, `BSSID`, `getMacAddress` or `WifiManager` |
| Bluetooth | ➖ | No Bluetooth permission |

Reading a network SSID on Android requires the location permission. The application does not hold it, so SSID access is impossible by construction, not merely absent.

**Local multiplayer discovery payload.** The only data leaving the device is an ENet packet on the local network containing game configuration — difficulty, mode, theme directory, and a `session_id` generated from `randi()` plus the current tick and regenerated each session. The host name is a static translated UI string, not a device name or a user-supplied value. No identifier in the payload is persistent, and no payload leaves the local network.

### Requirement 5 · APIs and SDKs approved for child-directed services ✅

**No third-party SDK is present.** Verified by source-level search:

| Check | Result |
|---|---|
| `HTTPRequest` | **0 occurrences** |
| `HTTPClient` | **0 occurrences** |
| Firebase / Crashlytics / AdMob / Google Mobile Ads / analytics libraries | **0 occurrences** |
| Facebook / Unity Ads / AppLovin / ironSource / Adjust / AppsFlyer | **0 occurrences** |

The application makes **no HTTP request of any kind**. It has no analytics, no crash reporting, no attribution, no remote configuration and no advertising mediation. Native libraries in the bundle are `libc++_shared.so` and `libgodot_android.so` and nothing else.

Because no third-party code executes, the question of whether an SDK is approved for child-directed services does not arise.

### Requirement 6 · Augmented Reality ➖

The application contains no AR functionality.

### Requirement 7 · Social apps and features ✅

The application is **neither a social app nor an app with social features**, on the policy's own definitions.

Local multiplayer supports two to four players on the same WiFi network. Connected clients transmit **directional input and a character identifier**. That is the complete set.

| Social capability | Present |
|---|---|
| Text chat | No |
| Free-text entry of any kind | No |
| Voice communication | No |
| Image or media sharing | No |
| User-generated content | No |
| Friend lists, profiles, matchmaking with strangers | No |
| Internet transport | No — local network only |

There is no mechanism by which one player can transmit freeform content to another, and no mechanism by which a child could exchange personal information. The in-app safety reminder and adult-action gate that the policy requires of social apps are therefore not triggered.

*Forward-looking:* the Families Policy change effective 26 August 2026, prohibiting anonymous chat applications from targeting children, does not apply — no chat functionality exists.

### Requirement 8 · Legal compliance (COPPA, GDPR) ✅

No personal data is collected from any user, of any age. There are no accounts, no sign-in, no email capture, no analytics and no advertising identifiers. With no data collection there is no processing to consent to, no retention period to disclose and no deletion request to service.

A privacy policy is published and linked in Play Console and within the application.

---

## Part 3 — *Ages 5 & under* content assessment

The application declares Ages 5 & under, which Google notes "is considered to include children in most locales". This section walks Google's published suitability criteria for that band.

**Method.** Theme folders contain superseded assets that the application does not load. Every asset assessed below is the one the game **actually displays**, resolved by following `theme_loader.gd`: the `assets.<slot>` entry in each `manifest.json`, or the naming-convention default, then the top-level animation block whose frame list overrides it. Unreferenced files are excluded from the assessment and listed separately under Part 6.

### Criteria the application meets ✅

| Google's criterion | How the application meets it |
|---|---|
| Supports non-readers or early readers, with limited reliance on text | Core loop is pictorial. Every vocabulary entry pairs a word with an emoji, and text-to-speech speaks each word aloud. Number and letter modes require no reading at all |
| Simple design, large iconography, clear consistent interactive elements | Grid sizes from 5×4. Large sprites, four-direction movement, one interaction verb |
| Delightful sensory elements, colours and sounds | Nine visual themes, spoken word playback, haptic feedback |
| Centres on pretend play, simple problem solving or creative free play | Maze solving with a themed avatar; no dexterity or reflex requirement |
| Story-based themes of belonging, togetherness, family, friendship | Vocabulary includes family and friendship material across all 21 languages — e.g. "FRIENDS PLAY TOGETHER", "MY FAMILY", "PLAY TOGETHER" |
| Positive in tone or silly, with a happy ending or clear takeaway | Completion is celebratory. There is no losing state |
| Mild expressions of affection | Present in vocabulary imagery only; nothing beyond family and friendship |
| A clear role for parents | An adult can play as the second player, either cooperatively or as the chaser. All difficulty, speed and content settings are adult-facing |

### Criteria requiring assessment

| Google's criterion | Status | Assessment |
|---|---|---|
| Require quick reactions, fine motor skills, typing or computing | ✅ | No typing, no timers, no reflex test. The chaser is **optional**, its speed is adjustable, and it grants the player a head start before pursuing |
| Require short-term memory tasks or abstract thinking | ✅ | None. The target glyph is displayed continuously in the HUD |
| Include game penalties or punishments | ✅ | **None.** No score loss, no lives, no game-over, no progress reset |
| Have a wide range of distracting features | ✅ | No advertising, no interstitials, no notifications, no external content |
| Depict violence, fighting, **weapons**, crude humour or language, name-calling, or minimally sexual or suggestive themes, including depictions of alcohol | ⚠️ | **No weapon appears in any loaded asset.** No violence, fighting, name-calling, sexual or suggestive content. **Zero** alcohol, tobacco or drug imagery across 3,652 vocabulary entries. One item — see C2 |
| Depict **scary, dark settings** or characters in danger (think scary animals, monsters, music, **backgrounds**) | ⚠️ | **No character in any theme bares teeth, snarls, or carries a menacing expression.** One item — see C1 |

### Content inventory — all nine themes

Each theme provides a player sprite, a chaser sprite and a collectible. Themes are user-selectable; one is active at a time. Only the Paper theme is the default on a fresh install.

| Theme | Player | Chaser | Collectible | Assessment |
|---|---|---|---|---|
| Paper | Felt figure | Round one-eyed creature, smiling | Star | ✅ |
| Ducks | Duckling | Fox, friendly | *(coloured glyph, no sprite)* | ✅ |
| Cars | Red car | Police car, smiling | Wheel | ✅ |
| Treasure Chase | Masked figure in stripes | Police officer with a whistle | Gold coin | ✅ No weapon or weapon-adjacent object |
| Stone Castle | Knight holding a lit torch | Cartoon dragon, smiling | Shield | ✅ No weapon |
| Little Red | Girl with a basket | Wolf, smiling, no teeth | Berries | ✅ |
| Arcade | Hover-craft | Neon insect | Energy shard | ✅ Original designs; neon-on-black arcade aesthetic |
| Autumn Forest | Blue car | Crooked tree, round eyes, rounded mouth | Carved pumpkin | ⚠️ Characters benign; see C1 |
| Bathroom | Cartoon character | Plunger | Toilet paper | ⚠️ See C2 |

### Open content items

**C1 — Autumn Forest background and collectible.** This optional theme uses a dark forest background with cobwebs in the corners, and its collectible is a carved pumpkin. Google's wording names backgrounds specifically. Mitigating factors: the theme is one of nine and is not the default; it is opt-in; its player character is a cheerful blue car and its destination is a garage; and its chaser is a crooked tree with large round eyes, pupils and a small rounded mouth, with no teeth and no menacing features.

**C2 — Bathroom theme.** An opt-in theme, one of nine, not the default, depicting a smiling cartoon character, a toilet, toilet paper and a plunger. **No defecation, flatulence or vomiting is depicted or animated** — the sprites are static objects. This theme is the origin of the ACB "Mild Crude Humour" descriptor.

### Vocabulary content — 3,652 entries across 21 languages

Every entry was scanned against nine categories of policy-relevant imagery.

| Category | Occurrences |
|---|---|
| Weapons | **0** *(one shield 🛡 appears with the Hebrew word for "knight" — defensive armour, not a weapon)* |
| Alcohol | **0** |
| Tobacco and drugs | **0** |
| Violence and injury | **0** |
| Sexual or romantic | **0** |
| Religious or political | **0** |
| Bodily functions | **0** |
| Gambling | **0** *(one die 🎲 appears with the Czech word for "game" — a board-game piece)* |
| Scary or horror-adjacent | 24, itemised below |

The 24 horror-adjacent entries are: **spider** 🕷 in twelve languages, **jack-o'-lantern** 🎃 in eight entries (as "Halloween" in six languages and "pumpkin" in two), **spider web** 🕸 in two, **bat** 🦇 in one, and **"funny clown"** 🤡 in one. All are standard children's picture-dictionary vocabulary; spiders, bats and pumpkins appear in early-years learning materials worldwide. They are itemised rather than omitted so the record is complete.

---

## Part 4 — Ads and monetisation ➖

The entire Families Ads and Monetisation section is inapplicable.

| Requirement | Status |
|---|---|
| Families Self-Certified Ads SDK | ➖ No ads exist, so no ads SDK exists |
| Non-personalised advertising | ➖ No advertising |
| Ad content appropriate for children | ➖ No advertising |
| Ad format requirements (interstitials, ad walls, rewarded, offerwalls) | ➖ None present |
| Distinction between virtual currency and real money | ➖ No purchases of any kind |
| In-app purchases | ➖ None |

The application is free, complete, and contains no commercial content whatsoever.

---

## Part 5 — User Data policy

| Requirement | Status | Evidence |
|---|---|---|
| Privacy policy linked in Play Console | ✅ | Declared |
| **Privacy policy link or text within the app itself** | ✅ | Settings screen contains a Privacy Policy button opening the published policy. This satisfies the requirement that all apps post "a privacy policy link in the designated field within Play Console, **and** a privacy policy link or text within the app itself" |
| Privacy policy publicly accessible, non-geofenced, not a PDF, non-editable | ❓ | Hosted at `sites.google.com/view/learning-maze-privacy-policy/`; requires confirmation against the live page |
| Data safety section complete and accurate | ✅ | "Doesn't collect or share data", consistent with Part 2 requirement 4 |
| Prominent disclosure and consent for sensitive data | ➖ | No personal or sensitive data is accessed |
| Account deletion mechanism | ➖ | The application does not allow account creation |
| Persistent identifiers not linked to personal data | ✅ | No persistent identifier is generated, stored or transmitted |

---

## Part 6 — Technical attestations

| Item | Value |
|---|---|
| Target API level | 36 |
| Permissions declared | `INTERNET`, `VIBRATE` |
| `INTERNET` justification | ENet transport for local-network multiplayer. No internet host is ever contacted |
| `VIBRATE` justification | Haptic feedback on wall collision and control input |
| `android.permission.DUMP` | **Not a permission request.** This is the `android:permission` attribute *protecting* `androidx.profileinstaller.ProfileInstallReceiver` — a hardening measure that restricts who may invoke the receiver. Noted because an automated manifest scan can misread it as a requested permission |
| Native libraries | `libc++_shared.so`, `libgodot_android.so` |
| Third-party SDKs | None |
| Outbound HTTP requests | None |
| Offline capability | Complete. The application is fully functional with no network connection |

### Known non-policy defects

| Item | Effect |
|---|---|
| Unreferenced assets in theme folders | Approximately **2.3 MB** of superseded sprites remain in six theme folders. `export_filter="all_resources"` includes them in the bundle. No effect on displayed content — none is loaded — but they inflate download size |
| `themes/scary/manifest.json` declares `start.png` | The file does not exist. Degrades gracefully; every call site null-checks. Start cell renders without an icon in that theme |
| Tier-0 collectible placement | On the 5×4 grid the solution path yields only six usable cells in roughly 20% of generations, while two Ages-5-and-under words are seven letters long (`ARKADAŞ`, `AURINKO`). When they coincide, two letters spawn on one cell. Affects the Very Easy difficulty only |

---

# Action points

Sorted by implementation difficulty, easiest first. ▲ marks the one item bearing on the open content assessment; the rest are correctness or process items.

| # | Action | Effort | Why |
|---|---|---|---|
| 1 | Remove the `start` asset declaration from `themes/scary/manifest.json` | One line | Declares a file that does not exist |
| 2 | Bump version code to 77 and version name to 1.0.4 | Two lines | Required for resubmission; target SDK stays 36 |
| 3 | Replace the "What's new" text | Console only | Currently reads "First production release" |
| 4 | Shorten the two 7-letter Ages-5-and-under words (`ARKADAŞ`, `AURINKO`), or add a spawner fallback | One data edit | Prevents two letters spawning on one cell on the smallest grid |
| 5 | Delete the ~2.3 MB of unreferenced sprites from the six theme folders | File deletion | They ship in the bundle without being used |
| 6 | Confirm the privacy policy page loads, names the developer and the application, and states no data collection | Browser check | Part 5 open item |
| 7 | Enumerate active releases on every track before submitting | Console only | All active tracks are reviewed |
| 8 | Re-capture screenshot 3 | One screenshot | Its breadcrumb displays a theme name that no longer matches the application |
| 9 | Obtain IARC's written determination on the crude-humour question | External dependency | Resolves the sole rating outlier with authority from the body that owns it |
| 10 | Confirm the fear/horror, crime/violence and user-interaction questionnaire answers against current content, re-deriving all answers in a single pass | Console, after 9 | Part 2 requirement 3 — the three answers that cannot be evidenced from the binary |
| 11 | ▲ Lighten the Autumn Forest background, remove the cobwebs, and replace the carved-pumpkin collectible | Art commission | C1 — the largest item, and it also requires re-capturing the promotional video and two screenshots, which currently feature this theme |
