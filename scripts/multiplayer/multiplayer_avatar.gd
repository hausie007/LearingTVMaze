class_name MultiplayerAvatar
extends Node2D

@onready var sprite: Sprite2D = %Sprite

var peer_id: int = 0
var character_id: String = ""
var role: String = ""
var grid_pos: Vector2i = Vector2i.ZERO

var _move_tween: Tween = null
var _shake_tween: Tween = null
var _animator: FrameAnimator = null
var _confusion_visual_version: int = 0

func setup(p_peer_id: int, p_character_id: String, renderer: MazeRenderer, start_grid_pos: Vector2i, p_role: String = "") -> void:
	peer_id = p_peer_id
	character_id = p_character_id
	role = p_role
	grid_pos = start_grid_pos
	var sprite_node: Sprite2D = _get_sprite()

	var frames := _character_frames(character_id)
	var texture: Texture2D = frames[0] if not frames.is_empty() else CharacterCatalog.get_texture_by_id(character_id)
	if texture == null:
		var fallback := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.25, 0.55, 0.95))
		texture = ImageTexture.create_from_image(fallback)
		frames.append(texture)

	if sprite_node == null:
		push_error("MultiplayerAvatar: Sprite node is missing")
		return

	sprite_node.texture = texture
	sprite_node.modulate = Color.WHITE
	_start_animation(sprite_node, frames, _character_fps(character_id))

	var cell_size: float = renderer.get_cell_size()
	var target_size: float = cell_size * 0.72
	var tex_size := texture.get_size()
	if maxf(tex_size.x, tex_size.y) > 0.0:
		var scale_factor := target_size / maxf(tex_size.x, tex_size.y)
		sprite_node.scale = Vector2.ONE * scale_factor

	position = renderer.grid_to_pixel(grid_pos)

func move_to_grid(new_grid_pos: Vector2i, renderer: MazeRenderer, duration: float) -> void:
	grid_pos = new_grid_pos
	var target_pos := renderer.grid_to_pixel(new_grid_pos)

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func shake_wall(direction: Vector2i, renderer: MazeRenderer) -> void:
	var sprite_node := _get_sprite()
	if sprite_node == null:
		return
	var cs := renderer.get_cell_size()
	var bump_offset := Vector2(direction) * (cs * 0.15)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	sprite_node.position = Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.bind_node(sprite_node)
	_shake_tween.tween_property(sprite_node, "position", bump_offset, 0.05).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(sprite_node, "position", Vector2.ZERO, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func set_confused_visual(enabled: bool, shake: bool = false, renderer: MazeRenderer = null, visual_delay_sec: float = 0.0) -> void:
	_confusion_visual_version += 1
	var version := _confusion_visual_version
	if visual_delay_sec > 0.0:
		_set_confused_visual_later(enabled, shake, renderer, visual_delay_sec, version)
		return
	_apply_confused_visual(enabled, shake, renderer)

func _set_confused_visual_later(enabled: bool, shake: bool, renderer: MazeRenderer, delay_sec: float, version: int) -> void:
	await get_tree().create_timer(delay_sec).timeout
	if not is_inside_tree() or version != _confusion_visual_version:
		return
	_apply_confused_visual(enabled, shake, renderer)

func _apply_confused_visual(enabled: bool, shake: bool = false, renderer: MazeRenderer = null) -> void:
	var sprite_node := _get_sprite()
	if sprite_node != null:
		sprite_node.rotation = PI if enabled else 0.0
		if shake:
			play_confusion_shake(renderer)

func play_confusion_shake(renderer: MazeRenderer = null) -> void:
	var sprite_node := _get_sprite()
	if sprite_node == null:
		return
	var cs := renderer.get_cell_size() if renderer != null else 120.0
	var offset := Vector2(cs * 0.13, 0.0)
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	sprite_node.position = Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.bind_node(sprite_node)
	_shake_tween.tween_property(sprite_node, "position", offset, 0.045).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(sprite_node, "position", -offset, 0.065).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(sprite_node, "position", offset * 0.45, 0.045).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(sprite_node, "position", Vector2.ZERO, 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _get_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	sprite = get_node_or_null("Sprite") as Sprite2D
	return sprite

func _character_frames(p_character_id: String) -> Array[Texture2D]:
	var preview_data := CharacterCatalog.get_preview_data_by_id(p_character_id)
	var frames_data: Array = preview_data.get("frames", [])
	var frames: Array[Texture2D] = []
	for item in frames_data:
		if item is Texture2D:
			frames.append(item)
	return frames

func _character_fps(p_character_id: String) -> float:
	var preview_data := CharacterCatalog.get_preview_data_by_id(p_character_id)
	return float(preview_data.get("fps", 5.0))

func _start_animation(sprite_node: Sprite2D, frames: Array[Texture2D], fps: float) -> void:
	if frames.size() <= 1:
		if _animator != null:
			_animator.stop()
		return
	if _animator == null:
		_animator = FrameAnimator.new()
		add_child(_animator)
	_animator.start(sprite_node, frames, fps)
