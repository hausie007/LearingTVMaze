# Feature Specification: Theme Color Contrast & TV Legibility Upgrades

## 1. Description & Context
Budget televisions, old projector units, and Chromecast devices frequently suffer from **color-crushing** (where dark gray, navy, and dark purple shades merge into pure black) and low visual sharpness. 

Because **Learning Maze (Bludiste)** utilizes dynamic, procedural 2D visual themes (e.g. *Scary*, *Thiefs*, *Castle*), a lack of luminance separation can make the maze borders, player characters, and collectible targets completely invisible to children playing on uncalibrated TV screens.

This document details the visual guidelines, exact color adjustments, and programmatic changes required to guarantee **Grade-A visibility** across all 7 game themes on low-power devices without sacrificing our premium storybook visual identity.

---

## 2. Core Aesthetic & Technical Principles

*   **No Shader Overhead**: Low-power Chromecast and Android TV chips cannot render real-time post-processing shaders, heavy glowing lights, or complex particle systems. All contrast improvements must be achieved purely through **texture adjustments, stylebox outlines, and dynamic base color overrides** in GDScript.
*   **Dual-Tone Outlines**: Every maze wall must use a high-contrast dual-tone design: a dark structural core paired with a bright, crisp exterior border (at least 3–4 pixels wide).
*   **Luminance Separation**: Maintain at least a 40% luminance difference between the path/floor tiles, the maze walls, and the active characters.
*   **Vector Styleboxes**: Rely on flat vector drawing (`StyleBoxFlat`) for borders and buttons to minimize GPU draw calls and texture lookups.

---

## 3. Theme-by-Theme Contrast Audit & Action Plan

### Theme 1: Default (Storybook Paper)
*   **Visual Profile**: Light cream/off-white floor tiles with crisp dark ink outlines.
*   **Legibility Rating**: **A** (Perfect contrast).
*   **Action Plan**: Keep as the design baseline. No changes needed.

### Theme 2: Scary (Electric Purple)
*   **Visual Profile**: Dark purple walls, eerie deep green floor paths, and purple outlines.
*   **Legibility Rating**: **C-** (Poor contrast; walls and character sprites blend into black).
*   **Action Plan**:
    *   Increase the electric-purple wall border color luminosity by **20%** (e.g. shift from `#4A154B` to `#8F2B91`).
    *   Brighten the deep green floor path tile texture highlights by **15%**.
    *   Programmatically add a thin, 2px off-white glow outline behind the player character sprite to separate it from dark purple tiles.

### Theme 3: Castle (Medieval Stones)
*   **Visual Profile**: Stone grays, royal red flags, shield icons.
*   **Legibility Rating**: **B** (Stone textures crush in tight corridors).
*   **Action Plan**:
    *   Brighten stone wall margins with crisp, light-gray outlines (`#8E9AA6`).
    *   Slightly increase the contrast of flag borders to make targets pop.

### Theme 4: Ducks (Rubber Pond)
*   **Visual Profile**: Vibrant pond blues, yellow duck character, water details.
*   **Legibility Rating**: **A+** (Exceptional contrast; yellow elements stand out perfectly).
*   **Action Plan**: Maintain intact.

### Theme 5: Cars (Neon Highway)
*   **Visual Profile**: Gray asphalt paths, orange/yellow road lines, car sprites.
*   **Legibility Rating**: **A** (Highway markings naturally stand out).
*   **Action Plan**: Maintain intact.

### Theme 6: Thiefs (Deep Navy Treasury)
*   **Visual Profile**: Shadowy navy floor tiles, bright gold coins, chest exits.
*   **Legibility Rating**: **B-** (Coins pop well, but the thief character blends into navy tiles).
*   **Action Plan**:
    *   Elevate the thief character sprite base colors by **18%** to make its clothing brighter.
    *   Add a subtle yellow drop-shadow behind the active character sprite at runtime.

### Theme 7: Poop (Earthy Forest)
*   **Visual Profile**: Earthy browns, funny micro-sprites.
*   **Legibility Rating**: **B** (Brown walls crush against dark brown path tiles).
*   **Action Plan**:
    *   Brighten the brown wall outer border with distinct cream-colored highlights (`#E6D7C3`).

---

## 4. Technical Implementation Strategy

### 1. Dynamic TV Color Scaling Profile
Inside `theme_loader.gd`, we can introduce a utility that detects if the game is running on a TV platform (or if a parent has toggled a "Boost Contrast" setting). If true, it automatically boosts the color values loaded from `manifest.json` files:

```gdscript
# Inside scripts/theme_loader.gd
func adjust_color_for_tv(base_color: Color, boost_factor: float = 0.20) -> Color:
    if OS.has_feature("tv") or Config.high_contrast_mode:
        # Interpolate color towards pure white to increase luminance
        return base_color.lerp(Color.WHITE, boost_factor)
    return base_color
```
This keeps our assets identical on all devices, but dynamically raises the luminance specifically on budget TV screens!

### 2. High Contrast Grid Option
For children with visual impairments or on extremely low-end displays, we can provide a **High Contrast Mode** toggle in Settings. When active:
*   Floor textures (stone grids, asphalt, pond waves) are replaced with a flat, solid dark-charcoal background.
*   Wall lines are converted to pure high-contrast primary colors (neon green, yellow, or white).
*   All educational collectibles (numbers, letters) are rendered in bold white text against solid black backing bubbles.
*   This is highly accessible, zero-performance-cost, and ensures absolute readability.
