# Learning Maze (Bludiste) — Game Design, UX & Technical Specification (v3)

## 1. Executive Summary & Game Identity

**Learning Maze (Bludiste)** is an educational, procedurally generated maze game designed specifically for children aged 4 and up (pre-readers to early primary school children). Built in Godot 4.6, the game targets a cross-platform deployment across Android phones, tablets, and Google TV (Android TV).

```
+-------------------------------------------------------------------------+
|                          Learning Maze (Bludiste)                       |
+-------------------------------------------------------------------------+
|  [Target Audience]  Children aged 4+ (Pre-readers to early readers)    |
|  [Supported Tech]   Godot 4.6, ENet Host-Authoritative local WiFi, TTS  |
|  [Input Paradigm]   D-Pad First (IR TV Remote & On-Screen Virtual D-Pad) |
|  [Core Objective]   Spatial awareness, counting, letters, spelling      |
|  [Deployments]      Android TV / Google TV, Android Phones & Tablets    |
+-------------------------------------------------------------------------+
```

### 1.1 The Core Player Value Proposition
At its heart, Learning Maze provides an accessible, completely frustration-free, self-correcting spatial and cognitive learning environment. It takes a classic gaming mechanic—the maze—and blends it with optional educational collectibles (numbers, letters, or spelling words) in 21 languages. Whether playing in single-player mode, co-op with a family member, or competing in a local multiplayer race, the experience is designed to encourage self-directed learning and fine motor control without the anxiety of timers, health bars, or punishing game-over screens.

---

## 2. Target Audience Psychology & UX Design

Designing for four-year-old pre-readers requires a complete departure from traditional video game design conventions. Below are the psychological foundations and corresponding UX implementations that govern the game.

### 2.1 Designing for Pre-Readers (No Text Barrier)
Children in the target demographic cannot read instructions or navigate text-heavy menus. 
* **Visual & Icon-Driven Interface:** Every menu selection is accompanied by large, distinct, colorful icons and character previews. Confirmed actions are shown by changing the card states.
* **Text-to-Speech (TTS) Voice Hints:** Any educational collectible (letters, numbers) or tutorial slide can be read aloud using the device's native TTS engine. A child hears the letter "A" or the word "Apple" spoken as they interact, bridging the gap between sound, symbol, and spatial movement.
* **Color Psychology Language:** The interface uses a strict color coding system to guide the eye without text:
  * **Blue (`#1188FF`):** Indicates gameplay controls, setup options, and difficulty settings.
  * **Yellow (`#FFCC00`):** Used for auxiliary navigation, system configurations, and learning tools (languages, themes, help slides).
  * **Green (`#22AA44`):** Denotes cooperative and multiplayer lobby elements.

### 2.2 Low Cognitive Load & Frustration-Free Play
Traditional failure conditions (dying, running out of time, score penalties) discourage young children, leading them to close the app.
* **No Time Constraints:** The core solo gameplay does not feature a countdown timer or a ticking clock. Children are permitted to explore the maze, trace dead ends, and find their way back at their own pace.
* **Self-Correcting Wall Collisions:** Bumping into walls does not damage the player. Instead, it triggers a brief, gentle screen shake and haptic feedback. This physically and visually communicates "blocked path" without using a red error label or sound effects that imply failure.
* **Positive Reinforcement Win Loops:** The end-game states are warm and inviting. They utilize a textured **parchment aesthetic** to feel premium, offering immediate transition options like "Next Round" or "Harder."

### 2.3 Developing Motor Skills & Device Competency
The game acts as a bridge for developing remote control and hand-eye coordination.
* **Directional Translation:** Pre-readers often struggle with swipe-to-move or analog controls because they require continuous fine motor pressure. Discrete, digital D-pad controls (Up, Down, Left, Right) map 1-to-1 with spatial movement, teaching children how to translate physical inputs on a TV remote or a phone screen into virtual movement.

---

## 3. Gaming Mechanics & Core Systems

Learning Maze relies on a robust grid-based gameplay loop where the host device coordinates maze structure, collectible spawning, and player movement.

```
       +------------------------------------+
       |       Choose Game Setup Wizard      |
       +------------------------------------+
                         |
                         v
       +------------------------------------+
       |      Procedural Maze Generation    |
       +------------------------------------+
                         |
                         v
       +------------------------------------+
       |       Spawn Player & Collectibles  |
       +------------------------------------+
                         |
                         v
       +------------------------------------+
       |    Continuous Movement Loop (D-Pad)| <---+
       +------------------------------------+     |
                         |                        |
                         v                        |
               Is Move Blocked?                   |
               /              \                   |
            (Yes)             (No)                |
             /                  \                 |
            v                    v                |
      Screen Shake          Slide Avatar          |
      Haptic Buzz                 |               |
            |                     v               |
            |             Collect Target?         |
            |             /              \        |
            |          (Yes)             (No)     |
            |           /                  \      |
            |          v                    |     |
            |      Update HUD Progress      |     |
            |      TTS Letter/Word Sound    |     |
            |             \                 /     |
            +------------->\               /------+
                            v             /
                     Reach Exit/Center?  /
                     /                \ /
                  (Yes)               (No)
                   /
                  v
             Win / Gotcha Screen
             Auto-countdown Play Loop
```

### 3.1 Grid-Based Procedural Maze Navigation
* **Maze Generation:** The maze is procedurally carved on a perfect grid using an iterative Depth-First Search (DFS) algorithm. This ensures that a single, continuous, solvable path exists between the start and end coordinates without isolated loops.
* **Spawn Balancing:** In standard play modes, the player character is spawned in the bottom-left corner of the grid, while the exit ladder is spawned in the top-right corner, ensuring maximum travel distance.
* **Collectible Placement:** Educational collectibles (numbers, letters, or spelling words) are scattered along the valid pathways. In modes where collection order is strict, the spawner spreads targets across the layout so the path between chronological items naturally spans different branches of the maze.

### 3.2 Continuous Movement & Input Repeating
Children naturally hold buttons down rather than tapping them repeatedly. If holding down a key does not repeat the action, a child will assume the game has frozen.
* **Cooldown-Driven Polling:** Instead of responding strictly to discrete keypress events, the movement system polls directional input. If a direction is held, it moves the player by exactly one grid square, then starts a **0.20-second cooldown**.
* **Visual Slide Interpolation:** To prevent the character from jarringly tele-porting between grid squares, the movement triggers a smooth **0.12-second sprite slide tween** to interpolate the position between cells. This creates a visual slide effect that feels fluid while preserving grid collision rules.

### 3.3 Collision & Blocked Path Feedback
When a player attempts to walk through a solid wall:
* **Input Intercept:** The physics and grid checker intercepts the invalid step. The player character's logical grid coordinates remain unchanged.
* **Haptic Rumble:** On supported mobile devices, a **24ms haptic buzz** is triggered, providing physical resistance feedback.
* **Wall Shake:** The player's sprite triggers a minor 3-pixel translation offset in the direction of the blocked movement and back, visually showing the collision.

### 3.4 Mission Archetypes
The game features four distinct mission archetypes, each providing a different core objective:

| Mission | ID | Description | Primary Focus | Chaser Allowed? |
|---|---|---|---|---|
| **Find Exit** | `find_exit` | Pure spatial navigation from start to exit. No collectibles spawn. | Basic orientation, obstacle avoidance. | Yes |
| **Follow Trail** | `follow_trail` | Collectibles spawn throughout the maze. The exit remains locked/disabled until all items have been gathered in the correct sequence. | Sequential ordering, short-term path planning. | Yes |
| **Find Next** | `find_next` | Only the immediate next collectible target is visible in the maze. Collecting it triggers the appearance of the next. | Dynamically adapting paths, focused visual searches. | Yes |
| **Race to Middle** | `race_middle` | A symmetrical maze layout. 2-4 players (or player vs AI) start at the corners and race to reach the center cell. | Speed, competitive path selection. | No (Forced Off) |

### 3.5 Educational Collectible Types
* **None:** Pure maze navigation. Excellent for toddlers focusing entirely on motor controls.
* **Numbers (`numbers`):** Spawns digits `1, 2, 3 ... N`. Teaches sequential counting.
* **Letters (`letters`):** Spawns letters of the alphabet in order. Fully supports Latin (A-Z), Greek (Α-Ω), Hebrew (א-ת), and Ukrainian (А-Я) layouts.
* **Words (`words`):** Chooses a word from the localized language vocabulary file. The letters of the word spawn in the maze. Collecting them one-by-one spells the target word in the HUD. Spaces are skipped automatically to handle compound nouns. An emoji preview appears in the HUD to reinforce vocabulary.

### 3.6 Difficulty Scales (7 Levels)
Grid sizing scales dynamically to match different developmental stages:
1. **Very Easy (5x4):** Fits on a single screen without camera scrolling. Perfect for 4-year-olds.
2. **Easy (7x6):** Minor scrolling, simple branch paths.
3. **Medium (9x8):** Moderate branching, introduces basic spatial choices.
4. **Hard (13x10):** Requires camera tracking, features deep dead ends.
5. **Very Hard (20x12):** Suitable for older children.
6. **Insane (26x13):** High branching factor.
7. **Unbelievable (36x15):** The ultimate cognitive challenge.

---

## 4. Comprehensive Menu Navigation & UX Walkthrough

The navigation system is designed so that a pre-reader can move from launching the app to playing the game in exactly **two button presses (OK, OK)**, while still offering robust configuration paths for parents and older children.

```
                  +--------------------------+
                  |       Splash Scene       |
                  +--------------------------+
                               |
                               v
            +--------------------------------------+
            |    Step 1: Mission Selection (HOME)  |<------------------+
            |  - Large cards, Theme, Maze size     |                   |
            +--------------------------------------+                   |
              /         |                      \                       |
       (Join Card) (Press Mission Card)      [Settings] or [Help]      |
           /            |                          \                   |
          v             v                           v                  |
   +------------+ +--------------------------+   +-------------------+ |
   | Join Setup | | Step 2: Pickup Selection |   | Settings or Help  | |
   +------------+ |  - Filters allowed pickups|   |  - Save and exit  | |
          |       +--------------------------+   +-------------------+ |
          |             |                                |             |
          |             v                                v             |
          |       +--------------------------+   +-------------------+ |
          |       | Step 3: Play Mode Selection| |  Return to HOME   |-+
          |       |  - Solo vs Multi choice  |   +-------------------+
          |       +--------------------------+
          |             |
          v             v
   +-----------------------------------------+
   |             Gameplay Screen             |
   |  - Controller Mode on Client devices    |
   |  - Main Maze Rendering on Host devices  |
   +-----------------------------------------+
                        |
                        v
   +-----------------------------------------+
   |          Win / Gotcha Screens           |
   |  - 10s auto-countdown to repeat round   |
   +-----------------------------------------+
```

### 4.1 The Game Setup Wizard (HOME) — `game_setup_wizard.gd`
This is the central lobby and home screen. It uses **Progressive Disclosure** to present options sequentially rather than exposing all configurations simultaneously, avoiding cognitive overload.

#### Step 1: Mission Selection (Active on Load)
* **What the User Sees:** A horizontal row of large, colorful cards representing the mission types (Find Exit, Follow Trail, etc.). Below the cards sit the cyclical **Theme** and **Maze Size** selectors, flanked by character previews. 
* **Why It Matters:** It gets the core objective in front of the child immediately. The default selections are always valid, so simply pressing the "OK" key twice bypasses configuration and starts the game.
* **The Dynamic Join Card:** When the background network thread discovers a local host broadcasting, a bright **Green Join Card (`#22AA44`)** is dynamically inserted into the middle of the mission card row. 
  * *UX Polish:* When this card is highlighted, all non-related selectors (theme, maze size, logo) fade to **35% opacity**. This visually declutters the screen, signaling that the child is joining someone else's setup where host settings take precedence. Pressing it opens the **Join Host List Overlay**.
* **Step 1 Focus Chain:**
  ```
  [Mission Card 1] <---> [Green Join Card] <---> [Mission Card 2]
                                |
                                v (D-Pad Down)
                     [Theme Selector (L/R)]
                                |
                                v (D-Pad Down)
                   [Maze Size Selector (L/R)]
                                |
                                v (D-Pad Down)
                   [Settings ⚙] <---> [Help ?]
  ```

#### Step 2: Pickup Selection
* **What the User Sees:** The Step 1 cards collapse upward into a compact, read-only breadcrumb button (e.g., `▾ Follow Trail • Space • Easy`). A new row of cards expands below, showing valid educational pickups (Numbers, Letters, Words, None) matching the selected mission. A cycling **Learning Language** selector appears below.
* **Why It Matters:** It isolates the educational choice from the game rules. If a selected mission only permits a single pickup type (for example, *Find Exit* only allows *None*), this step is automatically skipped, speeding up the path to gameplay.
* **Step 2 Focus Chain:**
  ```
  [Step 1 Breadcrumb Button (Press to expand/go back)]
                                |
                                v (D-Pad Down)
                   [Pickup Card 1] <---> [Pickup Card 2]
                                |
                                v (D-Pad Down)
                  [Learning Language Selector (L/R)]
                                |
                                v (D-Pad Down)
                   [Settings ⚙] <---> [Help ?]
  ```

#### Step 3: Play Mode Selection
* **What the User Sees:** Step 2 collapses into a second breadcrumb button. A final row of cards appears, split by a vertical divider:
  * **Left Side (Single Player):** `[Play Alone]` and `[+ Chaser]` (blue hues).
  * **Right Side (Multiplayer):** `[Play Together]` and `[vs Chaser]` (green hues, badged with 🟢 2-4 Players).
  * **Below:** Contextual selectors emerge: **Character Selector** (always shown for multiplayer) and **Chaser Speed** (shown when a chaser mode is selected).
* **Why It Matters:** It finalizes the session type. Once an action card is pressed, the game launches instantly.
* **Step 3 Focus Chain:**
  ```
  [Step 1 Breadcrumb Button] <---> [Step 2 Breadcrumb Button]
                                |
                                v (D-Pad Down)
                [Play Alone] <---> [Play Together] (Green)
                                |
                                v (D-Pad Down)
                   [Character Selector (L/R)]
                                |
                                v (D-Pad Down)
                   [Settings ⚙] <---> [Help ?]
  ```

#### Collapsed Breadcrumbs & Smart Back Navigation
* **Progress Recovery:** Breadcrumbs are focusable. Pressing a breadcrumb re-expands that step, hiding subsequent steps to let users easily modify early decisions.
* **Smart Back (`ui_cancel`):** Pressing the "Back" key moves the focus backward through the wizard steps. If a step was auto-skipped during forward progression, the back system skips it in reverse as well, ensuring fluid transitions.

---

### 4.2 Multiplayer Host Setup & Lobby
* **Host Setup Screen (`host_setup.gd`):** When hosting is chosen, this screen lets the host confirm local settings (language, character, chaser speeds) before launching the network session. Its visual layout mirrors the Join Setup screen, maintaining design consistency.
* **Host Lobby (`host_lobby.gd`):** The waiting room before a local multiplayer game begins.
  * **What the User Sees:** A row of player slots `[Slot 1] ... [Slot 4]`. The host occupies Slot 1 (marked with a yellow "You" label). Empty slots display dashed borders that **pulse slowly in opacity (from 45% to 100% using a 1.2s sine wave)**, signaling that the slot is waiting for a player. Below, a scrollable panel provides a 4-step "How to Join" guide instructing players to connect to the same WiFi network. *(The guide does not name the network: reading the SSID requires the location permission, which the app deliberately does not hold.)*
  * **Emulated Players (Crucial Testing Feature):** Developers and testers can focus an empty slot and press **OK** to spawn an emulated peer. This populates the slot with a random character. Selecting an occupied emulated slot kicks them. This allows full testing of multiplayer grid sizing, race HUD layouts, character conflicts, and lobby behaviors on a single device.
  * **Start Button Logic:** The green `[Start Game]` button remains disabled and shows "Waiting for players..." until at least two slots are occupied. Once ready, it lights up, prompting the host to begin.

---

### 4.3 Join Flow & Remote Controller Mode (`join_flow.gd`)
This is the secondary device's experience, designed to turn a physical phone into a pure remote controller.

```
       +------------------------------------+
       |       Join Setup Panel (Phase 2)    |
       |  - Host configuration read-only    |
       |  - Scrollable characters selector  |
       |  - Taken avatars shown in grey     |
       +------------------------------------+
                         |
                         v (Press [Join Game])
       +------------------------------------+
       |      Waiting in Network Lobby      |
       |  - Receives host start RPC signals |
       +------------------------------------+
                         |
                         v (Host starts game)
       +------------------------------------+
       |      Controller Mode (Phase 3)      |
       |  - All menu UI elements hidden     |
       |  - Screen morphs to pure D-Pad     |
       |  - Background matches character     |
       +------------------------------------+
                         |
                         v
       +------------------------------------+
       |  - D-Pad touches forwarded to Host |
       |  - Reads dynamic goal TTS speech   |
       +------------------------------------+
```

#### Phase 1 & 2: Discovery and Join Setup
* **What the User Sees:** Upon selecting a host from the discovery card, the device displays host configuration summaries and a list of character avatars. 
  * **Taken Avatars:** Characters already selected by other lobby members are shown in grey with locked badges.
  * **Layout Controls:** A toggle allows the user to position the on-screen virtual D-Pad on the left or right side of the screen, or turn it off entirely if they are using a hardware controller connected to their phone.
* **Back Safety:** Pressing "Back" unjoins the session cleanly, returns to the wizard, and displays a localized "Disconnected" notification.

#### Phase 3: Pure Remote Controller Mode
Once the host starts the match, the joiner's screen morphs completely.
* **What the User Sees:** Every menu button, list, and setting vanishes. The screen displays a massive virtual D-Pad in the selected orientation (left or right) alongside a large icon of the player's character. The remaining screen space is dedicated to a high-contrast **Goal Display** (e.g., "Collect all letters" or "Go to the Exit").
* **Avatar Accent Matching:** The controller's color scheme (buttons, highlights, background glow) automatically changes to match the selected character's color palette.
* **Why It Matters:** Keeping a phone controller interface simple means children don't have to look down at their hands while playing. The giant directional buttons are easily pressed with thumbs while their eyes remain focused on the TV or tablet screen.

---

### 4.4 Settings & Help Menus
* **Settings Menu (`settings_menu.gd`):** Uses a strict vertical stack of options (Quality, UI Language, Learning Language, Voice Hints, On-screen controls).
  * **Cycling Selectors:** Each option uses a common selector pattern:
    * Flanking arrows (`<` and `>`) appear only when the button is focused.
    * Pressing Left or Right cycles the value immediately and plays a click sound.
    * Pressing OK advances the selection.
  * **Real-time Live Previews:** Changing the UI language immediately updates all text on screen without requiring a reboot. Changing the on-screen controls updates the position of the D-pad overlay on the fly.
  * **TTS Status Diagnostics:** Below the "Voice Hints" option, a status label reads "Checking TTS...". If the device lacks a compatible text-to-speech engine, the text changes to a red "TTS not available", and the button is disabled and dimmed to 40% opacity.
* **Help Menu (`help_menu.gd`):** A child-friendly, 7-slide visual tutorial.
  * **What the User Sees:** Large, illustrated slides explaining the core concepts (Welcome, The Maze, You, Exit, Pickups, Chaser, Themes) using assets from the currently active theme.
  * **Why It Matters:** The tutorial is completely narrated by the TTS engine. Pre-readers can swipe or press D-Pad Right to listen to the rules of the game like a picture book.

---

### 4.5 In-Game HUD, Goal HUD, & Win/Gotcha Screens
* **In-Game HUD (`game_hud.gd`):** A clean 160px header anchored at the top of the screen.
  * **Dynamic Collectible Tracker:** Shows the letters of the word being spelled or the numbers in sequence. Uncollected items are dimmed. When collected, the corresponding character bounces in scale and lights up in bright yellow.
  * **Dynamic Goal HUD:** A text field displaying the immediate instruction (e.g., "Find the next number"). This text updates dynamically as the game state changes.
  * **Race Mode Layout:** In 3-4 player games, the HUD automatically reconfigures. Player badges move to the outer edges of the screen, keeping the center of the maze clear so players can see their characters.
* **Win/Gotcha Screens (`win_screen.gd`):** Rendered on a CanvasLayer using a parchment paper graphic style.
  * **Win Screen:** Displays "You Win!" or names the winning player, showing a large render of their character. Offers quick-launch buttons: `[Next Round]`, `[Harder]`, and `[Main Menu]`.
  * **Gotcha Screen:** Shows if a player is caught by the AI or another player in chaser mode. Displays "Gotcha!", offering `[Try Again]` and `[Easier]` buttons.
  * **Auto-Play Countdown Loop:** To keep children engaged, both screens feature a prominent **10-second countdown**. If no input is received, the game automatically launches the next round or restarts the current maze. The countdown pauses immediately if any D-pad input is detected, giving parents time to make adjustments.

---

## 5. Core Design Philosophy & Business Rationales

This section outlines the business and psychological rationales behind key design choices, serving as a guide for developers refactoring the codebase.

```
+-----------------------------------------------------------------------------------+
|                        THE BUSINESS & USER EXPERIENCE "WHYs"                      |
+-----------------------------------------------------------------------------------+
|  [D-Pad First]         -> Target smart TVs, eliminate touch drift/swipe errors    |
|  [OLED Burn-in]        -> Protect high-end family TV screens, reduce returns      |
|  [Progressive Wiz]     -> Zero cognitive block, toddler-friendly 2-tap gameplay   |
|  [Host-Authoritative]  -> Zero client desync, no local calculations on old phones  |
|  [Pre-Focused "No"]    -> Child safety, prevents accidental exits                 |
|  [Auto-Countdown]      -> Continuous engagement, keeps loop running automatically |
+-----------------------------------------------------------------------------------+
```

### 5.1 Why a D-Pad First and Focus-Driven Design?
* **Business Perspective (TV Engagement):** The living room TV remains a primary entertainment hub for young children. By making the entire game fully operable via a D-Pad (Up, Down, Left, Right, OK, Back), the game runs natively on Smart TVs (Google TV, Fire TV, Apple TV) using standard IR remote controls.
* **UX Perspective:** Young children often struggle with complex drag-and-drop or swipe gestures on touchscreens. A physical or virtual button press has a clear start, stop, and mechanical feedback.
* **Developer Mandate:** To ensure that the cursor never gets lost or trapped in a menu dead end, every screen transition must explicitly call `grab_focus()` on the primary button. Focus neighbors must be hardwired in Godot, avoiding automatic engine calculations which often fail on complex layouts.

### 5.2 Why OLED Screen Protections?
* **Business Perspective (Device Protection):** The game is designed to be played in family living rooms, where TVs often run static menu screens for hours. To prevent burn-in on OLED screens, an active protection system is critical.
* **UX Perspective:** An `IdleManager` monitors input inactivity. If no input is received for a set period, the screen automatically dims. Pressing any D-pad button or touching the screen instantly restores full brightness, keeping the screen protected without interrupting play.

### 5.3 Why a 3-Step Wizard with Progressive Disclosure?
* **Business Perspective (Session Retention):** Setting up multiplayer or choosing categories in educational apps is often slow and confusing, causing children to close the app.
* **UX Perspective:** By revealing choices one step at a time, children can configure games on their own. The default selections are always valid, allowing pre-readers to start a match in just two button presses.

### 5.4 Why a Host-Authoritative Network Architecture?
* **Business Perspective (Low Hardware Requirements):** Many families reuse older, low-end smartphones as controllers for their kids. Running a full physics engine and maze renderer on a low-end phone would cause lag and drain the battery.
* **UX & Tech Perspective:** The host device (usually a tablet or TV) handles all physics, collision, and game logic. The joiner's phone operates as a thin client, sending simple D-Pad inputs over ENet/UDP. This ensures a lag-free experience, uses minimal battery, and prevents desynchronization.

### 5.5 Why Child Safety and Frictionless Play?
* **Pause Menu Guard:** The pause dialog pre-focuses "No" when asking "Leave the maze?". This prevents children from accidentally quitting a match when trying to close a popup.
* **Auto-Play Loop:** The auto-countdown on the win screen proceeds to the next level automatically, preventing pre-readers from getting stuck in menu states when parents are not nearby to assist.

---

## 6. Technical Architecture & Developer Design Choices

For a senior developer refactoring the codebase, this section outlines the system structure, autoload singletons, and key performance choices.

```
       +-------------------------------------------------------------+
       |                         Godot Scene Loop                    |
       |  splash.tscn  ->  game_setup_wizard.tscn  ->  main.tscn     |
       +-------------------------------------------------------------+
              ^                    ^                    ^
              |                    |                    |
       +-------------------------------------------------------------+
       |                     Autoload Singletons                     |
       |  Config   |   TTS   |   DPad   |   Network   |   Idle       |
       +-------------------------------------------------------------+
```

### 6.1 The Autoload Singleton Layer
The game splits state and system services into global autoload singletons, keeping individual scenes modular:

| Singleton | Script Path | Responsibility | Why This Choice? |
|---|---|---|---|
| **`Config`** | `config.gd` | Handles game settings, translation options, difficulty levels, and saving configurations. | Keeps game settings organized and separated from menu interfaces. |
| **`TTS`** | `tts_manager.gd` | Manages text-to-speech calls on a background thread. Handles rate control and falls back gracefully if TTS is unavailable. | Asynchronous calls prevent menu stuttering when TTS is reading text. |
| **`DPad`** | `virtual_dpad.gd` | A `CanvasLayer` (Layer 150) that draws the virtual D-Pad buttons overlay on mobile screens. | Placing the D-pad in a separate layer ensures controls are always rendered on top, regardless of scene changes. |
| **`NetworkManager`** | `network_manager.gd` | Manages UDP discovery broadcasts, local ENet hosting, joining, and player synchronization. | Abstracts networking code from game scene logic, simplifying debugging. |
| **`IdleManager`** | `idle_manager.gd` | Monitors keyboard, mouse, and touch activity, automatically dimming the screen if the device is left idle. | Protects smart TV screens from OLED burn-in. |

---

### 6.2 Responsive Layout Shifting & RTL Mirroring
Mobile displays feature a wide variety of aspect ratios and safe zones. The game uses a custom responsive layout system to adapt to different screens:

```
+-----------------------------------------------------------+
| [HUD Header]                                              |
+-------------------+---------------------------------------+
|                   |                                       |
|                   |                                       |
|  [Virtual D-Pad]  |          [Game Content View]          |
|    (Left Side)    |                                       |
|                   |                                       |
|                   |                                       |
+-------------------+---------------------------------------+
|  <-  Width: 25%  ->|          <-  Width: 75%  ->           |
```

* **Dynamic Safe Zone Offsets:** When the virtual D-Pad is enabled, `UIHelpers.apply_dpad_layout()` shifts the main viewport, reserving **25% of the screen width** for the controls. The main content is drawn within the remaining 75% of the screen, preventing buttons from covering the player's view.
* **Right-to-Left (RTL) Mirroring:** For languages like Hebrew, the layout is automatically mirrored:
  * The virtual D-Pad shifts to the right side of the screen.
  * Card rows, settings buttons, and text layouts reverse their order.
  * This matches natural physical expectations for RTL readers.

---

### 6.3 Dynamic Goals & Network RPC Optimization
In local multiplayer matches, updating player objectives over the network quickly can cause high bandwidth usage and lag.
* **The Solution:** Rather than sending long, localized text strings from the host to client controllers, the host evaluates the game rules and sends a short translation key (e.g., `rpc_update_remote_goal("COLLECT_LETTERS")`).
* **The Implementation:** Client controllers receive the key, look up the localized text locally, and display the update. This keeps network traffic minimal and prevents synchronization lag.

---

### 6.4 Theme & Character Resource Loader
Themes are loaded dynamically to keep loading times fast and memory usage low.
* **The Theme Folder Structure:**
  ```
  res://themes/space/
     ├── manifest.json         # Wall colors, UI accents, background styles
     ├── wall.png              # Tilemap textures
     ├── player_sheet.png      # Character spritesheet
     └── chaser_sheet.png      # Chaser spritesheet
  ```
* **Dynamic Theme Caching:** `ThemeLoader` loads theme files into memory on demand rather than preloading all assets when the game starts. 
* **The Character Catalog:** The `CharacterCatalog` singleton scans the folders of active themes, building a flat list of available characters to populate the game's setup menus dynamically. This makes adding new themes as simple as creating a new folder with a valid `manifest.json`.

---

### 6.5 Threaded Text-to-Speech (TTS) Integration
Godot's default `DisplayServer.tts_speak()` executes synchronously on some platforms, which can freeze the main thread and cause visual lag during gameplay.
* **The Solution:** The game implements a background thread runner within `tts_manager.gd`. Text queries are queued, processed, and sent to the OS speech engine asynchronously.
* **Diagnostic Feature Check:** When the game starts, the TTS singleton tests the operating system's speech engine. If the test fails, the "Voice Hints" option in the settings menu is disabled and dimmed to 40% opacity, preventing crashes or unexpected behavior on devices without TTS engines.
