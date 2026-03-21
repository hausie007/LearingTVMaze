## game_manager.gd
## ---------------------------------------------------------------------------
## Top-level orchestrator for the maze game.
##
## Responsibilities:
##   1. Tell MazeGenerator to create a new MazeData.
##   2. Tell MazeRenderer to draw it.
##   3. Spawn the Player at the Start cell.
##   4. Listen for the player's `reached_end` signal → show win feedback and
##      regenerate a new maze.
##   5. Spawn collectibles (numbers, letters, or word letters) based on mode.
##   6. Display a universal top-bar HUD (stopwatch, move count, word progress).
##
## All tunable parameters are read from the Config autoload singleton.
## ---------------------------------------------------------------------------
class_name GameManager
extends Node

# ── Child-node references (assigned in _ready via node paths) ────────────────
@onready var maze_generator:  MazeGenerator    = $MazeGenerator
@onready var maze_renderer:   MazeRenderer     = $MazeRenderer
@onready var player:          PlayerController  = $Player

const CollectibleScene = preload("res://scenes/collectible.tscn")
const ChaserScene = preload("res://scenes/chaser.tscn")

# ── UI layer ─────────────────────────────────────────────────────────────────
var _win_container: Control = null
var _win_label: Label = null
var _score_label: Label = null
var _next_button: Button = null
var _harder_button: Button = null
var _timer_label: Label = null
var _suggestion_container: VBoxContainer = null

# ── Top-bar HUD ──────────────────────────────────────────────────────────────
const HUD_HEIGHT: float = 160.0

var _hud_layer: CanvasLayer = null
var _hud_time_label: Label = null
var _hud_moves_label: Label = null
var _hud_word_container: HBoxContainer = null
var _word_letter_labels: Array[Label] = []
var _word_next_index: int = 0

# ── Chaser State ─────────────────────────────────────────────────────────────
var _chaser: Node2D = null
var _nav_map: AStar2D = null
var _chaser_active: bool = false

# ── State ────────────────────────────────────────────────────────────────────
var _current_maze: MazeData = null
var _collectibles: Dictionary = {}  # Vector2i -> Collectible
var _win_timer_remaining: float = 0.0
var _win_timer_paused: bool = false
var _is_win_screen_active: bool = false
var _elapsed_time: float = 0.0
var _move_count: int = 0

# ── Threaded TTS (Android TV Optimization) ───────────────────────────────────
var _tts_thread: Thread = null
var _tts_mutex: Mutex = null
var _tts_semaphore: Semaphore = null
var _tts_exit_flag: bool = false
var _tts_pending_text: String = ""
var _tts_pending_voice: String = ""
var _tts_pending_rate: float = 1.0


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Build the "You Win!" label (hidden by default).
	_create_win_label()

	# Build the universal top-bar HUD.
	_create_top_hud()

	# Wire up the player signals.
	player.reached_end.connect(_on_player_reached_end)
	player.moved.connect(_on_player_moved)
	player.bumped.connect(_on_player_bumped)

	# Tell the maze renderer to leave space for the HUD bar.
	maze_renderer.top_margin = HUD_HEIGHT

	# Generate and display the first maze.
	_start_new_maze()

	# Start TTS background thread
	_tts_mutex = Mutex.new()
	_tts_semaphore = Semaphore.new()
	_tts_thread = Thread.new()
	_tts_thread.start(_tts_worker_loop)

func _exit_tree() -> void:
	# Clean up TTS thread
	if _tts_thread and _tts_thread.is_alive():
		_tts_mutex.lock()
		_tts_exit_flag = true
		_tts_mutex.unlock()
		_tts_semaphore.post()
		_tts_thread.wait_to_finish()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _process(delta: float) -> void:
	# Win countdown
	if _is_win_screen_active and not _win_timer_paused and _win_timer_remaining > 0.0:
		_win_timer_remaining -= delta
		if _timer_label:
			_timer_label.text = str(ceili(_win_timer_remaining))
		
		if _win_timer_remaining <= 0.0:
			_on_next_round_pressed()
	
	# Stopwatch (only while playing, not during win screen)
	if not _is_win_screen_active:
		_elapsed_time += delta
		if _hud_time_label:
			var mins := int(_elapsed_time) / 60
			var secs := int(_elapsed_time) % 60
			_hud_time_label.text = "%02d:%02d" % [mins, secs]

func _input(event: InputEvent) -> void:
	# Any interaction during win screen pauses the auto-countdown
	# Using _input instead of _unhandled_input ensures focus doesn't block it
	if _is_win_screen_active and not _win_timer_paused:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
		   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
		   event.is_action_pressed("ui_accept"):
			_win_timer_paused = true
			if _timer_label:
				_timer_label.text = "" # Hide number but keep spacer width

func _unhandled_input(event: InputEvent) -> void:
	# Android TV 'Back' button maps to ui_cancel
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Game flow ────────────────────────────────────────────────────────────────

## Generate a fresh maze, render it, and place the player.
func _start_new_maze() -> void:
	if _win_container:
		_win_container.visible = false

	# Clear old collectibles
	for c in _collectibles.values():
		if is_instance_valid(c):
			c.queue_free()
	_collectibles.clear()

	# Reset round state
	_elapsed_time = 0.0
	_move_count = 0
	_word_next_index = 0
	_update_hud_moves()
	_is_win_screen_active = false
	
	# Thorough Chaser Cleanup
	_chaser_active = false
	if _chaser and is_instance_valid(_chaser):
		_chaser.request_move.disconnect(_on_chaser_request_move)
		_chaser.queue_free()
	_chaser = null
	
	# Re-enable player
	player.set_process(true)
	player.set_physics_process(true)
	player.set_process_input(true)

	# 1. Generate
	_current_maze = maze_generator.generate()

	# 2. Render
	maze_renderer.draw_maze(_current_maze)

	# 2.2 Navigation for chaser
	_nav_map = maze_renderer.get_navigation_map()

	# 2.5 Spawn collectibles if applicable
	if Config.game_mode > 0:
		if Config.game_mode == 3:
			_spawn_word_collectibles()
		else:
			_spawn_collectibles()
	
	# Update word display in HUD (clears if not words mode)
	_update_hud_word_display()

	# 3. Place player at Start cell
	var start_cell := _current_maze.get_start_cell()
	if start_cell:
		player.grid_pos      = start_cell.coords
		player.maze_data     = _current_maze
		player.maze_renderer = maze_renderer
		player.position      = maze_renderer.grid_to_pixel(start_cell.coords)

	# Rebuild the player visual (picks up theme sprites if available).
	player._build_visual()

	# Re-enable player input (disabled during win sequence).
	player.set_process(true)


## Called when the player steps onto the End cell.
func _on_player_reached_end() -> void:
	if _is_win_screen_active: return
	_is_win_screen_active = true
	
	# Stop Chaser
	_chaser_active = false
	if _chaser: _chaser.stop()
	
	# Freeze player
	player.set_process(false)
	player.set_physics_process(false)
	player.set_process_input(false)
	
	_win_timer_remaining = 10.0
	_win_timer_paused = false
	
	# Full word progress update if word mode
	if Config.game_mode == 3:
		_light_up_word_letter(_word_next_index) 
	
	var elapsed_int := int(_elapsed_time)
	var mm := elapsed_int / 60
	var ss := elapsed_int % 60
	var time_str := "%02d:%02d" % [mm, ss]
	
	_show_win_screen(time_str)
	_update_mode_suggestions()

func _update_mode_suggestions() -> void:
	# Clear old suggestions
	for child in _suggestion_container.get_children():
		child.queue_free()
	
	var current_mode := Config.game_mode
	var suggestion_modes := []
	
	if current_mode == 1: # Numbers
		suggestion_modes = [2, 3] # Alphabet, Words
	elif current_mode == 2: # Alphabet
		suggestion_modes = [1, 3] # Numbers, Words
	elif current_mode == 3: # Words
		suggestion_modes = [1, 2] # Numbers, Alphabet
	else: # Normal or other
		suggestion_modes = [1, 2, 3]
	
	for m in suggestion_modes:
		var key := ""
		match m:
			1: key = "try_numbers"
			2: key = "try_alphabet"
			3: key = "try_words"
		
		if not key.is_empty():
			var hbox := HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			_suggestion_container.add_child(hbox)
			
			var btn := _create_styled_button(tr(key), 650, 100, Color(0.4, 0.6, 0.9)) # Blue-ish for suggestions
			btn.pressed.connect(_on_suggestion_pressed.bind(m))
			hbox.add_child(btn)

func _on_suggestion_pressed(target_mode: int) -> void:
	Config.game_mode = target_mode
	Config.save_settings()
	_is_win_screen_active = false
	_start_new_maze()

## Actions for the win screen buttons.
func _on_next_round_pressed() -> void:
	_is_win_screen_active = false
	_start_new_maze()

func _on_harder_pressed() -> void:
	if _harder_button and _harder_button.text == tr("challenge_mm"):
		# It's an "Easier" request from Gotcha screen
		Config.difficulty = clampi(Config.difficulty - 1, 0, 4)
	else:
		# It's a "Harder" request from Win screen
		if Config.difficulty >= 4: return
		Config.difficulty = clampi(Config.difficulty + 1, 0, 4)
		
	_is_win_screen_active = false
	Config.save_settings()
	_start_new_maze()

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ── Top-bar HUD ──────────────────────────────────────────────────────────────

## Create the persistent top-bar HUD with stopwatch, word display area, and move counter.
func _create_top_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 5
	add_child(_hud_layer)
	
	# Background panel spanning full width at the top
	var bg_panel := PanelContainer.new()
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.12, 0.16, 0.90)
	bg_style.content_margin_left = 20
	bg_style.content_margin_right = 20
	bg_style.content_margin_top = 8
	bg_style.content_margin_bottom = 8
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	bg_panel.anchors_preset = Control.PRESET_TOP_WIDE
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bg_panel.custom_minimum_size.y = HUD_HEIGHT
	_hud_layer.add_child(bg_panel)
	
	# Main HBox: [Stopwatch] [center word area] [Moves]
	var hbox := HBoxContainer.new()
	hbox.anchors_preset = Control.PRESET_FULL_RECT
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	bg_panel.add_child(hbox)
	
	# Left: Stopwatch
	_hud_time_label = Label.new()
	_hud_time_label.text = "00:00"
	_hud_time_label.add_theme_font_size_override("font_size", 64)
	_hud_time_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_hud_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_time_label.custom_minimum_size.x = 250
	hbox.add_child(_hud_time_label)
	
	# Center: Word display area (flexible, fills remaining space)
	_hud_word_container = HBoxContainer.new()
	_hud_word_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_word_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud_word_container.add_theme_constant_override("separation", 4)
	hbox.add_child(_hud_word_container)
	
	# Right: Move counter
	_hud_moves_label = Label.new()
	_hud_moves_label.text = "0"
	_hud_moves_label.add_theme_font_size_override("font_size", 64)
	_hud_moves_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_hud_moves_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_moves_label.custom_minimum_size.x = 200
	hbox.add_child(_hud_moves_label)


## Populate the center word display area of the HUD (Words mode only).
func _update_hud_word_display() -> void:
	# Clear previous letters
	_word_letter_labels.clear()
	for child in _hud_word_container.get_children():
		child.queue_free()
	
	if Config.game_mode != 3 or Config.current_word.is_empty():
		return
	
	var emoji: String = Config.current_word.get("emoji", "")
	var word: String = Config.current_word.get("word", "")
	if word.is_empty():
		return
	
	# Emoji label
	if not emoji.is_empty():
		var emoji_label := Label.new()
		emoji_label.text = emoji
		emoji_label.add_theme_font_size_override("font_size", 96)
		emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hud_word_container.add_child(emoji_label)
		
		# Small spacer
		var spacer := Control.new()
		spacer.custom_minimum_size.x = 12
		_hud_word_container.add_child(spacer)
	
	# Letter labels — dimmed by default
	for i in range(word.length()):
		var lbl := Label.new()
		lbl.text = word[i]
		lbl.add_theme_font_size_override("font_size", 80)
		lbl.add_theme_color_override("font_color", Color(0.3, 0.33, 0.4))  # Dim Navy
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size.x = 72
		_hud_word_container.add_child(lbl)
		_word_letter_labels.append(lbl)


func _update_hud_moves() -> void:
	if _hud_moves_label:
		_hud_moves_label.text = "%d" % _move_count


## Light up a letter in the word HUD when collected.
func _light_up_word_letter(index: int) -> void:
	if index < 0 or index >= _word_letter_labels.size():
		return
	
	var lbl := _word_letter_labels[index]
	
	# Bright yellow brand color
	lbl.add_theme_color_override("font_color", Color("#FFCC00"))
	
	# Pop animation
	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ── Win screen UI ────────────────────────────────────────────────────────────

## Create a centred "You Win!" badge with options.
func _create_win_label() -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	_win_container = CenterContainer.new()
	_win_container.anchors_preset = Control.PRESET_FULL_RECT
	_win_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(_win_container)

	var main_panel := PanelContainer.new()
	# We need to ensure the panel is centered in _win_container
	main_panel.anchors_preset = Control.PRESET_CENTER
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.custom_minimum_size.x = 800
	
	var main_style := StyleBoxFlat.new()
	main_style.bg_color = Color(0.15, 0.17, 0.22, 0.95) # Dark tint
	main_style.corner_radius_top_left = 32
	main_style.corner_radius_top_right = 32
	main_style.corner_radius_bottom_right = 32
	main_style.corner_radius_bottom_left = 32
	main_style.border_width_left = 4
	main_style.border_width_top = 4
	main_style.border_width_right = 4
	main_style.border_width_bottom = 4
	main_style.border_color = Color("#1188FF") # Sky border
	main_style.content_margin_left = 60
	main_style.content_margin_right = 60
	main_style.content_margin_top = 40
	main_style.content_margin_bottom = 40
	main_panel.add_theme_stylebox_override("panel", main_style)
	_win_container.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	main_panel.add_child(vbox)

	# 1. Header
	_win_label = Label.new()
	_win_label.text = tr("you_win")
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.add_theme_font_size_override("font_size", 90)
	_win_label.add_theme_color_override("font_color", Color("#FFCC00")) # Yellow
	vbox.add_child(_win_label)

	_score_label = Label.new()
	_score_label.text = "⏱ 00:00 | 🚶 0"
	_score_label.add_theme_font_size_override("font_size", 40)
	_score_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Ensure description fits
	vbox.add_child(_score_label)

	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 20)
	vbox.add_child(button_vbox)

	# 2. Next Round Button (Default) + Timer Label
	var next_hbox := HBoxContainer.new()
	next_hbox.add_theme_constant_override("separation", 20)
	next_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(next_hbox)

	var next_spacer_l := Control.new()
	next_spacer_l.custom_minimum_size.x = 80
	next_hbox.add_child(next_spacer_l)

	_next_button = _create_styled_button(tr("next_round"), 650, 100)
	_next_button.pressed.connect(_on_next_round_pressed)
	next_hbox.add_child(_next_button)

	_timer_label = Label.new()
	_timer_label.text = "10"
	_timer_label.custom_minimum_size.x = 80
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5)) # Muted grey
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	next_hbox.add_child(_timer_label)

	# 3. Harder Button
	var harder_hbox := HBoxContainer.new()
	harder_hbox.add_theme_constant_override("separation", 20)
	harder_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(harder_hbox)
	
	var h_spacer_l := Control.new()
	h_spacer_l.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_l)

	_harder_button = _create_styled_button(tr("challenge_pp"), 650, 100, Color("#FFCC00")) # Yellow accent
	_harder_button.pressed.connect(_on_harder_pressed)
	harder_hbox.add_child(_harder_button)
	
	var h_spacer_r := Control.new()
	h_spacer_r.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_r)

	# 4. Mode Suggestions
	_suggestion_container = VBoxContainer.new()
	_suggestion_container.add_theme_constant_override("separation", 20)
	button_vbox.add_child(_suggestion_container)

	# Padding before Main Menu
	var padding := Control.new()
	padding.custom_minimum_size.y = 40
	button_vbox.add_child(padding)

	# 5. Home Button
	var home_hbox := HBoxContainer.new()
	home_hbox.add_theme_constant_override("separation", 20)
	home_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(home_hbox)
	
	var home_spacer_l := Control.new()
	home_spacer_l.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_l)

	var home_btn := _create_styled_button(tr("main_menu"), 650, 100, Color("#1188FF")) # Sky
	home_btn.pressed.connect(_on_home_pressed)
	home_hbox.add_child(home_btn)
	
	var home_spacer_r := Control.new()
	home_spacer_r.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_r)

	_win_container.visible = false
	
	# Build navigation map for the chaser
	_nav_map = maze_renderer.get_navigation_map()
	_chaser_active = false
	if _chaser:
		_chaser.queue_free()
		_chaser = null


func _create_styled_button(btn_text: String, w: int, h: int, f_color: Color = Color("#1188FF")) -> Button:
	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(w, h)
	btn.add_theme_font_size_override("font_size", 42)
	
	# Normal style
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.17, 0.22)
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_right = 12
	normal.corner_radius_bottom_left = 12
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(1, 1, 1, 0.1)
	btn.add_theme_stylebox_override("normal", normal)
	
	# Focus / Hover style
	var focus := StyleBoxFlat.new()
	focus.bg_color = f_color
	focus.border_width_left = 4
	focus.border_width_top = 4
	focus.border_width_right = 4
	focus.border_width_bottom = 4
	focus.border_color = Color.WHITE
	focus.corner_radius_top_left = 12
	focus.corner_radius_top_right = 12
	focus.corner_radius_bottom_right = 12
	focus.corner_radius_bottom_left = 12
	
	var hover := focus.duplicate()
	hover.bg_color = f_color.lightened(0.2)
	
	btn.add_theme_stylebox_override("focus", focus)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", focus)
	
	# Text colors
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color("#112244"))
	btn.add_theme_color_override("font_hover_color", Color("#112244"))
	btn.add_theme_color_override("font_pressed_color", Color("#112244"))
	
	return btn

# ── Collectibles ──────────────────────────────────────────────────────────────

## Spawn numbers or letters along the main path based on the game mode.
func _spawn_collectibles() -> void:
	if _current_maze == null or Config.game_mode <= 0:
		return

	var path_coords := _current_maze.main_path_coords
	
	# Exclude start and end cells
	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c := _current_maze.get_cell(coord)
		if not c.is_start and not c.is_end:
			temp_path.append(c)
			
	var L: int = temp_path.size()
	if L == 0:
		return
		
	# Determine how many items to spawn (roughly 1 every 3-4 cells, max 26 for letters)
	var max_items := 26 if Config.game_mode == 2 else 50
	var num_items: int = maxi(1, mini(max_items, L / 3))
	
	# Space them out evenly along the valid path
	var step: float = float(L) / float(num_items)
	
	for i in range(num_items):
		var idx: int = int(i * step + (step / 2.0))
		idx = mini(idx, L - 1)
		var cell := temp_path[idx]
		
		# Generate the string value
		var val_str: String = ""
		if Config.game_mode == 1:
			val_str = str(i + 1)
		elif Config.game_mode == 2:
			val_str = String.chr(65 + i) # 65 == 'A'
			
		var col: Collectible = CollectibleScene.instantiate()
		col.grid_pos = cell.coords
		col.value_str = val_str
		
		# Add to tree and position it
		add_child(col)
		col.setup(maze_renderer.get_cell_size(), maze_renderer.theme)
		col.position = maze_renderer.grid_to_pixel(cell.coords)
		
		# Track it for pickup detection
		_collectibles[cell.coords] = col


## Spawn word-letter collectibles along the main path (Words mode).
func _spawn_word_collectibles() -> void:
	if _current_maze == null:
		return
	
	# Pick a random word for the effective language + difficulty
	var lang := Config.get_effective_language()
	var word_data := WordList.get_random_word(lang, Config.difficulty)
	if word_data.is_empty():
		push_warning("GameManager: No word found for lang=%s diff=%d" % [lang, Config.difficulty])
		return
	
	Config.current_word = word_data
	_word_next_index = 0
	
	var word: String = word_data.get("word", "")
	if word.is_empty():
		return
	
	var path_coords := _current_maze.main_path_coords
	
	# Exclude start and end cells
	var temp_path: Array[MazeData.CellData] = []
	for coord in path_coords:
		var c := _current_maze.get_cell(coord)
		if not c.is_start and not c.is_end:
			temp_path.append(c)
	
	var L: int = temp_path.size()
	if L == 0:
		return
	
	# Filter out spaces for collectibles
	var collectible_chars: Array[int] = [] # indices in the word
	for i in range(word.length()):
		if word[i] != " ":
			collectible_chars.append(i)
	
	var num_collectibles: int = collectible_chars.size()
	if num_collectibles == 0: return

	# Space the collectibles evenly along the path
	var step: float = float(L) / float(num_collectibles)
	
	for i in range(num_collectibles):
		var char_idx: int = collectible_chars[i]
		var path_idx: int = int(i * step + (step / 2.0))
		path_idx = mini(path_idx, L - 1)
		var cell := temp_path[path_idx]
		
		var col: Collectible = CollectibleScene.instantiate()
		col.grid_pos = cell.coords
		col.value_str = word[char_idx]
		col.collect_index = char_idx  # Original index in the full word/phrase
		
		add_child(col)
		col.setup(maze_renderer.get_cell_size(), maze_renderer.theme)
		col.position = maze_renderer.grid_to_pixel(cell.coords)
		
		_collectibles[cell.coords] = col


func _on_player_bumped(_dir: Vector2i) -> void:
	_move_count += 1
	_update_hud_moves()
	_check_chaser_trigger()
	_check_chaser_collision()

## ── TTS Voice Hints ─────────────────────────────────────────────────────────

## Speak text using the OS TTS engine, matching the current game language (unless overridden).
func _speak(text: String, rate: float = 1.0, lang_override: String = "") -> void:
	if not Config.voice_hints:
		return
		
	var lang := lang_override if not lang_override.is_empty() else Config.get_effective_language()
	var speak_text := text.to_lower()
	
	# Use the cached voice ID to avoid blocking the main thread with OS queries
	var voice_id := Config.get_tts_voice(lang)
	
	# Pass to background thread
	_tts_mutex.lock()
	_tts_pending_text = speak_text
	_tts_pending_voice = voice_id
	_tts_pending_rate = rate
	_tts_mutex.unlock()
	
	_tts_semaphore.post()


## Background thread loop for TTS calls
func _tts_worker_loop() -> void:
	while true:
		_tts_semaphore.wait()
		
		var text: String = ""
		var voice: String = ""
		var rate: float = 1.0
		
		_tts_mutex.lock()
		if _tts_exit_flag:
			_tts_mutex.unlock()
			break
		
		# Grab the LATEST request and clear the pending state
		text = _tts_pending_text
		voice = _tts_pending_voice
		rate = _tts_pending_rate
		_tts_pending_text = ""
		_tts_mutex.unlock()
		
		if not text.is_empty():
			# Note: DisplayServer methods are generally thread-safe in Godot 4,
			# but offloading the block solves the OS-level UI lag.
			DisplayServer.tts_stop()
			DisplayServer.tts_speak(text, voice, 50, 1.0, rate)

func _on_player_moved(new_pos: Vector2i) -> void:
	_move_count += 1
	_update_hud_moves()
	_check_chaser_trigger()
	_check_chaser_collision()
	
	if _collectibles.has(new_pos):
		var col: Collectible = _collectibles[new_pos]
		var val := col.value_str
		
		# Words mode: enforce collection order
		if Config.game_mode == 3 and col.collect_index >= 0:
			var word_lang: String = Config.current_word.get("lang", "")
			
			if col.collect_index == _word_next_index:
				# Correct letter — collect it and light up HUD
				col.collect()
				_collectibles.erase(new_pos)
				_light_up_word_letter(_word_next_index)
				_speak(val, 0.85, word_lang) # Speak the letter
				
				_word_next_index += 1
				
				# Check for spaces to auto-collect/skip
				var word_full: String = Config.current_word.get("word", "")
				var hit_word_boundary: bool = false
				
				while _word_next_index < word_full.length() and word_full[_word_next_index] == " ":
					_light_up_word_letter(_word_next_index)
					_word_next_index += 1
					hit_word_boundary = true
				
				# If we hit a space or completed the whole thing, say the phrase collected so far
				if hit_word_boundary or _word_next_index >= word_full.length():
					var phrase_so_far := word_full.substr(0, _word_next_index).strip_edges()
					if not phrase_so_far.is_empty():
						# Use a small delay so literal letter finishes
						get_tree().create_timer(1.2).timeout.connect(func(): _speak(phrase_so_far, 0.7, word_lang))
			else:
				# Wrong order — shake the collectible to give feedback
				_shake_collectible(col)
		else:
			# Numbers / Letters mode — collect freely
			col.collect()
			_collectibles.erase(new_pos)
			_speak(val, 0.85) # Speak the number or letter 15% slower


## Shake a collectible to indicate wrong collection order.
func _shake_collectible(col: Collectible) -> void:
	var base_pos := col.position
	var tw := col.create_tween()
	tw.tween_property(col, "position", base_pos + Vector2(8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(-8, 0), 0.04)
	tw.tween_property(col, "position", base_pos + Vector2(4, 0), 0.04)
	tw.tween_property(col, "position", base_pos, 0.04)


# ── Chaser Logic ─────────────────────────────────────────────────────────────

func _check_chaser_trigger() -> void:
	if not Config.chaser_enabled or _chaser_active:
		return
		
	# Spawn chaser after 6 moves for kids (Easy/V.Easy), 10 for others
	var threshold = 6 if Config.difficulty <= 1 else 10
	if _move_count >= threshold:
		_spawn_chaser()

func _spawn_chaser() -> void:
	_chaser_active = true
	var start_cell = _current_maze.get_start_cell()
	if not start_cell: return
	
	_chaser = ChaserScene.instantiate()
	add_child(_chaser)
	_chaser.grid_pos = start_cell.coords
	_chaser.position = maze_renderer.grid_to_pixel(_chaser.grid_pos)
	_chaser.setup(maze_renderer)
	
	_chaser.request_move.connect(_on_chaser_request_move)
	_chaser.move_finished.connect(_check_chaser_collision) # Check after slide too

func _on_chaser_request_move() -> void:
	if not _chaser or not _nav_map: return
	
	var player_pos = player.grid_pos
	var chaser_pos = _chaser.grid_pos
	
	if player_pos == chaser_pos:
		_on_chaser_caught_player()
		return
		
	# Find path to player
	var id_start = chaser_pos.y * _current_maze.grid_size.x + chaser_pos.x
	var id_end = player_pos.y * _current_maze.grid_size.x + player_pos.x
	
	var path = _nav_map.get_id_path(id_start, id_end)
	if path.size() > 1:
		# Next step is the second point in path
		var next_id = path[1]
		var next_pos = Vector2i(next_id % _current_maze.grid_size.x, next_id / _current_maze.grid_size.x)
		
		# Tailgating logic: if next step is the player, we already know they are 1 cell away.
		# If it's a child's game, we could add a "hesitation" here, but the speed diff is enough.
		_chaser.move_to(next_pos)

func _check_chaser_collision() -> void:
	if _chaser and _chaser.grid_pos == player.grid_pos:
		_on_chaser_caught_player()

func _on_chaser_caught_player() -> void:
	if not _chaser_active: return
	_chaser_active = false
	_is_win_screen_active = true
	
	if _chaser: _chaser.stop()
	
	# Throroughly freeze player
	player.set_process(false)
	player.set_physics_process(false) # Block movement loop
	player.set_process_input(false)   # Block direct input
	
	# Faster feedback
	_show_gotcha_screen()

func _show_gotcha_screen() -> void:
	_win_label.text = tr("gotcha")
	_score_label.text = tr("try_again_desc")
	_next_button.text = tr("try_again")
	
	# Show "Easier" if possible
	if _harder_button:
		_harder_button.visible = Config.difficulty > 0
		_harder_button.text = tr("challenge_mm")
		# We'll need to update the logic for this button in Gotcha context
		# but for now let's just use the existing harder logic which is actually difficulty change
		# Wait, if they click it, it currently does _on_harder_pressed (+1).
		# We need a new handler or change the handler.
	
	_win_container.visible = true
	_next_button.grab_focus()

func _show_win_screen(time_str: String) -> void:
	_win_label.text = tr("you_win")
	_score_label.text = tr("score_time") % time_str + " | " + tr("score_steps") % _move_count
	
	# On WIN, show "Harder"
	if _harder_button:
		_harder_button.visible = Config.difficulty < 4
		_harder_button.text = tr("challenge_pp")

	_win_container.visible = true
	_next_button.grab_focus()
