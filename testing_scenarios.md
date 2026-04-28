# Learning Maze — Manual Testing Scenarios

> This document lists topics and flows to be covered in manual testing.
> Full test case write-ups (steps, expected results, pass/fail criteria) will be added later.

---

## 1. Launch & Splash

- Cold launch → splash screen → loading → home screen transition
- Repeat launch (warm start) — correct screen shown without re-running splash

---

## 2. Game Setup Wizard — Step 1 (Mission)

- All 4 mission cards are visible and focusable
- Selecting each mission card collapses Step 1 into breadcrumb and advances to Step 2
- Breadcrumb displays correct summary text after confirming Step 1
- Theme selector cycling (L/R, full wrap-around)
- Maze Size selector cycling (L/R, all 7 difficulty levels)
- Character preview visible and positioned correctly (LTR layout)
- Character preview position in RTL layout
- Settings corner buttons ([Settings ⚙] and [Help ?]) reachable via D-pad
- D-pad navigation chain: Mission Cards → Theme → Maze Size → Settings/Help
- "Find Exit" mission — Step 2 auto-skip (only "none" pickup allowed)
- "Race to Middle" mission — all pickup options available in Step 2

---

## 3. Game Setup Wizard — Step 2 (Pickup)

- Pickup cards filtered correctly per selected mission
- Step 1 breadcrumb is focusable and re-expands Step 1 when pressed
- Language selector hidden when pickup = "none"
- Language selector visible and cycling when pickup is not "none"
- Confirming pickup collapses Step 2 into breadcrumb and advances to Step 3
- D-pad navigation chain: Step 1 breadcrumb → Pickup Cards → Language → Settings/Help
- Auto-skip of Step 2 when only one pickup is valid (back navigation also skips)

---

## 4. Game Setup Wizard — Step 3 (Play Mode)

- SP cards ("Play Alone", "+ Chaser") and MP cards ("Play Together", "vs Chaser") visible
- SP/MP visual divider line present
- MP cards show green palette and player count badge
- Character selector visible only when an MP action is focused
- Chaser Speed selector visible only when a chaser action is focused
- Character preview overlay displays and positions correctly next to character button
- D-pad navigation chain: Step 1 breadcrumb → Step 2 breadcrumb → Action Cards → Character → Chaser Speed → Settings/Help
- Confirming "Play Alone" or "+ Chaser" → transitions to solo game (main.tscn)
- Confirming "Play Together" or "vs Chaser" → transitions to Host Setup screen

---

## 5. Game Setup Wizard — Breadcrumb & Back Navigation

- Pressing a breadcrumb re-expands the corresponding step and hides subsequent steps
- Back from Step 2 → returns to Step 1
- Back from Step 3 → returns to Step 2 (or Step 1 if Step 2 was auto-skipped)
- Back from Step 1 → quit confirmation dialog shown

---

## 6. Game Setup Wizard — Responsive Layout

- Layout on narrow phone screen (< 820px height): smaller spacers, tighter gaps, reduced font sizes
- Layout on tablet / wide screen
- Card sizing algorithm: cards fill row correctly, width clamped 160–390px
- Card height clamped 220–340px
- Font size breakpoints at < 220px, < 270px, ≥ 270px card width
- D-pad zone reservation (25% width) when virtual D-pad active (left-handed, right-handed)

---

## 7. Game Setup Wizard — Join Card (Multiplayer Discovery)

- Join card does NOT appear when no host is broadcasting
- Join card appears (green, index 2 in row) when a host is discovered
- Join card focus: action buttons and settings dim (alpha 0.35)
- Join card focus: D-pad chain skips settings and goes directly to Settings/Help corner buttons
- Pressing Join card opens the Join Host List overlay
- Join Host List overlay: host name, IP, player count, theme, mission, character preview shown
- Pressing a host in the list navigates to join_flow.tscn
- Host List overlay dismisses correctly on back

---

## 8. Host Setup Screen

- Screen reachable from "Play Together" / "vs Chaser" in Step 3
- Title row shows correct mission description and player count
- Pickup card row filtered correctly for the selected mission
- Pressing a pickup card immediately starts hosting (no separate confirm button)
- Language selector hidden when pickup = "none"
- Character selector cycling through available characters
- Role description label updates per selected character
- Trouble toggle (chaser on/off) cycles correctly
- Head Start selector visible only when chaser is on, hidden when off
- D-pad chain: Pickup Cards → Host Game button → Language → Character → Trouble Toggle → Head Start
- Back from Host Setup: network session left, returns to home, selections persisted to Config
- Responsive sizing: card and selector sizes match wizard algorithm

---

## 9. Host Lobby Screen

- Screen displayed after host starts hosting
- App logo shown correctly
- Two read-only breadcrumbs display correct session summary
- Host's player slot: green border, character preview, "You" label in yellow
- Empty slots: dashed border, pulsing alpha animation (1.0 → 0.45 → 1.0)
- Start Game button disabled with "Waiting for players to join..." when < 2 players
- Start Game button enabled (filled green) and shows correct player count when ≥ 2 players
- New joiner appearing in a slot (border fills, animation stops)
- Joiner disconnecting: slot reverts to empty / pulsing state
- Broadcasting pauses when lobby is full; resumes when a player disconnects
- Join Banner: shows 4-step instructions with correct WiFi name
- Join Banner step 3: "Play Together" rendered in green bold (BBCode)
- Only Start Game button is focusable via D-pad
- Back from Host Lobby: network session left, returns to home

---

## 10. Join Flow — Phase 2: Join Setup

- Join Setup panel displays host's breadcrumbs (mission, pickup, difficulty, action, player count)
- Player Slots Row matches state of host lobby (pre-filled slots shown)
- Character selector cycles only through available (not taken) characters
- Taken avatars displayed as small previews
- Join Game button disabled when no valid character is available
- Join Game button enabled when a valid character is selected
- D-pad chain (pre-join): Character Selector → Join Game button
- Instruction panel shows correct mission goal text from host config
- Remote Layout selector: Off / Left / Right options
- After joining (join accepted): Join button hidden, character button disabled, focus moves to Remote Layout selector
- After joining: D-pad input forwarded to host (movement in game moves character on host)
- Remote Layout selector retains local focus and cycles layout without forwarding input
- Avatar accent system: D-pad button colors match selected character's palette
- Avatar accent reset on exit

---

## 11. Join Flow — Phase 3: Controller Mode

- Controller panel activates when host starts the game
- Character icon displayed on opposite side from D-pad
- "Controller" title visible
- Goal label shows correct role-specific text
- Goal label updates dynamically when role/phase changes (via rpc_update_remote_goal)
- Chaser countdown labels shown during head start delay and hidden afterwards
- All D-pad input forwarded to host during controller mode
- Back (ui_cancel) in controller mode: leaves session, returns to home

---

## 12. Settings Menu

- Settings menu reachable from home screen corner button
- All 5 settings present: Quality, UI Language, Learning Language, Voice Hints, On-Screen Controls
- Quality cycles: Standard / High
- UI Language cycling: Auto + all 21 languages, wraps around
- Learning Language cycling: Auto + all 21 languages, wraps around
- Voice Hints toggle: On / Off
- Voice Hints disabled and dimmed (alpha 0.4) when TTS unavailable
- TTS status indicator states: "Checking TTS...", hidden (ready), "TTS not available" (red)
- On-Screen Controls cycling: Off / Left / Right
- UI Language live preview: menu text updates immediately on change
- On-Screen Controls live preview: D-pad layout updates immediately on change
- D-pad chain: strict vertical stack, L/R cycles value without moving focus
- Arrows on cycling buttons appear only when focused
- Back: saves all settings, returns to home
- Back without save path: original controls mode restored

---

## 13. Help Menu

- Help menu reachable from home screen corner button
- All 7 slides present with correct visuals and text content
- Slide progression: D-pad Right / Right arrow button advances to next slide
- Slide regression: D-pad Left / Left arrow button goes to previous slide
- Right on last slide (slide 7) exits help
- ui_cancel exits immediately from any slide
- TTS narration plays for each slide (when TTS available)
- Arrow buttons have FOCUS_NONE (not individually focusable)
- D-pad layout shift: content area shifts away from D-pad zone
- Panel and font sizes adjust for D-pad mode

---

## 14. Solo Gameplay

- Maze generates correctly for each difficulty level (5×4 to 36×15)
- All themes render correctly (walls, floors, background, animated background)
- Player movement: 4 directions, 0.20s cooldown, 0.12s tween animation
- Wall collision: player does not pass through walls
- Wall bump: shake animation plays + haptic feedback (24ms)
- Collectibles spawn correctly (numbers, letters, words)
- Collecting an item: HUD lights up corresponding letter/number (yellow + bounce animation)
- TTS announces collectible when voice hints enabled
- HUD: timer counts up correctly
- HUD: move counter increments per move
- HUD: word/letter display correct for current mission
- HUD: mission description text scales up (42px, yellow) when no word display is active
- HUD: RTL word display uses RTL layout direction
- All collectibles gathered → reaching exit triggers Win Screen
- "Follow Trail" mission: collecting items in correct order
- "Find Next" mission: next item highlighted/indicated
- "Race to Middle" mission: progress toward center tracked
- Pause dialog (ui_cancel during game): "Leave the maze?" shown
- Pause dialog: "No" is pre-focused
- Pause dialog: "Yes" leaves game and returns to home
- Pause dialog: "No" dismisses and resumes game
- Pause dialog: game tree paused while open
- Chaser mode: chaser appears after N collector moves (based on head start)
- Chaser catches player → Gotcha variant of Win Screen

---

## 15. Multiplayer Gameplay (Host-side)

- Multiplayer game starts with all connected players present
- All player positions rendered correctly on host
- Collector role: collects items, reaches exit
- Chaser role: starts hidden, released after head start moves, catches collector
- Racer role: follows waypoints in order, first to center wins
- Chaser countdown notification sent to joiner devices on release
- Host processes all movement (own + joiner input)
- Joiner D-pad input correctly controls corresponding player on host
- Win Screen: "Swap Roles" swaps collector/chaser correctly
- Win Screen: "Play Alone" converts session to solo game
- Goal text updates correctly per role and progress phase
- Role-specific goal RPC sent to each joiner on phase change
- Race mode: per-player waypoint tracking and progress display

---

## 16. Win Screen

- Win variant: "You Win!" title, time and moves score displayed
- Gotcha variant: "Gotcha!" title, Try Again + Easier button
- "Next Round" button present with 10s auto-countdown label
- Auto-countdown pauses permanently on any D-pad input
- "Harder" button hidden when already at max difficulty
- "Easier" button hidden when already at min difficulty
- "Play Together" and "Play Alone" mode-switch buttons function correctly
- "Swap Roles" button visible in chaser multiplayer only
- "Main Menu" button returns to home correctly
- ui_cancel consumed (focus not lost, countdown not skipped unintentionally)

---

## 17. Input: Virtual D-Pad (Touch)

- D-pad renders as CanvasLayer at correct layer (150)
- 5 directional buttons (↑↓←→ OK) + Back button present
- Right-handed layout default on phone/tablet
- Left-handed layout when selected in settings
- D-pad zone reservation: content shifts 25% away from D-pad side
- RTL layout: D-pad physical edge logic inverted correctly
- Haptic feedback (24ms) on directional press
- D-pad navigates all menus correctly without touch on content area
- D-pad Back button triggers ui_cancel

---

## 18. Input: Google TV (IR Remote)

- On TV: virtual D-pad hidden
- On TV: cursor hidden
- On TV: mouse hover states suppressed (MOUSE_FILTER_IGNORE)
- Remote directional input navigates all screens correctly
- Remote OK triggers focused element
- Remote Back triggers ui_cancel on all screens

---

## 19. RTL Language Support

- Selecting an RTL language (e.g., Hebrew) switches UI to RTL layout
- Card row navigation reversed in RTL
- D-pad layout zones mirrored in RTL
- Corner buttons swapped in RTL
- Character preview overlay flips to opposite side in RTL
- Word display uses RTL layout_direction for RTL scripts
- Hebrew alphabet (א-ת) displayed and collected correctly
- All menu labels render correctly in RTL

---

## 20. Internationalization

- All 21 UI languages selectable and render correctly
- All 21 learning languages selectable
- Language selector in wizard shows correct language names
- Collectibles (words) display correctly in each learning language
- TTS announces in selected UI language (when available)
- Auto language selection picks correct locale from device

---

## 21. Theming & Visual

- All available themes selectable in wizard
- Theme cycling in Step 1 previews theme immediately
- Player, chaser, and collectible textures load from correct theme directory
- Background texture renders (including animated backgrounds)
- Wall and cell colors match theme color overrides
- Glow/bloom settings applied per theme
- CharacterCatalog builds complete character list across all themes for multiplayer

---

## 22. Accessibility

- TTS reads collectibles aloud (when voice hints on)
- TTS narrates help slides in order
- Buttons and cards meet minimum size targets (buttons ≥ 220×52px, cards ≥ 300×230px)
- High contrast: white text on dark navy, yellow/blue accents readable
- Win countdown pauses on any input (no time pressure)
- "No" pre-focused in quit/pause dialog (child safety)
- All interactive elements reachable and operable via D-pad only (no pointer required)

---

## 23. Networking & Discovery

- Host visible on joiner device's home screen within expected time
- Host card shows correct metadata (name, IP, player count, theme, mission, character)
- Host disappears from join list when host session ends
- Broadcasting pauses when lobby full, resumes on disconnect
- Joiner connecting mid-lobby: slot fills on host and other joiners
- Joiner disconnecting during lobby: slot empties, broadcasting resumes if was paused
- Joiner disconnecting during gameplay: game continues for remaining players
- Host device transitions game cleanly from lobby to gameplay for all connected joiners
- Network session cleaned up correctly on back / quit at each phase

---

## 24. Configuration Persistence

- Selected difficulty saved and restored on next launch
- Selected theme saved and restored
- Settings (quality, languages, voice hints, controls) saved across launches
- Host Setup selections persisted to Config on back

---

## 25. Edge Cases & Stability

- Quickly pressing back multiple times — no double navigation or crash
- Switching language rapidly — UI remains stable
- Joining a lobby that fills up just as you try to join
- Host cancels session while joiner is on Join Setup screen
- Game started from lobby with exactly 2 players
- Game started from lobby with maximum players
- Device rotation (if applicable) — layout reflows correctly
- Very long player/character names — UI does not overflow or clip illegibly
- Launching with no network connection — join card absent, no crash
