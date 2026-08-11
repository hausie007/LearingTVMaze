# Learning Maze (Bludiste) - Game Info for Marketing Evaluation

Last updated: 2026-05-28  
Current repo/export version: 1.0.2 build 75  
Package id: `com.hauzirek.learningmaze`  
Primary existing product name in app text: `Learning Maze`  
Project/internal name: `Bludiste`

## Purpose of this document

This is a context handoff for a marketing expert who has not yet studied the game. It is intentionally not a marketing strategy. It answers the practical questions a senior game marketer would want resolved before recommending positioning, store copy, pricing, launch channels, creative direction, PR, ads, or community work.

Where facts are taken from the repository, they are marked as current product facts. Where the repository does not provide the answer, the item is marked as needing owner input.

Primary repo sources reviewed:

- `README.md`
- `game_overview.md`
- `game_specification_v3.md`
- `tester_game_mechanics_overview.md`
- `store_descriptions/old_en.txt`
- `project.godot`
- `export_presets.cfg`
- `data/release_version.txt`
- `data/translations.csv`
- `data/words/`
- `themes/`
- Core scripts in `scripts/`, especially `game_config.gd`, `mission_catalog.gd`, `game_setup_wizard.gd`, `game_hud.gd`, `learning_recap.gd`, `trap_manager.gd`, and multiplayer/network scripts.

External comparison sources used are linked in the competitor section.

## Questions a senior marketing expert wanted answered

The requested marketing expert input checklist can be summarized as follows.

### Product reality

- What is the title, genre, platform, current stage, and one-sentence pitch?
- What does the player do minute to minute?
- What is the emotional promise: calm learning, mastery, competition, family play, or something else?
- What is already built versus aspirational?
- What content exists at launch and how replayable is it?
- What are the most marketable moments that can be shown in video?
- What parts are weak, confusing, or still unvalidated?

### Audience and buyer

- Who is the primary player?
- Who is the actual buyer/decision-maker?
- What age range and skill level is the product designed for?
- What problems does it solve for parents, caregivers, or teachers?
- What objections will adults have before installing or buying?
- Are there regional, language, bilingual-family, or accessibility opportunities?

### Positioning and market category

- What category should the game be marketed in?
- Which genre labels are accurate and which could mislead?
- What is the clearest differentiator?
- What is the "only this game lets you..." statement?
- What should a parent remember after seeing one trailer?
- What claims can be proven with gameplay footage?

### Competitors and comparables

- What are the closest direct competitors?
- What broader educational app comparables shape parent expectations?
- What local multiplayer or phone-as-controller products are relevant?
- Where is this game stronger or weaker than competitors?
- What market expectations around price, ads, privacy, curriculum, and polish already exist?

### Monetization and distribution

- Is the model premium, free, freemium, subscription, IAP, or ad-supported?
- What platforms are confirmed?
- Which platforms are missing?
- What store assets already exist?
- Are regional pricing, launch discounts, Play Store featuring, or family-policy requirements relevant?

### Community, press, and creator fit

- Does the game generate shareable moments?
- Is it fun to watch?
- Are there creators or parent communities likely to care?
- Are there review codes, preview builds, press kit assets, or trailer footage?
- Could creators misunderstand the game?

### Creative assets and messaging inputs

- Which screenshots, clips, GIFs, and trailer beats show the hook fastest?
- Is the logo readable and the art style consistent?
- What are the strongest characters, themes, UI moments, or family-use scenarios?
- What words should marketing use or avoid?
- What misconceptions must be prevented?

### Launch context, metrics, and operations

- What is the launch date/window?
- Is the app already live?
- What baseline metrics exist: installs, conversion, retention, reviews, revenue?
- Is analytics or crash reporting implemented?
- Who handles support?
- What are the known technical and product risks?
- What post-launch updates are planned?
- What budget and internal capacity exist for marketing?

## Short product summary

Learning Maze is a kid-friendly educational maze game for children aged about 4 and up. The child navigates a procedurally generated maze with a D-pad or TV remote, optionally collecting numbers, letters, or word letters in order. The game supports 21 UI and learning languages, voice hints through device text-to-speech, multiple visual themes, difficulty scaling, and local Wi-Fi multiplayer where extra phones can become simple D-pad controllers for a shared bigger-screen game.

The strongest simple pitch:

> A safe, ad-free learning maze for preschoolers that turns a TV remote or phone into a simple D-pad, helping kids practice mazes, letters, numbers, words, and languages in 21 languages.

The more complete pitch:

> Learning Maze is a TV-first educational maze game for young children. Kids guide a character through endless generated mazes, collect letters, numbers, or word letters in order, hear them spoken aloud, and can play alone or together on the local network while phones act as simple controllers.

## Product identity

### Current title and naming

- Internal/project name: `Bludiste`.
- In-app translated title key: `Learning Maze`.
- Store/config URL path and package name use `learningmaze`.
- Existing old English store text opens with "Learning Maze" and describes it as a safe educational maze for TV.

Marketing should confirm the final public name. `Learning Maze` is clear and searchable but generic. `Bludiste` is distinctive but may not be immediately understandable outside Czech/Slovak-speaking markets.

### Genre and category

Accurate labels:

- Educational game.
- Kids maze game.
- Preschool learning game.
- Family-friendly puzzle/maze game.
- TV remote game / Android TV game.
- Local multiplayer family game.
- Early learning: letters, numbers, words, languages.

Labels that could mislead:

- "Language learning app" if it implies full language acquisition.
- "Reading app" if it implies structured phonics curriculum or literacy progression.
- "School curriculum app" if it implies teacher dashboards, assessment, standards alignment, or lesson plans.
- "Party game" if it implies adult Jackbox-style humor or high-energy groups.
- "Offline multiplayer" if it hides the fact that multiplayer requires local network discovery/connectivity.

### Current stage

The repo contains:

- Android APK and AAB exports in the workspace.
- Google Play package id and Play Store URL configured in code.
- Version file: `1.0.2 build 75`.
- Android TV banner, launcher icons, adaptive icon assets, and store-style banners/icons.
- A substantial implemented codebase with solo play, setup wizard, TTS, themes, local Wi-Fi multiplayer, and translations.

Owner confirmations on 2026-05-28:

- The Play Store listing is live in all target regions and was approved by Google on 2026-05-28.
- The current AAB/APK is the intended public launch build.
- Existing usage data is limited to paid testers and the owner. There is no meaningful public install/review/revenue baseline yet.

Still to decide:

- Whether marketing should focus on launch, relaunch, store optimization, or growth after release.

## Core player experience

### What the child does

A typical session:

1. The child or parent opens the game.
2. The home/setup wizard offers large icon cards for missions, themes, maze size, and play mode.
3. The child can start quickly with defaults, or a parent can adjust language, difficulty, theme, controls, voice hints, and multiplayer options.
4. The player navigates a grid-based maze one cell at a time using a D-pad, TV remote, keyboard arrows, or on-screen D-pad.
5. Depending on mission and pickup type, the player:
   - Finds the exit.
   - Collects numbers in order.
   - Collects letters in order.
   - Collects letters of a word in order.
   - Searches for the next visible target.
   - Races other players toward the center.
6. Voice hints can speak letters, numbers, words, and recap content using the device TTS engine.
7. The level ends with a win screen, gotcha screen, or race winner screen.
8. The game can auto-start the next round after a countdown, reducing the chance that a pre-reader gets stuck on an end screen.

### Emotional experience

The intended emotional experience is:

- Safe and low-pressure.
- Calm but playful.
- Mastery-oriented: "I found the way."
- Parent-approved: no ads, no hidden purchases in the existing store copy, no personal data collection according to export privacy settings and old store text.
- Lightly exciting when a chaser is enabled.
- Social/family-oriented when multiplayer is used.

It is not designed as a high-stakes, punishing, fast-reaction arcade game. The core solo mode has no timer and no damage for hitting walls.

### First 30 seconds

Based on the current design docs and wizard:

- Splash screen opens into the setup/home screen.
- The child sees big, icon-heavy cards rather than text-heavy menus.
- Defaults should allow very fast play with about two OK presses.
- The experience should communicate "choose adventure, then play" quickly.

Marketing risk: if first-run UI is visually dense, adults may not immediately understand the learning hook from one screenshot. The best store assets should probably show actual gameplay and learning collectibles, not only the setup wizard.

### After 30 minutes

The replayability comes from:

- Procedural maze generation.
- Seven maze sizes.
- Multiple mission types.
- Numbers, letters, and words.
- 21 learning languages.
- 9 current themes.
- Optional chaser pressure.
- Multiplayer race/co-op/chaser variants.
- Traps in eligible chaser/race sessions.

The game is not content-heavy in the sense of a full curriculum, story campaign, hundreds of bespoke levels, or unlock/progression system. Its depth comes from permutations and repeatable maze play.

## Gameplay systems

### Missions

Current mission archetypes:

| Mission | What it does | Learning/game focus | Chaser |
|---|---|---|---|
| Find Exit | Navigate from start to exit with no pickups. | Spatial reasoning, D-pad control, maze orientation. | Allowed |
| Follow Trail | Collect all visible pickups in the correct order, then finish. | Sequence learning and path planning. | Allowed |
| Find Next | Only the next required pickup is visible; after collecting it, the next appears. | Focused search and dynamic goal-following. | Allowed |
| Race to Middle | Players race from starting corners toward the center. | Competitive maze navigation and optional marker sequence. | Forced off |

### Pickup/learning types

| Pickup type | What appears | Main value |
|---|---|---|
| None | No educational items. | Pure maze navigation, good for very young players or testing controls. |
| Numbers | Sequential numbers starting from 1. | Counting order and number recognition. |
| Letters | Alphabet characters for the selected learning language. | Letter recognition and alphabet order. |
| Words | A localized word is split into collectible letters. | Early spelling, vocabulary, symbol/sound association. |

Words mode also shows an emoji hint when available, and completed rounds can produce a learning recap.

### Difficulty scaling

Maze size scales across seven levels:

- Very Small: 5x4.
- Small: 7x6.
- Medium: 9x8.
- Large: 13x10.
- Very Large: 20x12.
- Huge: 26x13.
- Giant: 36x15.

Marketing relevance:

- The smallest mazes are friendly for 4-year-olds and first-time D-pad users.
- Large mazes can appeal to older siblings or adults who want relaxing maze play.
- The game can credibly claim replayability through procedural generation and size scaling.

### Movement and controls

The game is D-pad-first:

- Google TV / Android TV: TV remote D-pad, OK, Back.
- Android phones/tablets: on-screen virtual D-pad, configurable left/right/off.
- Keyboard/gamepad-style directional input in desktop/testing contexts.

Movement is discrete and grid-based:

- Holding a direction repeats movement after a cooldown.
- Each successful step moves one cell.
- Invalid wall movement gives gentle feedback such as shake and haptics where supported.

This is important for marketing because it differentiates the game from touch-trace maze apps. It can be positioned around "your child can play on the TV with the remote" and "learns directional controls."

### Chaser and traps

Chaser modes add optional pressure:

- Solo chaser: AI chaser pursues the player.
- Multiplayer chaser: one player can be the chaser in some modes.
- Chaser speed has several tiers.
- Head-start logic gives the collector a delay before pressure starts.

Traps:

- Eligible chaser/race sessions can enable traps.
- Each human player can drop one trap.
- A triggered trap causes temporary confusion for 5 moves, with reversed controls and visual feedback.

Marketing relevance:

- Chaser/traps are exciting trailer moments.
- For preschool parent trust, messaging should present them as optional/friendly challenge, not scary failure.

### Win/loss flow

- Win screen: positive reinforcement and next-round options.
- Gotcha screen: appears if the chaser catches the collector.
- Race screen: winner presentation in race mode.
- End screens include auto-countdown behavior to keep play moving unless the player/parent intervenes.

No core solo timer exists in current HUD behavior.

## Educational content

### Learning goals

The game supports:

- Spatial reasoning and maze navigation.
- Directional control: up/down/left/right.
- Number recognition and sequence.
- Letter recognition and alphabet order.
- Basic spelling by collecting word letters.
- Vocabulary reinforcement with words, emojis, and TTS.
- Early foreign-language exposure, especially for bilingual families.
- TV remote/device control skills.

Important limitation: this is not a full literacy curriculum. It teaches recognition, sequence, and playful exposure. It does not currently appear to include teacher dashboards, formal assessments, handwriting tracing, reading comprehension lessons, or adaptive learning paths.

### Languages

The game supports 21 UI languages and 21 learning languages:

- English.
- Spanish.
- French.
- German.
- Italian.
- Portuguese.
- Polish.
- Ukrainian.
- Dutch.
- Turkish.
- Romanian.
- Czech.
- Hungarian.
- Greek.
- Swedish.
- Danish.
- Finnish.
- Norwegian Bokmal.
- Slovak.
- Hebrew.
- Vietnamese.

UI language and learning language can be different. This is a major differentiator for bilingual or multilingual families.

Alphabet support includes:

- Latin alphabet for most supported languages.
- Greek.
- Hebrew, with RTL layout handling.
- Ukrainian.

### Word-list content

The repo currently contains 21 language word-list sets, each with 7 difficulty files. Total word entries counted in `data/words/`: 3,654.

Current word counts by language:

| Language code | Word entries |
|---|---:|
| cs | 277 |
| da | 160 |
| de | 178 |
| el | 140 |
| en | 290 |
| es | 207 |
| fi | 140 |
| fr | 182 |
| he | 147 |
| hu | 140 |
| it | 171 |
| nb | 168 |
| nl | 165 |
| pl | 170 |
| pt | 173 |
| ro | 140 |
| sk | 147 |
| sv | 179 |
| tr | 170 |
| uk | 140 |
| vi | 170 |

Marketing relevance:

- "21 languages" is a strong factual claim.
- "3,600+ word entries" is possible if owner confirms all entries are suitable, localized, and production-ready.
- The claim should be carefully phrased as word-list entries, not unique curriculum lessons.

### Text-to-speech

Voice hints use the device's native TTS engine. The game checks TTS availability and can disable/dim the voice-hints setting when unavailable.

Marketing should say "uses device text-to-speech" or "voice hints where supported." Avoid implying studio-recorded voices or guaranteed voice availability for every language/device.

## Modes and multiplayer

### Solo play

Solo play can be:

- Pure maze.
- Learning maze with numbers/letters/words.
- Maze with AI chaser.
- Race-like modes depending on mission setup.

Solo is the simplest path for marketing screenshots and parent understanding.

### Local Wi-Fi multiplayer

Current design:

- 2-4 players over local Wi-Fi.
- One host device runs the maze/game logic.
- Other devices join as thin clients/controllers.
- Discovery uses local network broadcast.
- Joiners choose characters and then use their phones as D-pad controllers.
- The host displays the actual game view on the TV/tablet/big screen.

Important caveat:

- Multiplayer depends on devices being able to discover each other on the local network. Guest/public Wi-Fi or mobile data may not work.

Marketing relevance:

- This is a distinctive feature for a preschool educational game.
- It creates a clear family/living-room use case: one device on TV, phones as controllers.
- It may be hard to explain in screenshots, so it likely needs a short clip or diagram.

### Multiplayer roles

Supported/expected variants:

- Players guide their own characters.
- Cooperative or competitive depending on mission.
- Race to Middle.
- Collector vs chaser.
- Multiplayer HUD adapts player badges and trackers around the screen.

## Themes and visual identity

### Current themes

The repo contains 9 themes with manifests:

| Theme directory | Display title |
|---|---|
| `arcade` | Arcade |
| `cars` | Cars |
| `castle` | Stone Castle |
| `default` | Paper |
| `ducks` | Ducks |
| `karkulka` | Little Red |
| `poop` | Bathroom |
| `scary` | Scary |
| `thiefs` | Thieves |

Several themes include custom maze wall/floor assets, not only character swaps. Cars, Castle, Bathroom, and Thieves have painted/raised maze asset sets.

Marketing relevance:

- Themes help prevent the game from looking like a single simple prototype.
- They create screenshot variety.
- Some themes may be stronger for store imagery than others. Cars, Castle, Ducks, Thieves, Arcade, and Paper likely have broader parent appeal. Bathroom and Scary may be funny or seasonal but should be used carefully depending on audience and store context.

### Existing brand/store assets

The repo includes:

- App icons and adaptive icon assets.
- Android TV banner.
- Logo images and horizontal/paper logo variants.
- Several large banners in `images/`.
- QR Play Store image.
- Old English store description.

Needs owner/marketer review:

- Whether icon/logo are final.
- Whether screenshots exist outside the repo.
- Whether trailer footage exists.
- Whether store listing assets meet current Google Play image requirements.
- Whether TV-specific screenshots show remote-control play.

## Platform and distribution

### Confirmed/current target platforms

From repo docs and export configuration:

- Android phones.
- Android tablets.
- Google TV / Android TV.
- Android APK/AAB exports.

Android TV is a primary product design target, not an afterthought. The whole UI is focus/D-pad driven.

### Not currently targeted

No current evidence of:

- iOS.
- Apple TV.
- Steam.
- Web.
- Nintendo Switch.
- Xbox/PlayStation.

Marketing should not imply these platforms unless there is a separate roadmap.

### Google Play details

Configured Play Store URL in code:

<https://play.google.com/store/apps/details?id=com.hauzirek.learningmaze>

Owner-confirmed on 2026-05-28:

- Live listing status: released and approved by Google on 2026-05-28.
- Regions: live in all target regions.
- Public launch build: the current AAB/APK is the intended public build.
- Early data: limited to paid testers and the owner so far.

Needs owner/marketer confirmation:

- Price.
- Category.
- Age rating.
- Family/Teacher Approved eligibility/status.
- Screenshots/video currently uploaded.
- Conversion and listing performance.

## Privacy, safety, and trust

### Current claims supported by repo/store draft

Existing old store copy says:

- No ads.
- No hidden purchases.
- Works fully offline.
- Collects no personal data.

Export privacy settings show all listed Apple-style data collection categories as false, tracking disabled, and no tracking domains. Android export only has internet permission enabled, likely for local/network multiplayer; many sensitive permissions are disabled.

Important nuance:

- Solo gameplay and educational content can be described as offline if that is confirmed in the actual build.
- Multiplayer requires local network functionality and therefore is not purely isolated from network use.
- "No data collection" should be confirmed against any live Play Console data safety form, analytics/crash SDKs, website privacy policy, and future support tooling.

### Parent trust angles

Factual trust strengths:

- Designed for preschool/pre-reader use.
- D-pad/focus UI reduces accidental taps.
- No ads or IAP according to existing product copy.
- TTS availability checks instead of failing silently.
- Exit/pause flows are designed to avoid accidental quitting.
- OLED idle/screen protection exists for family TVs.
- Privacy policy URL is configured.

Do not overclaim:

- Avoid "100% safe" in professional marketing unless legal/compliance approves.
- Prefer "ad-free", "no in-app purchases", "no personal data collected" if confirmed.

## Target audience

### Primary player

Children aged approximately 4-8:

- Preschoolers.
- Kindergarteners.
- Early primary school children.
- Pre-readers and early readers.
- Children learning D-pad/remote controls.
- Children who enjoy mazes, simple puzzle navigation, and collecting.

### Primary buyer/decision-maker

Adults:

- Parents.
- Grandparents.
- Caregivers.
- Homeschooling families.
- Bilingual/multilingual families.
- Potentially teachers, therapists, and childcare settings, but the product currently lacks classroom management features.

### Secondary audiences

- Older siblings who may enjoy larger mazes, race mode, and chaser mode.
- Adults who like simple relaxing mazes.
- Families using Google TV/Android TV who want child-safe living-room games.
- Families with old phones/tablets that can become controllers.

### Audience motivations

Children may respond to:

- Finding the path.
- Collecting visible symbols.
- Hearing the game speak letters/numbers/words.
- Choosing themes/characters.
- Racing or chasing family members.

Parents may respond to:

- Safe screen time.
- No ads/IAP.
- No account setup.
- TV remote simplicity.
- Language support.
- Educational value without pressure.
- Shared family play.
- Offline/low-data solo play.

### Likely objections

- "Is this educational enough, or just a maze?"
- "Will my child understand it without reading?"
- "Does it contain ads, tracking, subscriptions, or purchases?"
- "Will multiplayer work on my home network?"
- "Is it too hard/frustrating for a 4-year-old?"
- "Is TTS quality good in my language?"
- "Why choose this over free apps from PBS, Khan Academy Kids, Duolingo ABC, or RV AppStudios?"
- "Is there enough content for repeated use?"
- "Why no iOS?"

## Strengths

### Strongest product differentiators

1. TV-first preschool design.
   The game is built around TV remote/D-pad navigation. Many preschool learning apps are touch-first tablet apps.

2. Phones as controllers for family play.
   Local multiplayer lets a bigger screen host the maze while phones become simple controllers.

3. Multilingual learning depth.
   21 UI and learning languages, independent UI/learning language settings, 3,654 word-list entries, and TTS support are unusually broad for a small maze game.

4. Parent-trust posture.
   Existing copy and export settings support ad-free/no-IAP/no-data-collection messaging if confirmed.

5. Procedural replayability.
   Mazes are generated rather than fixed, helping avoid "finished all levels" fatigue.

6. Developmental fit.
   D-pad controls, no core timer, gentle collision feedback, and very small mazes fit young children better than many twitch games.

7. Clear learning activities.
   Numbers, letters, and word spelling are easy to show in screenshots and understandable to parents.

8. Multiple themes.
   The visual theme system gives variety and makes the same learning loop feel fresh.

### Strongest "show, do not tell" moments

- A child uses a TV remote to move through a maze.
- A phone screen becomes a giant D-pad controller while the maze runs on TV.
- A player collects letters of a word and the HUD fills in the word.
- A number/letter is collected and spoken aloud.
- Four players race toward the center from different corners.
- A chaser closes in but the child reaches the exit.
- Switching from Cars to Castle to Ducks changes the feel of the same maze.
- Parent opens settings and sees UI language, learning language, voice hints, controls, and no ad/purchase clutter.

## Weaknesses and risks

### Product and UX risks

- The product has many configuration options. This is powerful for parents, but store screenshots could look complex if they focus on setup screens.
- Multiplayer discovery may be fragile in some network environments. Public, guest, school, hotel, and restricted Wi-Fi networks may block discovery.
- TTS quality and voice availability depend on device and language. Voice hints may be inconsistent across devices.
- Word-list quality needs linguistic review before making strong educational claims in every language.
- The UI may need testing with actual 4-year-olds to confirm the "two OK presses" promise.
- If visual polish varies by theme, screenshots must use the strongest themes.
- Chaser/traps could be seen as too stressful unless framed as optional.
- Some theme concepts may not be universally marketable or parent-friendly.

### Market risks

- "Learning Maze" is descriptive but generic; discoverability may be hard without strong ASO and visual differentiation.
- Free/ad-free educational giants set high expectations: PBS KIDS Games, Khan Academy Kids, Duolingo ABC, and RV AppStudios.
- Direct maze competitors already exist with high download counts and simple parent-recognizable screenshots.
- Android-only limits reach for families on iPad/iPhone.
- Parents often expect kids educational apps to be free or subscription-based with broad curriculum. A narrow premium app needs a clear value reason.

### Missing validation

No clear evidence in repo of:

- Analytics.
- Crash reporting.
- Store conversion data.
- User testing results.
- Retention metrics.
- Review sentiment.
- Price experiments.
- Marketing budget.
- Launch date/window.
- Trailer performance.

These are important before final strategy.

## Competitor and comparable landscape

This section is context for evaluation, not a strategy recommendation.

### Direct maze competitors

#### Maze for Kids by Crab's Games

Source: [Google Play listing](https://play.google.com/store/apps/details?hl=en-US&id=hu.crabs.kidmaze)

Observed public claims/listing details:

- Cute maze game for all ages.
- Multiple maze sizes.
- Procedurally generated mazes.
- Twelve characters and twelve themes.
- No ads.
- One-time IAP to unlock all content.
- 10M+ downloads on Google Play listing.
- Teacher Approved badge shown.

Comparison:

- Strong competitor for "kids maze" search intent.
- Similar procedural replayability and theme variety.
- Learning Maze differentiates with letters/numbers/words, 21 languages, TTS, Android TV/D-pad-first design, and local multiplayer phones-as-controllers.
- Maze for Kids may have stronger direct maze-market recognition and high download social proof.

#### Kids Mazes: Educational Game by Baby Hub

Source: [Google Play listing](https://play.google.com/store/apps/details?id=com.babyhub.kids.maze.educational.puzzle)

Observed public claims/listing details:

- 50+ educational mazes.
- Categories such as pets, animals, underwater, monsters, veggies, fruits, Christmas, cars/vehicles.
- Touch-and-trace interaction.
- Contains ads and in-app purchases.
- 1M+ downloads on Google Play listing.

Comparison:

- Direct category competitor, but appears more like fixed/tracing maze content.
- Learning Maze can contrast on ad-free/IAP-free trust if confirmed, procedural generation, TV remote controls, multiplayer, and multilingual learning.

### Broader preschool educational comparables

#### ABC Kids - Tracing & Phonics by RV AppStudios

Source: [Google Play listing](https://play.google.com/store/apps/details?gl=US&hl=en-US&id=com.rvappstudios.abc_kids_toddler_tracing_phonics), [RV AppStudios kids apps page](https://www.rvappstudios.com/kidsapp.html)

Observed public claims/listing details:

- Free phonics and alphabet app for toddlers, preschoolers, and kindergarteners.
- Tracing, phonics pairing, letter matching.
- No third-party ads and no in-app purchases.
- 50M+ downloads on Google Play listing.
- RV AppStudios broader page presents many free kids apps with no ads and no IAP.

Comparison:

- ABC Kids is much stronger as a focused English alphabet/phonics/tracing product.
- Learning Maze is broader in languages and living-room maze play, but weaker if judged as a pure phonics/reading curriculum.
- Avoid competing head-on as "better phonics"; instead, treat it as movement-based symbol recognition and playful language exposure.

#### PBS KIDS Games

Source: [Google Play listing](https://play.google.com/store/apps/details?id=org.pbskids.gamesapp), [PBS KIDS app page](https://pbskids.org/apps/pbs-kids-games.html)

Observed public claims/listing details:

- 250+ free educational games.
- English and Spanish.
- Familiar PBS characters.
- Offline play after downloading games.
- 10M+ downloads on Google Play listing.
- Strong brand trust and curriculum-based media positioning.

Comparison:

- PBS has brand, breadth, and free content advantages.
- Learning Maze is much more focused, with stronger TV remote/D-pad specificity and broader language options.
- PBS sets parent expectations that educational kids apps can be free, polished, and safe.

#### Khan Academy Kids

Source: [official Khan Academy Kids page](https://www.khanacademy.org/kids)

Observed public claims:

- Ages 2-8.
- 100% free.
- No ads, no subscriptions.
- Foundational reading, writing, language, math, social-emotional growth, creative play.
- Developed with learning experts.

Comparison:

- Khan is a broad, expert-backed, free learning platform.
- Learning Maze should not pretend to match its curriculum breadth.
- Learning Maze can stand apart as a living-room game, multilingual maze activity, and family multiplayer experience.

#### Duolingo ABC

Source: [Google Play listing](https://play.google.com/store/apps/details?hl=en-US&id=com.duolingo.literacy), [Duolingo ABC site](https://abc.duolingo.com/)

Observed public claims/listing details:

- Preschool to first grade reading/writing.
- 700+ hands-on lessons.
- Alphabet, phonics, sight words, vocabulary, stories.
- Ad-free kids educational games.
- 10M+ downloads on Google Play listing.

Comparison:

- Stronger as a literacy curriculum and English reading pathway.
- Learning Maze has broader learning languages and TV/family gameplay, but less structured reading instruction.

### Phone-as-controller comparables

#### AirConsole

Sources: [AirConsole company page](https://corp.airconsole.com/), [AirConsole how it works](https://airconsole.zendesk.com/hc/en-us/articles/360014567539-How-AirConsole-works), [AirConsole smartphone-controller guidelines](https://documentation.airconsole.com/smartphones-as-controllers)

Observed public claims:

- Turns a TV/desktop/browser/car screen into a console.
- Phones become controllers.
- Focused on local multiplayer with no additional hardware.

Comparison:

- AirConsole validates the "phone as controller" behavior, but is a broader entertainment platform rather than a preschool learning product.
- Learning Maze can borrow the clarity of "big screen + phone controllers" while avoiding adult party-game associations.

#### Jackbox Games

Source: [Jackbox support: getting started](https://support.jackboxgames.com/hc/en-us/articles/15794771245975-How-do-I-get-started-playing-Jackbox-Games)

Observed public claims:

- Players use phones/tablets through `jackbox.tv` as controllers.
- Only the host needs a copy.

Comparison:

- Jackbox proves that phone controllers are understandable to families and groups.
- Learning Maze is not an adult party game; it is a child-safe learning/family version of the shared-screen controller idea.

## Positioning inputs

### Clear differentiator

The strongest differentiator is the combination of:

- Preschool maze learning.
- TV remote / D-pad-first controls.
- 21-language learning content and voice hints.
- Local Wi-Fi family multiplayer with phones as controllers.
- Ad-free/no-IAP/no-data trust posture, if confirmed.

### "Only this game lets you..." statement

Possible factual statement:

> Only this game combines a preschool-friendly TV maze, ordered letters/numbers/word pickups in 21 learning languages, and local family multiplayer where phones become simple controllers.

Needs legal/product review before use as a public claim.

### What players/parents should remember

After one trailer, the ideal memory should be:

- "My child can play an educational maze on the TV with the remote."
- "It teaches letters, numbers, and words in many languages."
- "It is safe: no ads, no hidden purchases, no account."
- "The family can play together using phones as controllers."

### Words that fit

Useful language:

- Safe.
- Ad-free.
- No in-app purchases.
- Private.
- TV-friendly.
- Remote-control friendly.
- D-pad.
- Preschool.
- Early learning.
- Letters, numbers, words.
- Multilingual.
- Voice hints.
- Family play.
- Local multiplayer.
- Procedural mazes.
- Low-pressure.

Use carefully:

- "Offline" because solo may be offline, but multiplayer uses local network.
- "Educational" is accurate but should be tied to specific learning activities.
- "Language learning" should be framed as exposure/practice, not fluency.
- "Reading" should be framed as early letters/words/spelling, not a full reading curriculum.

Avoid unless backed by evidence:

- Curriculum-aligned.
- Clinically proven.
- Teacher approved.
- Improves literacy outcomes.
- Best.
- Unique in the market.
- 100% safe.
- Works on every TV/network/device.

## Monetization and pricing

Known from current repo/store draft:

- Old store copy says no ads and no hidden purchases.
- Export/config does not show obvious billing/IAP integrations.

Needs owner input:

- Is the app free, paid premium, or free with future paid expansions?
- Current/planned Play Store price.
- Regional pricing.
- Launch discounts.
- Whether "no hidden purchases" means no IAP at all.
- Whether future DLC/theme packs are planned.

Marketing note:

- The kids app market contains both free/ad-free giants and ad/IAP-heavy low-trust products. If Learning Maze is paid, the value proposition must make the TV, multilingual, privacy, and multiplayer value obvious.

## Creative asset guidance for evaluator

This is not a strategy, but these are the product facts the creative evaluation should consider.

### Best screenshot/clip subjects

- TV gameplay with maze, player, target collectibles, and clear HUD.
- Word mode showing emoji + word letters.
- Number/letter collection with highlighted next target.
- Phone controller mode next to big-screen maze.
- Multiplayer lobby and race to middle.
- Chaser mode with optional excitement.
- Theme carousel or side-by-side theme variety.
- Settings showing UI language vs learning language.
- No ads/IAP clutter in actual UI.

### Assets that already exist in repo

- App icon variants.
- Android TV banner.
- Several Learning Maze logo/banner images.
- Theme art.
- Icons for missions and pickups.
- Old English store text.

Needs owner input:

- Current screenshots.
- Trailer.
- Short vertical clips.
- Press kit.
- Website/landing page.
- Final store icon/capsules.
- Review/preview build distribution process.

## Launch and operational context

Known:

- Version `1.0.2 build 75`.
- Android export configuration exists.
- Play Store release is live in all target regions and was approved by Google on 2026-05-28.
- Current AAB/APK is the intended public launch build.
- Existing data is limited to paid testers and the owner; meaningful public installs, reviews, ratings, and revenue are not yet available.
- Privacy policy URL is configured:
  <https://sites.google.com/view/learning-maze-privacy-policy/>
- Play Store URL is configured:
  <https://play.google.com/store/apps/details?id=com.hauzirek.learningmaze>

Needs owner input:

- Whether marketing should treat this as launch support, store optimization, relaunch, or post-release growth. Current answer: TBD.
- Current installs, conversion rate, retention, revenue, reviews, and ratings once public traffic exists.
- Whether any paid ads or ASO work has already been tried.
- Support email/process.
- Crash reporting/analytics plan, if any.
- Compliance status for Google Play Families / Teacher Approved.
- Age rating.
- Marketing budget.
- Who approves final claims and assets.

## Metrics the marketer should request

If available, gather:

- Store page impressions.
- Store page conversion rate.
- Acquisition sources.
- Install/uninstall counts.
- Day 1 / Day 7 retention.
- Session length.
- Rounds played per user.
- Most-used themes.
- Most-used modes.
- Language selections.
- TTS enabled/disabled rates.
- Multiplayer host/join success rates.
- Crash/ANR rates, especially on Android TV.
- Reviews and review keywords.
- Support tickets.
- Refunds, if paid.

If no analytics are implemented, that is consistent with the privacy-forward posture, but it limits marketing diagnosis. Store-console-level data may be the main measurement source.

## Main strengths for marketing evaluation

- Very clear parent-safe promise if claims are verified: no ads, no IAP, no data collection.
- Android TV / Google TV orientation gives a distinctive living-room niche.
- D-pad controls are rare among preschool learning apps and very relevant for TV.
- The language support is broad for an indie educational game.
- Multiplayer with phones as controllers is unusual and visually demonstrable.
- Procedural mazes create long-tail replayability without requiring hundreds of hand-authored levels.
- The product has several easy-to-understand learning modes.
- A family can play together without buying extra controllers.

## Main weaknesses for marketing evaluation

- Generic name and crowded "kids learning" app category.
- Lack of big-brand trust compared with PBS, Khan, Duolingo, and RV AppStudios.
- No evidence in repo of user testing, analytics, or proven learning outcomes.
- Android-only scope excludes many iPad-first families.
- TTS is device-dependent.
- Multiplayer setup may be hard to communicate and may fail on restricted networks.
- Educational depth is more "playful reinforcement" than structured curriculum.
- If paid, the product must compete against strong free/ad-free alternatives.
- If free, monetization/business sustainability needs explanation.

## Recommended factual positioning boundaries

Safe factual territory:

- Educational maze game for kids aged 4+.
- Works with TV remote/D-pad and on-screen controls.
- Numbers, letters, and words.
- 21 UI/learning languages.
- Device TTS voice hints where available.
- Procedurally generated mazes.
- Local Wi-Fi multiplayer for 2-4 players.
- Phones can act as controllers.
- No ads/no in-app purchases/no data collection, if confirmed against live store and code.

Claims needing evidence before public use:

- Improves reading.
- Teaches a foreign language.
- Best educational maze.
- First/only app with these features.
- Teacher approved.
- Curriculum-based.
- Works fully offline in all modes.
- Works on all Google TV devices.
- No data collected, unless verified against live data safety and all dependencies.

## Open questions for the owner

These should be answered before a detailed marketing strategy is prepared.

1. What is the final public title: Learning Maze, Bludiste, or another name?
2. What is the price/business model?
3. Are ads and IAP permanently excluded?
4. Is "no data collected" legally/compliance-approved for the current build?
5. Once public traffic starts, what Play Store metrics are available?
6. Once public traffic starts, what are current ratings/reviews and common complaints?
7. Should marketing focus on launch support, relaunch, store optimization, or post-release growth?
8. Has any user testing with children aged 4-8 been done?
9. Which themes are considered final and marketing-safe?
10. Which visual assets are final?
11. Is there a trailer or gameplay capture?
12. Is multiplayer stable on typical home routers?
13. What devices have been tested: phones, tablets, Google TV, Android TV boxes, Chromecast?
14. Is iOS/Apple TV planned?
15. Is there a post-launch roadmap: themes, languages, modes, curriculum, parent dashboard?
16. Is there a support workflow and response owner?
17. What regions/languages matter most commercially?
18. What marketing budget and execution capacity exist?
19. What would count as success after 30 days?
20. Are there any legal/IP/licensing concerns around assets, word lists, fonts, TTS, themes, or translations?

Answered owner confirmations on 2026-05-28:

- The app is live on Google Play in all target regions and was approved by Google on 2026-05-28.
- The current AAB/APK is the intended public launch build.
- Existing install/review/revenue data is limited to paid testers and the owner.

## Bottom-line product read for marketing expert

Learning Maze is best understood as a safe, family-oriented, TV-first preschool maze game with meaningful educational overlays rather than as a full curriculum app. Its most defensible market difference is the intersection of D-pad/Android TV play, multilingual letters/numbers/words, procedural mazes, and local family multiplayer with phones as controllers.

The marketing challenge is that the kids educational market is crowded and includes extremely strong free/ad-free brands. The game should therefore be evaluated around the niches where it is genuinely different: living-room play, remote-control accessibility, multilingual families, privacy-conscious parents, and shared family maze play.
