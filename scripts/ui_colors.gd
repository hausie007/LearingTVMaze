## ui_colors.gd
## ---------------------------------------------------------------------------
## Centralized color constants for the game's UI brand palette.
##
## Convention:
##   BLUE  = Gameplay modifiers (Mode, Difficulty, Chaser, Play actions)
##   YELLOW = App/navigation actions (Settings, Theme, Language, Voice, Home)
##   BG    = Dark panel backgrounds
## ---------------------------------------------------------------------------
class_name UIColors
extends RefCounted


# ── Brand Palette ────────────────────────────────────────────────────────────

## Sky Blue — used for gameplay-modifying buttons and focused states.
const BLUE := Color("#1188FF")

## Warm Yellow/Gold — used for app/navigation buttons and settings focus.
const YELLOW := Color("#FFCC00")

## Dark Navy — panel and background color for dialogs and menus.
const BG_DARK := Color(0.15, 0.17, 0.22)

## Very Dark — page-level background.
const BG_PAGE := Color(0.1, 0.11, 0.14)

## Semi-transparent black overlay for modals.
const OVERLAY := Color(0, 0, 0, 0.7)

## Dark text color for buttons with bright backgrounds.
const TEXT_ON_BRIGHT := Color("#112244")

## Light grey for secondary text (row titles, scores).
const TEXT_SECONDARY := Color(0.8, 0.82, 0.85)

## White for primary text on dark backgrounds.
const TEXT_PRIMARY := Color.WHITE

## Subtle border for unfocused buttons.
const BORDER_SUBTLE := Color(1, 1, 1, 0.1)

# ── HUD & In-Game UI ────────────────────────────────────────────────────────

## Dim text for unlit word letters in the HUD.
const TEXT_DIM := Color(0.3, 0.33, 0.4)

## Muted text for HUD time/moves display.
const TEXT_HUD := Color(0.7, 0.75, 0.8)

## HUD top-bar background with transparency.
const BG_HUD := Color(0.1, 0.12, 0.16, 0.90)

## Win/Gotcha panel background with near-opaque transparency.
const BG_PANEL := Color(0.15, 0.17, 0.22, 0.95)

## Timer countdown text color.
const TIMER_DIM := Color(0.5, 0.5, 0.5)

## Mode card subtitle when unfocused.
const TEXT_SUBTITLE := Color(0.7, 0.7, 0.7, 1.0)

# ── TTS Status Indicators ───────────────────────────────────────────────────

## TTS checking/pending state.
const TTS_PENDING := Color(0.8, 0.8, 0.8)

## TTS unavailable/error state.
const TTS_ERROR := Color(1.0, 0.4, 0.4)

## TTS ready/available state.
const TTS_OK := Color(0.4, 0.8, 0.4)
