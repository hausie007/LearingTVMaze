## player_controller.gd
## ---------------------------------------------------------------------------
## Discrete grid-based player controller for D-pad / arrow-key input.
##
## Design goals:
##   • One key press  = one cell move (no analog / continuous movement).
##   • Wall collision  – movement only if MazeData says the wall is open.
##   • Input debounce  – a short cooldown prevents rapid-fire movement when
##     a toddler mashes the remote.
##   • Smooth visual   – a short tween slides the sprite to the new position
##     so the movement feels polished rather than instantaneous.
##
## Supports an optional theme image (player.png) loaded via ThemeLoader.
## Falls back to a coloured square if no image is available.
##
## All tunable parameters are read from the Config autoload singleton.
##
## Signals:
##   reached_end – emitted the moment the player lands on the End cell.
## ---------------------------------------------------------------------------
class_name PlayerController
extends Node2D

# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted when the player moves to a new cell.
signal moved(new_pos: Vector2i)

## Emitted when the player bumps into a wall.
signal bumped(direction: Vector2i)

## Emitted when the player arrives at the End cell.
signal reached_end

# ── Runtime state ────────────────────────────────────────────────────────────

## Current grid coordinate.
var grid_pos: Vector2i = Vector2i.ZERO
var previous_grid_pos: Vector2i = Vector2i.ZERO
var has_previous_grid_pos: bool = false
var controls_reversed: bool = false

## References injected by GameManager.
var maze_data: MazeData       = null
var maze_renderer: MazeRenderer = null

## Internal cooldown tracker.
var _cooldown_remaining: float = 0.0

# ── Visual ───────────────────────────────────────────────────────────────────
## The visual node (either a ColorRect or a Sprite2D).
var _visual: Node = null

## Tracked tweens so we can kill them before starting a new one or on game reset.
var _shake_tween: Tween = null
var _move_tween: Tween = null
var _animator: FrameAnimator = null
var _confusion_visual_version: int = 0
var _outline_sprites: Array[Sprite2D] = []


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	rebuild_visual()


## Build (or rebuild) the player visual.  Uses a theme sprite if available,
## otherwise falls back to a coloured square.
func rebuild_visual() -> void:
	# Remove previous visual if rebuilding.
	if _visual:
		_visual.queue_free()
		_visual = null

	_outline_sprites.clear()

	var cs: float = 120.0
	if maze_renderer:
		cs = maze_renderer.get_cell_size()

	# Try to use a theme sprite.
	var theme_tex: Texture2D = null
	var theme_color: Color = Color(0.25, 0.55, 0.95)  # Fallback; overridden by ThemeLoader below
	var theme_loader: ThemeLoader = null
	
	if maze_renderer:
		theme_loader = maze_renderer.get_theme_loader()
		if theme_loader:
			theme_color = theme_loader.color_player
			if theme_loader.player_texture:
				theme_tex = theme_loader.player_texture

	if theme_tex:
		# ── Sprite2D from theme ──
		var sprite := Sprite2D.new()
		sprite.texture = theme_tex
		sprite.centered = true

		# Scale to fit the cell with a margin.
		var margin := cs * 0.1
		var target_size := cs - margin * 2
		var tex_size := Vector2(theme_tex.get_width(), theme_tex.get_height())
		var scale_factor: float = target_size / float(max(tex_size.x, tex_size.y))
		sprite.scale = Vector2(scale_factor, scale_factor)

		_visual = sprite

		# Add dynamic legibility outline/shadow based on active theme
		if theme_loader:
			var t_name := theme_loader.theme_name.to_lower()
			if t_name == "scary":
				var offsets := [
					Vector2(-2.0, 0.0),
					Vector2(2.0, 0.0),
					Vector2(0.0, -2.0),
					Vector2(0.0, 2.0)
				]
				for offset in offsets:
					var outline_sprite := Sprite2D.new()
					outline_sprite.texture = theme_tex
					outline_sprite.centered = true
					outline_sprite.show_behind_parent = true
					outline_sprite.position = offset / scale_factor
					outline_sprite.modulate = Color("f5f5f5")
					sprite.add_child(outline_sprite)
					_outline_sprites.append(outline_sprite)
			elif t_name == "thiefs" or t_name == "thieves":
				var shadow_sprite := Sprite2D.new()
				shadow_sprite.texture = theme_tex
				shadow_sprite.centered = true
				shadow_sprite.show_behind_parent = true
				shadow_sprite.position = Vector2(0.0, 4.0) / scale_factor
				shadow_sprite.modulate = Color("ffea6699")
				sprite.add_child(shadow_sprite)
				_outline_sprites.append(shadow_sprite)

		# Add animation support
		if theme_loader and not theme_loader.player_frames.is_empty():
			if _animator == null:
				_animator = FrameAnimator.new()
				add_child(_animator)
			_animator.start(sprite, theme_loader.player_frames, theme_loader.player_fps)
		elif _animator:
			_animator.stop()

	else:
		# ── Fallback: coloured square ──
		var rect := ColorRect.new()
		var sprite_size := cs * Config.player_scale
		rect.size = Vector2(sprite_size, sprite_size)
		rect.position = Vector2(-sprite_size / 2.0, -sprite_size / 2.0)
		rect.pivot_offset = rect.size / 2.0
		rect.color = theme_color
		_visual = rect

	add_child(_visual)
	set_confused_visual(controls_reversed)


## NOTE: Input is polled in _process() with manual cooldown instead of using
## _unhandled_input() with is_action_just_pressed(). This is a deliberate
## design choice: children hold D-pad buttons and expect continuous repeated
## movement. Using _process guarantees consistent repeat rate regardless of
## the engine's key-repeat settings. The tradeoff is that input bypasses
## Godot's focus-based propagation, but GameManager's process_mode guards
## for paused/win states compensate for this.
func _process(delta: float) -> void:
	# Synchronize outlines/shadow textures with the player sprite
	if _visual is Sprite2D and not _outline_sprites.is_empty():
		var parent_tex: Texture2D = _visual.texture
		for outline in _outline_sprites:
			if outline.texture != parent_tex:
				outline.texture = parent_tex

	# Tick cooldown.
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
		return  # Ignore input during cooldown.

	# Read D-pad / arrow keys.
	var direction := Vector2i.ZERO

	if Input.is_action_pressed("ui_up"):
		direction = Vector2i.UP
	elif Input.is_action_pressed("ui_down"):
		direction = Vector2i.DOWN
	elif Input.is_action_pressed("ui_left"):
		direction = Vector2i.LEFT
	elif Input.is_action_pressed("ui_right"):
		direction = Vector2i.RIGHT

	if direction == Vector2i.ZERO:
		return  # No input this frame.

	_try_move(-direction if controls_reversed else direction)


# ── Movement ─────────────────────────────────────────────────────────────────

## Attempt to move one cell in `direction`.
func _try_move(direction: Vector2i) -> void:
	if maze_data == null or maze_renderer == null:
		return

	# Check wall – deny if blocked.
	if not maze_data.is_wall_open(grid_pos, direction):
		_shake_visual(direction)
		if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
			Input.vibrate_handheld(24)
		bumped.emit(direction)
		return

	# Update logical position.
	previous_grid_pos = grid_pos
	has_previous_grid_pos = true
	grid_pos += direction

	# Start cooldown.
	_cooldown_remaining = Config.move_cooldown

	# Notify listeners that we moved.
	moved.emit(grid_pos)

	# Tween to new pixel position.
	var target_pixel := maze_renderer.grid_to_pixel(grid_pos)
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
		
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_pixel, Config.tween_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	# Check win condition.
	var cell := maze_data.get_cell(grid_pos)
	if cell and cell.is_end:
		# Small delay so the tween finishes before the signal fires.
		await _move_tween.finished
		reached_end.emit()

## Kills any active tweens and resets cooldowns (used when restarting the game).
func reset_movement() -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_cooldown_remaining = 0.0
	has_previous_grid_pos = false
	
	if _visual:
		_visual.position = Vector2.ZERO if _visual is Sprite2D else Vector2(-_visual.size.x / 2.0, -_visual.size.y / 2.0)
		_visual.rotation = PI if controls_reversed else 0.0

func set_controls_reversed(enabled: bool, shake: bool = false, visual_delay_sec: float = 0.0) -> void:
	controls_reversed = enabled
	_confusion_visual_version += 1
	var version := _confusion_visual_version
	if visual_delay_sec > 0.0:
		_apply_confused_visual_later(enabled, shake, visual_delay_sec, version)
	else:
		set_confused_visual(enabled)
		if shake:
			play_confusion_shake()

func _apply_confused_visual_later(enabled: bool, shake: bool, delay_sec: float, version: int) -> void:
	await get_tree().create_timer(delay_sec).timeout
	if not is_inside_tree() or version != _confusion_visual_version or controls_reversed != enabled:
		return
	set_confused_visual(enabled)
	if shake:
		play_confusion_shake()

func set_confused_visual(enabled: bool) -> void:
	if _visual == null:
		return
	if _visual is Control:
		var control := _visual as Control
		control.pivot_offset = control.size / 2.0
	_visual.rotation = PI if enabled else 0.0

func play_confusion_shake() -> void:
	if _visual == null:
		return
	var cs: float = 120.0
	if maze_renderer:
		cs = maze_renderer.get_cell_size()
	var base_pos: Vector2 = Vector2.ZERO if _visual is Sprite2D else Vector2(-_visual.size.x / 2.0, -_visual.size.y / 2.0)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_visual.position = base_pos
	var offset := Vector2(cs * 0.13, 0.0)
	_shake_tween = create_tween()
	_shake_tween.bind_node(_visual)
	_shake_tween.tween_property(_visual, "position", base_pos + offset, 0.045).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_visual, "position", base_pos - offset, 0.065).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_visual, "position", base_pos + offset * 0.45, 0.045).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_visual, "position", base_pos, 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Apply a short shake animation when bumping into a wall.
func _shake_visual(dir: Vector2i) -> void:
	if _visual == null:
		return
		
	# Trigger cooldown so they can't spam it and break the tween.
	_cooldown_remaining = Config.move_cooldown
	
	var cs: float = 120.0
	if maze_renderer:
		cs = maze_renderer.get_cell_size()
	
	var base_pos: Vector2 = _visual.position
	# Define start position based on visual node type since Sprite2D and ColorRect differ
	if _visual is Sprite2D:
		base_pos = Vector2.ZERO # Centered
	else:
		var sprite_size: float = cs * Config.player_scale
		base_pos = Vector2(-sprite_size / 2.0, -sprite_size / 2.0)
		
	# Kill any previous shake tween to prevent drift
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
			
	# Reset position before shaking (in case of killed tweens)
	_visual.position = base_pos

	var bump_offset: Vector2 = Vector2(dir) * (cs * 0.15)
	
	_shake_tween = create_tween()
	_shake_tween.bind_node(_visual)
	_shake_tween.tween_property(_visual, "position", base_pos + bump_offset, 0.05).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(_visual, "position", base_pos, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
