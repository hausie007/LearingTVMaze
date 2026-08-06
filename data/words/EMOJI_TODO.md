# Vocabulary emoji — outstanding issues

Companion to `EMOJI_AUDIT_2026-08-03.md` (which lists the 28 fixes already applied).
Everything below was found during the same full pass over all 3,654 entries / 21 languages / 147 files, and deliberately **not** changed.

Nothing here is a Google Play policy problem. Alcohol, weapons and poop imagery were all removed in the applied pass. These are quality and correctness items.

**Priority key:** 🔴 wrong data, should be fixed · 🟡 misleading, worth fixing · ⚪ no better emoji exists, informational only

---

## 🔴 A. Word errors — the word is wrong, not the emoji

Needs a decision on the word itself, so left alone.

| Lang | File | Word | Emoji | Problem |
|---|---|---|---|---|
| da | `words_da_2.json` | LOSOS | 🐟 | **Wrong language.** "Losos" is Czech/Slovak for salmon. Danish is **LAKS**. A Slavic word is sitting in the Danish list. |
| pl | `words_pl_0.json` | MÓD | 🍯 | **Not a Polish word.** `MIÓD` (honey) already exists in `words_pl_2.json` with the same 🍯. Looks like a corrupted duplicate — likely delete. |
| da | `words_da_1.json` | BOLT | ⚽ | `BOLD` (ball) already exists in `words_da_2.json` with the same ⚽. "Bolt" means bolt/pin. Typo duplicate — likely delete. |
| de | `words_de_0.json` | TOP | 🍲 | Probably meant **TOPF** (pot). "Top" is not a German word for a cooking pot. |
| sk | `words_sk_0.json` | LIETAK | 🪁 | Non-standard spelling. `LIETADLO` (aeroplane) exists separately in `words_sk_3.json` = ✈️. Intended word unclear — kite? leaflet? |
| nb | `words_nb_1.json` | REVE | 🦊 | Norwegian for fox is **REV**. "Reve" is an inflected form. |
| pl | `words_pl_4.json` | WOZ STRAŻACKI | 🚒 | Missing diacritic — should be **WÓZ STRAŻACKI**. |
| fi | `words_fi_5.json` | LEIKKIKÄÄTE | 🤝 | **Not a Finnish word.** Every other language has "play together" here (EN PLAY TOGETHER, SV LEK TILLSAMMANS). Probably meant `LEIKKIKÄÄ YHDESSÄ`. |
| fi | `words_fi_5.json` | ILONEN LAPSI | 👦 | Typo — should be **ILOINEN**. Note `ILOINEN TYTTÖ` in the same file is spelled correctly. |
| fi | `words_fi_6.json` | KUU VALAISTAA MEITÄ | 🌙 | Verb form wrong — should be **VALAISEE**. |
| da | `words_da_5.json` | LEGEFUL HUND | 🐕 | "Legeful" is not standard Danish. Compare NB `LEKEFULL HUND`. Probably **LEGESYG** or **LEGELYSTEN**. |

### ⚠️ One to check with a native speaker

| Lang | File | Word | Emoji | Problem |
|---|---|---|---|---|
| pl | `words_pl_4.json` | STRASZAK | 🌾 | Every other language uses a **scarecrow** word in this slot (EN SCARECROW, ES ESPANTAPÁJAROS, FR ÉPOUVANTAIL, IT SPAVENTAPASSERI). Polish for scarecrow is *strach na wróble*. **"Straszak" more commonly means a cap gun / toy pistol.** If a Polish speaker reads it that way, it is a weapon word in a preschool list — which would make it the one policy-relevant item left in the vocabulary. Worth confirming. |

---

## 🟡 B. Emoji doesn't match the word well

Not wrong enough to change without your view, but each is misleading to a child.

| Lang | File | Word | Meaning | Emoji | Problem |
|---|---|---|---|---|---|
| tr | `words_tr_4.json` | GÜVE | moth | 🦋 | Butterfly, not moth. `KELEBEK` (butterfly) already uses 🦋. Duplicate + wrong. |
| cs | `words_cs_1.json` | KRTEK | mole | 🦫 | Beaver. Wrong animal entirely. No mole emoji exists — see section C. |
| cs | `words_cs_4.json` | VÁŽKA | dragonfly | 🦋 | Butterfly. `MOTÝL` already uses 🦋. Other languages use 🪽 for dragonfly. |
| uk | `words_uk_3.json` | ТХІР | polecat/ferret | 🦦 | Otter. Wrong animal. |
| de | `words_de_4.json` | BAUERNHAUS | farmhouse | 🚜 | Tractor. 🏡 would fit; `TRAKTORFAHRT` already uses 🚜. |
| de | `words_de_2.json` | NAGEL | nail | 🔨 | Hammer, not nail. |
| de | `words_de_1.json` | ROHR | pipe/tube | 🧪 | Test tube. Different object. |
| de | `words_de_4.json` | WINTERHÖHLE | winter cave | 🌙 | Moon. Unrelated. |
| sv | `words_sv_1.json` | KÖTTBULLE | meatball | 🍝 | Spaghetti. 🍖 or 🥩 closer. |
| sv | `words_sv_0.json` | SIL | sieve/strainer | 🥣 | Bowl. |
| it | `words_it_2.json` | COSCIA | thigh | 🍗 | Poultry leg — reads as food, not body part. |
| it | `words_it_2/3.json` | PUMA / PANTERA | puma / panther | 🐆 / 🐆 | Both use leopard. Identical emoji for two words. |
| nl | `words_nl_1.json` | BUUR | neighbour | 🏘️ | Houses, not a person. |
| nl | `words_nl_3.json` | VRIEND | friend | 🙂 | Generic face. Other languages use 🤝 / 👫. |
| nb | `words_nb_3.json` | VENNEN | the friend | 🙂 | Same as above. |
| nb | `words_nb_3.json` | LEKEN | the toy / playful | 🎠 | Carousel. 🧸 would fit. |
| hu | `words_hu_1.json` | JÁTÉK | toy / game | 🎠 | Carousel. Same issue. |
| hu | `words_hu_0.json` | PAD | bench | 🪑 | Chair, not bench. |
| hu | `words_hu_0.json` | BOT | stick | 🪵 | Log. Same emoji used for "table" elsewhere. |
| en | `words_en_0.json` | JAM | jam | 🍯 | Honey pot. |
| en | `words_en_1.json` | DESK | desk | 🖥️ | Desktop monitor, not a desk. |
| cs | `words_cs_4.json` | OSTRUŽINY | blackberries | 🍇 | Grapes. |
| cs | `words_cs_4.json` | POPELÁŘSKÉ AUTO | bin lorry | 🛻 | Pickup truck. |
| pt | `words_pt_4.json` | TRICICLO | tricycle | 🚲 | Bicycle. Same as `tr ÜÇ TEKER` = 🚲. |
| tr | `words_tr_4.json` | HAVA TAKSİ | air taxi | 🚁 | Helicopter — arguably fine, listed for completeness. |
| uk | `words_uk_0.json` | ГАЗ | gas | 🔥 | Fire. |
| uk | `words_uk_0.json` | МУЛ | mule | 🐴 | Horse. No mule emoji exists. |
| es | `words_es_1.json` | COLA | tail / queue | 🐒 | Monkey (for its tail). Indirect. |
| fr | `words_fr_1.json` | NAIN | dwarf | 🧙‍♂️ | Wizard/mage, not a dwarf. |
| ro | `words_ro_0.json` | SAC | sack | 🛍️ | Shopping bag. |
| he | `words_he_1.json` | פירמידה | pyramid | 🔺 | Plain red triangle. |
| nb | `words_nb_1.json` | SKIP | ship | ⛵ | Sailboat; `BÅT` (boat) in `words_nb_0.json` uses the same ⛵. |
| sk | `words_sk_0.json` | RAK | crayfish | 🦞 | Lobster. Close enough, noted only. |
| pl | `words_pl_4.json` | KOLCZATEK | echidna | 🦔 | Hedgehog. No echidna emoji. |

### Inconsistency

| Lang | File | Word | Emoji | Note |
|---|---|---|---|---|
| sv | `words_sv_5.json` | FÄRSK FRUKT | 🍊 | Every other language uses 🍏 or 🍐 for "fresh fruit". |
| nb | `words_nb_5.json` | FRISK FRUKT | 🍊 | Same. |
| en/fr/sk | `words_en_0`, `words_fr_0`, `words_sk_4` | ZOO | 🦁 | Lion stands in for zoo in three languages — consistent, just noting it is indirect. |

---

## ⚪ C. No suitable emoji exists

Left alone deliberately. Listed so nobody re-investigates them later.

| Concept | Affected entries | Current | Note |
|---|---|---|---|
| **table** | `en TABLE` (en_2), `cs STŮL` (cs_2), `da BORD` (da_1), `fi PÖYTÄ` (fi_0), `sv BORD` (sv_1), `nl TAFEL` (nl_2), `sk STÔL` (sk_2) | 🪵 | No table emoji in Unicode. 🪵 (log) is now used consistently across all seven after the applied pass. |
| **rug / carpet** | `en RUG` (en_0), `sv MATTA` (sv_3) | 🧶 | No carpet emoji. 🧶 (yarn) is a weak stand-in. |
| **mole** | `cs KRTEK` (cs_1) | 🦫 | No mole emoji. Currently beaver — actively wrong, but nothing better exists. |
| **dragonfly** | `en DRAGONFLY` (en_4), `pt LIBÉLULA` (pt_4), `it LIBELLULA` (it_4), `cs VÁŽKA` (cs_4) | 🪽 / 🦋 | No dragonfly emoji. 🪽 (wing) used in three languages; Czech uses 🦋 and should at least be made consistent with 🪽. |
| **submarine** | `en SUBMARINE` (en_3), `cs PONORKA` (cs_3) | 🛳️ | No submarine emoji. Currently passenger ship. |
| **polecat** | `uk ТХІР` (uk_3) | 🦦 | No polecat/ferret emoji. |
| **plum** | `cs ŠVESTKY` (cs_4) | 🟣 | No plum emoji. Purple circle is the honest choice; `pl ŚLIWKA` was set to 🟣 in the applied pass for consistency. |

---

## Suggested order of work

1. **Section A** — real data errors. `da LOSOS`, `pl MÓD` and `da BOLT` in particular; two of the three look like entries that should simply be deleted.
2. **`pl STRASZAK`** — check with a Polish speaker. Only item here with any policy bearing.
3. **Section B** — quality pass whenever convenient. `tr GÜVE`, `cs VÁŽKA` and `cs KRTEK` are the most misleading.
4. **Section C** — nothing to do, unless you decide to drop the affected words rather than ship an approximate emoji.

---

*Full pass completed 3 Aug 2026: 3,654 entries, 21 languages, 147 files, 498 unique emoji. Re-scanning is not necessary — everything found is recorded here or in `EMOJI_AUDIT_2026-08-03.md`.*
