## frame_animator.gd
## ---------------------------------------------------------------------------
## Tiny component that cycles through an array of textures on a Sprite2D.
##
## Offloads simple frame-based animation logic from controller scripts.
## ---------------------------------------------------------------------------
class_name FrameAnimator
extends Node


@export var fps: float = 5.0

var _frames: Array[Texture2D] = []
var _target: Node = null
var _timer: float = 0.0
var _index: int = 0
var _active: bool = false


func _process(delta: float) -> void:
	if not _active or _frames.is_empty():
		return
		
	_timer += delta
	var period: float = 1.0 / fps
	if _timer >= period:
		_timer = 0.0
		_index = (_index + 1) % _frames.size()
		if _target:
			if _target is Sprite2D:
				_target.texture = _frames[_index]
			elif _target is TextureRect:
				_target.texture = _frames[_index]


# ── Public API ───────────────────────────────────────────────────────────────

## Initialize and start the animation if multiple frames exist.
func start(target: Node, frames: Array[Texture2D], speed: float = 5.0) -> void:
	_target = target
	_frames = frames
	fps = speed
	_timer = 0.0
	_index = 0
	
	if _frames.size() > 1:
		_active = true
		set_process(true)
	else:
		_active = false
		set_process(false)


## Stop animation and reset to the first frame.
func stop() -> void:
	_active = false
	_index = 0
	if _target and not _frames.is_empty():
		if _target is Sprite2D:
			_target.texture = _frames[0]
		elif _target is TextureRect:
			_target.texture = _frames[0]
	set_process(false)
