# Vocabulary emoji audit — 3 August 2026

Reviewed all **3,654 entries** across **21 languages** (147 files, 498 unique emoji).
Verified after patching: 147 files parse, 3,654 entries intact, 0 malformed, 0 replacement characters.

---

## Applied — 28 fixes

### Policy-relevant (Google Play Families, Age 5-and-under criteria)

| Lang | Word | Was | Now | Why |
|---|---|---|---|---|
| es | VASO | 🥃 | 🥤 | 🥃 is a spirits tumbler with liquor. Google's Age 5-and-under guidance names *"depictions of alcohol"* as unsuitable. VASO just means drinking glass. |
| fr | BOUE | 💩 | 🟤 | BOUE means mud. The poop emoji here put crude-humor imagery in the *educational content*, not just the optional Bathroom theme — directly relevant to the IARC crude-humor question. |
| es | ARCO | 🏹 | 🌈 | Bow-and-arrow is a weapon; 5-and-under guidance names weapons. French already uses ARC = 🌈. |
| he | אביר (knight) | 🤺 | 🛡️ | Fencing emoji is a weapon sport. A shield fits "knight" better anyway. |

### Data corruption

| Lang | Word | Was | Now | Why |
|---|---|---|---|---|
| es | PLATA | `U+FFFD U+FFFD` | 🥈 | The emoji field held two literal replacement characters — it was rendering as two tofu boxes in-game. Genuine data loss, not a style choice. |

### Wrong meaning

| Lang | Word | Meaning | Was | Now |
|---|---|---|---|---|
| en | MUD | mud | 🛤️ railway track | 🟤 |
| en | RUG | rug | 🪶 feather | 🧶 |
| en | CATERPILLAR | caterpillar | 🐞 ladybug | 🐛 |
| en | CHIPMUNK | chipmunk | 🌰 chestnut | 🐿️ |
| en | IT IS RAINING NOW | — | 🐈 cat | 🌧️ |
| de | HAMPELMANN | jumping-jack toy | 🤡 clown | 🧸 |
| de | PAPA LIEST MIR VOR | "Dad reads to me" | 🤡 clown | 📖 |
| es | PAPÁ | dad | 🥔 potato | 👨 |
| fr | SŒUR | sister | 👭 two women | 👧 |
| it | PRATO | meadow | 🍏 green apple | 🌱 |
| pt | MICRÓBIO | microbe | 🔬 microscope | 🦠 |
| sv | KULA | ball / marble | 🔮 crystal ball | ⚪ |
| sk | PRST | finger | 🖐️ whole hand | 👆 |
| cs | ZLATO | gold | 🌟 star | 🪙 |
| pl | ŚLIWKA | plum | 🍑 peach | 🟣 |
| pl | MALINA | raspberry | 🍇 grapes | 🍓 |
| pl | CHRABĄSZCZ | cockchafer beetle | 🐞 ladybug | 🪲 |
| pl | MELON | melon | 🍉 watermelon | 🍈 |
| uk | СИНЄ НЕБО | blue sky | ☁️ cloud | 🌤️ |
| uk | СОЛОДОЩІ | sweets | 🍯 honey | 🍬 |

### Consistency

`table` was 🪵 in en/cs/da/fi but 🪑 (chair) in sk, 🍽️ (plate) in sv, 🛋️ (sofa) in nl. Normalised sk/sv/nl to 🪵.

---

## Not applied — needs your decision

### Likely word errors, not emoji errors

| Lang | Entry | Issue |
|---|---|---|
| pl | `MÓD = 🍯` | Not a Polish word. `MIÓD` (honey) already exists separately with the same emoji — looks like a corrupted duplicate. |
| da | `LOSOS = 🐟` | "Losos" is Czech/Slavic for salmon. Danish is **LAKS**. A word from the wrong language is in the Danish list. |
| da | `BOLT = ⚽` | `BOLD` (ball) already exists with the same emoji. "Bolt" means bolt/pin — probably a typo duplicate. |
| pl | `WOZ STRAŻACKI` | Missing diacritic — should be `WÓZ`. |
| de | `TOP = 🍲` | Probably meant `TOPF` (pot). |
| sk | `LIETAK = 🪁` | Non-standard spelling; `LIETADLO` (aeroplane) exists separately. |
| nb | `REVE = 🦊` | Probably `REV` (fox). |

**`pl STRASZAK` deserves a specific look.** Every other language uses a scarecrow word here (EN SCARECROW, DE —, ES ESPANTAPÁJAROS, FR ÉPOUVANTAIL). Polish for scarecrow is *strach na wróble*; **straszak** more commonly means a **cap gun / toy pistol**. If that is how a Polish speaker reads it, it is a weapon word in a preschool list. Worth a native-speaker check.

### No suitable emoji exists

Left as-is rather than forcing a poor substitute: **table** (🪵 is the least-bad convention), **rug/carpet**, **mole** (cs KRTEK = 🦫 beaver), **dragonfly** (cs VÁŽKA = 🦋 butterfly; en/pt/it use 🪽), **polecat** (uk ТХІР = 🦦 otter), **submarine** (en/cs use 🛳️ passenger ship).

---

## Compliance effect

Two items are now removed outright from Google's *Age 5 and under* "may not be suitable" list:

- **Depictions of alcohol** — eliminated (🥃 was the only instance).
- **Weapons** — eliminated (🏹 and 🤺 were the only instances).

**Crude humor** is reduced but not eliminated: 💩 is gone from the vocabulary, but the Bathroom theme remains and is still what drives the ACB PG and the ESRB "Crude Humor" descriptor.

**Scary content is untouched by this work** — the Scary theme's monster chaser and the wolf chasers remain, and Google's guidance names those for the 5-and-under band. That decision is still open.

---

## Verification

- Backup of all 147 original files taken before patching.
- Post-patch: 147/147 files parse as valid JSON; 3,654 entries (unchanged); 21 languages; 0 malformed records; 0 empty emoji; 0 replacement characters.
- Residual scan for 🥃, 💩, 🏹, 🤺 across all files: **none remaining**.
- `git diff --stat`: 21 files changed, 49 insertions, 49 deletions — a pure 1:1 value swap, no structural change.
