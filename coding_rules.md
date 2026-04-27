# Coding Rules — Learning Maze (Bludiste)

Best practices for keeping this Godot 4 / GDScript codebase maintainable.
Written after a full architectural audit and remediation — these rules exist
because each one was violated at some point and caused real pain.

---

## 1. Single Source of Truth

Every value, pattern, or path should be defined **once**.

### Constants & Domain Values

| What | Canonical Location | How to Consume |
|------|--------------------|----------------|
| Mission / pickup / role / style IDs | `MissionCatalog` | `MissionCatalog.MISSION_FIND_EXIT`, etc. |
| Game mode enums, session state | `game_config.gd` (`Config` autoload) | `Config.GameMode.WORDS`, `Config.game_style` |
| Colors | `UIColors` | `UIColors.BLUE`, `UIColors.BG_DARK`, etc. |
| Scene paths | `Scenes` | `Scenes.HOME`, `Scenes.GAME`, etc. |

**Never re-declare a constant locally.** If you need it in another file, import
or alias it:

```gdscript
# ✅ Good — alias from the source
const STYLE_PATH = MissionCatalog.STYLE_PATH

# ❌ Bad — redeclaring the same value
const STYLE_PATH := "path"
```

If a constant lives in two places, delete one and alias the other.

### Scene Paths

Use `Scenes.*` for `change_scene_to_file()` and `go_to_scene_with_loading()`:

```gdscript
# ✅ Good
get_tree().change_scene_to_file(Scenes.HOME)

# ❌ Bad
get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
```

> **Exception:** `preload()` requires a compile-time string literal.
> `preload("res://scenes/collectible.tscn")` is fine. Only `preload()` gets
> this exception.

### Pickup Card Metadata

Pickup card order, icons, title keys, and subtitle keys live in
`MissionCatalog.PICKUP_CARD_*`. Do not scatter these into individual screen
scripts.

---

## 2. UI Components — Use the Shared Utilities

The `scripts/ui/` folder contains reusable UI building blocks. **Use them
instead of copy-pasting the pattern into your screen script.**

| Utility | Purpose | Key API |
|---------|---------|---------|
| `CyclingSelector` | `< Button >` D-pad cycling rows | `create_row()`, `setup_cycling()`, `setup_arrow_visibility()` |
| `FocusNavigator` | D-pad focus neighbor wiring | `wire_vertical()`, `wire_horizontal()`, `wire_grid()` |
| `PlayerSlotPanel` | Multiplayer player slot frames | `apply_character_preview()`, `ordered_peer_ids()` |
| `BreadcrumbRow` | Read-only settings summary bar | `BreadcrumbRow.create()` |

### How to tell you need to extract

If you're writing code that:
- Creates a `Button` + two `Label` arrows + connects `gui_input` → use `CyclingSelector`
- Sets `focus_neighbor_*` on multiple controls → use `FocusNavigator`
- Builds a slot frame with `CharacterPreview` + name label → use `PlayerSlotPanel`
- Creates a non-focusable chevron + summary row → use `BreadcrumbRow`

### Adding new shared utilities

1. Place it in `scripts/ui/`
2. Use `class_name` so it's globally available
3. Prefer `static func` factories on `RefCounted` for purely data-constructing utilities
4. Add a doc comment header with usage example (see `cycling_selector.gd`)

---

## 3. Strings and Localization

### Every user-visible string must go through `tr()`

```gdscript
# ✅ Good
label.text = tr("mp_waiting_for_players")

# ❌ Bad
label.text = "Waiting for players to join..."
```

### Translation keys live in `data/translations.csv`

- Add the key with at least the English column filled
- Use descriptive, namespaced keys: `mp_slot_waiting`, `hud_desc_sp_path`,
  `mission_goal_exit`
- For format strings with `%s` or `%d`, keep the placeholder in the translation:
  `Start Game with %d players`

### Do not duplicate goal/description text in code

Goal text for the HUD is already handled by `MissionCatalog.goal_key()` and
the `hud_desc_*` / `mission_goal_*` translation keys. Use `tr(key)`, do not
write your own English fallback strings.

---

## 4. Navigation and D-Pad

This app runs on **Android TV with D-pad only** as the primary input. Every
interactive screen must work without touch or mouse.

### Rules

1. **Every focusable control must have explicit focus neighbors** — never rely
   on Godot's auto-focus. Use `FocusNavigator` to wire them.
2. **`gui_input` over `_input`** — use `gui_input` on the focused control to
   intercept D-pad Left/Right for cycling. Call `get_viewport().set_input_as_handled()`
   to prevent the event from moving focus.
3. **`_unhandled_input` for Back** — wire `ui_cancel` in `_unhandled_input`
   for the back/escape action so it doesn't conflict with focused controls.
4. **Test every screen with keyboard-only** — Tab, Shift+Tab, arrows, Enter,
   Escape must all work correctly.

### Focus wiring checklist for new screens

- [ ] Call `FocusNavigator.wire_*` after building the layout
- [ ] Set initial focus with `button.grab_focus()` in `_ready()` or after
      the layout is visible
- [ ] Verify wrap-around behavior (topmost ↔ bottommost)
- [ ] Test with `ui_cancel` to go back

---

## 5. File and Folder Organization

```
scripts/
  game_config.gd          # Config autoload — game state, settings
  game_manager.gd         # Single-player game loop
  game_setup_wizard.gd    # Main menu / setup wizard
  mission_catalog.gd      # Domain constants, mission logic
  scenes.gd               # Scene path constants
  ui_colors.gd            # Color palette constants
  ui_helpers.gd           # Static UI utility functions
  ...

  ui/                     # Reusable UI components
    cycling_selector.gd
    focus_navigator.gd
    player_slot_panel.gd
    breadcrumb_row.gd
    character_preview.gd
    mode_card.gd
    wizard_step.gd
    avatar_accent.gd

  multiplayer/            # Multiplayer-specific screens and logic
    host_setup.gd
    host_lobby.gd
    join_flow.gd
    multiplayer_game_manager.gd
    ...

  network/                # Networking layer
    network_manager.gd
    wifi_helper.gd
```

### Rules

- **One script per concern.** A script attached to a scene node should only
  manage that node's behavior.
- **No orphan scripts.** If a `.gd` file is not attached to any `.tscn` and
  not referenced by any other script, delete it.
- **Multiplayer screens go in `scripts/multiplayer/`.**
- **Reusable UI goes in `scripts/ui/`.** If two screens use the same visual
  pattern, extract it here.
- **No duplicate script files.** If `scripts/ui/avatar_accent.gd` exists,
  there must not also be a `scripts/multiplayer/avatar_accent.gd`.

---

## 6. Scene Transitions

### Lightweight transitions (menu ↔ menu)

```gdscript
get_tree().change_scene_to_file(Scenes.SETTINGS)
```

### Heavy transitions (loading a game level)

```gdscript
UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)
```

### Leaving a multiplayer session

Always clean up before transitioning:

```gdscript
NetworkManager.leave_session()
Config.show_join_list_on_home = true
Config.join_status_override = ""
get_tree().change_scene_to_file(Scenes.HOME)
```

Do not create multiple functions that do the same cleanup-and-navigate
sequence. Consolidate into one (e.g., `_leave_session()`).

---

## 7. Responsive Layout

All screens must work across phone, tablet, and TV form factors.

### Pattern

Each screen script should have:

```gdscript
func _apply_responsive_layout() -> void:
    var viewport_height := get_viewport_rect().size.y
    var short_screen := viewport_height < 820.0
    # Adjust sizes, spacings, font sizes based on short_screen
```

Call it from `_ready()` and on `NOTIFICATION_RESIZED`.

### Rules

- Use `clampf()` for sizing: `clampf(width * 0.48, 380.0, 780.0)`
- Define two tiers: `short_screen` (< 820px) and normal
- Don't hardcode pixel values without clamp ranges
- Always test at 720p (TV minimum) and 1080p

---

## 8. Code Style

### Header comments

Every `.gd` file should have a header comment explaining what it does:

```gdscript
## cycling_selector.gd
## -----------------------------------------------------------------------
## Shared factory for the "cycling selector" UI pattern used across the app.
##
## Usage:
##   var row := CyclingSelector.create_row("setting_lang")
## -----------------------------------------------------------------------
```

### Naming

- **Constants:** `UPPER_SNAKE_CASE` — `const STYLE_PATH := "path"`
- **Private functions:** `_leading_underscore` — `func _build_layout()`
- **Signals:** past tense — `signal lobby_updated`
- **Nodes:** `snake_case` for `@onready` vars — `@onready var host_list_vbox`
- **Translation keys:** `snake_case` with namespace prefix — `mp_slot_waiting`,
  `hud_desc_sp_path`

### Section separators

Use decorated comments to group sections within large files:

```gdscript
# ── Layout ──────────────────────────────────────────────────────────────────

# ── Slot Management ─────────────────────────────────────────────────────────
```

### Null safety

Always guard against null nodes, especially in multiplayer code where timing
is unpredictable:

```gdscript
if btn == null:
    return
```

### Type hints

Use static typing wherever possible:

```gdscript
var peer_ids: Array[int] = []
var style: String = Config.game_style
func _get_goal() -> String:
```

---

## 9. What NOT to Do

These are patterns that were found during the audit and removed. Do not
reintroduce them.

| Anti-pattern | Why it's bad | What to do instead |
|--------------|--------------|--------------------|
| Copying a function from one script to another | Creates drift when only one copy gets fixed | Extract to `scripts/ui/` or a shared utility |
| Declaring `const ROLE_CHASER := "chaser"` in multiple files | One file gets updated, others don't | Use `MissionCatalog.ROLE_CHASER` |
| Hardcoding `"res://scenes/main_menu.tscn"` | Rename breaks 17 files | Use `Scenes.HOME` |
| Writing `label.text = "Some English"` | Breaks localization | Use `label.text = tr("some_key")` |
| Creating `_go_back()` and `_leave()` that do the same thing | Confusion about which to call | Consolidate into one function |
| Keeping a dead `.gd` file "just in case" | Confuses future developers | Delete it. Git has history. |
| Using `_input()` for D-pad cycling on a button | Steals events from other controls | Use `gui_input` on the specific button |

---

## 10. Pre-Commit Checklist

Before merging any screen-related change:

- [ ] No new hardcoded `"res://scenes/"` strings (use `Scenes.*`)
- [ ] No new hardcoded English UI strings (use `tr()` + translation key)
- [ ] No duplicate functions across files (check `scripts/ui/` first)
- [ ] No duplicate constant declarations (check `MissionCatalog`, `UIColors`)
- [ ] D-pad navigation works (keyboard-only test)
- [ ] Layout works at 720p and 1080p
- [ ] `ui_cancel` goes back correctly
- [ ] No orphan `.gd` files left behind
