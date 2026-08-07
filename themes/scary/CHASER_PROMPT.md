# Chaser prompt — white rabbit

Canonical. Supersedes section 2 of `ART_REGENERATION_PROMPTS.md` and `CHASER_PROMPT_V2.md` (both the tree redesigns — the tree concept is abandoned).

## Why a cream-white rabbit

Every other asset in the theme already owns a hue band:

| hue | owned by |
|---|---|
| 50–90° yellow-green | background |
| 190–215° cyan-blue | **the player's car** |
| 20–45° orange-gold | collectible + finish |
| 245–274° violet | maze walls (`#A88BFF`) + trap |

That is why the violet tree felt wrong — it was competing with the maze walls. A cream-white character sidesteps the problem entirely: it separates by **brightness**, not hue, so it can never collide with a palette decision made later.

Measured against the background (luminance 0.100):

| | luminance | contrast |
|---|---|---|
| cream fur `#F5EFE2` | 0.866 | **6.11:1** |
| warm shadow `#C9BCA8` | 0.512 | 3.75:1 |
| deep shadow `#A8977F` | 0.320 | 2.47:1 |
| *old chaser that worked* | | *1.95:1* |
| *best violet attempt* | | *2.61:1* |

Even the character's **shadow tones** out-contrast the best violet version. This is a large margin, not a marginal win.

Deliberately cream `#F5EFE2` rather than pure white — pure white hits 7:1 but tends to blow out into a flat silhouette with no readable form, and looks harsh next to a warm painterly background.

**Policy-wise this is the safest thing in the whole theme.** A waistcoated storybook rabbit cannot be read as a scary character, a monster, or an animal in danger, which is the exact language in Google's *Age 5 and under* guidance. And "chasing" is intrinsic to the character — a rabbit that's late and hurrying — so pursuit reads as comic urgency rather than threat.

---

## Attach two images

1. **`tile4.png`** — the background. This teaches the model the painting style and what the character must stand out against
2. **`chaser.png`** — the current version, **for style reference only**. Say explicitly that the character is being replaced, not modified

---

## The prompt

> I'm attaching two images from a children's maze game for ages 4–8. The first is the game's painted forest background. The second is the current character sprite, which I am **replacing entirely** with a different character — use it only to understand the size and framing, not the design.
>
> I need a new character sprite: **a cheerful white rabbit in a waistcoat, running in a hurry** — a storybook rabbit who is late for something very important. In the game he playfully chases the player around a maze, so he should look like he is dashing forward with comic urgency, never menacing.
>
> ---
>
> **COLOUR — the most important requirement.**
>
> This character stands on top of the attached forest background, which is green and gold and quite busy. He must be instantly visible against it.
>
> - Fur is **warm cream-white**, base tone `#F5EFE2`, with soft warm-grey shadows around `#C9BCA8` and deeper accents near `#A8977F`. **Not pure white** — warm cream, so he still has visible form and modelling
> - He must be **much brighter than the background.** Brightness is what makes him readable — do not darken or grey him down
> - Inner ears and nose in soft pink, around `#E8A0A8`
> - A **deep raspberry-crimson waistcoat**, around `#B33A5C` with a slightly darker trim near `#7E2440`. This is the one saturated accent and it sits in the only colour lane no other game asset uses
> - **No green, no yellow-green, no olive** (the background owns those), **no blue or cyan** (the player's car is blue and must never be confused with him), **no orange or gold** (the collectible items are orange)
>
> ---
>
> **STYLE.**
>
> Paint him in **the same style as the attached background** — soft painterly brushwork, visible fur texture, painted light and shadow, warm atmospheric lighting, organic edges. **No thick uniform black cartoon outline.** No flat vector fills. He should look like the same artist painted him and the forest.
>
> ---
>
> **POSE AND CHARACTER.**
>
> - **Mid-run, side-on or three-quarter view**, leaning forward, legs extended in a clear dash. The pose must read as *running* in a single still image — this is a static sprite, so the silhouette does all the work
> - **Long ears swept back** by the speed. The ears are the most recognisable part of his silhouette — make them prominent and clearly separated from the head
> - Friendly, flustered expression: **large warm brown eyes with bright catchlights**, raised brows, small open mouth as if saying "oh no, I'm late!". Determined and comic, never angry, never sinister
> - Optional charming details: a brass pocket watch on a chain, a small satchel, a tuft of fur out of place. Keep them small and bold — no fine detail
>
> ---
>
> **TECHNICAL.**
>
> - Exactly **440 × 440 pixels**
> - **Fully transparent background.** No white background, no checkerboard, no drop shadow, no ground plane, no scenery — the character only
> - Displayed at about **40–60 pixels** on screen. He must read at that size: bold chunky silhouette, large clear eyes, prominent ears, no fine detail that disappears
> - He should fill most of the 440×440 frame
>
> ---
>
> **DO NOT produce:** a scary, aggressive, sinister or snarling rabbit; visible fangs or claws; red glowing eyes; a dark or shadowy character; a thick uniform cartoon outline; flat vector art; a photorealistic rabbit; any background or ground.
>
> The result: a warm, funny, slightly panicked storybook rabbit in a raspberry waistcoat, painted like the forest he's running through, that a four-year-old would laugh at rather than fear.

---

## Before accepting it

Send me the file and I'll re-measure against the real background and re-render the side-by-side at game scale. Pass marks:

- [ ] Luminance contrast against background **> 3:1** (target ~6:1; old working chaser was 1.95:1)
- [ ] Nothing in the sprite falls in the blue 190–215° band — must not read as the player's car
- [ ] Exactly 440×440, genuine alpha, no white halo when composited over a dark backdrop
- [ ] Silhouette reads as a running rabbit at 60 px with the detail thrown away
- [ ] No hard uniform outline — sits stylistically with the background

## If the rabbit doesn't land

The other concepts from the same shortlist, all satisfying the colour constraint:

1. **Grumpy badger** — black-and-white face, separates on luminance like the rabbit, chunkier silhouette
2. **Magenta fairy or pixie** — uses the open 300–360° lane; needs a deliberately chunky design to survive at 60 px
3. **Big pink butterfly** — boldest silhouette after the rabbit, though it risks reading as scenery in an already nature-heavy background
