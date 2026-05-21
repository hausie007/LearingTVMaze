## ui_helpers.gd
## ---------------------------------------------------------------------------
## Static utility class providing shared UI styling functions.
##
## Eliminates copy-pasted StyleBoxFlat button creation across game_setup_wizard.gd,
## game_manager.gd, and settings_menu.gd.
##
## Usage:
##   var btn := UIHelpers.create_styled_button("Play", 300, 80)
##   var panel := UIHelpers.create_rounded_stylebox(Color.BLACK, Color.WHITE, 12)
## ---------------------------------------------------------------------------
class_name UIHelpers
extends RefCounted


## Preloaded bundled emoji font for 100% compatibility across Android versions.
const EMOJI_FONT = preload("res://assets/fonts/NotoColorEmoji-Regular.ttf")

## Preloaded Quicksand variable font for weight variations.
const QUICKSAND_FONT = preload("res://assets/fonts/Quicksand-VariableFont_wght.ttf")

## OpenType tag for 'wght' axis (w=119, g=103, h=104, t=116).
const OT_WGHT := 2003265652

## Standard Fredoka weight values.
const WEIGHT_MEDIUM := 500
const WEIGHT_SEMIBOLD := 600
const WEIGHT_BOLD := 700

## Cached font variations by weight to avoid creating duplicates.
static var _font_cache: Dictionary = {}

## Get a FontVariation at a specific weight. Cached for reuse.
static func get_font_at_weight(weight: int) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var fv := FontVariation.new()
	fv.base_font = QUICKSAND_FONT
	fv.variation_opentype = {OT_WGHT: weight}
	
	# Explicitly configure a system font fallback with matched weight 
	# to prevent Cyrillic/Greek/Hebrew characters from defaulting to ultra-bold faces.
	var sf := SystemFont.new()
	sf.font_weight = weight
	sf.font_names = PackedStringArray(["Sans-Serif", "Segoe UI", "Arial", "Helvetica", "Roboto", "Noto Sans", "DejaVu Sans"])
	fv.fallbacks = [sf]
	
	_font_cache[weight] = fv
	return fv

## Apply SemiBold (600) font weight to a Control (Label or Button).
static func apply_semibold(control: Control) -> void:
	control.add_theme_font_override("font", get_font_at_weight(WEIGHT_SEMIBOLD))

## Apply Medium (500) font weight to a Control (Label or Button).
static func apply_medium(control: Control) -> void:
	control.add_theme_font_override("font", get_font_at_weight(WEIGHT_MEDIUM))


## Return a Font configured specifically for Emoji rendering with multi-platform fallbacks.
## Essential for Android (Samsung) where default fonts often lack emoji glyphs.
static func get_emoji_font() -> Font:
	# In Godot 4, we use FontVariation to wrap a SystemFont and add the bundled font as fallback.
	var variation := FontVariation.new()
	var system_font := SystemFont.new()
	
	# Attempt to use system emoji families as base for better performance/look if available.
	system_font.font_names = PackedStringArray([
		"Emoji", 
		"Noto Color Emoji", 
		"Samsung Color Emoji", 
		"Apple Color Emoji", 
		"Segoe UI Emoji"
	])
	
	variation.base_font = system_font
	
	# Add our bundled font as the definitive fallback to prevent "tofu".
	variation.fallbacks = [EMOJI_FONT]
	
	return variation


## Screen fraction reserved for the on-screen D-Pad when active.
## Used by MazeRenderer, Help, and Settings to shift content away from the D-Pad area.
const DPAD_SCREEN_FRACTION := 0.25
const DPAD_SCREEN_FRACTION_LARGE := 0.325

static func get_dpad_screen_fraction() -> float:
	if is_instance_valid(Config) and int(Config.controller_size) == Config.ControllerSize.LARGE:
		return DPAD_SCREEN_FRACTION_LARGE
	return DPAD_SCREEN_FRACTION


## Create a fully styled Button matching the game's brand design.
##
## Parameters:
##   btn_text    — The button label text.
##   w, h        — Minimum size in pixels.
##   focus_color — Background color when focused/hovered (default: Sky blue).
##   font_size   — Font size override (default: 42).
static func create_styled_button(
	btn_text: String,
	w: int,
	h: int,
	focus_color: Color = UIColors.BLUE,
	font_size: int = 42,
) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", font_size)

	apply_style_to_button(btn, focus_color)
	return btn

## Applies standardized game button styles (normal, focus, hover layers and text colors) to an existing button node.
static func apply_style_to_button(btn: Button, focus_color: Color) -> void:
	# Map legacy bright colors to the new muted storybook palette
	var mapped_color: Color = focus_color
	if focus_color == UIColors.BLUE:
		mapped_color = UIColors.UI_BLUE
	elif focus_color == UIColors.YELLOW:
		mapped_color = UIColors.UI_YELLOW
	elif focus_color == UIColors.GREEN or focus_color == UIColors.GREEN_ACCENT_LEGACY:
		mapped_color = UIColors.UI_GREEN

	# Normal state (dark background, subtle border)
	var normal := create_rounded_stylebox(
		UIColors.BG_DARK,
		UIColors.BORDER_SUBTLE,
		12, 2
	)
	btn.add_theme_stylebox_override("normal", normal)
	
	# Fix for phantom mouse highlights on TV
	if is_likely_tv():
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Focus / Pressed (Muted fill, Parchment border)
	var focus := create_rounded_stylebox(mapped_color, UIColors.SELECTED_BORDER, 12, 4)

	# Hover (Similar to focus)
	var hover := create_rounded_stylebox(mapped_color, UIColors.SELECTED_BORDER, 12, 2)

	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", focus)

	# Text colors — uniform primary text for both dark and bright mapped colors
	btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_focus_color", UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", UIColors.TEXT_PRIMARY) 
	btn.add_theme_color_override("font_pressed_color", UIColors.TEXT_PRIMARY)
	
	# Ensure the button text has confident weight
	apply_semibold(btn)

	# Dynamic organic scale-up and scale-down on focus
	if not btn.has_meta("styled_focus_animations"):
		btn.set_meta("styled_focus_animations", true)
		
		btn.item_rect_changed.connect(func():
			if is_instance_valid(btn):
				btn.pivot_offset = btn.size * 0.5
		)
		btn.pivot_offset = btn.size * 0.5

		btn.focus_entered.connect(func():
			if is_instance_valid(btn):
				var tw := btn.create_tween()
				tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.15)
		)
		btn.focus_exited.connect(func():
			if is_instance_valid(btn):
				var tw := btn.create_tween()
				tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)
		)


## Applies a safe accent palette derived from avatar art to a button.
## Keeps the control visually linked to the selected character while preserving contrast.
static func apply_avatar_accent_button_style(btn: Button, palette: Dictionary) -> void:
	if btn == null:
		return

	var accent: Color = palette.get("accent", UIColors.BLUE)
	var accent_soft: Color = palette.get("accent_soft", accent.lerp(Color.WHITE, 0.2))
	var accent_vivid: Color = palette.get("accent_vivid", accent.lerp(Color.WHITE, 0.35))
	var accent_deep: Color = palette.get("accent_deep", accent.darkened(0.15))
	var shell: Color = palette.get("shell", UIColors.BG_DARK.lerp(accent, 0.12))
	var shell_hover: Color = palette.get("shell_hover", shell.lerp(accent_soft, 0.18))
	var border: Color = palette.get("border", accent_soft)
	var text_color: Color = palette.get("text", UIColors.TEXT_PRIMARY)

	var normal := create_rounded_stylebox(shell, border, 16, 3)
	var focus := create_rounded_stylebox(accent, accent_soft, 16, 4)
	var hover := create_rounded_stylebox(shell_hover, accent_vivid, 16, 4)
	var pressed := create_rounded_stylebox(accent_deep, accent_soft, 16, 4)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)

	if is_likely_tv():
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_focus_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)




## Create a StyleBoxFlat with uniform corner radius and border width.
static func create_rounded_stylebox(
	bg_color: Color,
	border_color: Color = Color.TRANSPARENT,
	corner_radius: int = 12,
	border_width: int = 0,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	return style


## Adjust a container's horizontal anchors to avoid the on-screen D-Pad area.
## Call from any screen that needs to shift its layout when D-Pad is active.
static func apply_dpad_layout(container: Control, controls_mode: int) -> void:
	var eff_mode = controls_mode
	var dpad_fraction := get_dpad_screen_fraction()
	if container.is_layout_rtl():
		if eff_mode == Config.ControlsMode.LEFT_HANDED:
			eff_mode = Config.ControlsMode.RIGHT_HANDED
		elif eff_mode == Config.ControlsMode.RIGHT_HANDED:
			eff_mode = Config.ControlsMode.LEFT_HANDED
			
	match eff_mode:
		Config.ControlsMode.LEFT_HANDED:
			container.anchor_left = dpad_fraction
			container.anchor_right = 1.0
			container.offset_left = -100 # Slight bias towards d-pad as requested
			container.offset_right = -100
		Config.ControlsMode.RIGHT_HANDED:
			container.anchor_left = 0.0
			container.anchor_right = 1.0 - dpad_fraction
			container.offset_left = 100
			container.offset_right = 100
		_:
			container.anchor_left = 0.0
			container.anchor_right = 1.0
			container.offset_left = 0
			container.offset_right = 0


## Compute the usable content rectangle, accounting for D-pad screen reservation.
## Use this instead of manually computing rect_left/rect_right from DPAD_SCREEN_FRACTION.
static func get_content_rect(viewport_size: Vector2, controls_mode: int, top_margin: float = 0.0) -> Rect2:
	var dpad_fraction := get_dpad_screen_fraction()
	var margin_x: float = viewport_size.x * 0.02
	var left: float = margin_x
	var right: float = viewport_size.x - margin_x

	if controls_mode == Config.ControlsMode.LEFT_HANDED:
		left = (viewport_size.x * dpad_fraction) + margin_x
	elif controls_mode == Config.ControlsMode.RIGHT_HANDED:
		right = (viewport_size.x * (1.0 - dpad_fraction)) - margin_x

	return Rect2(left, top_margin, right - left, viewport_size.y - top_margin)

## Transition to a target scene via the branded loading screen.
## Handles freeing the current scene and setting the loading screen as active.
##
## CONVENTION — Scene Transition Strategy:
##   • Use go_to_scene_with_loading() for resource-heavy targets (main.tscn,
##     initial startup) where loading time could cause visible stalls or ANR.
##   • Use tree.change_scene_to_file() for lightweight menu-to-menu transitions
##     (main_menu ↔ settings, main_menu ↔ help, etc.) where scenes load instantly.
static func go_to_scene_with_loading(tree: SceneTree, target_path: String) -> void:
	var loading_scene = load(Scenes.LOADING).instantiate()
	loading_scene.target_scene_path = target_path
	tree.root.add_child(loading_scene)
	tree.current_scene.queue_free()
	tree.current_scene = loading_scene


## Configure global visual settings (MSAA, AA, and Glow) for the current viewport.
## Centralizes visual post-processing logic away from drawing logic (MazeRenderer).
static func configure_environment(node: Node2D, theme: ThemeLoader, performance_mode: bool) -> void:
	var vp := node.get_viewport()
	if vp:
		if performance_mode:
			vp.msaa_2d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		else:
			vp.msaa_2d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA

	# Update or Create WorldEnvironment
	var env_node: WorldEnvironment = null
	for child in node.get_children():
		if child is WorldEnvironment:
			env_node = child
			break
	
	if not theme.glow_enabled or performance_mode:
		if env_node: env_node.queue_free()
		return

	if not env_node:
		env_node = WorldEnvironment.new()
		node.add_child(env_node)
	
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.5 # Only things > 1.5 glow (Icons/BG stay at 1.0)
	env.glow_intensity = theme.glow_strength
	env.glow_bloom = theme.glow_bloom
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	
	# Standard glow levels for 2D
	env.set_glow_level(3, 1.0)
	env_node.environment = env


## Multi-layered detection to distinguish between TVs (Chromecast, Android TV) 
## and Mobile devices (Phones, Tablets).
##
## TVs should have virtual D-Pad OFF by default.
## Tablets/Phones should have virtual D-Pad ON by default.
static func is_likely_tv() -> bool:
	if OS.get_name() != "Android":
		return false
	
	# Layer 1: JNI Leanback Check (The gold standard)
	# Check for "android.software.leanback" feature via Java.
	var bridge = null
	if Engine.has_singleton("GodotAndroid"):
		bridge = Engine.get_singleton("GodotAndroid")
	elif Engine.has_singleton("GodotAndroidBridge"):
		bridge = Engine.get_singleton("GodotAndroidBridge")

	if bridge:
		var activity = bridge.get_activity()
		if activity:
			var pm = activity.call("getPackageManager")
			if pm:
				if pm.call("hasSystemFeature", "android.software.leanback"):
					return true

	# Layer 2: Model Name Filtering
	# Catch common TV brands and generic TV identifiers.
	var model = OS.get_model_name().to_lower()
	var tv_keywords = [
		"tv", "player", "shield", "chromecast", "aft", "box", "adt-", "mibox", 
		"bravia", "viera", "aquos", "tcl", "hisense", "philips", "stick"
	]
	for key in tv_keywords:
		if key in model:
			return true

	# Layer 3: Physical Presence Check
	# If the OS explicitly says no touchscreen is available, trust it.
	# (User manifest changes to remove faketouch should help here).
	if not DisplayServer.is_touchscreen_available():
		return true

	# Layer 4: DPI & Aspect Ratio Heuristics
	# TVs are almost exclusively 16:9 (1.77) and report low "virtual" DPI (160-213).
	# Tablets (including 10") are usually 16:10 or 4:3 and have higher DPI (240+).
	var dpi = DisplayServer.screen_get_dpi()
	var size = DisplayServer.window_get_size()
	var aspect = float(size.x) / float(size.y)
	
	# Heuristic: Low density + traditional TV aspect ratio
	if dpi < 220 and abs(aspect - 1.778) < 0.05:
		return true
		
	return false


# ── Player Badge Builders ──────────────────────────────────────────────────

static func get_role_emoji(role: String) -> String:
	match role:
		Config.ROLE_COLLECTOR:
			return "⭐"
		Config.ROLE_CHASER:
			return "⚡"
		Config.ROLE_RACER:
			return "🏁"
		"exit":
			return ""
		_:
			return ""

static func get_role_translation_key(role: String) -> String:
	match role:
		Config.ROLE_COLLECTOR:
			return "hud_role_collect"
		Config.ROLE_CHASER:
			return "hud_role_chase"
		Config.ROLE_RACER:
			return "hud_role_race"
		"exit":
			return "hud_role_find_exit"
		_:
			return ""

## Builds a standardized player chip used in the HUD and remote clients.
## If scale_mult is provided, it scales up or down all paddings and fonts (e.g. 2.0 for huge UI on mobile).
static func build_player_chip(data: Dictionary, total_players: int = 1, scale_mult: float = 1.0) -> PanelContainer:
	var scale_down := total_players > 2

	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	var accent_color: Color = data.get("color", UIColors.BLUE)
	chip_style.bg_color = Color(accent_color, 0.15)
	chip_style.border_color = accent_color
	chip_style.set_border_width_all(int((4 if not scale_down else 2) * scale_mult))
	chip_style.set_corner_radius_all(int((16 if not scale_down else 8) * scale_mult))
	chip_style.content_margin_left = int((12 if not scale_down else 6) * scale_mult)
	chip_style.content_margin_right = int((12 if not scale_down else 6) * scale_mult)
	chip_style.content_margin_top = int((8 if not scale_down else 4) * scale_mult)
	chip_style.content_margin_bottom = int((8 if not scale_down else 4) * scale_mult)
	chip.add_theme_stylebox_override("panel", chip_style)

	var chip_hbox := HBoxContainer.new()
	chip_hbox.add_theme_constant_override("separation", int((8 if not scale_down else 4) * scale_mult))
	chip_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(chip_hbox)

	var icon_size = int((72 if not scale_down else 40) * scale_mult)
	var trap_icon_size = int((34 if not scale_down else 24) * scale_mult)
	var emoji_size = int((48 if not scale_down else 28) * scale_mult)
	var text_size = int((36 if not scale_down else 20) * scale_mult)

	# Character icon
	var character_id: String = data.get("character_id", "")
	var tex := CharacterCatalog.get_texture_by_id(character_id) if not character_id.is_empty() else null
	if tex != null:
		var icon_slot := Control.new()
		icon_slot.custom_minimum_size = Vector2(icon_size, icon_size)
		icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_slot.clip_contents = false

		var icon := TextureRect.new()
		icon.texture = tex
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.pivot_offset = Vector2(icon_size, icon_size) / 2.0
		icon.resized.connect(func(): icon.pivot_offset = icon.size * 0.5)
		if bool(data.get("is_confused", false)) or int(data.get("confusion_moves", 0)) > 0:
			icon.rotation = PI
		icon_slot.add_child(icon)
		chip_hbox.add_child(icon_slot)

	var is_ai: bool = data.get("is_ai", false)
	if tex == null:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(icon_size, icon_size)
		chip_hbox.add_child(spacer)

	if bool(data.get("trap_available", false)):
		var trap_tex: Texture2D = data.get("trap_texture", null) as Texture2D
		if trap_tex != null:
			var trap_icon := TextureRect.new()
			trap_icon.name = "TrapAvailableIcon"
			trap_icon.texture = trap_tex
			trap_icon.custom_minimum_size = Vector2(trap_icon_size, trap_icon_size)
			trap_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trap_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chip_hbox.add_child(trap_icon)
		else:
			var trap_lbl := Label.new()
			trap_lbl.name = "TrapAvailableIcon"
			trap_lbl.text = "?"
			trap_lbl.add_theme_font_size_override("font_size", trap_icon_size)
			trap_lbl.add_theme_color_override("font_color", accent_color.lightened(0.2))
			trap_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip_hbox.add_child(trap_lbl)

	var confusion_moves := int(data.get("confusion_moves", 0))
	if confusion_moves > 0:
		var confusion_lbl := Label.new()
		confusion_lbl.name = "ConfusionCountLabel"
		confusion_lbl.text = str(confusion_moves)
		confusion_lbl.add_theme_font_size_override("font_size", text_size)
		confusion_lbl.add_theme_font_override("font", get_font_at_weight(WEIGHT_SEMIBOLD))
		confusion_lbl.add_theme_color_override("font_color", accent_color.lightened(0.2))
		confusion_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		confusion_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip_hbox.add_child(confusion_lbl)

	# Role emoji and localized word
	var role: String = data.get("role", "")
	var role_emoji := get_role_emoji(role)
	var role_key := get_role_translation_key(role)

	if not role_emoji.is_empty():
		var emoji_lbl := Label.new()
		emoji_lbl.text = role_emoji
		emoji_lbl.add_theme_font_size_override("font_size", emoji_size)
		emoji_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_hbox.add_child(emoji_lbl)

	if not role_key.is_empty():
		var role_lbl := Label.new()
		role_lbl.name = "RoleLabel"
		role_lbl.text = TranslationServer.translate(role_key)
		role_lbl.add_theme_font_size_override("font_size", text_size)
		role_lbl.add_theme_font_override("font", get_font_at_weight(WEIGHT_SEMIBOLD))
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var text_color = accent_color.lightened(0.2)
		role_lbl.add_theme_color_override("font_color", text_color)
		role_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip_hbox.add_child(role_lbl)

	if is_ai or role == Config.ROLE_CHASER:
		var countdown_lbl := Label.new()
		countdown_lbl.name = "ChaserCountdownLabel"
		countdown_lbl.add_theme_font_size_override("font_size", text_size)
		countdown_lbl.add_theme_color_override("font_color", accent_color.lightened(0.2))
		countdown_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		countdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown_lbl.visible = false
		chip_hbox.add_child(countdown_lbl)

	return chip


## Dynamically fits a label's font size to prevent visual clipping when localized strings are long.
static func fit_font_size_to_width(label: Label, max_width: float, base_font_size: int) -> void:
	if label == null or label.text.is_empty() or max_width <= 0.0:
		return
	var font := get_font_at_weight(WEIGHT_SEMIBOLD)
	var width := font.get_string_size(label.text, label.horizontal_alignment, -1.0, base_font_size).x
	if width <= max_width:
		label.add_theme_font_size_override("font_size", base_font_size)
		return
	var scale := max_width / maxf(width, 1.0)
	var new_size := maxi(14, int(floor(float(base_font_size) * scale)))
	label.add_theme_font_size_override("font_size", new_size)


## Preloaded circular flag shader for high-performance anti-aliased rendering.
const FLAG_SHADER = preload("res://assets/shaders/flag_circle.gdshader")

## Dynamically applies circular flag icons and formatted text inside a language selection button.
static func apply_flag_to_button(btn: Button, lang_code: String, display_text: String) -> void:
	if btn == null:
		return
	
	btn.text = ""
	for child in btn.get_children():
		child.queue_free()
		
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(btn_hbox)
	
	# Flag Display using Shader
	var flag_info: Dictionary = Config.get_flag_info(lang_code)
	if flag_info.texture_a != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = flag_info.texture_a
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.custom_minimum_size = Vector2(48, 48)
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Set up custom shader material for circle clip and split flag
		var mat := ShaderMaterial.new()
		mat.shader = FLAG_SHADER
		mat.set_shader_parameter("is_split", flag_info.is_split)
		
		var aspect_a: float = flag_info.texture_a.get_size().x / flag_info.texture_a.get_size().y
		mat.set_shader_parameter("aspect_ratio_a", aspect_a)
		
		var is_pt := (lang_code == "pt") or (lang_code == "auto" and Config.get_auto_detected_language() == "pt")
		if is_pt:
			mat.set_shader_parameter("uv_offset_a", Vector2(0.15, 0.0))
			
		if flag_info.is_split and flag_info.texture_b != null:
			mat.set_shader_parameter("texture_b", flag_info.texture_b)
			var aspect_b: float = flag_info.texture_b.get_size().x / flag_info.texture_b.get_size().y
			mat.set_shader_parameter("aspect_ratio_b", aspect_b)
			
		tex_rect.material = mat
		
		btn_hbox.add_child(tex_rect)
		
	# Text Label
	var lbl := Label.new()
	lbl.text = display_text
	lbl.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	apply_semibold(lbl)
	
	# Prevent visual clipping/overflow by dynamically scaling font sizes of long values
	var btn_w := btn.custom_minimum_size.x if btn.custom_minimum_size.x > 0 else btn.size.x
	if btn_w <= 0:
		btn_w = 500.0 # Standard fallback button width
	var max_text_width := btn_w - 48 - 16 - 36 # Subtract flag (48), HBox separation (16), and borders/padding margin (36)
	fit_font_size_to_width(lbl, max_text_width, 38)
	
	btn_hbox.add_child(lbl)
