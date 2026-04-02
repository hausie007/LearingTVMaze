# Bludiste (Learning Maze)

A kid-friendly, theme-aware maze game built in Godot 4, targeting Android and Google TV devices.

## Architecture Overview

The app follows a component-based orchestrator pattern with strong separation of data and presentation.

### Core Autoloads

- **`Config` (GameConfig)**: Stores global settings, game parameters (grid size calculation based on difficulty), and references to the active theme. State is persisted to `user://settings.cfg`.
- **`TTS` (TTSManager)**: A background-threaded text-to-speech manager responsible for voice scanning, caching, and handling async speech requests without blocking the main game loop.

### Main Game Components

- **`GameManager`**: The top-level orchestrator. It receives state/events from children and coordinates game progression. It does no rendering or generation itself.
- **`MazeData`**: The data layer representing the maze (paths, walls, start/end).
- **`MazeGenerator`**: Creates the `MazeData`. Uses iterative DFS for path carving.
- **`MazeRenderer`**: Draws the `MazeData` using a shared `MazeCellDrawer` utility and the currently loaded theme.
- **`Player`**: Handles movement and input.
- **`CollectibleSpawner`**: Spawns numbers/letters/words into the maze and handles collection logic.
- **`ChaserManager`**: Manages the "enemy" AI that chases the player on higher difficulties.
- **`WinScreen` / `PauseDialog` / `GameHUD`**: UI components that communicate via signals.

### UI & Styling

The app targets TV environments, meaning D-pad navigation and explicit focus management are critical. `UIHelpers` and `UIColors` centralize styling so buttons and panels look consistent without scattering manual StyleBox overrides across scenes.

## Theming

Themes are fully declarative and swap colors, backgrounds, and sprites. See `themes/README.md` for information on the `manifest.json` format.

## Platform Target Notes (Google TV)

- **Focus**: Every UI transition (closing dialogs, returning to menus) must end with an explicit `grab_focus()` on the main interactive element.
- **Blocking**: Long operations (like TTS voice scanning) must yield to the engine via `await` to prevent Android from showing the "App isn't responding" (ANR) dialog.
- **Inputs**: `ui_cancel` (the back button) explicitly closes dialogs or backs out of menus. `ui_accept` confirms. Avoid using `_input` to universally swallow D-pad events; rely on Godot's built-in focus system when possible.
