# Chaser — minimal tweak prompt (keep the original tree)

Goal: the **same** crooked tree, unchanged in every way except that its face is no longer a monster face. The promo video already shows this character, so silhouette, colour and pose must survive.

Attach **`themes/scary/chaser.png`** (440×440, RGBA, transparent).

---

## The prompt

> I'm attaching a 440×440 PNG game sprite with a transparent background — a magenta-pink crooked tree character from a children's maze game.
>
> I need **one change only: the face.** Everything else in this image must stay as close to identical as you can make it. This character already appears in a promotional video, so it has to remain recognisably the same sprite.
>
> **KEEP EXACTLY AS-IS — do not redraw, restyle or reinterpret any of this:**
> - The identical silhouette and outline shape of the whole tree
> - The identical pose and lean
> - The identical magenta-pink and crimson trunk colours
> - Every branch, twig and pointed tip, in the same positions and at the same angles
> - The olive-green cloud-shaped foliage on top, unchanged in shape, position and colour
> - The same flat painterly art style, the same brush texture, the same shading
> - The same size and position within the 440×440 frame
>
> **CHANGE ONLY THE FACE ON THE TRUNK:**
> - The two **hollow black angular eye sockets** become **large, round, friendly cartoon eyes** — white sclera with dark round pupils and a small white catchlight in each. Make them big and clearly round, not narrow or slanted. This is the single most important part of the change: hollow voids read as menace, round eyes with pupils read as a character
> - The **jagged black gash of a mouth** becomes a **small, simple, rounded mouth** — a soft "o" of surprise, or a tiny neutral curve. No teeth, no jagged edges, no fangs
> - Keep the face in **the same position** on the trunk and at roughly the same overall size
>
> The result should be the same tree, instantly recognisable as the same character, that now looks **surprised and goofy rather than frightening** — the sort of thing a four-year-old would laugh at.
>
> **TECHNICAL:**
> - Exactly 440×440 pixels
> - Fully transparent background — no white, no checkerboard, no drop shadow, no ground
> - Do not crop, rescale, re-centre or re-frame the character
>
> **DO NOT:** redraw the tree, change its colour, change its shape, change the branches, change the leaves, change the style, add or remove any element, or turn it into a different character. Only the eyes and mouth change.

---

## If it drifts

Very likely on the first attempt. Useful follow-ups in the same chat:

- *"That's a different tree. Go back to my original image and change only the eyes and mouth — keep the exact same shape, colour and branches."*
- *"The eyes are still narrow and angry. Make them large, round and friendly, like simple cartoon eyes."*
- *"You changed the colour. It must stay the same magenta-pink as the image I attached."*

## Verification

Send me the result. I'll measure against the original and report:

- **silhouette overlap (IoU)** — how much of the shape survived. Above ~0.95 means the video still matches
- **mean colour delta** on the trunk and foliage
- **percentage of pixels changed**, and whether the changes are confined to the face region
- legibility of the new face at 60 px and 38 px

For reference, the surgical edit I already have ready changes **3.3%** of pixels, all inside `x 168–330, y 164–268`, with the silhouette bit-for-bit identical. That is the benchmark any ChatGPT result should be judged against.
