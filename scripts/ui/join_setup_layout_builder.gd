# scripts/ui/join_setup_layout_builder.gd
# ─────────────────────────────────────────────────────────────────────────────
# JoinSetupLayoutBuilder
# Standardized layout builder for the setup screen in multi-player join flow.
# ─────────────────────────────────────────────────────────────────────────────
class_name JoinSetupLayoutBuilder
extends RefCounted

const LogoTexture := preload("res://images/lm_paper_horizontal.png")

static func build(flow: Control) -> Dictionary:
	var center: CenterContainer = flow.join_setup_center
	for child in center.get_children():
		center.remove_child(child)
		child.queue_free()

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "SetupVBox"
	main_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	center.add_child(main_vbox)

	var gameplay_char_preview := CharacterPreview.new()
	gameplay_char_preview.visible = false
	gameplay_char_preview.custom_minimum_size = Vector2(256, 256)
	center.add_child(gameplay_char_preview)

	# Top spacer
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 4)
	main_vbox.add_child(top_spacer)

	# Logo
	var logo := TextureRect.new()
	logo.name = "AppLogo"
	logo.texture = LogoTexture
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.clip_contents = false
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(logo)

	# Logo -> Breadcrumbs spacer
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(0, 8)
	main_vbox.add_child(sp1)

	# Breadcrumb 1
	var breadcrumb1 := BreadcrumbRow.create()
	main_vbox.add_child(breadcrumb1)

	# Breadcrumb 2
	var breadcrumb2 := BreadcrumbRow.create()
	main_vbox.add_child(breadcrumb2)

	# Breadcrumbs -> Title spacer
	var logo_title_spacer := Control.new()
	logo_title_spacer.custom_minimum_size = Vector2(0, 4)
	main_vbox.add_child(logo_title_spacer)

	# Title
	var title_label := Label.new()
	title_label.text = flow.tr("mp_join_title")
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", UIColors.YELLOW)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(title_label)

	# Title -> Join Card spacer
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 8)
	main_vbox.add_child(sp2)

	# ── Join Card row: [‹]  [card]  [›] ────────────────────────────────────
	var card_center := HBoxContainer.new()
	card_center.alignment = BoxContainer.ALIGNMENT_CENTER
	card_center.add_theme_constant_override("separation", 40)
	main_vbox.add_child(card_center)

	# Prev arrow
	var game_prev_button := Button.new()
	game_prev_button.text = "‹"
	game_prev_button.add_theme_font_size_override("font_size", 48)
	game_prev_button.add_theme_color_override("font_color", Color.WHITE)
	game_prev_button.focus_mode = Control.FOCUS_NONE
	game_prev_button.custom_minimum_size = Vector2(56, 0)
	game_prev_button.modulate.a = 0.0
	game_prev_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_prev_button.pressed.connect(func(): flow.call("_cycle_game", -1))
	var prev_style := StyleBoxEmpty.new()
	game_prev_button.add_theme_stylebox_override("normal", prev_style)
	game_prev_button.add_theme_stylebox_override("hover", prev_style)
	game_prev_button.add_theme_stylebox_override("pressed", prev_style)
	game_prev_button.add_theme_stylebox_override("focus", prev_style)
	card_center.add_child(game_prev_button)

	var join_card_container := MarginContainer.new()
	card_center.add_child(join_card_container)

	# Next arrow
	var game_next_button := Button.new()
	game_next_button.text = "›"
	game_next_button.add_theme_font_size_override("font_size", 48)
	game_next_button.add_theme_color_override("font_color", Color.WHITE)
	game_next_button.focus_mode = Control.FOCUS_NONE
	game_next_button.custom_minimum_size = Vector2(56, 0)
	game_next_button.modulate.a = 0.0
	game_next_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_next_button.pressed.connect(func(): flow.call("_cycle_game", 1))
	var next_style := StyleBoxEmpty.new()
	game_next_button.add_theme_stylebox_override("normal", next_style)
	game_next_button.add_theme_stylebox_override("hover", next_style)
	game_next_button.add_theme_stylebox_override("pressed", next_style)
	game_next_button.add_theme_stylebox_override("focus", next_style)
	card_center.add_child(game_next_button)

	var join_card_panel := PanelContainer.new()
	var join_card_normal := UIHelpers.create_rounded_stylebox(UIColors.JOIN_GREEN.darkened(0.06), UIColors.JOIN_GREEN.lightened(0.16), 15, 2)
	join_card_normal.content_margin_left = 32; join_card_normal.content_margin_right = 32
	join_card_normal.content_margin_top = 16; join_card_normal.content_margin_bottom = 16
	join_card_panel.add_theme_stylebox_override("panel", join_card_normal)
	
	var join_card_focus := UIHelpers.create_rounded_stylebox(UIColors.JOIN_GREEN.darkened(0.02), Color.WHITE, 15, 6)
	join_card_focus.content_margin_left = 32; join_card_focus.content_margin_right = 32
	join_card_focus.content_margin_top = 16; join_card_focus.content_margin_bottom = 16
	join_card_focus.shadow_color = Color(0, 0, 0, 0.25)
	join_card_focus.shadow_size = 10
	
	join_card_container.add_child(join_card_panel)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 4)
	join_card_panel.add_child(card_vbox)

	var card_title := Label.new()
	card_title.text = flow.tr("mp_join_game")
	card_title.add_theme_font_size_override("font_size", 36)
	card_title.add_theme_color_override("font_color", Color.WHITE)
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(card_title)

	var sp_card := Control.new()
	sp_card.custom_minimum_size = Vector2(0, 12)
	card_vbox.add_child(sp_card)

	# ── Player slots (inside the card) ──────────────────────────────────────
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 32)
	slots_row.custom_minimum_size = Vector2(0, 140)
	card_vbox.add_child(slots_row)

	# ── The clickable button overlay ────────────────────────────────────────
	var join_button := Button.new()
	join_button.name = "JoinCardButton"
	join_button.focus_mode = Control.FOCUS_ALL
	join_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var empty_style := StyleBoxEmpty.new()
	join_button.add_theme_stylebox_override("normal", empty_style)
	join_button.add_theme_stylebox_override("hover", empty_style)
	join_button.add_theme_stylebox_override("pressed", empty_style)
	join_button.add_theme_stylebox_override("focus", empty_style)
	
	join_button.pressed.connect(flow._on_join_pressed)
	join_button.focus_entered.connect(func(): flow.call("_apply_card_zoom", true))
	join_button.focus_exited.connect(func(): flow.call("_apply_card_zoom", false))
	join_button.mouse_entered.connect(join_button.grab_focus)
	join_button.gui_input.connect(flow._on_join_button_gui_input)
	
	join_card_container.add_child(join_button)

	# Small spacer
	var counter_spacer := Control.new()
	counter_spacer.custom_minimum_size = Vector2(0, 6)
	main_vbox.add_child(counter_spacer)

	# Counter label
	var game_switcher_label := Label.new()
	game_switcher_label.add_theme_font_size_override("font_size", 20)
	game_switcher_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	game_switcher_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_switcher_label.custom_minimum_size = Vector2(0, 20)
	game_switcher_label.text = ""
	main_vbox.add_child(game_switcher_label)

	# Status/Error label
	var join_error_label := Label.new()
	join_error_label.add_theme_font_size_override("font_size", 22)
	join_error_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45, 1))
	join_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	join_error_label.custom_minimum_size = Vector2(0, 24)
	join_error_label.text = ""
	main_vbox.add_child(join_error_label)

	# Settings spacer
	var sp3 := Control.new()
	sp3.custom_minimum_size = Vector2(0, 8)
	main_vbox.add_child(sp3)

	# ── Settings block ──────────────────────────────────────────────────────
	var settings_vbox := VBoxContainer.new()
	settings_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_vbox.add_theme_constant_override("separation", 8)
	main_vbox.add_child(settings_vbox)

	# Character row
	var char_data := CyclingSelector.create_row_dict("mp_join_character")
	var char_row := char_data["row"] as HBoxContainer
	var char_left := char_data["left"] as Label
	var char_button := char_data["button"] as Button
	var char_right := char_data["right"] as Label
	char_button.pressed.connect(func(): flow.call("_cycle_character", 1))
	CyclingSelector.setup_cycling(char_button, flow._cycle_character)
	CyclingSelector.setup_arrow_visibility(char_button, char_left, char_right)
	var char_preview := CharacterPreview.new()
	char_preview.custom_minimum_size = Vector2(56, 56)
	char_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	char_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var char_extras := char_data["extras"] as HBoxContainer
	char_extras.add_child(char_preview)
	settings_vbox.add_child(char_row)

	# Controller layout row
	var ctrl_data := CyclingSelector.create_row_dict("mp_join_remote_layout")
	var controller_row := ctrl_data["row"] as HBoxContainer
	var controller_left := ctrl_data["left"] as Label
	var controller_button := ctrl_data["button"] as Button
	var controller_right := ctrl_data["right"] as Label
	controller_button.pressed.connect(func(): flow.call("_cycle_controller_layout", 1))
	CyclingSelector.setup_cycling(controller_button, flow._cycle_controller_layout)
	CyclingSelector.setup_arrow_visibility(controller_button, controller_left, controller_right)
	settings_vbox.add_child(controller_row)

	# Controller size row
	var ctrl_size_data := CyclingSelector.create_row_dict("setting_controller_size")
	var controller_size_row := ctrl_size_data["row"] as HBoxContainer
	var controller_size_left := ctrl_size_data["left"] as Label
	var controller_size_button := ctrl_size_data["button"] as Button
	var controller_size_right := ctrl_size_data["right"] as Label
	controller_size_button.pressed.connect(func(): flow.call("_cycle_controller_size", 1))
	CyclingSelector.setup_cycling(controller_size_button, flow._cycle_controller_size)
	CyclingSelector.setup_arrow_visibility(controller_size_button, controller_size_left, controller_size_right)
	settings_vbox.add_child(controller_size_row)

	return {
		"main_vbox": main_vbox,
		"gameplay_char_preview": gameplay_char_preview,
		"top_spacer": top_spacer,
		"logo": logo,
		"breadcrumb1": breadcrumb1,
		"breadcrumb2": breadcrumb2,
		"title_label": title_label,
		"game_prev_button": game_prev_button,
		"game_next_button": game_next_button,
		"join_card_container": join_card_container,
		"join_card_panel": join_card_panel,
		"slots_row": slots_row,
		"join_button": join_button,
		"game_switcher_label": game_switcher_label,
		"join_error_label": join_error_label,
		"game_unavailable_label": join_error_label, # alias
		"settings_vbox": settings_vbox,
		"char_row": char_row,
		"char_left": char_left,
		"char_button": char_button,
		"char_right": char_right,
		"char_preview": char_preview,
		"controller_row": controller_row,
		"controller_left": controller_left,
		"controller_button": controller_button,
		"controller_right": controller_right,
		"controller_size_row": controller_size_row,
		"controller_size_left": controller_size_left,
		"controller_size_button": controller_size_button,
		"controller_size_right": controller_size_right,
		"join_card_normal": join_card_normal,
		"join_card_focus": join_card_focus,
	}
