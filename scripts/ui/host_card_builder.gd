# HostCardBuilder
# Static helper utility to construct a uniform Host Card UI component.
class_name HostCardBuilder
extends RefCounted

const MissionCatalog := preload("res://scripts/mission_catalog.gd")

## Constructs a standardized host card button.
static func create_card(host: Dictionary, index: int, include_footer: bool = true) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(1000, 136)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	UIHelpers.apply_style_to_button(button, UIColors.BLUE)

	var card_margin: MarginContainer = MarginContainer.new()
	card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_margin.add_theme_constant_override("margin_left", 18)
	card_margin.add_theme_constant_override("margin_top", 12)
	card_margin.add_theme_constant_override("margin_right", 18)
	card_margin.add_theme_constant_override("margin_bottom", 12)
	button.add_child(card_margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card_margin.add_child(row)

	var icon: CharacterPreview = CharacterPreview.new()
	icon.custom_minimum_size = Vector2(104, 104)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var host_character_id: String = String(host.get("character_id", ""))
	
	PlayerSlotPanel.apply_character_preview(host_character_id, icon)
	row.add_child(icon)

	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 6)
	row.add_child(text_box)

	var host_name: String = String(host.get("host_name", "Host"))
	var host_ip: String = String(host.get("ip", ""))
	var theme_title: String = String(host.get("theme_title", host.get("theme_dir", "")))
	var player_count: int = int(host.get("player_count", 1))
	var max_players: int = int(host.get("max_players", 2))

	var title: Label = Label.new()
	title.text = host_name
	title.add_theme_font_size_override("font_size", 34)
	text_box.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "%s | %d/%d | %s" % [host_ip, player_count, max_players, theme_title]
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.modulate = Color(1, 1, 1, 0.8)
	text_box.add_child(subtitle)

	if include_footer:
		var footer: Label = Label.new()
		footer.text = "%s | %s | %s | %s" % [
			get_host_mission_title(host),
			get_host_pickup_title(host),
			get_host_role_summary(host),
			CharacterCatalog.display_name_for_id(host_character_id),
		]
		footer.add_theme_font_size_override("font_size", 24)
		footer.modulate = Color(0.92, 0.75, 0.2, 1)
		text_box.add_child(footer)

	return button

static func get_host_mission_title(host: Dictionary) -> String:
	return String(host.get("mission_title", host.get("game_style_title", tr("mission_follow_trail"))))

static func get_host_pickup_title(host: Dictionary) -> String:
	var training := String(host.get("training_type", NetworkManager.TRAINING_WORDS))
	if training == NetworkManager.TRAINING_NONE:
		return tr("pickup_none")
	var title := String(host.get("training_type_title", ""))
	if not title.is_empty():
		return title
	return tr(MissionCatalog.pickup_title_key(MissionCatalog.pickup_for_training(training)))

static func get_host_role_summary(host: Dictionary) -> String:
	var mission_id := String(host.get("mission_id", MissionCatalog.MISSION_FOLLOW_TRAIL))
	var chaser_enabled := bool(host.get("chaser_enabled", false))
	return tr(String(host.get("role_summary_key", MissionCatalog.role_summary_key(mission_id, chaser_enabled))))
