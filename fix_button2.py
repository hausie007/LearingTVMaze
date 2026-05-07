import re

with open('scripts/multiplayer/host_lobby.gd', 'r') as f:
    content = f.read()

content = content.replace('empty_frames.append(slot["frame"] as PanelContainer)', 'empty_frames.append(slot["frame"] as Button)')

# Replace "panel" with all button styles
content = content.replace('frame.add_theme_stylebox_override("panel", style)', '''frame.add_theme_stylebox_override("normal", style)
	frame.add_theme_stylebox_override("hover", style)
	frame.add_theme_stylebox_override("pressed", style)
	frame.add_theme_stylebox_override("disabled", style)''')

with open('scripts/multiplayer/host_lobby.gd', 'w') as f:
    f.write(content)

print("Fixed button styles")
