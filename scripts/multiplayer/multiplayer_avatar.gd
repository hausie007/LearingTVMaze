class_name MultiplayerAvatar
extends Node2D

@onready var sprite: Sprite2D = %Sprite

var peer_id: int = 0
var character_id: String = ""
var role: String = ""
var grid_pos: Vector2i = Vector2i.ZERO

var _move_tween: Tween = null

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
	if role == NetworkManager.ROLE_CHASER:
		sprite_node.modulate = Color(1.0, 0.55, 0.55, 1.0)
	elif role == NetworkManager.ROLE_RACER:
		sprite_node.modulate = Color(0.65, 0.9, 1.0, 1.0)
	else:
		sprite_node.modulate = Color.WHITE

	var cell_size: float = renderer.get_cell_size()
	var target_size: float = cell_size * 0.72
	var tex_size := texture.get_size()
	if maxf(tex_size.x, tex_size.y) > 0.0:
		var scale_factor := target_size / maxf(tex_size.x, tex_size.y)
		sprite_node.scale = Vector2.ONE * scale_factor

	position = renderer.grid_to_pixel(grid_pos)
	_update_role_badge(cell_size)

func move_to_grid(new_grid_pos: Vector2i, renderer: MazeRenderer, duration: float) -> void:
	grid_pos = new_grid_pos
	var target_pos := renderer.grid_to_pixel(new_grid_pos)

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()

	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _get_sprite() -> Sprite2D:
	if sprite != null:
		return sprite
	sprite = get_node_or_null("Sprite") as Sprite2D
	return sprite

func _update_role_badge(cell_size: float) -> void:
	var badge := get_node_or_null("RoleBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "RoleBadge"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 22)
		add_child(badge)

	match role:
		NetworkManager.ROLE_CHASER:
			badge.text = tr("mp_role_chaser_short")
			badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		NetworkManager.ROLE_RACER:
			badge.text = tr("mp_role_racer_short")
			badge.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, 1.0))
		_:
			badge.text = tr("mp_role_collector_short")
			badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.18, 1.0))

	var width := cell_size * 1.1
	badge.position = Vector2(-width * 0.5, -cell_size * 0.70)
	badge.size = Vector2(width, 28)
	if role.is_empty():
		badge.text = ""
