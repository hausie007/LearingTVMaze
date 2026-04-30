class_name MultiplayerAvatar
extends Node2D

@onready var sprite: Sprite2D = %Sprite

var peer_id: int = 0
var character_id: String = ""
var role: String = ""
var grid_pos: Vector2i = Vector2i.ZERO

var _move_tween: Tween = null
var _shake_tween: Tween = null

func setup(p_peer_id: int, p_character_id: String, renderer: MazeRenderer, start_grid_pos: Vector2i, p_role: String = "") -> void:
	peer_id = p_peer_id
	character_id = p_character_id
	role = p_role
	grid_pos = start_grid_pos
	var sprite_node: Sprite2D = _get_sprite()

	var texture := CharacterCatalog.get_texture_by_id(character_id)
	if texture == null:
		var fallback := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.25, 0.55, 0.95))
		texture = ImageTexture.create_from_image(fallback)

	if sprite_node == null:
		push_error("MultiplayerAvatar: Sprite node is missing")
		return

	sprite_node.texture = texture
	sprite_node.modulate = Color.WHITE

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

func _get_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	sprite = get_node_or_null("Sprite") as Sprite2D
	return sprite
