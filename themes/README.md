# Bludiste Theme Format

This directory contains the themes for the Bludiste app. The `default` theme acts as the fallback for any missing assets in other themes.

To create a new theme:
1. Create a new directory under `themes/` (e.g. `themes/my_theme/`)
2. Create a `manifest.json` file.
3. Provide replacement images for the ones you want to override (`player.png`, `start.png`, etc.)

## Manifest Format (`manifest.json`)

The manifest defines the basic metadata and colors for the theme.

### Required Fields
- `name` (string): The human-readable name of the theme (e.g., "The Default Theme").
- `author` (string): The creator of the theme.
- `color_floor` (string): The hex color for the maze floor/corridor (e.g., "#1A1C23").
- `color_wall` (string): The hex color for the maze walls (e.g., "#EEEEEE").

### Optional Fields
- `color_start` (string): Color for the start cell floor. If omitted, the app will generate a subtle tint from `color_floor`.
- `color_end` (string): Color for the end cell floor. If omitted, generates a subtle tint from `color_floor`.
- `color_wall_border` (string): If provided, draws a secondary color on the inside border of the walls. Usually semi-transparent (e.g., "#00000044").
- `bg_tiled` (boolean): If you provide a `bg.png`, this determines if the background should stretch to fit the screen (`false`) or tile infinitely (`true`). Default is `false`.

### Supported Images
Place any of these in your theme directory to override the defaults:
- `player.png`: The character/icon the player controls.
- `chaser.png`: The enemy/chaser character.
- `start.png`: An icon drawn on the start cell.
- `end.png`: An icon drawn on the goal cell.
- `bg.png`: An image drawn *behind* the corridors. If present, the `color_wall` rectangles are drawn over it to form the solid walls, but the floor is entirely transparent.
