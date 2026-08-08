# Arcade theme — "Neon Grid" redesign

Replaces the current Pac-Man-styled arcade theme with an original early-80s arcade theme that
carries the same era vibe without borrowing any protected character design.

---

## Why

The current theme uses a yellow wedge-shaped player with a chomping-mouth animation, a coloured
ghost chaser, dot collectibles, and a `#0000FF` maze with `#FFFF00` player colour. That is a
direct Pac-Man homage. Bandai Namco holds trademarks on the character shapes and enforces them.

This is **not** a Google Play Families matter — it falls under Play's Intellectual Property and
Impersonation policies, a separate surface. It is worth fixing on its own merits.

### What is actually protected — avoid all of it

- A **yellow circular character with a pie-slice wedge mouth** that opens and closes
- **Ghost-shaped characters**: rounded dome head, wavy or scalloped bottom edge, large eyes with
  offset pupils — in any colour
- The specific **maze layout**, the **power pellet** concept, the **fruit bonus** items
- The names, sounds, or any recognisable maze silhouette

### What is *not* protected — lean into all of it

The early-80s arcade *aesthetic* is a genre, not an asset: neon on black, CRT glow and scanlines,
chunky low-resolution shapes, a tight saturated palette, vector-line art, grid floors. Think of
the visual language shared by Tron, Tempest, Battlezone, Berzerk and Robotron rather than any one
title.

---

## The concept — "Neon Grid"

A small explorer craft navigating a glowing circuit-board maze, pursued by a neon glitch-bug.
Everything is drawn as if lit from within on a black CRT.

| Slot | Design |
|---|---|
| **Player** | A compact **arrow-shaped hover-craft** in cyan-white with a bright thruster glow at the rear. Animates as a **thruster pulse**, not a mouth |
| **Chaser** | A **neon glitch-bug** — an angular crawler with two antennae and segmented legs, in hot orange-red. Animates as a leg-and-antenna twitch |
| **Collectible** | A **glowing energy shard** — a faceted diamond/gem in amber-gold. Animates as a pulse-and-blink |
| **Background** | A near-black **circuit-grid tile** with faint teal traces and subtle scanlines |
| **Start** | A glowing **spawn pad** — a flat circular platform with a soft upward light |
| **End** | A neon **exit portal** — a glowing ring or archway |
| **Trap** | A **glitch node** — an unstable crackling hazard |

### Palette

Chosen so no two game objects share a hue, which matters because they overlap on screen:

| Element | Colour | Role |
|---|---|---|
| Background | `#05070D` near-black, traces `#0E3A3A` teal | The stage — stays dark and quiet |
| Maze walls | `#5B5BFF` neon blue-violet | Engine-drawn from the manifest |
| **Player** | `#7DF9FF` cyan-white | Brightest object on screen |
| **Chaser** | `#FF5A3C` neon orange-red | Opposite the player on the colour wheel |
| **Collectible** | `#FFD24A` amber-gold | Warm, distinct from both |
| Exit portal | `#5BFF9B` neon green | Reads as "goal" |

---

## Files required — exact specification

Every file **200 × 200 px**, PNG, RGBA, except the trap.
Everything is **fully transparent background except `background.png`**, which is fully opaque.

| File | Size | Background | Notes |
|---|---|---|---|
| `player_open.png` | 200×200 | transparent | Craft, thruster at **full** flare |
| `player_slight.png` | 200×200 | transparent | Same craft, thruster **medium** |
| `player_closed.png` | 200×200 | transparent | Same craft, thruster **minimal** |
| `chaser_0.png` | 200×200 | transparent | Bug, legs/antennae position A |
| `chaser_1.png` | 200×200 | transparent | Same bug, legs/antennae position B |
| `collectible_0.png` | 200×200 | transparent | Shard, full brightness |
| `collectible_2.png` | 200×200 | **fully transparent** | **Empty file** — the blink frame |
| `collectible_4.png` | 200×200 | transparent | Shard, dimmer |
| `collectible_6.png` | 200×200 | transparent | Shard, mid brightness |
| `background.png` | 200×200 | **fully opaque** | **Must tile seamlessly** |
| `start.png` | 200×200 | transparent | Spawn pad |
| `end.png` | 200×200 | transparent | Exit portal |
| `trap.png` | 256×256 | transparent | Glitch node |

`collectible_2.png` is a fully transparent 200×200 file — that is what produces the blink. Ask me
and I will generate it directly; there is nothing to draw.

**Animation timing is already set** in the manifest: player 12 fps across 3 frames, chaser 3 fps
across 2, collectible 8 fps across 4. Frames must therefore be **the same object in the same
position**, varying only as described — any drift in size or placement will read as a jitter.

---

# Prompts

Send the style brief first, in a new chat, then request assets one at a time in the same chat so
the model keeps the established look. Generating them in one batch produces inconsistent results.

## Step 1 — style brief (send this first, on its own)

> I need a matching set of game sprites for a children's maze game, in an original early-1980s
> arcade art style. I'll ask for them one at a time. First, here is the style to hold across all
> of them:
>
> **Visual style:** neon-on-black arcade cabinet art of the early 1980s. Objects look lit from
> within, like glowing vector graphics on a dark CRT screen. Bold, simple, chunky shapes with
> clean silhouettes. Bright saturated neon colours with a soft outer glow or bloom against pure
> black. Slight retro-futuristic circuit-board feel. Flat and graphic rather than painterly — no
> soft airbrushed shading, no realistic textures, no 3D rendering.
>
> **Palette — use only these:**
> - background/black: `#05070D`
> - circuit traces: `#0E3A3A` teal
> - player craft: `#7DF9FF` cyan-white
> - enemy: `#FF5A3C` neon orange-red
> - collectible: `#FFD24A` amber-gold
> - exit portal: `#5BFF9B` neon green
> - maze walls: `#5B5BFF` neon blue-violet
>
> **Everything must be original.** Do not reproduce, imitate or reference any existing arcade game
> character. Specifically **never** draw: a yellow circular character with a wedge-shaped mouth; a
> ghost-shaped character with a rounded top and wavy bottom edge; anything resembling a known
> arcade mascot. I want the *era's aesthetic*, not any particular game's characters.
>
> **All sprites:** 200×200 pixels, PNG with a **fully transparent background** — no black
> rectangle, no backdrop, no drop shadow, no ground. Displayed at roughly 40–60 px on screen, so
> shapes must be bold and read clearly when small.
>
> Confirm you understand, and I'll request the first asset.

## Step 2 — player craft (3 frames)

> **Asset 1 of 7 — the player character, frame 1 of 3.**
>
> A compact **arrow-shaped hover-craft** seen from directly above, pointing up. Cyan-white
> `#7DF9FF` hull with glowing edge lines, a small darker cockpit, and a **bright thruster flare at
> the rear**. Symmetrical, chunky, instantly readable as a little ship. Friendly and appealing
> rather than military — no guns, no weapons, no missiles.
>
> This frame: the thruster is at **full flare**, large and bright.
>
> 200×200, transparent background, centred, filling most of the frame.

Then, in the same chat:

> **Frame 2 of 3** — the identical craft in the identical position and at the identical size.
> Change **only** the thruster: reduce it to about half the length and brightness. Nothing else
> may move or change.

> **Frame 3 of 3** — the identical craft again, same position and size. Thruster reduced to a
> small dim glow. Nothing else may change.

## Step 3 — chaser bug (2 frames)

> **Asset 2 of 7 — the enemy character, frame 1 of 2.**
>
> A **neon glitch-bug** seen from directly above: an angular segmented body in hot orange-red
> `#FF5A3C` with glowing edges, two antennae at the front and three pairs of short legs. It should
> look like a mischievous electronic insect made of light.
>
> **It must not be frightening** — this is for children aged 4–8. Two simple round glowing eyes,
> curious rather than angry. **No teeth, no fangs, no claws, no menacing expression.**
>
> This frame: antennae angled outward, legs in a forward stride.
>
> 200×200, transparent background, centred.

> **Frame 2 of 2** — the identical bug, same position, size and colour. Change **only** the
> antennae angle and the leg positions, as a small walking twitch. Nothing else may change.

## Step 4 — collectible shard (3 drawn frames)

> **Asset 3 of 7 — the collectible, frame 1 of 3.**
>
> A **glowing energy shard**: a simple faceted diamond or gem shape in amber-gold `#FFD24A`, lit
> from within, with a soft glow around it and a few small sparkle points. Bold and simple.
>
> **Important:** the game prints a letter or number on top of this item in dark text, so keep the
> **centre of the shard bright, clean and uncluttered** — no busy detail or dark markings in the
> middle.
>
> This frame: full brightness.
>
> 200×200, transparent background, centred, occupying about 70% of the frame.

> **Frame 2** — identical shard, identical position and size, at about **60% brightness**, with a
> slightly smaller glow.

> **Frame 3** — identical shard again, at about **80% brightness**. Only the glow intensity
> changes.

## Step 5 — background tile

> **Asset 4 of 7 — the background tile.**
>
> A **200×200 seamlessly tiling** background: a near-black `#05070D` surface with a faint
> circuit-board pattern in dark teal `#0E3A3A` — thin traces, small nodes and junction dots,
> like a printed circuit seen in the dark. Add very subtle horizontal CRT scanlines.
>
> **It must stay dark and quiet.** Game characters sit on top of it, so it must never compete —
> low contrast, no bright areas, no focal points.
>
> **Critical: it must tile seamlessly.** The left edge must continue into the right edge and the
> top into the bottom, with no visible seam. No border, no frame, no vignette, no edge darkening.
> Avoid any continuous line running the full width or height, and distribute the circuit nodes
> unevenly so a repeating grid pattern isn't obvious when tiled.
>
> 200×200, **fully opaque** — this one has no transparency.

## Step 6 — start pad and exit portal

> **Asset 5 of 7 — the start pad.** A glowing circular **spawn platform** seen from above: a flat
> disc with concentric neon rings in cyan-white `#7DF9FF`, and a soft upward light. Simple and
> symmetrical. 200×200, transparent background, centred.

> **Asset 6 of 7 — the exit portal.** A neon **exit gateway** seen from above: a glowing ring or
> rounded archway in neon green `#5BFF9B`, with a soft luminous centre suggesting a way through.
> Inviting and rewarding — this is where the child is trying to reach. 200×200, transparent
> background, centred.

## Step 7 — trap

> **Asset 7 of 7 — the hazard.** A **glitch node**: an unstable crackling energy knot in orange-red
> `#FF5A3C`, drawn as jagged electric arcs radiating from a small bright core. It should read as
> "don't touch" — but **playful and electric, not scary**. No spikes, no skull, no warning
> iconography, nothing sharp-looking enough to alarm a small child.
>
> **256×256** pixels — note this one is larger than the others. Transparent background, centred.

---

## The manifest

Write this to `themes/arcade/manifest.json` once the assets are in. Filenames and animation
structure are unchanged, so nothing else in the game needs touching. Only the colours change.

```json
{
  "title": "Arcade",
  "assets": {
    "player": "player_open.png",
    "chaser": "chaser_0.png",
    "background": "background.png",
    "start": "start.png",
    "end": "end.png",
    "collectible": "collectible_0.png",
    "trap": "trap.png"
  },
  "colors": {
    "wall": "#5B5BFF",
    "wall_glow_factor": 1.9,
    "wall_border": "#2A2A99AA",
    "floor": "#05070D",
    "start_cell": "#05070D",
    "end_cell": "#05070D",
    "player": "#7DF9FF",
    "highlight": "#FFD24A88"
  },
  "background": {
    "tiled": true,
    "full_screen": false
  },
  "glow": {
    "enabled": true,
    "strength": 0.85,
    "bloom": 0.28
  },
  "collectible": {
    "color": "#FFD24A",
    "text-color": "#1A1000",
    "image": "collectible_0.png",
    "fps": 8,
    "frames": [
      "collectible_0.png",
      "collectible_2.png",
      "collectible_4.png",
      "collectible_6.png"
    ]
  },
  "player": {
    "fps": 12,
    "frames": [
      "player_open.png",
      "player_slight.png",
      "player_closed.png"
    ]
  },
  "chaser": {
    "fps": 3,
    "frames": [
      "chaser_0.png",
      "chaser_1.png"
    ]
  }
}
```

Two colour changes worth noting: `wall` moves off pure `#0000FF` and `player` off pure `#FFFF00`,
since that exact pairing is part of what makes the current theme read as a specific game.
`text-color` on the collectible changes from black to `#1A1000` so the glyph sits warmly on the
amber shard rather than as a hard black hole.

---

## Verification

Send the files and I will check, before anything goes in:

- exact dimensions — 200×200, and 256×256 for the trap
- genuine alpha on all sprites; **fully opaque** on `background.png`
- `background.png` tiles seamlessly — measured as opposite-edge RMS difference, and rendered 3×3
- animation frames aligned: same silhouette bounding box across each frame set, so the loop
  doesn't jitter at 12 fps
- no two game objects sharing a hue band, and each sprite's contrast against the background tile
- legibility rendered at 60 px and 40 px
- a dark glyph placed on the collectible to confirm the letter stays readable
