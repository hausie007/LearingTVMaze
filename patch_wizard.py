import re

with open('scripts/game_setup_wizard.gd', 'r') as f:
    content = f.read()

# We want to add breadcrumb sizing logic to `_apply_responsive_layout`.
# Let's find: `if _logo_step_spacer != null:` and insert our logic before it.

patch = """
	for step in [_step1, _step2, _step3]:
		if step == null:
			continue
		var collapse_row := step.get_collapse_row()
		if collapse_row != null:
			collapse_row.custom_minimum_size.x = clampf(available_width * 0.85, 600.0, 1300.0)
			collapse_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	if _logo_step_spacer != null:
"""

content = content.replace("	if _logo_step_spacer != null:", patch)

with open('scripts/game_setup_wizard.gd', 'w') as f:
    f.write(content)

print("Patched game_setup_wizard.gd")
