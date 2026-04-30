## oled_idle_guard.gd
## ---------------------------------------------------------------------------
## Reusable OLED burn-in protection node.
##
## Drop this as a child of any scene that needs idle-state protection.
## Call start() to begin watching, stop() to pause, and reset() on any
## meaningful user interaction (player moved, button pressed, etc.).
##
## Signals fire when the scene has been idle for the configured durations:
##   idle_tier_1  — soft idle (default 45 s): start subtle animation / dim
##   idle_tier_2  — deep idle (default 180 s): aggressive dim / safe state
##   idle_reset   — meaningful input received; tiers were reset
##
## The guard also listens to _unhandled_input automatically while active.
## Deliberately avoids autoload and global state — it is purely local.
## ---------------------------------------------------------------------------
class_name OledIdleGuard
extends Node


# ── Signals ──────────────────────────────────────────────────────────────────

## Fired when the scene has been idle for tier-1 duration.
signal idle_tier_1

## Fired when the scene has been idle for tier-2 duration.
signal idle_tier_2

## Fired when a meaningful input resets the idle timers.
signal idle_reset


# ── Configuration ─────────────────────────────────────────────────────────────

## Set to 1.0 for release. Set to 0.1 to run all timers 10× faster for testing.
const DEBUG_TIME_SCALE: float = 0.1

## Seconds of no input before tier-1 fires. Default: 45 s.
var tier1_sec: float = 45.0

## Seconds of no input before tier-2 fires. Default: 180 s (3 min).
var tier2_sec: float = 180.0


# ── Internal state ────────────────────────────────────────────────────────────

var _elapsed: float = 0.0
var _tier1_fired: bool = false
var _tier2_fired: bool = false
var _active: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	set_process(false)
	set_process_input(false)



func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if not _tier1_fired and _elapsed >= tier1_sec:
		_tier1_fired = true
		idle_tier_1.emit()
	if not _tier2_fired and _elapsed >= tier2_sec:
		_tier2_fired = true
		idle_tier_2.emit()


func _input(event: InputEvent) -> void:
	if not _active:
		return
	# Only count deliberate interactions — not mouse motion / touch drag.
	var is_deliberate: bool = (
		event is InputEventKey or
		event is InputEventJoypadButton or
		(event is InputEventMouseButton and event.pressed) or
		(event is InputEventScreenTouch and event.pressed) or
		(event is InputEventAction and event.pressed)
	)

	if is_deliberate:
		reset()


# ── Public API ────────────────────────────────────────────────────────────────

## Begin (or resume) idle detection with optional custom thresholds.
## Passing 0 uses the current tier1_sec / tier2_sec values.
func start(t1_sec: float = 0.0, t2_sec: float = 0.0) -> void:
	if t1_sec > 0.0:
		tier1_sec = t1_sec * DEBUG_TIME_SCALE
	if t2_sec > 0.0:
		tier2_sec = t2_sec * DEBUG_TIME_SCALE
	_active = true
	set_process(true)
	set_process_input(true)


## Pause idle detection without resetting the elapsed counter.
func stop() -> void:
	_active = false
	set_process(false)
	set_process_input(false)


## Reset the elapsed counter and all tier flags.
## Call this whenever meaningful user interaction occurs.
## Also emits idle_reset if any tier had previously fired.
func reset() -> void:
	var was_fired := _tier1_fired or _tier2_fired
	_elapsed = 0.0
	_tier1_fired = false
	_tier2_fired = false
	if was_fired:
		idle_reset.emit()
