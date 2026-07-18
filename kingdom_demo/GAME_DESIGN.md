# Kingdom — Game Design (North Star)

A top-down 45° Kingdom Two Crowns–like. This is the target vision; see
"Prototype status" at the bottom for what's actually built today.

## 0. Pillars
- Indirect control: the monarch has a tiny verb set; the kingdom self-organizes.
- Two parallel economies (coin vs. soup) that never fully substitute — the core dial.
- One day/night (~6–8 min); the cauldron's supper is the heartbeat between phases.
- Two hearts (crown + keep) so bad nights are survivable, not instant losses.

## 1. The Resource Triangle
Three resources that never fully substitute for each other.

| Resource | Earned from | Spent on | Held by |
|---|---|---|---|
| Coin | Enemy corpses → coin at dawn; market; looting ruins | Construction (walls/towers/buildings) and hiring + paying mercenaries | The monarch only — you physically ferry it |
| Broth (Soup) | The Cauldron, cooking raw ingredients into servings | Recruiting wanderers + nightly upkeep of the whole population | The cauldron; served at supper |
| Labor (Population) | Wanderers converted by soup | Staffing towers, gathering, cooking, building | The villagers themselves |

Core dial: coin buys instant military muscle (mercenaries); soup grows slow,
self-sustaining citizen-soldiers. Mercs never need soup and never gather;
citizens never cost ongoing coin. Most runs blend the two.

## 2. Core Gameplay Loop (~6–8 min/day)
**☀️ DAY (~4 min) — Build & Provide.** Villagers self-organize (cooks haul to
cauldron, farmers/hunters/gatherers work, builders build where coin was dropped).
The monarch does monarch-only things: ferry coin caches to build sites; forage
wild ingredients and dump them in the cauldron (early-game bootstrap); lead
wanderers home before dark; hire mercs at camps; scout corridors, loot ruins,
wake statues. Wanderers arrive drawn by cauldron smoke and loiter as "hungry."

**🍲 DUSK / THE SUPPER (~30–45 s) — the ritual telegraph.** Horn sounds, work
stops, soup is served. Well-fed camp → morale bump (troops hit harder, tower
fire-rate up); thin/empty pot → hungry citizens, morale drop, some wanderers
drift back to the wild. Hungry wanderers who eat convert to citizens and grab a
tool. Mercs collect coin pay; unpaid mercs are flagged to desert at dawn.
Attack-direction glow appears on scouted corridors — last chance to move banners.

**🌙 NIGHT (~2–3 min) — Survive.** Waves pour down corridors. Building disabled
(or ~3× coin cost). Mercs are heavy hitters; citizen archers man towers; the
monarch rides the line, rallies squads to banners, plugs gaps. Both hearts at risk.

**🌅 DAWN — Assess.** Corpses → coin. Damaged buildings smoke; broken walls need
repair. Unpaid mercs leave (may pillage/steal on the way out). Choose the day's
priority: repair vs. expand vs. push cauldron output vs. ride out. Loop repeats.

## 3. Cauldron & Soup — Recruitment (replaces coin-as-recruitment entirely)
Central, upgradeable building; emotional center of camp.
- **Fill it (diegetic, no menus):** cooks auto-haul farm/hunt/forage ingredients;
  the monarch can personally dump foraged wild ingredients (early bootstrap +
  emergencies). Ingredients are a soft resource (veg, meat/fish, water, rare herbs).
- **Recruit:** fed cauldron → smoke/aroma draws wanderers to camp edge → they
  loiter "hungry" (not yours yet) → at supper, those who get a bowl convert to
  loyal citizens and take up tools. Player verb is never "click recruit" — it's
  "keep ingredients flowing and protect the newcomers."
- **Upkeep (pressure valve):** supper feeds the *existing* population too. A dry
  cauldron starves morale → citizen attrition. Population size is tied to food
  surplus: grow too fast and you can't feed everyone.
- **Recipes (light system):** which ingredients dominate shifts the night's effect.

| Soup | Made from | Effect |
|---|---|---|
| Thin Broth (default) | Water + scraps | Keeps people alive, minimal morale, but draws the most wanderers |
| Hearty Stew | Meat + roots | Strong morale + temporary worker/soldier buff for the night |
| Spiced / Medicinal | Rare herbs | Heals wounded, cures status (hooks into blight later) |
| Feast | Everything, expensive | One-night big morale + defense buff; burn before a blood moon |

- **Upgrades / forward kitchens:** bigger pot → more servings → higher pop cap.
  A second cauldron at a forward outpost lets you sustain/recruit at the frontier.
  Ties to depletion (§4): ingredient supply lines march outward over time.

## 4. Mercenaries — the coin-fueled counterweight
Strong, immediate, pre-trained, temporary.
- **Get them:** merc camps spawn in the corridors (mid/outer map); wandering
  sellsword groups may appear. Ride out, pay a coin bounty up front, they follow home.
- **Contract/upkeep tension:** pay each supper (coin) → they hold. Fail → desertion
  at dawn, and on a bad roll they pillage on the way out. Over-hiring is dangerous.
- **Loyalty conversion:** a merc paid reliably over many nights may "settle" into a
  permanent citizen — a slow, rewarding path to stabilize a lean economy.

| | Citizen (soup) | Mercenary (coin) |
|---|---|---|
| Recruited by | Feeding the cauldron | Paying a bounty |
| Ongoing cost | Soup upkeep at supper | Coin upkeep at supper |
| Needs housing? | Yes | No |
| Economy work? | Yes | No — pure combat |
| Strength | Grows slowly, cheap long-term | Strong now, expensive |
| Permanence | Permanent | Temporary (until settled) |

- **Archetypes (starter set):** Pikeman (holds chokepoints), Crossbow (single-target
  punch), Berserker (high dmg, fragile), Outrider (mounted, fast; escort/hunt),
  Siege Engineer (portal-destroying endgame; slow, protect), Captain (buffs nearby
  mercs; keystone hire).
- **Role in the loop:** the answer to "can't grow an army fast enough for the blood
  moon" and "I want to push a corridor and destroy a portal now." Run out of coin
  with a camp full of sellswords → mutiny. That risk is the point.

## 5. Supporting Loop Features
- **Indirect control — the monarch's ENTIRE verb set:** drop coin (builds/upgrades
  where dropped); keep the cauldron fed (population grows on its own); plant/move
  2–3 rally banners (soldiers cluster & redeploy — the one 360° tactical lever);
  ring the bell (recall everyone inside); sound the horn (push workers to frontier
  caches). No unit selection, ever.
- **Exploration incentives:** depletion (near-camp resources run dry → economy
  marches outward); rich stuff always far (spices, relics, mounts, statues, merc
  camps in the middle/outer thirds); the monarch is the only courier (carries coin,
  leads wanderers, activates ruins). The day timer makes every trip a gamble.
- **Lose condition — two hearts:** The Crown (your body, no health bar — hits
  scatter coin; broke + hit knocks the crown off; a stealer sprinting it to a portal
  ends the run, but troops can save you / you can chase it). The Keep (the one
  existential building — walls/towers/districts can fall & rebuild; only the keep
  ends the run). No crown, no king; no keep, no kingdom.

## Prototype status (what exists today) & gap map
Built now (see `kingdom_demo/scripts/`):
- Monarch movement + interact + retinue (`monarch.gd`); pixel billboard sprites.
- Coin from chopping trees (`tree_resource.gd` → `coin.gd` → `game_manager.gd`).
- Peasants: WANDER → recruit → FOLLOWING, assigned ARCHER/BUILDER at job stations
  (`peasant.gd`, `job_station.gd`); archers patrol the base, builders feed a
  construction meter.
- Base tiers upgraded by coin or builder construction (`base_manager.gd`).
- Cosmetic day/night (`day_night_cycle.gd`); icon HUD (coin / sun-moon / base tier).

Not yet built (vision gaps, rough build order):
1. **Combat & night waves:** enemies down corridors, archers shoot, monarch fights,
   corpses → coin at dawn, and the **two-hearts lose condition**. (Makes it a game.)
2. **Cauldron/soup economy:** replace coin-recruit with soup-recruit; ingredients +
   monarch forage; the **supper ritual**; population **upkeep/morale/attrition**.
   NOTE: today's "recruit peasant for 1 coin" contradicts the vision and should be
   retired in favor of soup once the cauldron exists.
3. **Mercenaries:** merc camps in corridors, coin bounty + supper upkeep, desertion/
   pillage, settle-into-citizen.
4. **Indirect control polish:** drop-coin-to-build, rally banners, bell/horn.
5. **World/exploration:** resource depletion, corridors, ruins/statues, market.
