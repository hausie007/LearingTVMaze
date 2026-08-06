# "Thieves" theme — recommended changes

From the Google Play Families compliance audit, 3 August 2026.

**This theme is fine.** Cops-and-robbers is not prohibited anywhere in Google Play's Families policy — crime and theft appear on none of the violation lists. The actual content is a cartoon chase: collect gold coins, dodge banana peels, reach a treasure chest, avoid a cartoon policeman. There is no theft depicted, no victim, no weapon used.

Two small changes are still worth making, and one of them matters more than expected.

---

## ⚠️ Why this theme matters more than the others

**`thiefs` is the default theme on a fresh install.**

`scripts/game_config.gd`:
```gdscript
var selected_theme_dir: String = "thiefs"        # line 118
var theme_dir_name:    String = "thiefs"         # line 252
```

There is no saved config on a fresh install, so these defaults apply. **A Google reviewer installing the app for the first time lands in the Thieves theme**, and sees "Thieves" in the theme selector on the home screen.

That is the opposite of the Bathroom and Scary themes, which are opt-in and have to be deliberately selected. Whatever is worth doing here is worth more than the equivalent work on the other two.

---

## 1. Swap the baton for a whistle

`t_chaser_0.png` — the cartoon policeman carries a black baton.

It is held, never used, and entirely cartoon. But **it is now the only weapon-adjacent object left in the game**, after 🏹 and 🤺 were removed from the vocabulary in the emoji pass. Google's *Age 5 and under* guidance names weapons explicitly, and the app declares that age band.

**Replace with a whistle.** It reads instantly as "police", it fits a chase game better than a baton does, and it removes the weapon category from the game entirely.

Alternatives if a whistle doesn't work visually at small size: a torch/flashlight, a raised pointing hand, or simply an empty hand.

Everything else about the sprite stays — same pose, same uniform, same friendly face.

---

## 2. Retitle the theme

"Thieves" is the one word in the whole theme that frames it as crime. The assets themselves — a gold coin, a treasure chest, a banana peel — already read as a treasure hunt. Only the player's mask-and-stripes and the theme name say otherwise.

Since this is the **default** theme, its name is the first theme name a reviewer reads.

### How to change it — simpler than expected

`theme_loader.gd:350-357` resolves the display title from `title_key` if the manifest has one, otherwise falls back to `"theme_" + <folder name>`. No manifest currently sets `title_key`, so every theme already resolves through `data/translations.csv`, where a `theme_thiefs` row already exists in all 21 languages.

**So the change is a single row edit in `data/translations.csv`. No manifest change, no code change.**

**Do NOT rename the folder.** `game_config.gd:427` persists the theme as `dir_name`, and `CharacterCatalog` prefixes character IDs with the folder name. Renaming `thiefs/` → something else would break the saved theme preference for existing players, invalidate stored `character_id` values carrying the `thiefs:` prefix, and desync `theme_dir` in the multiplayer discovery payload between versions. The folder name is never shown to users — leave it as `thiefs`.

*(The same applies to the `theme_scary` row if you go ahead with the Enchanted Forest rename — it is also just a `translations.csv` edit.)*

---

## 3. Ten title ideas

Current: **Thieves** / Zloději / Diebe / Ladrones / Voleurs …

Ranked by how well they fit the assets and translate across all 21 locales.

| # | Title | Why | Translates cleanly? |
|---|---|---|---|
| 1 | **Treasure Chase** | Names both halves of the gameplay — the coins and the pursuit. Keeps all the energy, drops the crime framing entirely. | ✅ Yes — every language has both words |
| 2 | **Coin Chase** | Simplest and most literal. The collectible *is* a coin. Alliterative in English, still clear elsewhere. | ✅ Yes |
| 3 | **Treasure Hunt** | Universally understood children's phrase. Matches the treasure-chest finish exactly. | ✅ Yes — an established phrase in most languages |
| 4 | **Gold Rush** | Energetic, matches the gold coin palette. | ⚠️ Idiomatic — has a fixed historical meaning in some languages |
| 5 | **Catch Me!** | Focuses on the chase, which is what the child actually does. Short, works on a small TV card. | ✅ Yes |
| 6 | **City Chase** | Neutral and descriptive; the background is a city. | ✅ Yes |
| 7 | **Golden Coins** | Purely descriptive, zero controversy, slightly flat. | ✅ Yes |
| 8 | **Hide and Seek** | Instantly familiar to children everywhere. Slightly inaccurate — this is tag, not hide-and-seek. | ✅ Yes — established phrase everywhere |
| 9 | **Tag!** | Exactly what the mechanic is. Very short. | ⚠️ The children's game has very different names per language; check each |
| 10 | **The Great Coin Chase** | Storybook flavour. Longest option — check it fits the theme selector card. | ✅ Yes, but watch the length |

### Recommendation

**Treasure Chase** (#1), or **Treasure Hunt** (#3) if you prefer the calmer option.

Both keep everything that makes the theme fun, describe the assets accurately, translate cleanly into all 21 languages, and remove the only word that frames a children's chase game as crime.

If you pick one, the player sprite can stay exactly as it is — a masked character in stripes reads perfectly well as a storybook treasure hunter, and changing art is not necessary for the retitle to work.

---

## 4. Also worth doing

When you next go through the IARC content-rating questionnaire, answer the violence and any crime-related questions honestly for what is actually here: a cartoon chase, no aggression, no injury, no weapon use. Families policy requirement 3 is about accuracy in both directions — under-declaring is as much a problem as over-declaring.

---

## Checklist

- [ ] `t_chaser_0.png` — baton replaced with a whistle
- [ ] `data/translations.csv` — `theme_thiefs` row retitled in all 21 languages
- [ ] Folder left as `thiefs/` — **do not rename**
- [ ] Player sprite unchanged
- [ ] Coin, chest and banana peel unchanged
- [ ] New title checked for length on the theme selector card at TV distance
- [ ] `t_collectible_money_bag.png` — unreferenced in the manifest; delete or ignore
