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
| **Assessed** | 7 August 2026 |

Assessed against the policy text published at:

- [Google Play Families Policies](https://support.google.com/googleplay/android-developer/answer/9893335)
- [User Data](https://support.google.com/googleplay/android-developer/answer/10144311)
- [Manage target audience and app content settings](https://support.google.com/googleplay/android-developer/answer/9867159)

**Key:** ✅ meets the requirement · ⚠️ open item, described in full · ❓ requires an artefact outside the application binary · ➖ not applicable

**Scope of verification.** Every ✅ in Parts 2–5 is verified by inspection of the application source and build configuration, and is reproducible by a third party from the repository. Items marked ❓ depend on Play Console state or external services and cannot be evidenced from the binary. No claim in this document rests on assertion alone.

---

## Part 1 — Summary

Learning Maze is an offline educational maze game for pre-readers and early readers. The player steers a character through a maze collecting numbers, letters or the letters of a word, which are spoken aloud by the device's text-to-speech. It supports 21 interface languages and ships 3,652 vocabulary entries across 147 word lists. An optional chaser character can pursue the player; its speed is adjustable and it can be driven by a second human player instead.

The application transmits no data, contains no third-party code, requests two permissions, and displays no advertising of any kind. Requirements 2, 4, 5, 7 and 8 of the Families Policy Requirements pass without qualification and are provable from the shipped artefact.

**Open items are confined to two areas**, both set out in full below and neither of which is a data, privacy, advertising or technical matter:

1. Two character sprites and three theme-level items warrant review against the *Ages 5 & under* content guidance (Part 3).
2. Three IARC content-rating questionnaire answers require confirmation against current content (Part 2, requirement 3).

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

Native Godot application. **No webview component of any kind exists in the codebase** — verified by search for `WebView`, `JavaScriptBridge` and embedded HTML rendering; zero occurrences. The application renders its own interface and has no browsing capability.

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
| Depict violence, fighting, **weapons**, crude humour or language, name-calling, or minimally sexual or suggestive themes, including depictions of alcohol | ⚠️ | No violence, fighting, name-calling, sexual or suggestive content. **Zero** alcohol, tobacco or drug imagery anywhere in 3,652 vocabulary entries. Two items warrant review — see C1 and C4 below |
| Depict **scary, dark settings** or characters in danger (think scary animals, monsters, music, **backgrounds**) | ⚠️ | Two items warrant review — see C2 and C3 below |

### Content inventory — all nine themes

Each theme provides a player sprite, a chaser sprite and a collectible. Themes are user-selectable; one is active at a time.

| Theme | Player | Chaser | Assessment |
|---|---|---|---|
| Paper | Blue felt figure | Round one-eyed creature, smiling | ✅ Cute, no menace |
| Ducks | Duckling | Fox | ✅ Friendly cartoon, no bared teeth |
| Treasure Chase | Masked figure in stripes | Police officer with a whistle | ✅ No weapon or weapon-adjacent object |
| Autumn Forest | Blue car | Crooked tree with round eyes and a small rounded mouth | ⚠️ Character itself is benign; see C2 for the background |
| Bathroom | Cartoon character | Plunger with a cross expression | ⚠️ See C5 |
| Little Red | Girl with a basket | Wolf | ⚠️ See C3 |
| Stone Castle | Knight | Three-headed dragon, cartoon style | ⚠️ See C1 |
| Cars | Red car | Police car, smiling | ✅ Round friendly eyes, open smile, no teeth |
| Arcade | Yellow wedge | Coloured ghost | ⚠️ See C5 |

### Open content items

**C1 — Knight carries a drawn sword.** In the Stone Castle theme the *player* sprite is a cartoon knight holding a raised sword. Google's *Ages 5 & under* guidance names weapons explicitly. Because this is a player rather than a chaser, it is on screen continuously while that theme is selected. The depiction is a stylised storybook sword with no blood, no target and no combat: the sword is never used, and the game contains no fighting mechanic of any kind.

**C2 — Autumn Forest background and collectible.** The theme uses a dark forest background with cobwebs in the corners, and its collectible is a carved pumpkin. Google's wording names backgrounds specifically. Mitigating factors: the theme is one of nine, is not the default, and is opt-in; its player character is a cheerful blue car and its destination is a garage; the chaser has round friendly eyes and a small rounded mouth.

**C3 — Wolf chaser.** In the Little Red theme the chaser is a cartoon wolf with bared teeth and narrowed yellow eyes. The framing is a recognised European fairy tale, and the wolf never reaches or harms the player — contact simply restarts the attempt. "Scary animals" appears in Google's wording, so the sprite is listed for review notwithstanding its literary context.

**C4 — Bathroom theme.** An opt-in theme, one of nine, not the default, depicting a smiling cartoon character, a toilet, toilet paper and a plunger. **No defecation, flatulence or vomiting is depicted or animated** — the sprites are static objects. This theme is the origin of the ACB "Mild Crude Humour" descriptor.

**C5 — Arcade theme resemblance.** The Arcade theme presents a yellow wedge-shaped player, a coloured ghost chaser and dot collectibles. This is a matter for Google Play's Intellectual Property and Impersonation policies rather than the Families policies, and is recorded here for completeness.

### Vocabulary content — 3,652 entries across 21 languages

Every entry was scanned against nine categories of policy-relevant imagery.

| Category | Occurrences |
|---|---|
| Alcohol | **0** |
| Tobacco and drugs | **0** |
| Violence and injury | **0** |
| Weapons | **0** *(one shield 🛡 appears with the Hebrew word for "knight" — defensive armour, not a weapon)* |
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

---

# Action points

Sorted by implementation difficulty, easiest first. Items marked ▲ bear on the open content assessment in Part 3; the remainder are correctness or process items.

| # | Action | Effort | Why |
|---|---|---|---|
| 1 | Add the missing `.png` extension to `collectible.image` in `themes/castle/manifest.json` | One character | The value reads `"shield_new"`, so the loader returns null and the collectible renders with no sprite |
| 2 | Remove the `start` asset declaration from `themes/scary/manifest.json` | One line | Declares a file that does not exist. Harmless but untidy |
| 3 | Bump version code to 77 and version name to 1.0.4 | Two lines | Required for resubmission; target SDK stays 36 |
| 4 | Replace the "What's new" text | Console only | Currently reads "First production release" |
| 5 | Shorten the two 7-letter Ages-5-and-under words (`ARKADAŞ`, `AURINKO`) or add a spawner fallback | One data edit | On the 5×4 grid the solution path yields only six usable cells in roughly 20% of generations, so a 7-letter word places two letters on one cell |
| 6 | Confirm the privacy policy page loads, names the developer and the application, and states no data collection | Browser check | Part 5 open item |
| 7 | Enumerate active releases on every track before submitting | Console only | All active tracks are reviewed |
| 8 | Re-capture screenshot 3 | One screenshot | Its breadcrumb displays a theme name that no longer matches the application |
| 9 | ▲ Soften the wolf face in Little Red — remove bared teeth, open the eyes | Localised sprite edit | C3 |
| 10 | ▲ Replace the knight's sword with a torch, banner or lantern | Sprite edit | C1 — not a shield; the theme's collectible is already a shield |
| 11 | ▲ Recolour the Arcade ghost and replace the wedge player with a distinct character | Two sprites | C5 |
| 12 | Obtain IARC's written determination on the crude-humour question | External dependency | Resolves the sole rating outlier with authority from the body that owns it |
| 13 | Confirm the fear/horror, crime/violence and user-interaction questionnaire answers against current content, re-deriving all answers in a single pass | Console, after 12 | Part 2 requirement 3 — the three answers that cannot be evidenced from the binary |
| 14 | ▲ Lighten the Autumn Forest background, remove the cobwebs, and replace the carved-pumpkin collectible | Art commission | C2 — the largest item, and it also requires re-capturing the promotional video and two screenshots, which currently feature this theme |
