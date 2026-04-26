# Game Setup Wizard — Architecture & Design Guide

> **Audience**: Developers refactoring the wizard code. This doc explains _why_ things work the way they do, not just _what_ they do.

---

## Overview

The wizard (`game_setup_wizard.gd`) is a **3-step collapsible flow** that replaces three separate screens (main menu, mode selection, host setup). It lives in a single scene and builds its entire UI programmatically in `_build_layout()`.

```
Step 1: Mission   → Find the Exit, Follow the Trail, Find the Next One, Race to the Middle
Step 2: Pickup    → Numbers, Words, Letters, Just the Maze
Step 3: Action    → Play Alone, With Chaser, Play Together, vs Chaser
```

Each step has:
- **Active state**: Shows a row of cards + settings below
- **Collapsed state**: Single-line breadcrumb summary (clickable to re-expand)
- **Hidden state**: Invisible, takes no space

**Flow**: Step 1 active → confirm → Step 1 collapses, Step 2 activates → confirm → Step 2 collapses, Step 3 activates → confirm → game starts.

---

## Key Components

### `WizardStep` (`wizard_step.gd`)

Reusable component that manages one step. It extends `VBoxContainer` and contains:
- A **collapse row** (Button with chevron + summary text)
- An **active container** (VBoxContainer with card row + settings area)

**Card row**: `HBoxContainer` with `ModeCard` instances. Cards are built dynamically via `setup_cards()` — the data is an array of dictionaries.

**Signals**:
- `card_confirmed(card_id)` — user pressed a card
- `card_focus_changed(card_id)` — user navigated focus to a different card (critical for updating settings visibility)
- `expand_requested()` — user clicked the collapsed breadcrumb

**Important behavior**: Focusing a card also selects it (`_on_card_focus_entered` sets `_selected_card_id`). This is intentional: the "selected" card is always the last one you focused, so when navigating away and back, focus returns to the right card.

**API for navigation**:
- `get_card_buttons()` — returns visible, focusable card buttons in data order
- `get_selected_card_button()` — returns the button for the currently selected card (used to wire `focus_neighbor_top` from settings)
- `focus_selected_card()` — called after step transitions to grab focus on the right card

### `ModeCard` (`mode_card.tscn`)

A styled `Button` with icon, title, subtitle, and selection glow. Configured via:
- `setup(icon, title, subtitle)` — set content
- `configure_compact(icon_size, title_size, subtitle_size)` — adjust font sizes
- `set_selected(selected, animated)` — show/hide the selection border/glow
- `set_badge(text, color)` — player count badge (e.g. "🔵 1 Player", "🟢 2-4 Players")

---

## Step-Specific Logic

### Step 1 — Mission Selection

**Cards**: 4 mission types from `MissionCatalog.missions()`. Always 4 cards.

**Settings below cards** (in a separate `HBoxContainer` called `settings_row`):
- **Theme selector** (cycling button with `< Theme Name >`)
- **Theme preview** (animated character sprite beside the theme button)
- **Maze size selector** (cycling button with `< Easy / Medium / ... >`)

**Theme preview** is a `CharacterPreview` inside a `Control` container, added as a child of the settings `HBoxContainer`. This means the HBoxContainer handles RTL positioning automatically. The preview shows the player sprite from the selected theme.

### Step 2 — Pickup Type

**Cards**: Variable count based on which pickups the selected mission allows.
- "Find the Exit" allows only `none` → **auto-skipped** (see below)
- Other missions show 3-4 pickup options

**Settings below cards**:
- **Learning language selector** — hidden when pickup is "none" (Just the Maze), since there's nothing to learn.

**Auto-skip**: If only one pickup is allowed, step 2 is skipped entirely. `_on_step1_confirmed` calls `_on_step2_confirmed` directly. The back button also knows to skip back over auto-skipped steps (`_go_back_smart`).

### Step 3 — Start Action

**Cards**: 2-4 cards depending on mission type:
- **Solo** (always)
- **Solo + Chaser** (unless the mission forces chaser off, e.g. Race to Middle)
- **Coop** (MP, unless chaser is required)
- **Versus** (MP, one player is chaser)

Cards are grouped "SP" vs "MP" with a vertical divider. MP cards get green styling, SP cards get blue styling (applied in `_apply_step3_card_styles`).

**Settings below cards** — visibility depends on which card is focused:
| Focused card | "Choose Your Player" row | "Chaser Speed/Delay" row |
|---|---|---|
| Solo | hidden | hidden |
| Solo + Chaser | hidden | visible ("Chaser Speed") |
| Coop | visible | hidden |
| Versus | visible | visible ("Chaser Delay") |

**Why "Chaser Delay" vs "Chaser Speed"?**: In versus mode, the chaser speed is controlled by the other player. The setting only changes the head-start delay before the chaser begins moving.

**"Choose Your Player"** — cycling selector for character (from `CharacterCatalog`). Default is the player sprite from the currently selected theme. The character preview is an **overlay** — see section below.

---

## Character Preview Overlay (Step 3)

> **Why it's an overlay**: The character preview image is large (94-124px) and must not affect the alignment or height of the settings row. If placed inside the `HBoxContainer`, it would expand the row height and misalign it with other settings rows.

**Implementation**: `_character_preview_container` is a `Control` added as a direct child of the wizard root (`self`), not inside any container. Its position is calculated in `_position_character_preview()`:

- Gets the button's `global_rect`
- In **LTR**: places preview at `btn_rect.end.x + 30` (to the right)
- In **RTL**: places preview at `btn_rect.position.x - 30 - size` (to the left)
- Top-aligned with the button

**Contrast with Step 1 theme preview**: Step 1's preview IS inside the HBoxContainer (it's simpler, smaller, doesn't need to be huge). The HBoxContainer handles RTL automatically.

**When to call `_position_character_preview()`**:
- On character cycle
- On responsive layout change
- When settings visibility changes (MP card focused)
- On every deferred layout update

---

## Navigation System

All navigation is managed by `_configure_navigation()` called from `_configure_step{1,2,3}_nav()`.

### Why manual navigation wiring?

Godot's auto-navigation finds the geometrically nearest focusable control, but this fails for the wizard's layout because:
1. Cards are in a row — left/right should wrap around
2. The "Settings" and "Help" corner buttons float outside the main layout
3. Steps above/below might be collapsed (hidden) — Godot would focus through them

### Card row navigation (`_configure_card_row_nav`)

- Left/right: **circular wrapping** (last card → first card)
- **RTL handling**: In RTL, `HBoxContainer` reverses card order visually. The focus neighbor indices are swapped: pressing "left" (→ higher index) and "right" (→ lower index) so they match the visual direction.
- Top: collapse row of the previous step (or nothing for step 1)
- Bottom: first visible setting below cards

### Focus retention

**Problem**: When navigating down from cards to a setting and then back up, Godot would focus the first/last card instead of the one that was focused before.

**Solution**: Every `card_focus_changed` signal triggers `_configure_navigation()`, which re-wires `focus_neighbor_top` of the setting below to point at `get_selected_card_button()`. This ensures the "up" from settings always returns to the last-focused card.

### Corner buttons (Settings, Help)

Positioned absolutely at the bottom corners of the screen. Their `focus_neighbor_top` points to the last focusable setting in the active step. Left/right wraps between the two buttons. They don't participate in the card row's navigation chain.

---

## Auto-Skip Logic

Steps can be auto-skipped when they have only one option:

- **Step 2**: "Find the Exit" only allows `none` → skip to step 3 directly
- **Step 3**: Theoretically possible but currently all missions have 2+ actions

When going **back** (`_go_back_smart`), skipped steps are also skipped in reverse. If step 2 was auto-skipped, pressing back from step 3 goes to step 1.

---

## Responsive Layout

`_apply_responsive_layout()` adapts to screen size:

- **Logo**: Scales between 380-780px width
- **Cards**: Width computed from available space, capped at 160-390px. Height uses viewport percentage, capped 220-310px
- **Font sizes**: Scale down for short screens (<820px height)
- **Spacers**: Reduce on short screens
- **Corner buttons**: Repositioned using `UIHelpers.get_content_rect` which accounts for D-pad overlay

Layout recalculates on `NOTIFICATION_RESIZED`, controls mode change, and after step transitions.

---

## D-Pad / RTL Layout

`_apply_dpad_layout()` calls `UIHelpers.apply_dpad_layout()` which shifts the content area to accommodate on-screen D-pad controls (left or right side).

**RTL handling** is done via:
1. Godot's built-in `is_layout_rtl()` which auto-mirrors HBoxContainers
2. Manual swaps in `_configure_card_row_nav` for focus neighbor directions
3. Manual position calculation in `_position_character_preview` for the overlay

---

## State Persistence

`_persist_state()` (called before leaving the wizard for settings/help screens) saves:
- `Config.selected_mission_id` — so step 1 restores the right card when returning
- `Config.selected_theme_dir` — theme selection
- `Config.training_type` — derived from pickup selection

On return from settings/help, `_initialize_state()` restores everything from `Config`.

---

## Game Start

Step 3 confirmation dispatches to `_start_single_player(with_chaser)` or `_start_multiplayer(with_chaser)`:

**Single Player**: Sets config values directly, calls `Config.configure_single_player_session()`, saves, and loads `main.tscn` via loading screen.

**Multiplayer**: Builds a config dictionary with all game parameters, sets `Config.difficulty`, calls `NetworkManager.configure_host()` + `start_host()`, and navigates to `host_lobby.tscn`.

---

## Win/Gotcha Screen Integration

After a game ends, the win screen shows:
- **Next Round** / **Try Again** + auto-countdown
- **Harder** / **Easier** (adjusts maze size)
- **Play Together** (SP only, green) → starts MP host with current settings, goes to lobby
- **Play Alone** (MP only, blue) → leaves MP session, starts SP with current settings
- **Swap Roles** (MP versus only)
- **Home** → back to main menu

The win screen uses `set_is_multiplayer(bool)` to know which mode-switch button to show.

---

## Common Pitfalls for Refactoring

1. **`MissionCatalog` is not a class_name** — it must be `preload()`'d in every script that uses it
2. **Character preview is an overlay** — if you move it into a container, it will break row alignment
3. **Focus rewiring on every card focus change** — if you remove the `_configure_navigation()` call from `_on_stepN_card_focus_changed`, cards will lose focus retention
4. **Auto-skip changes the back-navigation target** — `_go_back_smart` must mirror the skip logic in `_on_step1_confirmed` / `_on_step2_confirmed`
5. **RTL swaps left/right nav indices** — if you change card ordering or add new card rows, update `_configure_card_row_nav`
6. **Corner buttons are positioned absolutely** — they're children of a `Control` overlay, not the VBox. Position updates are in `_position_corner_buttons()`
7. **Step 3 settings visibility is contextual** — it depends on which card is _focused_, not _selected_. Use `get_focused_card_id()` not `_selected_action`
