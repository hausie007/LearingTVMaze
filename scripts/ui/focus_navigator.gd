## focus_navigator.gd
## ---------------------------------------------------------------------------
## Static utility for wiring D-pad focus navigation graphs.
##
## Centralizes the focus_neighbor_* wiring logic that was previously
## duplicated across game_setup_wizard.gd, mode_selection.gd,
## host_setup.gd, join_flow.gd, and host_lobby.gd.
##
## Usage:
##   FocusNavigator.configure_single(button, top_btn, bottom_btn)
##   FocusNavigator.configure_row(card_buttons, above_btn, below_btn)
## ---------------------------------------------------------------------------
class_name FocusNavigator
extends RefCounted


## Wire a single button's focus neighbors.
## Left/Right point to self (prevents escaping the row).
## Top/Bottom point to provided controls (if non-null).
static func configure_single(button: Control, top: Control, bottom: Control) -> void:
	if button == null:
		return
	button.focus_neighbor_left = button.get_path_to(button)
	button.focus_neighbor_right = button.get_path_to(button)
	if top != null:
		button.focus_neighbor_top = button.get_path_to(top)
	if bottom != null:
		button.focus_neighbor_bottom = button.get_path_to(bottom)


## Wire a horizontal row of buttons with wrapping Left/Right navigation.
## All buttons share the same top and bottom neighbors.
static func configure_row(buttons: Array, above: Control, below: Control) -> void:
	var row := valid_buttons(buttons)
	if row.is_empty():
		return
	for i in range(row.size()):
		var card := row[i] as Button
		var left := row[(i - 1 + row.size()) % row.size()] as Button
		var right := row[(i + 1) % row.size()] as Button
		card.focus_neighbor_left = card.get_path_to(left)
		card.focus_neighbor_right = card.get_path_to(right)
		if above != null:
			card.focus_neighbor_top = card.get_path_to(above)
		if below != null:
			card.focus_neighbor_bottom = card.get_path_to(below)


## Wire a multi-row grid with wrapping Left/Right and column-aware Up/Down.
## [columns] defines how many buttons per row.
## [above] is the control above the first row, [below] is below the last row.
static func configure_grid(buttons: Array, columns: int, above: Control, below: Control) -> void:
	var valid := valid_buttons(buttons)
	if valid.is_empty():
		return
	for i in range(valid.size()):
		var btn := valid[i] as Button
		# Left/Right: wrap within logical row
		var row_start := (i / columns) * columns
		var row_end := mini(row_start + columns, valid.size())
		var row_size := row_end - row_start
		var pos_in_row := i - row_start
		var left_idx := row_start + ((pos_in_row - 1 + row_size) % row_size)
		var right_idx := row_start + ((pos_in_row + 1) % row_size)
		btn.focus_neighbor_left = btn.get_path_to(valid[left_idx])
		btn.focus_neighbor_right = btn.get_path_to(valid[right_idx])

		# Up: same column in previous row, or [above]
		if i >= columns:
			btn.focus_neighbor_top = btn.get_path_to(valid[i - columns])
		elif above != null:
			btn.focus_neighbor_top = btn.get_path_to(above)

		# Down: same column in next row, or [below]
		if i + columns < valid.size():
			btn.focus_neighbor_bottom = btn.get_path_to(valid[i + columns])
		elif below != null:
			btn.focus_neighbor_bottom = btn.get_path_to(below)


## Filter an array to only visible, valid Button instances.
static func valid_buttons(items: Array) -> Array[Button]:
	var result: Array[Button] = []
	for item in items:
		if item is Button and is_instance_valid(item):
			var button := item as Button
			if button.visible:
				result.append(button)
	return result


## Check whether a control is focusable (visible, not disabled, focus_mode != NONE).
static func is_focusable(control: Control) -> bool:
	if control == null:
		return false
	if control is Button:
		var btn := control as Button
		if btn.disabled:
			return false
	return control.visible and control.focus_mode != Control.FOCUS_NONE
