# PulseAnimator
# Static helper utility to manage repeating fade pulse animations on generic Control nodes.
class_name PulseAnimator
extends RefCounted

## Starts a looping pulse (alpha fade) on the given list of target Control nodes.
## Returns the Tween instance.
static func start_pulse(creator: Node, targets: Array, start_alpha: float = 1.0, end_alpha: float = 0.45, duration: float = 1.2) -> Tween:
	if targets.is_empty():
		return null
		
	var tween := creator.create_tween()
	tween.set_loops()
	
	for node in targets:
		if is_instance_valid(node) and node is Control:
			node.modulate.a = start_alpha
			
	tween.tween_method(func(alpha: float):
		for node in targets:
			if is_instance_valid(node) and node is Control:
				node.modulate.a = alpha
	, start_alpha, end_alpha, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_method(func(alpha: float):
		for node in targets:
			if is_instance_valid(node) and node is Control:
				node.modulate.a = alpha
	, end_alpha, start_alpha, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	return tween

## Safely stops and kills the given pulse tween.
static func stop_pulse(tween: Tween) -> Tween:
	if tween != null and tween.is_valid():
		tween.kill()
	return null
