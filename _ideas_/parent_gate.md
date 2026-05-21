# Feature Specification: Reusable Parent Gate

## 1. Description & Context
The **Parent Gate** is a critical security and friction overlay designed to prevent toddlers (ages 4–6) from accidentally wandering into advanced menus, altering settings, changing the system language, resetting educational progress, or disrupting multiplayer host lobbies. 

By introducing a gentle, non-frustrating verification gate that requires basic reading comprehension or elementary arithmetic, we ensure that only parents can modify the game's core configuration, while children remain in a safe, enclosed play environment.

---

## 2. Goals & Success Criteria
*   **Toddler-Proof Security**: The gate must effectively block children under 7 who cannot yet read fluidly or perform multi-digit calculations.
*   **Zero Parental Friction**: The challenge must be instantly resolvable for a parent or older sibling in less than 2–3 seconds, without requiring keyboard entry or complex typing.
*   **D-Pad Ergonomics**: The interface must be completely operable using a standard television remote control (D-pad + OK + Back) and touchscreens.
*   **Localization Friendly**: The challenge prompts must adapt to all 21 supported languages without breaking UI boundaries.

---

## 3. Challenge Designs

To keep the gate engaging and dynamic, the system can rotate between three simple challenge modes:

### Challenge A: Word-Based Arithmetic (Recommended Default)
*   **Concept**: Display a simple, single-digit addition or subtraction equation written entirely as words (not numbers). Toddlers who only recognize numerical symbols ("5 + 2") will not be able to read the equation.
*   **Prompt Example**: *"three + four = ?"* or *"nine - two = ?"*
*   **Interactions**: Display a row of 4 large, numerical button cards containing potential answers (e.g. `[ 5 ]`, `[ 7 ]`, `[ 8 ]`, `[ 6 ]`).
*   **D-Pad Flow**: Horizontal row navigation. Select correct number to pass.

### Challenge B: Directional Pattern Sequence
*   **Concept**: Instruct the user to press a quick, unique sequence on their D-pad/remote.
*   **Prompt Example**: *"Press: Up, Right, Up"* or *"Stiskněte: Dolů, Vlevo, Dolů"*
*   **Interactions**: Large directional icons pulse as the player enters the pattern.
*   **D-Pad Flow**: Captures raw `ui_*` inputs.

### Challenge C: Visual Shape & Color Matching
*   **Concept**: Present a sequence of shapes and colors.
*   **Prompt Example**: *"Tap: Blue Star, then Red Triangle"*
*   **Interactions**: Grid of colorful shapes. Good for touchscreen tablets where keyboards are intrusive.

---

## 4. Proposed Implementation Architecture

### Scene Structure
A reusable CanvasLayer (`parent_gate.tscn` / `parent_gate.gd`) that instantiates on top of all other viewports.

```
ParentGate (CanvasLayer, layer = 120)
└── BackgroundDim (ColorRect - semi-transparent #0D1117CC)
    └── GatePanel (PanelContainer - Parchment Flat StyleBox)
        └── MarginContainer (24px padding)
            └── VBoxContainer
                ├── GateTitle (Label - Bold, "Parent Verification")
                ├── GateInstructions (Label - Medium, e.g. "five + two = ?")
                ├── Spacer (Control)
                ├── OptionsContainer (HBoxContainer - large rounded buttons)
                │   ├── Option1 (Button)
                │   ├── Option2 (Button)
                │   ├── Option3 (Button)
                │   └── Option4 (Button)
                └── CancelButton (Button - "Cancel / Back to Game")
```

### Static Initialization Pattern (GDScript)
To make integration trivial across the codebase, `ParentGate` exposes a static initialization method. Any menu script can invoke the gate inline with a custom callback:

```gdscript
# Inside scripts/parent_gate.gd
extends CanvasLayer

signal passed
signal cancelled

static func check(caller: Node, on_success: Callable) -> void:
    var gate_scene = load("res://scenes/ui/parent_gate.tscn")
    var gate_inst = gate_scene.instantiate()
    caller.get_tree().root.add_child(gate_inst)
    
    # Connect signals dynamically
    gate_inst.passed.connect(func():
        on_success.call()
    )
```

---

## 5. Integration Points

### 1. Main Menu Settings Button
*   **File**: `scripts/top_menu.gd`
*   **Trigger**: Clicking the bottom-left `Settings` button.
*   **Flow**:
    ```gdscript
    func _on_settings_pressed() -> void:
        ParentGate.check(self, func():
            _transition_to_scene("res://scenes/settings_menu.tscn")
        )
    ```

### 2. Setup Wizard Multiplayer Card
*   **File**: `scripts/game_setup_wizard.gd`
*   **Trigger**: Clicking `[Play Together]` in Step 3.
*   **Flow**:
    ```gdscript
    func _on_multiplayer_selected() -> void:
        ParentGate.check(self, func():
            _start_multiplayer(true)
        )
    ```

### 3. Clear/Reset Progress Button
*   **File**: `scripts/settings_menu.gd`
*   **Trigger**: Pressing `[Reset All Scores/Learning Recaps]`.
*   **Flow**: Double-verify with a math challenge to avoid absolute data loss.

---

## 6. UX Polish & Refinement
*   **Failed Attempts**: If the child guesses wrong twice, the gate closes and returns them gracefully to the main menu without any loud buzzer sounds or negative prompts.
*   **Back/Cancel Routing**: Pressing the `Back` button (or `ui_cancel` action) instantly closes the gate and reverts focus to the calling button.
*   **OLED Dimmability**: Integrate with `OledIdleGuard` so if the parent gets distracted mid-gate, the screen safely dims.
