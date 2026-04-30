## scenes.gd
## ---------------------------------------------------------------------------
## Single source of truth for all scene paths used in scene transitions.
##
## Usage:
##   get_tree().change_scene_to_file(Scenes.HOME)
##   UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.GAME)
## ---------------------------------------------------------------------------
class_name Scenes
extends RefCounted

# ── Menu / UI ────────────────────────────────────────────────────────────────
const HOME := "res://scenes/top_menu.tscn"
const WIZARD := "res://scenes/main_menu.tscn"
const GAME := "res://scenes/main.tscn"
const SETTINGS := "res://scenes/settings_menu.tscn"
const HELP := "res://scenes/help_menu.tscn"
const LOADING := "res://scenes/loading_screen.tscn"

# ── Multiplayer ──────────────────────────────────────────────────────────────
const HOST_SETUP := "res://scenes/multiplayer/host_setup.tscn"
const HOST_LOBBY := "res://scenes/multiplayer/host_lobby.tscn"
const JOIN_FLOW := "res://scenes/multiplayer/join_flow.tscn"
const MP_GAME := "res://scenes/multiplayer/multiplayer_game.tscn"

# ── Spawnable / Preloaded (not used for change_scene) ────────────────────────
const COLLECTIBLE := "res://scenes/collectible.tscn"
const CHASER := "res://scenes/chaser.tscn"
const MODE_CARD := "res://scenes/ui/mode_card.tscn"
