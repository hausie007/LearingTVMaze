# scripts/ui/join_card_helper.gd
# ─────────────────────────────────────────────────────────────────────────────
# JoinCardHelper
# Manages card-zoom animations on focus events.
# ─────────────────────────────────────────────────────────────────────────────
class_name JoinCardHelper
extends RefCounted

static func apply_card_zoom(flow: Control, focused: bool) -> void:
	if flow._join_card_panel != null:
		flow._join_card_panel.add_theme_stylebox_override("panel", flow._join_card_focus if focused else flow._join_card_normal)
		
	if flow._join_card_container == null: return
	
	var pivot_size := flow._join_card_container.size
	if pivot_size.x <= 0 or pivot_size.y <= 0:
		pivot_size = flow._join_card_container.get_minimum_size()
	if pivot_size.x > 0 and pivot_size.y > 0:
		flow._join_card_container.pivot_offset = pivot_size * 0.5
		
	var target_scale := Vector2(1.16, 1.16) if focused else Vector2.ONE
	
	if flow._join_card_tween != null and flow._join_card_tween.is_valid():
		flow._join_card_tween.kill()
		
	flow._join_card_tween = flow.create_tween()
	flow._join_card_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flow._join_card_tween.tween_property(flow._join_card_container, "scale", target_scale, 0.18)
	flow._join_card_container.z_index = 2 if focused else 0
