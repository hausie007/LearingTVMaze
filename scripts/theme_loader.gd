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

var player_frames: Array[Texture2D] = []
var chaser_frames: Array[Texture2D] = []
var bg_frames: Array[Texture2D] = []
var col_frames: Array[Texture2D] = []

## Animation speeds (FPS).
var player_fps: float = 5.0
var chaser_fps: float = 5.0
var bg_fps: float = 5.0
var col_fps: float = 5.0

var color_wall:     Color = Color(0.75, 0.78, 0.82)
var color_wall_border: Color = Color(0, 0, 0, 0) # Transparent by default
var color_floor:    Color = Color(0.18, 0.20, 0.25)
var color_start:    Color = Color(0.21, 0.36, 0.29)
var color_end:      Color = Color(0.20, 0.30, 0.43)
var color_player:   Color = Color(0.25, 0.55, 0.95)

var bg_tiled:       bool = false
var bg_full_screen: bool = false
var bg_modulate:    Color = Color.WHITE

# Glow Options (HDR)
var glow_enabled:   bool = false
var glow_strength:  float = 1.0
var glow_bloom:     float = 0.2
var wall_glow_factor: float = 1.0

# Collectible Styling
var col_color:      Color = Color(1.0, 0.95, 0.6)  # Default pale yellow
var col_text_color: Color = Color(0.1, 0.1, 0.15) # Default dark slate

var manifest: Dictionary = {}

## Load theme resources from the directory specified in Config, or override.
func load_theme(override_dir_name: String = "") -> void:
	var dir_path: String = Config.theme_dir
	if not override_dir_name.is_empty():
		var res_path := "res://themes/".path_join(override_dir_name)
		if DirAccess.dir_exists_absolute(res_path):
			dir_path = res_path
		else:
			var user_path := "user://themes/".path_join(override_dir_name)
			if DirAccess.dir_exists_absolute(user_path):
				dir_path = user_path
			else:
				dir_path = "res://themes/default"

	player_frames.clear()
	chaser_frames.clear()
	bg_frames.clear()
	col_frames.clear()
	player_fps = 5.0
	chaser_fps = 5.0
	bg_fps = 5.0
	col_fps = 5.0

	manifest = _load_manifest(dir_path)

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
		var bg_cfg: Variant = manifest["background"]
		if bg_cfg is Dictionary:
			bg_tiled = bg_cfg.get("tiled", false)
			bg_full_screen = bg_cfg.get("full_screen", false)
			if bg_cfg.has("color"):
				# Background color can optionally override wall color for the whole maze base
				color_wall = Color.from_string(bg_cfg["color"], color_wall)
			if bg_cfg.has("modulate"):
				bg_modulate = Color.from_string(bg_cfg["modulate"], Color.WHITE)

	# Glow Options
	if manifest.has("glow"):
		var glow_cfg: Variant = manifest["glow"]
		if glow_cfg is Dictionary:
			glow_enabled  = glow_cfg.get("enabled", false)
			glow_strength = float(glow_cfg.get("strength", 1.0))
			glow_bloom    = float(glow_cfg.get("bloom", 0.2))

	# Wall Glow Factor (Multiplies base color to reach HDR threshold)
	if manifest.get("colors", {}).has("wall_glow_factor"):
		wall_glow_factor = float(manifest["colors"]["wall_glow_factor"])

	# Collectible Options
	if manifest.has("collectible"):
		var col_cfg: Variant = manifest["collectible"]
		if col_cfg is Dictionary:
			if col_cfg.has("color"):
				col_color = Color.from_string(col_cfg["color"], col_color)
			if col_cfg.has("text-color"):
				col_text_color = Color.from_string(col_cfg["text-color"], col_text_color)
			if col_cfg.has("image"):
				col_texture = _try_load(dir_path, col_cfg["image"])

	# Animation Options
	var p_anim: Dictionary = _parse_anim_cfg("player", _get_asset("player", "player.png"), dir_path)
	player_fps = p_anim["fps"]
	player_frames = p_anim["frames"]
	if player_texture == null and not player_frames.is_empty():
		player_texture = player_frames[0]

	var c_anim: Dictionary = _parse_anim_cfg("chaser", _get_asset("chaser", "chaser.png"), dir_path)
	chaser_fps = c_anim["fps"]
	chaser_frames = c_anim["frames"]
	if chaser_texture == null and not chaser_frames.is_empty():
		chaser_texture = chaser_frames[0]

	var b_anim: Dictionary = _parse_anim_cfg("background", _get_asset("background", "background.png"), dir_path)
	bg_fps = b_anim["fps"]
	bg_frames = b_anim["frames"]
	if bg_texture == null and not bg_frames.is_empty():
		bg_texture = bg_frames[0]

	var col_file: String = "collectible.png"
	if manifest.has("collectible") and manifest["collectible"] is Dictionary and manifest["collectible"].has("image"):
		col_file = manifest["collectible"]["image"]
		
	var col_anim: Dictionary = _parse_anim_cfg("collectible", col_file, dir_path)
	col_fps = col_anim["fps"]
	col_frames = col_anim["frames"]
	if col_texture == null and not col_frames.is_empty():
		col_texture = col_frames[0]

## Return the human-readable display title for this loaded theme.
## Uses the manifest "title" field if present, otherwise capitalizes the dir name.
func get_display_title(fallback_dir_name: String = "") -> String:
	var display_title: String = fallback_dir_name.capitalize() if not fallback_dir_name.is_empty() else "Theme"
	if manifest.has("title"):
		var manifest_title = manifest["title"]
		if manifest_title is String and not manifest_title.is_empty():
			display_title = manifest_title
	return display_title

## Scan available themes dynamically.
static func get_available_themes() -> Array[String]:
	var themes: Array[String] = []
	
	# 1. Scan built-in themes
	_scan_theme_dir("res://themes/", themes)
	
	# 2. Scan user-downloaded themes
	_scan_theme_dir("user://themes/", themes)
	
	if themes.is_empty():
		themes.append("default")
		
	return themes

static func _scan_theme_dir(path: String, out_list: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
		
	var dir := DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				if not out_list.has(file_name):
					out_list.append(file_name)
			file_name = dir.get_next()

# ── Private Helpers ──────────────────────────────────────────────────────────

func _load_manifest(dir_path: String) -> Dictionary:
	var path: String = dir_path + "/manifest.json"
	var result: Dictionary = {}
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		var json_text := file.get_as_text()
		var json: JSON = JSON.new()
		if json.parse(json_text) == OK:
			result = json.data
		else:
			push_error("ThemeLoader: Failed to parse %s" % path)
	return result

func _parse_anim_cfg(cfg_key: String, file_name: String, dir_path: String) -> Dictionary:
	var fps: float = 5.0
	var frames: Array[Texture2D] = []
	
	var cfg: Variant = manifest.get(cfg_key, null)
	var base_name: String = file_name.replace(".png", "")
	
	if cfg is Dictionary:
		fps = float(cfg.get("fps", fps))
		if cfg.has("frames"):
			var frames_val: Variant = cfg["frames"]
			if frames_val is Array:
				frames = _load_list_frames(dir_path, frames_val)
			elif frames_val is String:
				frames = _load_auto_frames(dir_path, frames_val)
			elif frames_val is int or frames_val is float:
				frames = _load_numbered_frames(dir_path, base_name, int(frames_val))
		else:
			frames = _load_auto_frames(dir_path, base_name)
	else:
		frames = _load_auto_frames(dir_path, base_name)
		
	return {"fps": fps, "frames": frames}


func _load_numbered_frames(dir_path: String, base_name: String, count: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for i in range(count):
		var suffix: String = "" if i == 0 else "_" + str(i)
		var filename: String = base_name + suffix + ".png"
		var tex: Texture2D = _try_load(dir_path, filename)
		if tex:
			frames.append(tex)
	return frames


func _load_list_frames(dir_path: String, file_list: Array) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for f in file_list:
		if f is String:
			var tex: Texture2D = _try_load(dir_path, f)
			if tex:
				frames.append(tex)
	return frames


func _load_auto_frames(dir_path: String, base_name: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var clean_name: String = base_name.replace(".png", "")
	
	# 1. Try base file (player.png)
	var base_tex: Texture2D = _try_load(dir_path, clean_name + ".png")
	if base_tex:
		frames.append(base_tex)
	
	# 2. Try _1, _2...
	var i: int = 1
	while true:
		var filename: String = clean_name + "_" + str(i) + ".png"
		var tex: Texture2D = _try_load(dir_path, filename)
		if tex:
			frames.append(tex)
			i += 1
		else:
			break
	return frames

func _get_asset(key: String, default: String) -> String:
	if manifest.has("assets") and manifest["assets"].has(key):
		var val: Variant = manifest["assets"][key]
		if val is String:
			return val
	return default

func _get_color(key: String, default: Color) -> Color:
	if manifest.has("colors") and manifest["colors"].has(key):
		var val: Variant = manifest["colors"][key]
		if val is String:
			return Color.from_string(val, default)
	return default

func _try_load(dir_path: String, file_name: String) -> Texture2D:
	var full_path := dir_path.path_join(file_name)
	
	# 1. Standard Godot way (works for already imported assets with .import files)
	if ResourceLoader.exists(full_path):
		return ResourceLoader.load(full_path) as Texture2D
			
	# 2. Manual Fallback: Raw image load (essential for files added by the AI that lack .import records)
	# Image.load_from_file and FileAccess handle res://, user:// and absolute paths correctly on most platforms.
	if FileAccess.file_exists(full_path):
		var img := Image.load_from_file(full_path)
		if img:
			return ImageTexture.create_from_image(img)
	
	return null
