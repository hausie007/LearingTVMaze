class_name TrapManager
extends Node2D

var _maze: MazeData = null
var _renderer: MazeRenderer = null
var _traps: Dictionary = {}

func setup(maze: MazeData, renderer: MazeRenderer) -> void:
	clear()
	_maze = maze
	_renderer = renderer

func clear() -> void:
	for trap_node in _traps.values():
		if trap_node is Node and is_instance_valid(trap_node):
			(trap_node as Node).queue_free()
	_traps.clear()

func can_drop_on(coord: Vector2i, blocked_cells: Dictionary = {}) -> bool:
	if _maze == null or _renderer == null:
		return false
	var cell := _maze.get_cell(coord)
	if cell == null:
		return false
	if not cell.is_visited or cell.is_start or cell.is_end:
		return false
	if has_trap(coord):
		return false
	if blocked_cells.has(coord):
		return false
	return true

func drop_trap(owner_id: int, coord: Vector2i) -> bool:
	if has_trap(coord) or _renderer == null:
		return false
	var node := _create_trap_node(owner_id, coord)
	add_child(node)
	_traps[coord] = node
	return true

func has_trap(coord: Vector2i) -> bool:
	return _traps.has(coord)

func trigger_at(coord: Vector2i) -> bool:
	if not _traps.has(coord):
		return false
	var node := _traps[coord] as Node
	_traps.erase(coord)
	if node != null and is_instance_valid(node):
		node.queue_free()
	return true

func get_trap_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for key in _traps.keys():
		if key is Vector2i:
			result.append(key)
	return result

func _create_trap_node(owner_id: int, coord: Vector2i) -> Node2D:
	var root := Node2D.new()
	root.name = "Trap_%d_%d_%d" % [owner_id, coord.x, coord.y]
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = _renderer.grid_to_pixel(coord)

	var trap_texture: Texture2D = null
	var theme := _renderer.get_theme_loader()
	if theme != null:
		trap_texture = theme.trap_texture

	if trap_texture != null:
		var sprite := Sprite2D.new()
		sprite.name = "TrapSprite"
		sprite.texture = trap_texture
		sprite.centered = true
		var max_dim := maxf(float(trap_texture.get_width()), float(trap_texture.get_height()))
		if max_dim > 0.0:
			sprite.scale = Vector2.ONE * ((_renderer.get_cell_size() * 0.62) / max_dim)
		root.add_child(sprite)
	else:
		var fallback := Label.new()
		fallback.name = "TrapFallback"
		fallback.text = "?"
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var size := _renderer.get_cell_size() * 0.54
		fallback.size = Vector2(size, size)
		fallback.position = -fallback.size / 2.0
		fallback.add_theme_font_size_override("font_size", int(size * 0.78))
		fallback.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35, 1.0))
		root.add_child(fallback)
	return root
