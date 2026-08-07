# Prompt for replacing the baton in `t_chaser_0.png`

Attach `themes/thiefs/t_chaser_0.png` (220×220, RGBA, transparent background) and paste the prompt below.

**Before you send it:** image models routinely flatten transparency, shift the palette and resize. Expect to check those three things on every result, and to re-cut the alpha channel yourself. Ask for one variation at a time — batches drift further from the original.

---

## The prompt

> I'm attaching a 220×220 PNG game sprite with a transparent background. It's the "chaser" character in a children's maze game for ages 4–8 — a friendly cartoon police officer in a running pose, drawn in a flat cel-shaded style with thick dark navy outlines.
>
> **The single change I need:** he is holding a dark police baton in his raised hand (his right hand, on the left side of the image as you look at it). Replace the baton with a **whistle** — a small referee-style whistle, ideally with a short lanyard or cord, held in that same raised hand. A whistle instantly reads as "police" and suits a chase game, without depicting a weapon.
>
> **Keep everything else pixel-for-pixel as close to the original as you can:**
> - Identical pose — mid-stride running, same leg positions, same arm angles, same body lean
> - Identical face — same big open smile, same eyes, same friendly expression. Do not restyle the face.
> - Identical uniform — navy peaked cap with the gold star emblem, navy jacket, gold chest badge, belt, light-blue trim, same shoes
> - Identical colour palette, identical outline weight and colour, identical cel-shading style
> - Identical framing, scale and position of the character within the 220×220 canvas
>
> **Technical requirements:**
> - Output exactly 220×220 pixels
> - Preserve the fully transparent background — no white, no checkerboard, no drop shadow, no added ground plane or scenery
> - The whistle must be smaller than the baton was, so the character's silhouette stays compact. This sprite is displayed at roughly 40–60 px on screen, so the whistle needs to read clearly as a whistle at that size: keep it chunky and simple rather than finely detailed, and give it enough contrast against the navy sleeve
>
> **Must not appear in the result:** any baton, nightstick, club, truncheon, stick, gun, taser, or any other object that could be read as a weapon. Nothing sharp or menacing. The character must stay warm and friendly — this is for very young children.
>
> Return the edited PNG with transparency intact.

---

## Fallbacks, in order of preference

If the whistle doesn't read clearly at sprite size, re-run with the same prompt but swap the object:

1. **Torch / flashlight** — reads as "searching", still obviously police, easy silhouette
2. **Raised pointing hand** — replace the object entirely with an open hand, index finger up, as if calling "stop!"
3. **Empty open hand** — the safest option; ask explicitly for an *open* hand, not a closed fist, since a raised fist reads as aggressive

## Acceptance check

- No object in the sprite could be described as a weapon
- Still 220×220 with a genuinely transparent background (open it over a dark and a light backdrop to confirm no white halo)
- Dropped into the game, the character still reads as the same character at normal zoom
- Checked on a TV at ~3 m, per the theme checklist

## Why this is being changed

Not a known violation. Google's *Age 5 and under* guidance names weapons explicitly, and after the emoji audit removed 🏹 and 🤺 from the vocabulary, this baton is the last weapon-adjacent object anywhere in the game. It's risk reduction on the default theme, which is what a reviewer sees first on a cold install.
