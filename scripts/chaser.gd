extends Node2D

signal request_move
signal move_finished

@onready var sprite: Sprite2D = $Sprite2D

var grid_pos: Vector2i = Vector2i.ZERO
var _maze_renderer: MazeRenderer = null
var _animator: FrameAnimator = null
var _move_timer: Timer = null
var _is_moving: bool = false

func setup(renderer: MazeRenderer) -> void:
	_maze_renderer = renderer
	var theme: ThemeLoader = renderer.get_theme_loader()
	
	if theme and theme.chaser_texture:
		sprite.texture = theme.chaser_texture
	else:
		_create_fallback_visual()
		
	# Scale to fit cell (slightly larger than player for visibility)
	var cs: float = renderer.get_cell_size()
	if sprite.texture == null:
		_create_fallback_visual()
	var tex_size: Vector2 = sprite.texture.get_size()
	var target_size: float = cs * 0.75
	sprite.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
	
	# Add animation support
	if theme and not theme.chaser_frames.is_empty():
		if _animator == null:
			_animator = FrameAnimator.new()
			add_child(_animator)
		_animator.start(sprite, theme.chaser_frames, theme.chaser_fps)
	
	# Start movement timer
	_move_timer = Timer.new()
	_move_timer.wait_time = 1.0 / Config.chaser_speed
	_move_timer.timeout.connect(_on_timer_timeout)
	add_child(_move_timer)
	_move_timer.start()

func _create_fallback_visual() -> void:
	var img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.INDIAN_RED)
	sprite.texture = ImageTexture.create_from_image(img)

func move_to(new_grid_pos: Vector2i) -> void:
	if _is_moving: return
	_is_moving = true
	
	# 1. Jiggle before move
	var jiggle_tw = create_tween()
	var offset: Vector2 = Vector2(10, 0)
	jiggle_tw.tween_property(sprite, "position", offset, 0.04)
	jiggle_tw.tween_property(sprite, "position", -offset, 0.04)
	jiggle_tw.tween_property(sprite, "position", offset * 0.5, 0.04)
	jiggle_tw.tween_property(sprite, "position", Vector2.ZERO, 0.04)
	
	await jiggle_tw.finished
	
	# 2. Slide to target
	grid_pos = new_grid_pos
	var target_pixel = _maze_renderer.grid_to_pixel(grid_pos)
	
	var move_tw = create_tween()
	move_tw.tween_property(self, "position", target_pixel, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await move_tw.finished
	
	_is_moving = false
	move_finished.emit()

func _on_timer_timeout() -> void:
	if not _is_moving:
		request_move.emit()

func stop() -> void:
	if _move_timer:
		_move_timer.stop()
