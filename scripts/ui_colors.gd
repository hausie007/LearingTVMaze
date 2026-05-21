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
const BG_INK := Color("#151A23")

## Slightly deeper ink for vignette edges or overlays.
const BG_INK_DEEP := Color("#11151D")

## Default inactive card / panel fill — quiet but distinct from background.
const CARD_NEUTRAL := Color("#242B38")

## Alternate inactive card fill for subtle variety.
const CARD_NEUTRAL_ALT := Color("#202633")

## Inactive card / panel border.
const CARD_BORDER := Color("#3A4658")

## Softer inactive card border variant.
const CARD_BORDER_SOFT := Color("#2F394A")

## Dark fill for secondary setting fields (unfocused state).
const PANEL_BG_DARK := Color("#171C25")

# ── Text ─────────────────────────────────────────────────────────────────────

## Warm off-white for primary text on dark backgrounds.
const TEXT_PRIMARY := Color("#F5F1E8")

## Muted secondary text — subtitles, descriptions.
const TEXT_SECONDARY := Color("#C9CCD4")

## Very low-emphasis text / disabled.
const TEXT_MUTED := Color("#9EA4B2")

# ── Parchment & Focus ───────────────────────────────────────────────────────

## Parchment cream matching the paper-cutout icon outlines / card borders.
const PARCHMENT := Color("#F6EDD8")

## Darker parchment — borders of backplates, icon outline shadows.
const PARCHMENT_DARK := Color("#D9C48A")

## Deep warm shadow for parchment elements.
const PARCHMENT_SHADOW := Color("#8A6A2E")

## Warm gold used for focus indicators and field borders.
const FOCUS_GOLD := Color("#F2C94C")

## Softer gold for selected card borders.
const FOCUS_GOLD_SOFT := Color("#FFE8A3")

## Semi-transparent gold glow for focus states.
const FOCUS_GLOW := Color(0.949, 0.788, 0.298, 0.33)

## Bright heading yellow.
const HEADING_YELLOW := Color("#F6C51A")

# ── Logo-Derived UI Colors (selected card fills) ────────────────────────────

## Yellow — Play Now / quick primary action.
const UI_YELLOW := Color("#95690F")

## Blue — learning / adventure / default selected.
const UI_BLUE := Color("#2F7DBB")

## Green — friendly co-op / Play Together.
const UI_GREEN := Color("#2F8A4E")

## Orange-Red — competitive / race.
const UI_ORANGE_RED := Color("#B95746")

## Purple — settings or special utility (reserved).
const UI_PURPLE := Color("#6A4BA3")

# ── Accent Colors (brighter, for icons & highlights on selected cards) ──────

const BLUE_ACCENT := Color("#2F8DE4")
const GREEN_ACCENT := Color("#8DBB4A")
const RED_ACCENT := Color("#E86A4A")

# ── Dark Category Tints (inactive card backgrounds for themed cards) ────────

const CARD_GREEN_DARK := Color("#14381F")
const CARD_BLUE_DARK := Color("#1C3148")
const CARD_YELLOW_DARK := Color("#3E2B08")
const CARD_ORANGE_RED_DARK := Color("#3B211D")

# ── Selected Card Accents ────────────────────────────────────────────────────

## Warm parchment border for selected/focused cards.
const SELECTED_BORDER := Color("#F6EDD8")

## Semi-transparent warm glow around focused cards.
const SELECTED_GLOW := Color(0.949, 0.788, 0.298, 0.33)

## Soft warm shadow for selected cards.
const SELECTED_SHADOW := Color(0, 0, 0, 0.35)


# ── Multiplayer & Game Roles ───────────────────────────────────────────────

## Base green for cooperative play / host slots / join setups
const MP_GREEN := Color("#2D9B58")

## Highlight/border color for green multiplayer elements
const MP_GREEN_BORDER := Color("#3DC878")

## Base red for chaser role slots / join setups
const MP_RED := Color("#C84848")

## Highlight/border color for red multiplayer elements
const MP_RED_BORDER := Color("#E05050")

## Inactive/empty multiplayer slots outline tone
const SLOT_EMPTY_COLOR := Color(1, 1, 1, 0.18)

## Inactive/empty multiplayer slots background plate tone
const SLOT_EMPTY_BG := Color(0.15, 0.17, 0.22, 0.6)

## Action success button accent for join flow
const JOIN_GREEN := Color(0.18, 0.62, 0.34)


# ── Legacy Aliases ───────────────────────────────────────────────────────────
# Kept so that non-menu code (HUD, D-Pad, dialogs, TTS indicators, etc.)
# continues to compile without changes.  Prefer the new names in new code.

const BLUE := Color("#1188FF")
const YELLOW := Color("#FFCC00")
const BG_DARK := Color("#151A23")          # → BG_INK
const BG_PAGE := Color("#11151D")          # → BG_INK_DEEP
const OVERLAY := Color(0, 0, 0, 0.7)

const GREEN := Color("#22AA44")
const GREEN_DARK := Color("#14381F")       # → CARD_GREEN_DARK
const GREEN_BORDER := Color("#2F394A")     # → CARD_BORDER_SOFT
const GREEN_ACCENT_LEGACY := Color("#2F8A4E")  # → UI_GREEN
const GREEN_HINT := Color(0.45, 0.82, 0.52)

const GOLD := Color("#FFB800")
const GOLD_DARK := Color("#3E2B08")        # → CARD_YELLOW_DARK
const GOLD_BORDER := Color("#3A4658")      # → CARD_BORDER
const GOLD_ACCENT := Color("#95690F")      # → UI_YELLOW

const TEAL := Color("#1AA89E")
const TEAL_DARK := Color("#1C3148")        # → CARD_BLUE_DARK
const TEAL_BORDER := Color("#2F394A")      # → CARD_BORDER_SOFT
const TEAL_ACCENT := Color("#2F7DBB")      # → UI_BLUE

const TEXT_ON_BRIGHT := Color("#112244")
const BORDER_SUBTLE := Color(1, 1, 1, 0.1)
const TEXT_SUBTITLE := Color("#C9CCD4")    # → TEXT_SECONDARY
const TEXT_DISABLED := Color("#9EA4B2")    # → TEXT_MUTED

# Storybook-palette aliases used in earlier pass (keep for compat)
const SELECTED_BLUE := Color("#2F7DBB")    # → UI_BLUE
const SELECTED_GREEN := Color("#2F8A4E")   # → UI_GREEN
const SELECTED_AMBER := Color("#95690F")   # → UI_YELLOW
const SELECTED_TEAL := Color("#2F7DBB")    # → UI_BLUE
const SELECTED_ACCENT_YELLOW := Color("#F2C94C")  # → FOCUS_GOLD
const SELECTED_BORDER_CREAM := Color("#F6EDD8")  # → SELECTED_BORDER

# Old names for paper cream
const PAPER_CREAM := Color("#F6EDD8")      # → PARCHMENT
const PAPER_CREAM_LIGHT := Color("#FFF0C8")

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
