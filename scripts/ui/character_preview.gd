extends TextureRect
class_name CharacterPreview

var frames: Array[Texture2D] = []
var fps: float = 5.0
var _anim_time: float = 0.0

func _process(delta: float) -> void:
	if frames.size() > 1:
		_anim_time += delta
		var idx = int(_anim_time * fps) % frames.size()
		texture = frames[idx]
	elif frames.size() == 1:
		texture = frames[0]
	else:
		texture = null

func set_character(new_frames: Array[Texture2D], new_fps: float) -> void:
	frames = new_frames
	fps = new_fps
	_anim_time = 0.0
	if frames.is_empty():
		texture = null
	else:
		texture = frames[0]
	set_process(frames.size() > 1)

func clear() -> void:
	frames = []
	texture = null
