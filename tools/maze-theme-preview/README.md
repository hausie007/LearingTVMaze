# Maze Theme Preview

Static browser fixture for iterating on fake raised-2D maze themes without launching Godot.

Run from the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

Open the Cars theme on the real Very Easy `5x4` footprint:

```text
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=cars&board=very_easy
```

Open the enlarged seam-inspection fixture:

```text
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=cars&board=all_masks&cell=96
```

The `theme` query parameter maps to `themes/<theme>/manifest.json`. The preview reads the same `maze_rendering.assets` keys used by `MazeWallPainter`, renders either a real Godot difficulty footprint or an enlarged all-mask inspection fixture, and shows swatches for all loaded maze textures.

Real Godot footprints:

- `very_easy`: `5x4`, suggested cell `128`
- `easy`: `7x6`, suggested cell `112`
- `medium`: `9x8`, suggested cell `96`
- `hard`: `13x10`, suggested cell `72`
- `very_hard`: `20x12`, suggested cell `56`
- `insane`: `26x13`, suggested cell `48`
- `unbelievable`: `36x15`, suggested cell `40`
- `all_masks`: compact enlarged seam-atlas board for checking all mask joins and pixel alignment, suggested cell `96`

The fixture includes:

- dead ends: masks `1`, `2`, `4`, `8`
- straight runs: masks `5`, `10`
- L corners: masks `3`, `6`, `9`, `12`
- T junctions: masks `7`, `11`, `13`, `14`
- cross junction: mask `15`
- exposed horizontal front-face ends
- connected horizontal front-face corners
- player, chaser, finish, and collectible contrast checks when the theme provides those sprites
