# Painted Raised Maze Texture Contract

This is the generic texture contract for the fake 2.5D maze renderer.
It is theme-neutral: castle, candy, forest, sci-fi, road, ice, sewer, or any other theme should use the same structural files.

The maze is still a flat 2D grid. The raised look comes from layered art:

1. floor tiles
2. soft wall shadows
3. south/front faces below horizontal wall runs
4. top surfaces on all wall runs
5. compact end caps and junction overlays
6. optional floor/path decals such as lane markings
7. gameplay objects above the maze art

There is no isometric projection, no side wall on vertical walls, and no 3D mesh.

## Coordinate Model

Use these native metrics when authoring a theme:

- `cell_size`: native logical maze cell, recommended `128 px`
- `top_width`: wall-top thickness, recommended `20-28 px` at `128 px` cell size
- `front_depth`: visible south/front face depth, recommended `16-24 px`
- `shadow_depth`: soft shadow depth, recommended `6-12 px`
- `bleed`: transparent or painted overlap inside the declared canvas, recommended up to `4 px`

Godot scales every asset to the current runtime cell size, so files must stay readable when shrunk for dense mazes.
The canvas size of each PNG should match the size listed below; do not add extra outer pixels unless the renderer is changed to account for them.

## Required Compact Pack

The standard compact pack is `35` PNG files. More variants can be added later by listing them in the theme manifest, but this 35-file set is the target for adding a polished new theme without renderer code changes.

Themes may also provide combined horizontal wall textures where the horizontal top and the south/front face are one coherent PNG. This is recommended for stripe or panel themes such as racing barriers, candy stripes, pipes, conveyor belts, and any material where the top and face must share an exact rhythm.

### Floor

`floor_00.png`

- Opaque.
- Recommended size: `512x512`.
- Seamless tile or at least crop-safe.
- Lower contrast than walls and collectibles.
- Must not contain a cell-sized maze grid.

`floor_01.png`

- Required in the standard 35-file pack.
- Same size and palette as `floor_00.png`.
- Different stains/cracks/variation.
- Renderer can alternate floor tiles to reduce wallpaper repetition.

### Straight Wall Tops

`wall_top_h_00.png` through `wall_top_h_03.png`

- Transparent PNG.
- Recommended native size: `256 x top_width`.
- Tileable horizontally.
- Represents only the top surface of an east-west wall.
- North/top edge should be slightly highlighted.
- South/bottom edge should have a darker bevel that visually connects to `wall_face_h_*`.

`wall_top_v_00.png` through `wall_top_v_03.png`

- Transparent PNG.
- Recommended native size: `top_width x 256`.
- Tileable vertically.
- Same material, brush scale, bevel strength, and lighting as `wall_top_h_*`.
- Must not show a full side wall.

Matching rule:

- Horizontal and vertical top variants must look like the same material.
- Repetition should vary by block length, chips, cracks, stains, and value.
- Do not make each segment look like a single repeated square cell.

### South/Front Face

`wall_face_h_00.png` through `wall_face_h_03.png`

- Transparent PNG.
- Recommended native size: `256 x front_depth`.
- Tileable horizontally.
- Drawn only below horizontal wall runs.
- Must be darker than the wall top but clearly the same material.
- Its top edge must tuck directly under the south/bottom bevel of `wall_top_h_*`.

Matching rule:

- `wall_face_h_00` should share visual rhythm with `wall_top_h_00`, `wall_face_h_01` with `wall_top_h_01`, and so on.
- Seams do not have to align pixel-perfect for every stone, but the face must not feel like a different wallpaper.
- Vertical walls do not get front-face textures.

### Combined Horizontal Wall

`wall_h_combined_00.png` through `wall_h_combined_03.png`

- Optional but recommended for stripe/panel themes.
- Transparent PNG.
- Recommended native size: `256 x (top_width + front_depth)`.
- Contains the horizontal wall top and the south/front face as a single aligned piece.
- The upper part must match `wall_top_h_*`; the lower part must match `wall_face_h_*`.
- It must tile horizontally without red/white, stone, panel, stripe, or seam drift.
- It should include the top bevel, darker front face, lower rim, and baked material lighting.
- Do not bake the floor cast shadow here; use dedicated shadow assets or renderer shadows.

### Front-Face End And Corner Pieces

`wall_face_end_left_00.png`

- Transparent PNG.
- Recommended native size: `top_width x front_depth`.
- Finishes an exposed left end of a horizontal south/front face.
- Must not be a square block or a circular knob.
- Should look like the face material wraps or is carved at the end.

`wall_face_end_right_00.png`

- Same as left, mirrored logically but not necessarily identical.
- Finishes an exposed right end.

`wall_face_corner_left_00.png`

- Transparent PNG.
- Recommended native size: `top_width x front_depth`.
- Used when the left side of a horizontal front face meets a vertical wall.
- Should hide the chopped face seam and tuck under the junction.

`wall_face_corner_right_00.png`

- Same purpose for the right side of a horizontal front face.

Matching rule:

- Face end/corner pieces must use the same color range, seam scale, and lower rim as `wall_face_h_*`.
- They should be slightly shorter-looking than top/junction pieces, so the top reads as sitting above the face.

### Wall Top Dead-End Caps

`wall_top_end_left_00.png`

- Transparent PNG.
- Recommended native size: `top_width x top_width`.
- Finishes a horizontal wall that ends on the left.
- Shape should be carved/chipped, not a ball and not a square post.

`wall_top_end_right_00.png`

- Same for a horizontal wall ending on the right.

`wall_top_end_north_00.png`

- Transparent PNG.
- Recommended native size: `top_width x top_width`.
- Finishes a vertical wall ending upward/north.

`wall_top_end_south_00.png`

- Same for a vertical wall ending downward/south.

Matching rule:

- Top end caps must align with straight top textures at the exact same thickness.
- If a horizontal wall has a front face, the top cap and face cap should look like one finished wall end.

### Junction Overlays

All junctions use a 4-bit mask at grid vertices:

- north connection = `1`
- east connection = `2`
- south connection = `4`
- west connection = `8`

Use these filenames:

`wall_joint_mask_03.png`

- North + East L-corner.

`wall_joint_mask_06.png`

- East + South L-corner.

`wall_joint_mask_09.png`

- North + West L-corner.

`wall_joint_mask_12.png`

- South + West L-corner.

`wall_joint_mask_07.png`

- North + East + South T-junction.

`wall_joint_mask_11.png`

- North + East + West T-junction.

`wall_joint_mask_13.png`

- North + South + West T-junction.

`wall_joint_mask_14.png`

- East + South + West T-junction.

`wall_joint_mask_15.png`

- Cross junction.

Properties for all junction overlays:

- Transparent PNG.
- Recommended native size: `top_width x top_width`.
- Must cover seams between straight strips.
- Must not look like a pasted node, ball, or square pillar.
- Shape should follow only the connected wall arms.
- Missing quadrants should stay transparent for L-corners.
- T and X centers should be visually quiet, with no special button-like detail.

Important:

- Junction overlays are seam covers, not decorative posts.
- They should be very close in color/value to the straight wall top.
- A junction may include cracks or bevels, but those details must continue the wall material rather than announce a separate object.

### Shadows

`wall_shadow_h.png`

- Transparent PNG.
- Recommended native size: `256 x shadow_depth`.
- Soft horizontal shadow below south/front faces.
- Should fade down/out, not form a hard black bar.

`wall_shadow_h_end_left.png`

- Transparent PNG.
- Recommended native size: `top_width x shadow_depth`.
- Tapered left end of the horizontal shadow.

`wall_shadow_h_end_right.png`

- Transparent PNG.
- Recommended native size: `top_width x shadow_depth`.
- Tapered right end of the horizontal shadow.

`wall_shadow_v.png`

- Transparent PNG.
- Recommended native size: `shadow_depth x 256`.
- Very subtle vertical contact shadow.
- Should be weaker than `wall_shadow_h.png`.

Matching rule:

- Shadows must sit under walls, not compete with characters or collectibles.
- Shadow direction must match the wall bevel lighting.

### Optional Floor/Path Markings

Floor markings are renderer logic, not wall textures. A theme may enable them in the manifest when the floor represents a road, track, pipeline, conveyor route, river current, magic path, or similar directional surface.

Recommended manifest properties:

- `road_markings.enabled`: boolean
- `road_markings.color`: line color with alpha
- `road_markings.shadow_color`: subtle shadow/occlusion color with alpha
- `road_markings.dash_length_ratio`: dash length as a fraction of cell size
- `road_markings.width_ratio`: line width as a fraction of cell size

Generic drawing rule:

- Draw a horizontal dash inside cells that have horizontal openings and no vertical openings.
- Draw a vertical dash inside cells that have vertical openings and no horizontal openings.
- Draw no dash in corners, T-junctions, crosses, or fully closed cells.
- Keep dashes behind walls, collectibles, player, chaser, start, and finish.

This rule is reproducible in Godot from `MazeData` and works for any procedural maze theme.

## Manifest Example

```json
{
  "maze_rendering": {
    "wall_mode": "painted_raised_2d_assets",
    "top_width_ratio": 0.18,
    "front_depth_ratio": 0.16,
    "shadow_depth_ratio": 0.05,
    "assets": {
      "floor_tile": "maze/floor_00.png",
      "floor_tiles": [
        "maze/floor_00.png",
        "maze/floor_01.png"
      ],
      "wall_top_h_variants": [
        "maze/wall_top_h_00.png",
        "maze/wall_top_h_01.png",
        "maze/wall_top_h_02.png",
        "maze/wall_top_h_03.png"
      ],
      "wall_top_v_variants": [
        "maze/wall_top_v_00.png",
        "maze/wall_top_v_01.png",
        "maze/wall_top_v_02.png",
        "maze/wall_top_v_03.png"
      ],
      "wall_face_h_variants": [
        "maze/wall_face_h_00.png",
        "maze/wall_face_h_01.png",
        "maze/wall_face_h_02.png",
        "maze/wall_face_h_03.png"
      ],
      "wall_face_end_left_variants": ["maze/wall_face_end_left_00.png"],
      "wall_face_end_right_variants": ["maze/wall_face_end_right_00.png"],
      "wall_face_corner_left_variants": ["maze/wall_face_corner_left_00.png"],
      "wall_face_corner_right_variants": ["maze/wall_face_corner_right_00.png"],
      "wall_top_end_left_variants": ["maze/wall_top_end_left_00.png"],
      "wall_top_end_right_variants": ["maze/wall_top_end_right_00.png"],
      "wall_top_end_north_variants": ["maze/wall_top_end_north_00.png"],
      "wall_top_end_south_variants": ["maze/wall_top_end_south_00.png"],
      "wall_shadow_h": "maze/wall_shadow_h.png",
      "wall_shadow_h_end_left": "maze/wall_shadow_h_end_left.png",
      "wall_shadow_h_end_right": "maze/wall_shadow_h_end_right.png",
      "wall_shadow_v": "maze/wall_shadow_v.png",
      "wall_joints": {
        "3": "maze/wall_joint_mask_03.png",
        "6": "maze/wall_joint_mask_06.png",
        "7": "maze/wall_joint_mask_07.png",
        "9": "maze/wall_joint_mask_09.png",
        "11": "maze/wall_joint_mask_11.png",
        "12": "maze/wall_joint_mask_12.png",
        "13": "maze/wall_joint_mask_13.png",
        "14": "maze/wall_joint_mask_14.png",
        "15": "maze/wall_joint_mask_15.png"
      }
    }
  }
}
```

## Art Quality Rules

Use these checks for any new theme:

- The wall top and front face must feel like one material system.
- Long horizontal walls must not look like one stretched repeated stamp.
- Vertical walls must not grow side faces.
- Exposed ends must look finished, not sliced.
- L-corners must not become square pillars.
- T and X junctions must hide seams without becoming visible buttons.
- The floor should support the maze, not fight it.
- Tiny mazes and dense mazes must still read clearly.
- Details should soften or simplify naturally when scaled down.

## Test Maze Checklist

Before accepting a theme, screenshot mazes that include:

- long horizontal wall runs
- long vertical wall runs
- exposed horizontal ends
- exposed vertical ends
- all four L-corners
- all four T-junctions
- cross junction
- outer border
- dense zigzags
- smallest supported maze
- largest supported maze

Acceptance criteria:

- no ball joints
- no square post joints
- no chopped south/front face ends
- no visible gaps at corners
- no true isometric or 3D side walls
- characters and collectibles remain readable
- performance remains mobile-safe
