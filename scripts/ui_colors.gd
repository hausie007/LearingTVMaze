## ui_colors.gd
## ---------------------------------------------------------------------------
## Centralized color constants for the game's UI brand palette.
##
## Palette derived from the storybook paper-cutout logo and icons.
## All menu card colors, borders, and text tones should reference these
## constants so the interface stays cohesive as the art evolves.
## ---------------------------------------------------------------------------
class_name UIColors
extends RefCounted


# ── Foundation ───────────────────────────────────────────────────────────────

## Main dark ink background for all menu screens.
const BG_INK := Color("#171B24")

## Slightly deeper ink for vignette edges or overlays.
const BG_INK_DEEP := Color("#11151D")

## Default inactive card fill — quiet but distinct from background.
const CARD_NEUTRAL := Color("#252B38")

## Alternate inactive card fill for subtle variety.
const CARD_NEUTRAL_ALT := Color("#202633")

## Inactive card border.
const CARD_BORDER := Color("#465166")

## Softer inactive card border variant.
const CARD_BORDER_SOFT := Color("#384254")

## Warm off-white for primary text on dark backgrounds.
const TEXT_PRIMARY := Color("#F7F5ED")

## Muted secondary text — subtitles, descriptions.
const TEXT_SECONDARY := Color("#B9BAC2")

## Disabled / very low-emphasis text.
const TEXT_DISABLED := Color("#7E838E")

## Cream matching the paper-cutout icon outlines.
const PAPER_CREAM := Color("#F7E3AD")

## Lighter cream for highlights.
const PAPER_CREAM_LIGHT := Color("#FFF0C8")

## Warm gold used for focus indicators and selected card glow.
const FOCUS_GOLD := Color("#E7B62E")

## Bright heading yellow.
const HEADING_YELLOW := Color("#F6C51A")

# ── Logo-Derived UI Colors (selected card fills) ────────────────────────────

## Yellow — Play Now / quick primary action.
const UI_YELLOW := Color("#95690F")

## Blue — learning / adventure selection.
const UI_BLUE := Color("#2B73B5")

## Green — friendly co-op / Play Together.
const UI_GREEN := Color("#267C42")

## Orange-Red — chaser / competitive / race.
const UI_ORANGE_RED := Color("#A94D3B")

## Purple — settings or special utility (reserved).
const UI_PURPLE := Color("#6A4BA3")

# ── Dark Category Tints (inactive card backgrounds for themed cards) ────────

const CARD_GREEN_DARK := Color("#14381F")
const CARD_BLUE_DARK := Color("#1C3148")
const CARD_YELLOW_DARK := Color("#3E2B08")
const CARD_ORANGE_RED_DARK := Color("#3B211D")

# ── Selected Card Accents ────────────────────────────────────────────────────

## Warm cream border for selected/focused cards — matches paper icons.
const SELECTED_BORDER_CREAM := Color("#F7E3AD")

## Warm gold glow around focused cards (rgba 231,182,46, 0.28).
const SELECTED_GLOW := Color(0.906, 0.714, 0.180, 0.28)

## Soft warm shadow for selected cards.
const SELECTED_SHADOW := Color(0, 0, 0, 0.35)


# ── Legacy Aliases ───────────────────────────────────────────────────────────
# Kept so that non-menu code (HUD, D-Pad, dialogs, TTS indicators, etc.)
# continues to compile without changes.  Prefer the new names in new code.

const BLUE := Color("#1188FF")
const YELLOW := Color("#FFCC00")
const BG_DARK := Color("#171B24")          # → BG_INK
const BG_PAGE := Color("#11151D")          # → BG_INK_DEEP
const OVERLAY := Color(0, 0, 0, 0.7)

const GREEN := Color("#22AA44")
const GREEN_DARK := Color("#14381F")       # → CARD_GREEN_DARK
const GREEN_BORDER := Color("#384254")     # → CARD_BORDER_SOFT
const GREEN_ACCENT := Color("#267C42")     # → UI_GREEN
const GREEN_HINT := Color(0.45, 0.82, 0.52)

const GOLD := Color("#FFB800")
const GOLD_DARK := Color("#3E2B08")        # → CARD_YELLOW_DARK
const GOLD_BORDER := Color("#465166")      # → CARD_BORDER
const GOLD_ACCENT := Color("#95690F")      # → UI_YELLOW

const TEAL := Color("#1AA89E")
const TEAL_DARK := Color("#1C3148")        # → CARD_BLUE_DARK
const TEAL_BORDER := Color("#384254")      # → CARD_BORDER_SOFT
const TEAL_ACCENT := Color("#2B73B5")      # → UI_BLUE

const TEXT_ON_BRIGHT := Color("#112244")
const BORDER_SUBTLE := Color(1, 1, 1, 0.1)
const TEXT_SUBTITLE := Color("#B9BAC2")    # → TEXT_SECONDARY

# Storybook-palette aliases used in earlier pass (keep for compat)
const SELECTED_BLUE := Color("#2B73B5")    # → UI_BLUE
const SELECTED_GREEN := Color("#267C42")   # → UI_GREEN
const SELECTED_AMBER := Color("#95690F")   # → UI_YELLOW
const SELECTED_TEAL := Color("#2B73B5")    # → UI_BLUE
const SELECTED_ACCENT_YELLOW := Color("#E7B62E")  # → FOCUS_GOLD

# ── HUD & In-Game UI ────────────────────────────────────────────────────────

const TEXT_DIM := Color(0.3, 0.33, 0.4)
const TEXT_HUD := Color(0.7, 0.75, 0.8)
const BG_HUD := Color(0.09, 0.11, 0.14, 0.90)
const BG_PANEL := Color(0.09, 0.11, 0.14, 0.95)
const TIMER_DIM := Color(0.5, 0.5, 0.5)

# ── TTS Status Indicators ───────────────────────────────────────────────────

const TTS_PENDING := Color(0.8, 0.8, 0.8)
const TTS_ERROR := Color(1.0, 0.4, 0.4)
const TTS_OK := Color(0.4, 0.8, 0.4)

# ── Collectible Tracker ─────────────────────────────────────────────────────

const TRACKER_COLLECTED := Color("#FFCC00")
const TRACKER_CURRENT := Color("#1188FF")
const TRACKER_FUTURE := Color(0.22, 0.24, 0.30)
const TRACKER_FUTURE_TEXT := Color(0.55, 0.58, 0.65)
const HIGHLIGHT_HALO := Color(0.07, 0.53, 1.0, 0.35)
