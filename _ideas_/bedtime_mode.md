# Feature Specification: Bedtime Mode (Screen-Time Limits)

## 1. Description & Context
Managing screen-time is one of the most common friction points for parents of young kids. Traditional screen limit overlays are harsh, dry, and clinical—often triggering tantrums when the screen suddenly locks.

**Bedtime Mode** introduces a gamified, gentle, and child-safe wind-down mechanism. Instead of a abrupt "game over" screen, the characters in the maze act as proxies for the child. As the session limit approaches, characters get visibly sleepy, yawn, and eventually head to bed. This visual cue teaches children empathy and screen boundaries organically, helping them transition away from the device without tears.

---

## 2. Goals & Success Criteria
*   **Empathetic Screen-Time Limits**: Shift limits from a negative restriction ("you are locked out") to a natural, positive transition ("the characters are tired and need to sleep").
*   **No Tantrums**: Give children a gradual 2-minute visual and narrative warning so they are psychologically prepared for the end of the session.
*   **Fully Configurable**: Protected by the **Parent Gate**, allowing parents to choose limits (e.g., 15, 30, 45, 60 mins) or disable it completely.
*   **Performance Safe**: Ensure the transition animations use simple sprites and flat vector overlays that do not strain low-power Android TV CPUs.

---

## 3. The Wind-Down Flow

```
[ Active Play ]
       │  (Timer reaches Last 2 Minutes)
       ▼
[ Yawn & HUD Warning Phase ]
  - Character pauses briefly and plays a sleepy "yawn" balloon
  - Gentle moon & stars icon appears on top corner of the HUD
  - Music tempo slows down slightly (lower pitch/calmer mix)
       │  (Timer reaches 0:00 - End of current level)
       ▼
[ Yawn Transition ]
  - Complete level and transition to Cozy Bedroom instead of next level
       │
       ▼
[ Cozy Bedroom Screen (Soft Lock) ]
  - Dynamic screen-dimming
  - Soft lullaby soundtrack
  - Visual of character sleeping in a sleeping bag or bed
  - Localized prompt: "Time for a rest! The maze will wake up tomorrow."
```

### Stage A: Dynamic HUD Yawn Warning (2 Minutes Remaining)
*   When the session limit is close, a gentle, semi-transparent crescent moon and stars icon slowly fades into the corner of the in-game HUD.
*   The player character occasionally stops for `0.8` seconds, playing a micro-animation of stretching or yawning, with a little speech bubble containing `Zzz...` or a sleeping emoji (`😴`).

### Stage B: Cozy Bedroom Soft Lock (Time Expired)
*   Once the current level ends (or immediately if time runs out and no levels are active), the game loads `bedtime_screen.tscn`.
*   A beautifully illustrated, low-lit cozy room is displayed.
*   The active character is animated sleeping soundly.
*   All gameplay controls are disabled. The only active key is **Back** (which exits the app) or **OK** (which brings up the Parent Gate if a parent wants to extend the time).

---

## 4. Proposed Implementation Architecture

### Configuration Variables (`game_config.gd`)
We store Bedtime Mode configuration variables in the persistent config singleton:
```gdscript
# Inside scripts/game_config.gd
var bedtime_enabled: bool = false
var bedtime_limit_minutes: int = 30 # Options: 15, 30, 45, 60
var bedtime_session_start_time: int = 0
```

### Bedtime Manager Autoload (`bedtime_manager.gd`)
A lightweight, background autoload that tracks real playtime without blocking game rendering loops:
```gdscript
# Inside scripts/bedtime_manager.gd
extends Node

signal limit_warning_started # 2 minutes left
signal limit_expired         # Time is up!

var _play_timer: float = 0.0
var _warning_triggered: bool = false

func start_session(minutes: int) -> void:
    _play_timer = minutes * 60.0
    _warning_triggered = false
    set_process(true)

func _process(delta: float) -> void:
    if _play_timer <= 0.0:
        return
        
    _play_timer -= delta
    
    # 2-minute warning
    if _play_timer <= 120.0 and not _warning_triggered:
        _warning_triggered = true
        limit_warning_started.emit()
        
    # Timeout
    if _play_timer <= 0.0:
        set_process(false)
        limit_expired.emit()
```

---

## 5. UI & Layout Mockup: Cozy Bedroom Scene
The bedroom screen uses vector circles and smooth flat background coloring to maintain a premium look without high-performance assets:

```
┌───────────────────────────────────────────────────────────┐
│                                                           │
│                 [ Crescent Moon & Stars ]                 │
│                                                           │
│                                                           │
│                       [Character]                         │
│                        sleeping                           │
│                        "Zzz..."                           │
│                                                           │
│              "Time for a rest, little explorer!           │
│             Our characters are sleeping soundly.          │
│               The maze will wake up tomorrow!             │
│                            😴"                            │
│                                                           │
│    [ Exit App (Back) ]                 [ Parent Gate (OK) ]│
└───────────────────────────────────────────────────────────┘
```

---

## 6. Key UX Polish Details
*   **Graceful Game Completion**: If the countdown expires *during* a maze, we do not abruptly close the maze. Instead, we let the child finish their current maze, reach the exit, and then substitute the victory screen with the Cozy Bedroom scene. This avoids frustrating the child at the finish line!
*   **Gentle Lullaby Audio**: Swap the standard energetic theme tracks for a soft, synthesized lullaby arrangement at 60 BPM to lower the child's heart rate and prepare them for bedtime.
*   **TV Friendly**: The Cozy Bedroom screen naturally supports `OledIdleGuard` to slowly pulse the moon visual and prevent screen damage if the television is left active overnight.
