# Default Theme Manifest

This defines the rendering structure for the Bludiste theme.
To create a new theme:
1. Copy this folder.
2. Edit `manifest.json`.
3. Provide missing/replacement images as desired.

The manifest file format requires:
- `name`: string
- `author`: string
- `color_floor`: string (hex)
- `color_wall`: string (hex)

And optional features: `color_wall_border` (string hex), `bg_tiled` (bool), etc.
