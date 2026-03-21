## theme_loader.gd
## ---------------------------------------------------------------------------
## Loads theme images (PNG with transparency) from a directory.
##
## Expected files in the theme directory:
##   • start.png  – displayed on the Start cell
##   • end.png    – displayed on the End / goal cell
##   • player.png – displayed as the player character
##
## If a file is missing or cannot be loaded, the corresponding texture is
## left as null and the caller should fall back to the default ColorRect.
## ---------------------------------------------------------------------------
class_name ThemeLoader
extends RefCounted

## Loaded resources.
var start_texture:  Texture2D = null
var end_texture:    Texture2D = null
var player_texture: Texture2D = null
var bg_texture:     Texture2D = null
var col_texture:    Texture2D = null
var chaser_texture: Texture2D = null

var color_wall:     Color = Color(0.75, 0.78, 0.82)
var color_wall_border: Color = Color(0, 0, 0, 0) # Transparent by default
var color_floor:    Color = Color(0.18, 0.20, 0.25)
var color_start:    Color = Color(0.21, 0.36, 0.29)
var color_end:      Color = Color(0.20, 0.30, 0.43)
var color_player:   Color = Color(0.25, 0.55, 0.95)

var bg_tiled:       bool = false
var bg_full_screen: bool = false

# Collectible Styling
var col_color:      Color = Color(1.0, 0.95, 0.6)  # Default pale yellow
var col_text_color: Color = Color(0.1, 0.1, 0.15) # Default dark slate

var manifest: Dictionary = {}

## Load theme resources from the directory specified in Config.
func load_theme() -> void:
	var dir_path: String = Config.theme_dir
	_load_manifest(dir_path)

	# Textures
	player_texture = _try_load(dir_path, _get_asset("player", "player.png"))
	start_texture  = _try_load(dir_path, _get_asset("start", "start.png"))
	end_texture    = _try_load(dir_path, _get_asset("end", "end.png"))
	bg_texture     = _try_load(dir_path, _get_asset("background", "background.png"))
	chaser_texture = _try_load(dir_path, _get_asset("chaser", "chaser.png"))

	# Colors
	color_wall    = _get_color("wall", color_wall)
	color_wall_border = _get_color("wall_border", Color(0, 0, 0, 0))
	color_floor   = _get_color("floor", color_floor)
	color_start   = _get_color("start_cell", color_start)
	color_end     = _get_color("end_cell", color_end)
	color_player  = _get_color("player", color_player)

	# Background Options
	if manifest.has("background"):
		var bg_cfg = manifest["background"]
		if bg_cfg is Dictionary:
			bg_tiled = bg_cfg.get("tiled", false)
			bg_full_screen = bg_cfg.get("full_screen", false)
			if bg_cfg.has("color"):
				# Background color can optionally override wall color for the whole maze base
				color_wall = Color.from_string(bg_cfg["color"], color_wall)

	# Collectible Options
	if manifest.has("collectible"):
		var col_cfg = manifest["collectible"]
		if col_cfg is Dictionary:
			if col_cfg.has("color"):
				col_color = Color.from_string(col_cfg["color"], col_color)
			if col_cfg.has("text-color"):
				col_text_color = Color.from_string(col_cfg["text-color"], col_text_color)
			if col_cfg.has("image"):
				col_texture = _try_load(dir_path, col_cfg["image"])

func _load_manifest(dir_path: String) -> void:
	var path := dir_path.path_join("manifest.json")
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json_text := file.get_as_text()
		var json = JSON.new()
		if json.parse(json_text) == OK:
			manifest = json.data
		else:
			push_error("ThemeLoader: Failed to parse manifest at %s" % path)

func _get_asset(key: String, default: String) -> String:
	if manifest.has("assets") and manifest["assets"].has(key):
		return manifest["assets"][key]
	return default

func _get_color(key: String, default: Color) -> Color:
	if manifest.has("colors") and manifest["colors"].has(key):
		return Color.from_string(manifest["colors"][key], default)
	return default

func _try_load(dir_path: String, file_name: String) -> Texture2D:
	var full_path := dir_path.path_join(file_name)
	if not ResourceLoader.exists(full_path):
		return null
	var resource = ResourceLoader.load(full_path)
	if resource is Texture2D:
		return resource as Texture2D
	return null
