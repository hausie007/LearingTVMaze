# Learning Maze — Game Design & UX Specification

## 1. Game Identity

Educational maze game for children 4+, built in Godot 4.6 targeting Android phones/tablets and Google TV. Procedural mazes with optional educational collectibles (numbers, letters, words in 21 languages). Single-player and local multiplayer via WiFi.

---

## 2. Design Principles

| Principle | Implementation |
|---|---|
| **D-Pad First** | Every screen fully operable with 4-dir D-pad + OK + Back. No pointer required. |
| **Focus-Driven** | All transitions end with explicit `grab_focus()`. Focus neighbors manually wired. |
| **Progressive Disclosure** | 3-step wizard reveals choices one at a time, collapsing confirmed steps. |
| **Instant Play** | 2 taps from launch to gameplay. Defaults always valid. |
| **No Dead Ends** | Every `ui_cancel` navigates back or shows quit confirmation. |
| **TV-Safe** | On TV: D-pad OFF, cursor hidden, mouse hover suppressed via `MOUSE_FILTER_IGNORE`. |
| **OLED Safe** | Idle detection, automated screen dimming, and rapid reset behaviors across UI to prevent burn-in. |

### Color Language
- **Blue** (`#1188FF`) — Gameplay controls (actions, difficulty, play mode)
- **Yellow** (`#FFCC00`) — Navigation/settings (theme, language, help)
- **Green** (`#22AA44`) — Multiplayer elements (join card, host button)
- **Parchment Aesthetics** — Win/Gotcha screens use a cohesive parchment-style visual theme for professional presentation.

---

## 3. Input Model

| Platform | Primary Input | On-Screen D-Pad Default |
|---|---|---|
| Android Phone | Touch | Right-handed |
| Android Tablet | Touch | Right-handed |
| Google TV | IR Remote | Off |

### Virtual D-Pad (`virtual_dpad.gd`)
CanvasLayer (layer 150) with 5 `TouchScreenButton` nodes (↑↓←→ OK) + Back (↰). Positioned on chosen screen edge. Haptic feedback (24ms) on directional presses.

### Layout Shifting
When D-pad active, `UIHelpers.apply_dpad_layout()` reserves 25% screen width:
- Left-handed: `anchor_left = 0.25`
- Right-handed: `anchor_right = 0.75`
- RTL: modes swap so D-pad stays on physical edge

### In-Game Movement (`player_controller.gd`)
Uses `_process()` polling with manual cooldown (0.20s). Deliberate: children hold buttons expecting continuous movement. Tween (0.12s) slides sprite. Wall bumps trigger shake animation + haptic.

---

## 4. Scene Flow

```
splash.tscn → [Loading] → game_setup_wizard (HOME)
                              ├── Card press → game_setup_wizard Step 2/3 → main.tscn (Solo Game)
                              ├── Play Together → host_setup.tscn → host_lobby.tscn → multiplayer_game.tscn
                              ├── Join card → join_flow.tscn → multiplayer_game.tscn
                              ├── Settings → settings_menu.tscn → HOME
                              └── Help → help_menu.tscn → HOME
```

### Autoloads
| Singleton | Purpose |
|---|---|
| `Config` | Game state, settings persistence, difficulty/grid calc |
| `TTS` | Background-threaded text-to-speech |
| `DPad` | On-screen virtual D-pad |
| `NetworkManager` | Multiplayer discovery, hosting, joining |
| `IdleManager` | Tracks input inactivity to trigger automated OLED-dimming protections |

---

## 5. Mission & Content System

### 5.1 Missions
| Mission | ID | Chaser? | Pickups |
|---|---|---|---|
| Find Exit | `find_exit` | Allowed | None only |
| Follow Trail | `follow_trail` | Allowed | Numbers, Letters, Words |
| Find Next | `find_next` | Allowed | Numbers, Letters, Words |
| Race to Middle | `race_middle` | Never | All (incl. None) |

### 5.2 Pickups
| ID | Content |
|---|---|
| `numbers` | Sequential numbers |
| `letters` | Alphabet (Latin/Greek/Hebrew/Ukrainian) |
| `words` | Word spelled letter-by-letter with emoji + TTS |
| `none` | No collectibles |

### 5.3 Difficulty (7 levels)
Very Easy (5×4) → Easy (7×6) → Medium (9×8) → Hard (13×10) → Very Hard (20×12) → Insane (26×13) → Unbelievable (36×15)

### 5.4 Dynamic Goals System
In-game goals use a multi-step instruction system that updates dynamically based on player progress. Goals are role-specific (e.g., Collector vs. Chaser) and minimize network traffic while scaling appropriately in the HUD. These goals also extend to remote D-Pad controller screens.

---

## 6. Screens — Detailed UX

### 6.1 Game Setup Wizard (HOME) — `game_setup_wizard.gd`

The canonical home screen. A 3-step progressive wizard using `WizardStep` components.

#### Layout (top → bottom)
1. **Top Spacer** — responsive gap
2. **App Logo** — horizontal, centered, 480–930px width
3. **Step 1: Mission** — card row + settings area
4. **Step 2: Pickup** — card row + settings area (initially hidden)
5. **Step 3: Action** — card row + settings area (initially hidden)
6. **Corner Buttons** — `[Settings ⚙]` bottom-left, `[Help ?]` bottom-right

#### Step 1 — Mission Type (Active on load)
**Cards**: 4 mission cards + 1 conditional green Join card ("Play Together") dynamically inserted into the middle of the mission card row without causing layout shifts.

**Settings below cards**:
- Theme selector (cycling, L/R cycles themes, arrows appear on focus)
- Maze Size selector (cycling, L/R cycles difficulty)
- Character preview overlay (positioned next to theme button, flips in RTL)

**Join Card**: Appears when `NetworkManager` discovers a host. Green palette (`#22AA44`). When focused, action buttons and settings dim (alpha 0.35) since they're irrelevant for joining. Pressing it opens the Join Host List overlay.

**D-Pad chain (Step 1 active)**:
```
Mission Cards (L/R wraps within row)
    ↓
Theme Selector (L/R cycles value)
    ↓
Maze Size Selector (L/R cycles value)
    ↓
[Settings] ←→ [Help]
```

When Join card is focused, settings are skipped:
```
Cards + Join Card → [Settings] ←→ [Help]
```

**Confirming Step 1**: Press any mission card → Step 1 collapses into breadcrumb (e.g., "▾ Follow Trail • Thiefs • Easy"), Step 2 expands. If mission has only 1 allowed pickup → Step 2 auto-skipped.

#### Step 2 — Pickup Type
**Cards**: Filtered by mission. Numbers, Words, Letters, Just Maze (only those allowed).

**Settings below cards**:
- Language selector (hidden if pickup = none)

**D-Pad chain (Step 2 active)**:
```
Step 1 breadcrumb (focusable, press to re-expand)
    ↓
Pickup Cards (L/R wraps)
    ↓
Language Selector (if visible, L/R cycles)
    ↓
[Settings] ←→ [Help]
```

**Confirming Step 2**: Press any pickup card → collapses, Step 3 expands. Auto-skipped if only 1 option.

#### Step 3 — Play Mode
**Cards**: Split into SP group and MP group with vertical divider line.
- SP: `[Play Alone]` `[+ Chaser]`
- MP: `[Play Together]` `[vs Chaser]`
- MP cards use green palette, show player count badges (🟢 2-4 Players)

**Settings below cards (contextual)**:
- Character selector — visible only when MP action focused
- Chaser Speed selector — visible only when chaser action focused
- Character preview overlay — floats beside character button

**D-Pad chain (Step 3 active)**:
```
Step 1 breadcrumb
    ↓
Step 2 breadcrumb
    ↓
Action Cards (L/R wraps, crosses SP/MP divider)
    ↓
Character Selector (if visible, L/R cycles)
    ↓
Chaser Speed (if visible, L/R cycles)
    ↓
[Settings] ←→ [Help]
```

**Confirming Step 3**: Press action card → starts game (solo) or transitions to host_setup (multiplayer).

#### Collapsed Step (Breadcrumb)
Focusable `Button` with chevron `▾` + summary text. Pressing re-expands that step and hides subsequent steps. Styled: dark translucent bg, yellow border on focus.

#### Smart Back (`ui_cancel`)
Auto-skipped steps are also skipped backward. E.g., if Step 2 was auto-skipped, Back from Step 3 → Step 1 directly.

#### Join Host List Overlay
When triggered from the join card, shows a scrollable list of discovered hosts. Each host card shows: host name, IP, player count, theme, mission, and character preview. Pressing a host card → navigates to `join_flow.tscn`. Navigation arrows embed directly alongside the join card to allow seamless switching between concurrent game sessions without UI jumping (uses opacity-based visibility control).

#### Responsive Layout
- `_apply_responsive_layout()` called on resize and controls change
- Short screen (<820px): smaller spacers, tighter gaps, reduced fonts
- Card width: `floor((available_width - gaps) / columns)`, clamped 160–390px
- Card height: `viewport_height × 0.30–0.335`, clamped 220–340px
- Font sizes scale with card width (3 breakpoints: <220, <270, ≥270)

---

### 6.2 Host Setup — `host_setup.gd`

Reached when pressing "Play Together" or "vs Chaser" in Step 3. Configures a multiplayer session before starting the host.

#### Layout (top → bottom)
1. **Top Spacer**
2. **Title Row** — `[Player Preview]` `"Play Together: Follow Trail (2-4 players)"`
3. **Pickup Card Row** — filtered by selected mission (same card component)
4. **Host Game button** — green, centered
5. **Settings Block**:
   - Language selector
   - Character selector (with preview)
   - Role description label
   - Trouble toggle (chaser on/off)
   - Head Start selector (chaser speed, visible only when chaser on)

#### D-Pad Navigation
```
Pickup Cards (L/R wraps)
    ↓
[Host Game] button
    ↓
Language Selector (L/R cycles, hidden if pickup=none)
    ↓
Character Selector (L/R cycles characters)
    ↓
Trouble Toggle (L/R or OK toggles, hidden if forced)
    ↓
Head Start Selector (L/R cycles, hidden if chaser off)
```

All selectors use the same pattern: arrows appear on focus (alpha 0→1), L/R cycles value, OK advances forward. Focus neighbors are dynamically reconfigured via `_configure_dpad_navigation()` when rows show/hide.

#### Card Press Behavior
Pressing a pickup card **immediately starts hosting** (calls `_on_start_pressed`). This mirrors the solo wizard's "card press = confirm" pattern.

#### Back (`ui_cancel`)
Persists selections to Config, leaves network session, returns to home.

#### Responsive Sizing
Same algorithm as wizard: card sizing, selector sizing, and spacers all derive from `_available_setup_width()` and viewport height. Visual parity is maintained with the Join Setup screen.

---

### 6.3 Host Lobby — `host_lobby.gd`

Waiting room shown after host starts. Displays connected players and provides a "Start Game" button.

#### Layout (top → bottom)
1. **Top Spacer**
2. **App Logo** — horizontal, centered
3. **Breadcrumb 1** — "▾ Follow Trail • Thiefs • Easy" (read-only, non-focusable)
4. **Breadcrumb 2** — "▾ Words • Play Together • 🟢 2-4 Players" (read-only)
5. **Players Row** — `[Slot 1] [Slot 2] ... [Slot N]` `[Start Game]`
6. **Join Banner** — "How to Join" instructions panel (localized from `translations.csv`)

#### Player Slots
Each slot: `PanelContainer` frame (110×110) + `CharacterPreview` + name label below.
- **Filled**: green border, character preview visible, name = "You" (host, yellow) or character name (white)
- **Empty**: dashed border, pulsing alpha animation (1.0→0.45→1.0, sine, 1.2s per direction)

#### Start Button
- **Disabled** (< 2 players): outline style (dark bg, green border), text "Waiting for players to join..."
- **Enabled** (≥ 2 players): filled green, text "Start Game with N players"

#### Broadcasting
When lobby is full (player count ≥ max), broadcasting pauses. When a player disconnects, broadcasting resumes.

#### Join Banner
4-step instructions with WiFi name auto-detection. Step 3 uses `RichTextLabel` with BBCode to highlight "Play Together" in green bold. All banner strings are pulled from the centralized translation system to support 21 languages.

#### D-Pad Navigation
Only the Start button is focusable. Breadcrumbs are read-only (`focus_mode = FOCUS_NONE`).

#### Back (`ui_cancel`)
Leaves network session, returns to home.

---

### 6.4 Join Flow — `join_flow.gd`

The joiner's device experience. Three sequential phases in one scene.

#### Phase 1: Discovery (if no pending host)
Normally skipped — the join card on the home screen already sets `pending_join_host`. If no pending host, redirects to home.

#### Phase 2: Join Setup (`join_setup_panel`)
Shown immediately with the selected host's configuration.

**Layout (top → bottom)**:
1. **Title** — "Join Game"
2. **Breadcrumb 1** — "▾ Mission • Theme • Difficulty" (read-only label)
3. **Breadcrumb 2** — "▾ Pickup • Action • 🟢 N Players" (read-only label)
4. **Player Slots Row** — same slot design as host lobby (shows who's already joined)
5. **Theme info** — host's setup summary
6. **Character selector** — cycling button with preview + taken avatars display
7. **Taken Avatars** — row of small previews showing already-taken characters
8. **Join Game button** — blue, disabled if no valid character available
9. **Instruction panel** — mission goal text from host config
10. **Remote Layout selector** — D-pad layout cycling (Off/Left/Right)

**D-Pad chain (pre-join)**:
```
Character Selector (L/R cycles available characters)
    ↓
[Join Game] button
```

**Back Handling (`ui_cancel`)**:
When "back" is pressed here, it properly unjoins the session, restores the lobby setup state in-place without returning to the main menu, and shows localized feedback ("Disconnected from the game").

**After joining (`_on_join_accepted`)**:
- Join button hides
- Character button disables
- Focus moves to Remote Layout selector
- D-pad input is **forwarded to host** via `NetworkManager.send_dpad()`
- Only the Remote Layout selector retains local focus (L/R cycles layout instead of forwarding)

#### Phase 3: Controller Mode (`controller_panel`)
Activated when the game starts on the host. The joiner's screen becomes an immersive pure remote controller. The setup interface (breadcrumbs, slots, settings) is hidden completely, leaving only the player icon, the colored virtual D-pad, and the goal/hint instruction text visible.

**Layout**:
- Character icon (positioned opposite to D-pad side)
- Title: "Controller"
- Goal label (updated dynamically via `rpc_update_remote_goal`)
- Chaser countdown labels (for delayed chaser release)

**All D-pad input forwarded to host**.
**Pause**: Once the game starts, pressing "back" (`ui_cancel`) correctly triggers the pause menu workflow instead of unjoining.

#### Avatar Accent System
The selected character's color palette is extracted and applied to the on-screen D-Pad buttons, creating a visual link between character and controls. On exit, the accent is reset.

---

### 6.5 Settings Menu — `settings_menu.gd`

#### Options (top → bottom)
| Setting | Control | Values |
|---|---|---|
| Quality | Cycling | Standard / High |
| UI Language | Cycling | Auto + 21 languages |
| Learning Language | Cycling | Auto + 21 languages |
| Voice Hints | Toggle | On / Off (disabled if TTS unavailable) |
| On-Screen Controls | Cycling | Off / Left / Right |

#### Cycling Button Pattern
All settings use the same interaction model:
1. Arrows (`<` `>`) appear only when focused (alpha 0→1)
2. D-pad Left/Right cycles the value, consumed via `gui_input` (prevents focus shift)
3. OK/press advances forward (+1)
4. Value change is immediate

#### Live Preview
- **UI Language**: `TranslationServer.set_locale()` called immediately, all labels refresh
- **On-Screen Controls**: D-pad layout updates live via `Config.on_screen_controls` setter

#### TTS Status
Voice button shows status indicator below:
- Checking: grey text "Checking TTS..."
- Ready: hidden
- Unavailable: red text "TTS not available" (button disabled, alpha 0.4)

#### D-Pad Navigation
Strict vertical stack. L/R never moves focus, only cycles value.

#### Back (`ui_cancel`)
Saves all settings, returns to home. On `_exit_tree` without save: restores original controls mode.

---

### 6.6 Help Menu — `help_menu.gd`

7-slide kid-friendly tutorial with theme-aware icons.

| # | Visual | Content |
|---|---|---|
| 1 | App logo (450×300) | Welcome text |
| 2 | Mini maze preview (640×320) | "This is the maze" |
| 3 | Player sprite (animated) | "This is you" |
| 4 | Exit sprite | "Find the exit" |
| 5 | Collectible preview (circle + letter) | "Collect items" |
| 6 | Chaser sprite (animated) | "Watch out!" |
| 7 | 3 random theme characters | "Change your look" |

#### Navigation
- Arrow buttons have `FOCUS_NONE` — D-pad Left/Right directly handled in `_unhandled_input`
- Right on last slide → exits
- `ui_cancel` → exits immediately
- Voice hints: each slide read aloud via TTS

#### D-Pad Layout
Content area shifts away from D-pad zone. Panel and font sizes adjust for D-pad mode.

---

### 6.7 In-Game: Solo — `game_manager.gd`

#### HUD (`game_hud.gd`, 160px top bar)
`[00:00 Timer]` — `[Word/Letter Display]` — `[Move Count]`

Below word display: mission description text. Font scales up (42px, yellow) when no word display is active.

Word display: per-letter labels, dimmed by default. Each collected letter "lights up" (yellow + scale bounce animation). RTL scripts get `layout_direction = RTL`.

#### Gameplay Loop
1. Maze generated by `MazeGenerator` (iterative DFS)
2. `MazeRenderer` draws using `ThemeLoader` textures
3. Player moves on grid, `CollectibleSpawner` checks collection
4. All collectibles gathered → reach exit → `WinScreen`
5. Chaser catches player → `WinScreen` (gotcha variant)

#### Pause (`ui_cancel`)
`PauseDialog` (CanvasLayer layer 100, `PROCESS_MODE_ALWAYS`):
- "Leave the maze?" with `[Yes]` `[No]`
- **"No" pre-focused** (child safety)
- D-pad layout shift applied
- Game tree paused

---

### 6.8 In-Game: Multiplayer — `multiplayer_game_manager.gd`

Host processes all movement. Joiners forward D-pad input via network.

#### Roles
| Role | Behavior |
|---|---|
| Collector | Collects items, reaches exit |
| Chaser | Catches the collector (delayed release based on head start) |
| Racer | Races to center cell (race mode) |

#### Chaser Release Mechanic
Chasers start hidden. After N collector moves (based on head start level), chasers appear with countdown notification sent via RPC to joiner devices.

#### Race Mode HUD
Optimized for 3-4 players. Player badges are enlarged and paired directly beside their status trackers on the screen edges (eliminating cluttered center-aligned layouts). The HUD dynamically calculates its vertical footprint to prevent overlapping with the main game area as badges scale.

#### Race Mode Gameplay
Each player gets a sequence of waypoints. Collecting waypoints in order advances progress. First to center wins.

#### Win/Gotcha
Same `WinScreen` component as solo, with additional buttons:
- `[Swap Roles]` — swaps collector/chaser after catch
- `[Play Alone]` — converts to solo session

#### Goal Updates
Host sends role-specific goal text to each joiner via `rpc_update_remote_goal`. Goals update dynamically in multi-step sequences based on player progress (e.g., "Collect all letters" → "Find the exit" after completion).

---

### 6.9 Win Screen — `win_screen.gd`

CanvasLayer (layer 10), `PROCESS_MODE_ALWAYS`. Both variants are styled with a cohesive, professional parchment-style aesthetic.

#### Win Variant
- Title: "You Win!" (or race winner with character preview)
- Dynamically displays the correct "Chaser" or "Player" character icon in multiplayer contexts.
- Score: Time + Moves
- `[Next Round]` + 10s auto-countdown (pauses on any D-pad input)
- `[Harder]` — increase difficulty (hidden at max)
- `[Play Together]` or `[Play Alone]` — mode switch
- `[Swap Roles]` — visible in chaser multiplayer
- `[Main Menu]`

#### Gotcha Variant
- Title: "Gotcha!"
- Dynamically displays the correct "Chaser" or "Player" character icon.
- `[Try Again]` + countdown
- `[Easier]` — decrease difficulty (hidden at min)

#### Auto-countdown
Timer label shows remaining seconds. Any `ui_up/down/left/right/accept/cancel` pauses the countdown permanently for that screen showing. `ui_cancel` is consumed (prevents focus loss).

---

## 7. Display & OLED Protection System

### OLED Burn-in Protections
To protect displays (especially on Google TV), the game includes active burn-in prevention:
- **Idle Detection**: Consistent idle detection tracks user inactivity across all multiplayer screens, setup wizards, and game states.
- **Automated Dimming**: Screen automatically dims after a period of inactivity.
- **Rapid Reset**: Any input via HUD controls or virtual D-Pad instantly resets the idle timer and restores full brightness.

---

## 8. Responsive Layout System

### Content Rect
`UIHelpers.get_content_rect(viewport_size, controls_mode)`: full viewport minus 2% margins, minus 25% D-pad zone if active.

### Card Sizing Algorithm
1. Count visible cards (Step 1 assumes 5 for stability)
2. Columns: all in one row if width ≥ 760px, else 2
3. Gap: 48px (wide) / 34px (medium) / 24px (narrow)
4. Card width: `floor((available - gaps) / columns)`, clamped 160–390px
5. Card height: `viewport_height × 0.30–0.335`, clamped 220–340px
6. Font sizes: 3 breakpoints based on card width

### RTL Support
- Card row navigation reversed
- D-pad layout zones mirrored
- Corner buttons swap
- Character preview overlay flips
- Word display switches `layout_direction`

---

## 9. Theming

Directory-based themes (`res://themes/<name>/`) with `manifest.json`:
- Player/chaser/collectible textures + animation frames
- Background textures (animated)
- Color overrides for walls, cells, UI accents
- Glow settings (HDR threshold, intensity, bloom)

`ThemeLoader` caches themes. `CharacterCatalog` builds flat list of all characters across themes for multiplayer character selection.

---

## 10. Internationalization

**21 languages** supported. Two independent settings:
- **UI Language** — all menu text, TTS announcements
- **Learning Language** — word lists, alphabet for collectibles

Alphabet support: Latin A-Z (default), Greek Α-Ω, Hebrew א-ת, Ukrainian А-Я (with Ґ, Є, І, Ї).

---

## 11. Networking

UDP broadcast discovery for host finding. Join card appears automatically on home screen. Host config serialized as Dictionary (mission, pickup, difficulty, theme, character, chaser, max players).

Joiner's device acts as pure D-pad controller after joining — all game logic runs on host. Input forwarded via `NetworkManager.send_dpad()`.

---

## 12. Accessibility

| Feature | Detail |
|---|---|
| TTS Voice Hints | Items spoken aloud, help slides narrated |
| Large Targets | Buttons ≥220×52px, cards 300×230px |
| High Contrast | White on dark navy, yellow/blue accents |
| No Time Pressure | Win countdown pauses on input |
| Haptic Feedback | 24ms vibration on D-pad touch |
| Safe Defaults | "No" pre-focused on quit dialogs |
