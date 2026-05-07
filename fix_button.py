import re

with open('scripts/multiplayer/host_lobby.gd', 'r') as f:
    content = f.read()

content = content.replace('var focusable_slots: Array[PanelContainer] = []', 'var focusable_slots: Array[Button] = []')
content = content.replace('var frame := slot["frame"] as PanelContainer', 'var frame := slot["frame"] as Button')
content = content.replace('var empty_frames: Array[PanelContainer] = []', 'var empty_frames: Array[Button] = []')
content = content.replace('func _apply_filled_frame_style(frame: PanelContainer) -> void:', 'func _apply_filled_frame_style(frame: Button) -> void:')
content = content.replace('func _apply_empty_frame_style(frame: PanelContainer) -> void:', 'func _apply_empty_frame_style(frame: Button) -> void:')

with open('scripts/multiplayer/host_lobby.gd', 'w') as f:
    f.write(content)

print("Fixed typing")
