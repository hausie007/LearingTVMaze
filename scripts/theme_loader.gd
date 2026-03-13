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

## Loaded textures (null = use default visual).
var start_texture:  Texture2D = null
var end_texture:    Texture2D = null
var player_texture: Texture2D = null

## Whether any theme images were loaded.
var has_any_texture: bool = false


## Load theme images from the directory specified in Config.
## Call this once at startup (or whenever the theme changes).
func load_theme() -> void:
	var dir_path: String = Config.theme_dir

	start_texture  = _try_load(dir_path, "start.png")
	end_texture    = _try_load(dir_path, "end.png")
	player_texture = _try_load(dir_path, "player.png")

	has_any_texture = (
		start_texture != null or
		end_texture != null or
		player_texture != null
	)


## Try to load a PNG file and return a Texture2D, or null on failure.
func _try_load(dir_path: String, file_name: String) -> Texture2D:
	var full_path := dir_path.path_join(file_name)

	# Check if the resource exists in the Godot file system.
	if not ResourceLoader.exists(full_path):
		return null

	var resource = ResourceLoader.load(full_path)
	if resource is Texture2D:
		return resource as Texture2D

	# Resource exists but is not a valid texture.
	push_warning("ThemeLoader: '%s' is not a valid Texture2D, skipping." % full_path)
	return null
