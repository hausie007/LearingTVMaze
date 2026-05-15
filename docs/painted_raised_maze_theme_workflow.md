# Painted Raised Maze Theme Workflow

This document captures the practical lessons from building the castle and cars fake 2.5D maze themes.
Use it when making a new theme for the same renderer.

It is not the raw asset contract. For exact file names and dimensions, see:

- `docs/painted_raised_maze_texture_requirements.md`
- `docs/painted_raised_maze_texture_generation_prompt.md`
- `tools/maze-theme-preview/README.md`

## Core Mental Model

The maze is still a flat 2D grid. The renderer draws a painted illusion:

1. floor
2. optional floor markings/decals
3. wall shadows
4. south/front faces under horizontal walls
5. wall tops on all horizontal and vertical walls
6. caps and junction overlays
7. start/end/collectibles/characters

Do not design it like isometric art. There are no true side walls. Vertical walls only show their top surface. Horizontal walls can show a darker south/front face. Corners and junctions are seam covers that make straight strips look connected.

The best themes feel like one continuous hand-painted material that happens to follow the maze graph. The worst themes look like repeated rectangles with decorative blocks pasted on the joints.

## Recommended Production Strategy

Do not start in Godot. Generate a theme pack, wire it into `manifest.json`, then iterate in the static previewer.

Recommended loop:

1. Pick the theme material and floor material.
2. Define the wall metrics in the manifest.
3. Generate or draw the floor, straight wall, face, end, junction, and shadow assets.
4. Open the previewer on `all_masks`.
5. Fix all seams, endpoints, caps, and junctions.
6. Open real difficulty footprints from `very_easy` through `unbelievable`.
7. Add/adjust player, chaser, collectible, start, and finish sprites.
8. Only then check in Godot.

The previewer is much faster for art iteration because it renders the exact same manifest-driven maze assets without launching the whole game.

Useful preview URLs:

```text
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=<theme>&board=all_masks&cell=96&labels=0&swatches=1
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=<theme>&board=very_easy&cell=128&labels=0&swatches=1
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=<theme>&board=hard&labels=0&swatches=1
http://127.0.0.1:8765/tools/maze-theme-preview/?theme=<theme>&board=unbelievable&labels=0&swatches=0
```

## Theme Directory Shape

A theme should live under:

```text
themes/<theme>/
  manifest.json
  player_1.png or player_1_readable.png
  chaser_1.png
  start.png
  end.png
  collectible_<name>.png
  maze/
    floor_00.png
    floor_01.png
    wall_h_combined_00.png
    ...
```

The renderer can keep old themes using simple colors, but polished raised themes should use:

```json
"maze_rendering": {
  "wall_mode": "painted_raised_2d_assets",
  "top_width_ratio": 0.24,
  "front_depth_ratio": 0.12,
  "shadow_depth_ratio": 0.055,
  "node_scale_ratio": 0.245,
  "assets": {}
}
```

Good starting ratios:

- `top_width_ratio`: `0.22` to `0.28`
- `front_depth_ratio`: `0.10` to `0.16`
- `shadow_depth_ratio`: `0.04` to `0.08`
- `node_scale_ratio`: usually close to the top width, `0.22` to `0.28`

If walls feel too thin, increase `top_width_ratio`. If the fake height feels weak, increase `front_depth_ratio` slightly. If corners look like plugs or buttons, reduce `node_scale_ratio` or redraw the junction masks so they follow the wall arms more closely.

## Wall Art Lessons

### Generate The Horizontal Wall As One Object When Needed

For materials with strong rhythm, stripes, panels, bricks, pipes, rails, or colored bands, use `wall_h_combined_*`.

This was essential for the cars theme. Separate top and front-face textures made the red/cream rhythm drift, so the wall looked assembled from unrelated wallpapers. A combined horizontal wall keeps the top and south face aligned in one PNG.

Use combined horizontal walls when:

- the top and front face share stripes or panel seams
- the face must inherit exact colors from the top
- a visible bevel crosses from top into face
- the theme has repeated color blocks

Separate `wall_top_h_*` and `wall_face_h_*` are still useful for fallback, swatches, or themes where exact seam continuation is less critical.

### Do Not Make Junctions Decorative

Junctions are not pillars. They are seam-hiding overlays.

Avoid:

- balls on every corner
- square posts
- large caps centered on intersections
- special symbols or high-contrast center details
- visible stacked straight strips

Aim for:

- the same material as straight walls
- same thickness as wall tops
- quiet center
- curved or molded transitions for L-corners
- T and X shapes that look like one continuous piece

For a racing barrier, an L-corner should look like a molded barrier bend. For stone, it should look like stones arranged around the bend, not a corner column unless the entire style is explicitly built around columns.

### End Caps Must Be Short

End caps can ruin the whole theme if they protrude too far. They should finish the wall, not announce themselves.

Good end caps:

- extend only a few pixels beyond the logical wall end
- match the wall thickness
- have rounded/chipped/tapered outside shape
- share the same bevel and color range as the straight wall
- align with the front-face end if the wall is horizontal

Bad end caps:

- capsule tips that stick out far from the wall
- square blocks
- circular knobs
- a lower shadow/face nub that extends past the top cap

For the cars theme, the successful fix was to shorten the cap mask and shrink the face-end/shadow pieces so the top, face, and shadow all ended at roughly the same visual contour.

### South/Front Faces Should Be Clearly Connected To Tops

The south/front face must read as the darker hanging face of the same wall top.

Rules:

- draw faces only under horizontal walls
- make the face darker and quieter than the top
- keep its top edge tucked under the bottom bevel of the top
- match seams, stripes, block scale, cracks, and colors
- finish face ends with small matching end pieces
- use soft shadow below the face, not a hard black rectangle

If the face looks like a different material, regenerate it from the same source palette or combine it with the top in `wall_h_combined_*`.

## Floor Art Lessons

The floor must support readability. It should not compete with walls, collectibles, or characters.

Good floor texture:

- lower contrast than walls
- no cell-sized grid
- no strong repeated symbol
- no directional scratches unless they are intentional gameplay markings
- enough noise/variation to avoid flat color
- dark enough or light enough to contrast with the theme collectible

For the cars theme, long faint horizontal strokes looked like accidental scratches. Those were removed from the tile. Road lane dashes are drawn separately by renderer logic, which is better because procedural markings can follow maze corridors and skip intersections.

If a theme needs path markings, prefer renderer-side markings when they depend on maze topology:

- racing lane dashes
- conveyor arrows
- river/current marks
- footprints or trail strokes on straight corridors

Only draw them in straight cells. Skip corners, T-junctions, crosses, and blocked cells.

## Collectible Sprite Lessons

Collectibles must not contain baked letters or numbers.

Godot draws letters/numbers on top of the collectible sprite. The sprite must be a clean icon with a label-safe center.

Good collectible:

- transparent PNG
- strong silhouette at small sizes
- high contrast against the floor
- simple center area for overlaid label
- no baked text
- no tiny details behind the label
- no pedestal or UI badge unless the theme really needs it

For the cars theme, the multi-wheel stack was too busy. The better version is a single racing wheel with:

- bright outer glow/rim for separation from asphalt
- dark simple center for white label text
- circular silhouette
- no stand
- no baked number

When designing a collectible for a new theme, test labels `1`, `2`, `3`, `A`, `B`, and `C` in the previewer. Digits and letters have different shapes, and `A`/`B` often reveal clutter that numbers hide.

## Character Sprite Lessons

Character sprites should be cutouts, not copied with their original ground patch.

Good player/chaser sprites:

- transparent background
- no pasted road, grass, shadow rectangle, or unrelated floor
- soft local contact shadow only if needed
- readable at real cell sizes
- not hidden behind walls
- palette separated from both floor and walls

For the cars player, the source image had a gray road patch under the car. It had to be alpha-cleaned so only the car remained, plus a small contact shadow. Do this before judging wall or floor contrast, because pasted source backgrounds make the theme look broken even when the maze textures are fine.

## Variant Strategy

A polished theme needs variation, but not chaos.

Use variants for:

- straight horizontal wall tops
- straight vertical wall tops
- horizontal front faces
- combined horizontal walls
- floor tiles
- optional red/cream, light/dark, or material-color junction variants

Do not create variation by changing the core geometry. All variants of one asset family must have the same:

- canvas size
- visible thickness
- edge alignment
- alpha footprint
- lighting direction
- material scale

Variation should come from:

- small cracks
- chips
- stains
- block seam offsets
- soft color/value changes
- subtle brush texture

Avoid:

- one variant with a much wider wall
- one variant with a different bevel direction
- repeated high-contrast marks
- random scratches that create visible stripes when tiled

## Manifest Wiring Checklist

For a new raised theme, check these manifest sections:

```json
"assets": {
  "player": "player_1_readable.png",
  "start": "start.png",
  "end": "end.png",
  "chaser": "chaser_1.png",
  "collectible": "collectible_<name>.png"
}
```

```json
"collectible": {
  "image": "collectible_<name>.png",
  "fps": 1,
  "frames": ["collectible_<name>.png"],
  "text-color": "#FFFFFF"
}
```

```json
"maze_rendering": {
  "wall_mode": "painted_raised_2d_assets",
  "top_width_ratio": 0.24,
  "front_depth_ratio": 0.12,
  "shadow_depth_ratio": 0.055,
  "node_scale_ratio": 0.245,
  "assets": {
    "floor_tiles": ["maze/floor_00.png", "maze/floor_01.png"],
    "wall_h_combined_variants": [],
    "wall_top_h_variants": [],
    "wall_top_v_variants": [],
    "wall_face_h_variants": [],
    "wall_joints": {}
  }
}
```

If the theme has procedural floor markings, add:

```json
"road_markings": {
  "enabled": true,
  "color": "#FFFFFF58",
  "shadow_color": "#0000002E",
  "dash_length_ratio": 0.38,
  "width_ratio": 0.026
}
```

The `road_markings` name is historical. The same renderer-side idea can be reused for other straight-corridor markings if the art direction supports it.

## Preview Review Checklist

Use `all_masks` first. It must answer:

- Are all four dead-end directions clean?
- Are horizontal face ends aligned with top ends?
- Are L-corners rounded/connected without looking like posts?
- Are all four T-junction orientations seamless?
- Does the X-junction stay quiet?
- Do vertical walls avoid fake side walls?
- Are shadows soft and not doubled at junctions?
- Do swatches reveal mismatched colors between top and face?

Then use real footprints:

- `very_easy`: checks large sprites, large walls, and obvious seam issues
- `medium` or `hard`: checks normal gameplay density
- `unbelievable`: checks tiny scaled assets and repetition

Important visual checks:

- Does the maze read as raised but still top-down?
- Does the wall material look continuous, not tiled cell-by-cell?
- Are corridors too cluttered?
- Are collectibles readable over the floor?
- Do characters sit on the floor, not on their old source background?
- Do floor markings skip intersections?
- Does the finish/start art remain visible near border walls?

## Quality Bar

A theme is ready when:

- the wall top and south/front face feel like one material
- corners, T-junctions, and X-junctions do not show pasted nodes
- end caps are short and natural
- floor texture is calm under gameplay objects
- collectible sprite has no baked text and supports overlay labels
- player/chaser cutouts have no source-background residue
- all real maze sizes are acceptable
- the all-mask fixture shows no gaps or obvious misalignment

If something looks wrong, fix the generator/source asset rather than hand-painting one exported PNG. Repeatable generation makes later themes and small corrections much cheaper.

## Common Failure Modes

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| Corners look like balls | Junction overlays are decorative instead of structural | Redraw junction masks to follow connected arms only |
| Corners look square | Junction radius too small or straight strips overlap visibly | Increase outer curve, soften inner transition, keep footprint compact |
| Horizontal wall looks mismatched | Top and face generated separately with different rhythm | Use `wall_h_combined_*` or regenerate top/face from same source |
| End tips stick out | End cap mask protrudes too far | Shorten cap, align face/shadow ends to same contour |
| Floor looks scratched | Tile contains directional high-contrast strokes | Remove directional marks from floor; use renderer markings |
| Collectible label is hard to read | Icon center is busy or too bright | Simplify center, choose label text color, add rim/glow outside label area |
| Sprite looks pasted in | Source sprite includes floor/shadow patch | Alpha-clean source and add only a soft local contact shadow |
| Large mazes look like wallpaper | Too few variants or repeated strong marks | Add variants with subtle variation; remove high-contrast repeated details |
| Dense mazes look muddy | Details too fine or contrast too low when scaled down | Increase silhouette contrast, simplify micro-detail |

## Practical New Theme Recipe

1. Copy the Cars theme structure into `themes/<new_theme>`.
2. Replace title, character sprites, collectible, and wall/floor asset names.
3. Create a deterministic generator script under `tools/maze-theme-preview/generate_<theme>_assets.py`.
4. Generate floor tiles first and inspect them alone.
5. Generate one combined horizontal wall and one vertical wall top.
6. Preview `all_masks` even before all variants exist.
7. Fix wall thickness, face depth, shadow depth, and cap protrusion.
8. Add L/T/X junction variants.
9. Add straight variants only after the base geometry is correct.
10. Add collectible and character sprites last.
11. Run `all_masks`, `very_easy`, `hard`, and `unbelievable`.
12. If the theme still reads well at all four sizes, test in Godot.

The main lesson: the hard part is not 3D math. The hard part is making many small 2D pieces behave like one continuous painted object.
