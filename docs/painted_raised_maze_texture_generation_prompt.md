# Painted Raised Maze Texture Generation Prompt

Use this prompt template with an image-generation LLM to create a complete texture pack for a painted raised 2D maze theme.
Fill in the placeholders before generating.

## Fill-In Values

- `THEME_NAME`: example `medieval castle`, `candy factory`, `forest ruins`, `space station`, `pirate island`.
- `MATERIAL`: example `light gray stone blocks`, `red plastic racing barriers`, `mossy wood`, `brushed metal`.
- `FLOOR_MATERIAL`: example `dark cobblestone`, `asphalt`, `grass and dirt`, `metal deck plates`.
- `STYLE`: example `hand-painted mobile game`, `soft cartoon fantasy`, `clean toy-like 3D painted`, `pixel-art inspired but high resolution`.
- `PALETTE`: short color direction.
- `NATIVE_CELL_SIZE`: recommended `128`.
- `TOP_WIDTH_PX`: recommended `24` when `NATIVE_CELL_SIZE=128`.
- `FRONT_DEPTH_PX`: recommended `20` when `NATIVE_CELL_SIZE=128`.
- `SHADOW_DEPTH_PX`: recommended `8` when `NATIVE_CELL_SIZE=128`.
- `OUTPUT_FORMAT`: recommended `transparent PNG` for wall parts and `opaque PNG` for floor tiles.

## Master Prompt

```text
Create a complete seamless texture pack for a top-down painted raised 2D maze game.

Theme: {{THEME_NAME}}
Primary wall material: {{MATERIAL}}
Floor/path material: {{FLOOR_MATERIAL}}
Art style: {{STYLE}}
Palette: {{PALETTE}}

The maze is NOT isometric and NOT 3D. It is a top-down grid maze with a painted height illusion:
- wall tops are visible on all horizontal and vertical walls
- only horizontal walls have a darker south/front face hanging downward
- vertical walls do not show true side walls
- corners and junctions must connect seamlessly without round balls, square blocks, or obvious pasted nodes

Native scale:
- one logical maze cell is {{NATIVE_CELL_SIZE}}x{{NATIVE_CELL_SIZE}} px
- wall top thickness is {{TOP_WIDTH_PX}} px
- south/front face depth is {{FRONT_DEPTH_PX}} px
- shadow depth is {{SHADOW_DEPTH_PX}} px
- use the exact canvas sizes listed below; transparent pixels may exist inside that canvas, but do not add extra outer pixels

Lighting:
- consistent top-left light direction
- wall top has a soft highlight on the north/top edge
- wall top has subtle darker bevel on the south/bottom edge
- south/front face is darker than the top and aligns visually with it
- shadows are soft, transparent, and low contrast

Texture cohesion:
- every wall top, face, cap, corner, and junction must look like the same material
- block seams, cracks, chips, stains, and brush detail must use the same scale across all assets
- avoid high-contrast repeated marks that create wallpaper patterns
- generate multiple variants so large mazes do not look repetitive

If the theme uses stripes, panels, repeating color bands, or any material rhythm that must continue from the top surface into the south/front face, also generate optional combined horizontal wall textures. These combine the horizontal top and the south/front face into one PNG so the renderer can draw them as a single aligned object.

Output the complete standard compact pack as 35 separate files using the names and specs below.
Use {{OUTPUT_FORMAT}}.
Do not include text, UI labels, characters, collectibles, start markers, or finish markers in these textures.
Do not add a background to transparent assets.
```

## Asset List To Generate

### Floor

```text
floor_00.png
Size: 512x512 px
Background: opaque
Description: seamless tile of {{FLOOR_MATERIAL}} for the maze floor. Lower contrast than the walls. Subtle variation, no strong cell-sized grid, no obvious repeated symbol.

floor_01.png
Size: 512x512 px
Background: opaque
Description: alternate seamless floor tile with same material and palette, different cracks/stains/variation.
```

### Horizontal Wall Tops

```text
wall_top_h_00.png through wall_top_h_03.png
Size: 256x{{TOP_WIDTH_PX}} px
Background: transparent
Description: horizontal wall top strip, tileable left-to-right. Same {{MATERIAL}}, hand-painted, varied blocks/chips/cracks. North/top edge slightly highlighted, south/bottom edge slightly darker. Ends should tile invisibly.
```

### Vertical Wall Tops

```text
wall_top_v_00.png through wall_top_v_03.png
Size: {{TOP_WIDTH_PX}}x256 px
Background: transparent
Description: vertical wall top strip, tileable top-to-bottom. Same material and lighting as horizontal top. No visible side wall. Ends should tile invisibly.
```

### South/Front Wall Faces

```text
wall_face_h_00.png through wall_face_h_03.png
Size: 256x{{FRONT_DEPTH_PX}} px
Background: transparent
Description: darker south/front face for horizontal walls only. The top edge must align under wall_top_h. Include matching seams and material detail, but darker and less highlighted. Bottom edge can have a soft darker rim.
```

### Optional Combined Horizontal Walls

```text
wall_h_combined_00.png through wall_h_combined_03.png
Size: 256x({{TOP_WIDTH_PX}} + {{FRONT_DEPTH_PX}}) px
Background: transparent
Description: one coherent horizontal wall asset containing both the top surface and the south/front face. The top and face must share matching seams, stripes, panels, highlights, and material rhythm. Use this for themes where separate top and face files would visibly drift. Do not bake floor shadows into this file.
```

### Horizontal Face End Caps

```text
wall_face_end_left_00.png
Size: {{TOP_WIDTH_PX}}x{{FRONT_DEPTH_PX}} px
Background: transparent
Description: left exposed end of the south/front face. Slight rounded/chipped outside profile. Same dark face material. Must not look like a square block or circular knob.

wall_face_end_right_00.png
Size: {{TOP_WIDTH_PX}}x{{FRONT_DEPTH_PX}} px
Background: transparent
Description: right exposed end of the south/front face. Mirror-compatible with left end, but not an exact repeated copy. Slight rounded/chipped profile.
```

### Horizontal Top End Caps

```text
wall_top_end_left_00.png
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: exposed left end of a horizontal wall top. Slightly rounded/chipped silhouette, same top material, no oversized cap.

wall_top_end_right_00.png
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: exposed right end of a horizontal wall top. Slightly rounded/chipped silhouette, same top material, no oversized cap.
```

### Vertical Top End Caps

```text
wall_top_end_north_00.png
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: exposed north/top end of a vertical wall top. Slightly rounded/chipped silhouette, same material.

wall_top_end_south_00.png
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: exposed south/bottom end of a vertical wall top. Slightly rounded/chipped silhouette, same material.
```

### L-Corners

Use the 4-bit connection mask:

- North = 1
- East = 2
- South = 4
- West = 8

```text
wall_joint_mask_03.png  # North + East
wall_joint_mask_06.png  # East + South
wall_joint_mask_09.png  # North + West
wall_joint_mask_12.png  # South + West
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: compact L-corner top overlay. Must connect wall top strips seamlessly. No square post, no ball, no oversized knob. Include subtle bevel and cracks matching straight walls.
```

### T-Junctions

```text
wall_joint_mask_07.png   # North + East + South
wall_joint_mask_11.png   # North + East + West
wall_joint_mask_13.png   # North + South + West
wall_joint_mask_14.png   # East + South + West
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: compact T-junction top overlay. Must look like one continuous material, not stacked strips. Keep the same wall width.
```

### Cross Junction

```text
wall_joint_mask_15.png
Size: {{TOP_WIDTH_PX}}x{{TOP_WIDTH_PX}} px
Background: transparent
Description: compact cross junction top overlay. Quiet center, seamless connection in all four directions, no large square block.
```

### Front-Face Corner Returns

```text
wall_face_corner_left_00.png
Size: {{TOP_WIDTH_PX}}x{{FRONT_DEPTH_PX}} px
Background: transparent
Description: short dark face return used where a horizontal front face starts beside a vertical wall. It visually tucks the face under the corner.

wall_face_corner_right_00.png
Size: {{TOP_WIDTH_PX}}x{{FRONT_DEPTH_PX}} px
Background: transparent
Description: short dark face return used where a horizontal front face ends beside a vertical wall. Same material as wall_face_h.
```

### Shadows

```text
wall_shadow_h.png
Size: 256x{{SHADOW_DEPTH_PX}} px
Background: transparent
Description: soft horizontal contact/drop shadow below south/front wall faces. Transparent gradient, no hard black rectangle.

wall_shadow_v.png
Size: {{SHADOW_DEPTH_PX}}x256 px
Background: transparent
Description: very subtle vertical contact shadow. Softer and less visible than horizontal shadow.

wall_shadow_h_end_left.png
wall_shadow_h_end_right.png
Size: {{TOP_WIDTH_PX}}x{{SHADOW_DEPTH_PX}} px
Background: transparent
Description: tapered ends for the horizontal shadow so short wall faces do not end with a rectangular shadow cut.
```

### Optional Decals

```text
wall_decal_crack_00.png through wall_decal_crack_15.png
Size: variable, max 64x64 px
Background: transparent
Description: small cracks/chips/stains matching {{MATERIAL}}. Low contrast. Usable on wall tops and faces.

floor_decal_00.png through floor_decal_15.png
Size: variable, max 96x96 px
Background: transparent
Description: subtle floor variation matching {{FLOOR_MATERIAL}}. Should not obscure collectibles or characters.
```

### Optional Renderer Floor Markings

Use renderer-side markings instead of PNG decals when the floor needs directional lane marks, trail marks, current marks, conveyor arrows, or similar procedural path details.

```text
road_markings.enabled: true or false
road_markings.color: semi-transparent marking color
road_markings.shadow_color: very subtle shadow/occlusion color
road_markings.dash_length_ratio: dash length as fraction of maze cell size
road_markings.width_ratio: line width as fraction of maze cell size
Rule: draw markings only in cells whose open passages are straight in one axis. Draw horizontal marks in cells with horizontal openings and no vertical openings. Draw vertical marks in cells with vertical openings and no horizontal openings. Draw nothing in corners, T-junctions, crosses, or closed cells.
```

## Negative Prompt

```text
Do not create isometric perspective.
Do not create 3D side walls.
Do not create spherical connector balls.
Do not create oversized square posts at corners.
Do not create UI elements, text, numbers, arrows, characters, collectible icons, start signs, or finish signs.
Do not use strong repeated symbols.
Do not use inconsistent lighting between assets.
Do not put shadows or backgrounds into transparent wall assets except the dedicated shadow files.
Do not crop painted edges tightly; keep transparent bleed.
Do not bake procedural road/lane/path markings into floor tiles when they need to follow the generated maze topology.
```

## Follow-Up Prompt For Consistency Fixes

Use this after the first generated batch if assets do not align:

```text
Revise the texture pack for consistency.
Keep the same {{THEME_NAME}} theme, {{MATERIAL}} wall material, {{FLOOR_MATERIAL}} floor material, {{STYLE}} style, and {{PALETTE}} palette.

Fix these issues:
- wall top and south/front face must share matching material scale and seam rhythm
- horizontal face end caps must align exactly with wall_face_h height
- top end caps must align exactly with wall_top_h and wall_top_v thickness
- corner and junction overlays must be compact and seamless, not square posts
- all transparent assets must include 4 px bleed
- all lighting must come from the same top-left direction

Return the complete corrected asset set with the same filenames.
```
