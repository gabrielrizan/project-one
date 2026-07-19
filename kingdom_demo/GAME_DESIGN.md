# The Last Monarch — Game Design

A top-down 45° Kingdom Two Crowns–like, in stylized flat-shaded low-poly 3D. You play
a monarch who **never builds anything personally**. You ride, you pay, and your people
do the work. Coin buys construction and mercenaries; soup recruits citizens. Each map
is a run: strip its timber, meet its objectives, sail on.

> **This file is the intent. It is not a description of the code.**
> For what is actually implemented — costs, groups, conventions, gotchas — see
> **`CLAUDE.md`**, which is authoritative and kept current with the source.
>
> Each system below carries a status tag so you know how far off it is:
> `✅ built` · `⚠️ partial` · `❌ not built` · `🔮 future concept`

---

# PART A — THE GAME

*Near-permanent. This is what the game **is**. Changing anything here is a pivot.*

## §1. Pillars

Each pillar is written with what it **forbids**, because a pillar that can't reject a
proposal isn't doing any work.

**1. Indirect control.** The monarch has a tiny verb set; the kingdom self-organizes.
> Never: unit selection, build menus, right-click-to-command, a cursor that targets
> units, or any UI that lets the player micromanage a villager.

**2. Two economies that never fully substitute.** Coin buys instant muscle; soup grows
slow, self-sustaining citizens.
> Never: a coin→soup exchange rate, or a purchase that lets one fully replace the other.
> Mercs never need soup and never gather. Citizens never cost ongoing coin.

**3. One day/night is the heartbeat.** Build by day, survive by night; the supper is the
ritual that separates them.
> Never: pausing time, a speed-up button, or letting the player skip the night.

**4. Two hearts, so bad nights are survivable.** The Crown and the main building. Losing
walls, huts and citizens hurts but is recoverable.
> Never: a single hit-point bar for the kingdom, or an instant-loss state that isn't one
> of the two hearts.

## §2. What this is not

Cheapest defence against scope creep. If a proposed feature belongs on this list, it's out.

- **Not an RTS.** No selection, no formations, no orders.
- **Not a menu city-builder.** Nothing is bought from a panel; everything is bought by
  standing in front of it.
- **Not a survival crafting game.** No inventory screen, no recipes-as-UI, no hunger bar
  on the monarch.
- **Not a tech tree.** Progression is the main building's tier ladder, not a research web.
- **Not permadeath-from-zero.** Two hearts and carry-forward progress exist precisely so a
  bad night isn't a restart.

## §3. The monarch's verb set

**This is the entire list of things the player can do.** It is deliberately tiny — it is
the concrete form of Pillar 1. Anything not on this list, the player cannot do.

| Verb | Status | Notes |
|---|---|---|
| Ride | ✅ | Camera-relative; `Z`/`X` spin the camera |
| Hold-E to pay | ✅ | The **tally** — see below. The universal "buy" verb |
| Mark a tree / bush | ✅ | Pays 1 to flag it; a worker or archer does the actual work |
| Ring the bell — recall everyone inside | ❌ | |
| Sound the horn — push workers to the frontier | ❌ | |
| Plant / move 2–3 rally banners | ❌ | The one 360° tactical lever, for night defence |
| Lead wanderers home before dark | ⚠️ | They walk in on their own; no leading yet |

**The tally is the payment verb — canon.** Standing near anything buyable and holding `E`
raises a row of coin pips over it and flies coins in one per gold. Let go, or walk more
than 4m away, and the deal is off: gold already handed over spills on the grass as
re-collectable coins.

> ⚠️ Earlier drafts of this doc described a *"drop a coin cache and workers build there"*
> verb. **That is superseded.** The tally is the payment mechanic. Do not reintroduce
> drop-to-build.

**The monarch commissions; he never builds.** Paying does not finish a structure — it
opens a **construction site**. Idle workers walk over and raise it with their hammers.
Up to **3 workers** per site; each one past the first adds **+30% pace**. Nobody on
site, no progress at all. This is the third expression of Pillar 1 and applies to
*every* building action. (Implementation: `build_crew.gd`.)

## §4. Art direction  ✅ built and enforced

Stylized **flat-shaded low-poly 3D** — the Thronefall / Tiny Glade register: cozy,
grounded, slightly melancholic. Large readable silhouettes, minimal geometry, matte
materials, no textures.

**Palette (canon):** moss / forest / sage / olive greens · oak and walnut browns · linen ·
stone · charcoal · muted gold · ember · **burgundy** — the red complement that makes the
monarch the focal point against all that green. Assets that arrive off-palette get tinted
into it (the castle-kit pennants ship blue and are flattened to burgundy).

**The 2D/3D split is deliberate.** Everything diegetic is a model. Only screen-space UI,
the paint-blaze decal and particle debris are 2D. Coins, tally pips, job banners and
`Label3D` prompts stay camera-facing sprites *on purpose* so they read from any camera
angle — that is not an unfinished conversion.

---

# PART B — THE SYSTEMS

*The vision. Each section is tagged with how much exists today.*

## §5. Resources

### Coin — the monarch's purse  ⚠️ partial

**The monarch physically carries all the kingdom's gold in his purse.** There is no
abstract treasury. Workers and archers who are holding gold hand it over when they meet
him — that is how income reaches you.

- **Earned from:** felling marked trees, hunting (rabbit, stag), stripping marked bushes.
- **Spent on:** every construction and upgrade, job positions, marking work, and
  🔮 hiring and paying mercenaries.

> **Bandits do not drop gold. There is no corpse looting.** Night is a pure cost, never
> an income source. Do not add corpse-gold — it would make turtling profitable and remove
> the reason to explore.

**Current gap:** the purse is **uncapped**, for testing. `game_manager.coins` *is* the
purse, not a treasury — the name is the only abstraction.

**🔮 Future:** a purse **cap**, and a **Treasury** building to deposit the overflow into.
Once the cap exists, being hit should scatter coins (see §12).

### Timber — finite, and it is the run clock  ⚠️ partial

Trees **do not regrow**, and that is the point. The map holds a fixed stock of timber;
as it runs down the economy marches outward, and when it is close to exhausted the map
is over.

> ⚠️ **Do not add tree regrowth.** Depletion is the pacing mechanism for the whole run,
> not a bug. An earlier draft of this doc listed "the economy flatlines" as a problem to
> fix; it is a feature.

### Broth (soup) — recruitment  ⚠️ partial

Made in the cauldron; see §7.

### Labour (population) — citizens  ⚠️ partial

**Vocabulary: a *citizen* is a loyal villager** — one who has eaten and taken a job.
A *wanderer* has been drawn in but has not eaten yet and is not yours.

**Population is capped by the main building's tier** (§6). Soup recruits; the hall houses.

| | Citizen (soup) | Mercenary (coin) |
|---|---|---|
| Recruited by | Feeding the cauldron | Paying a bounty |
| Ongoing cost | 🔮 Soup upkeep at supper | 🔮 Coin upkeep at supper |
| Housed? | Yes — capped by hall tier | No |
| Does economy work? | Yes | No — pure combat |
| Permanence | Permanent | Temporary until settled |

## §6. The main building ladder  ⚠️ partial

One building, one progression. It is the kingdom's second heart and it sets the
population cap.

| Tier | Name | Status | Notes |
|---|---|---|---|
| L0 | Unlit campfire | ✅ | The hall does not exist yet |
| L1 | Tent | ✅ | Raised by lighting the fire — the one free tier |
| L2 | Wooden Hall | ✅ | Crew-built |
| L3 | Stone Hall | ✅ | Crew-built. Unlocks each wall's stone upgrade |
| L4 | Castle | ❌ | Not built |

> **Every paid tier is crew-built.** There are no instant upgrades anywhere in the game.
> L1 is the exception only because it is raised by lighting the fire, at a point when no
> villagers exist yet.

**Housing cap per tier is not implemented yet.** Today the only limit on population is
how often you refill the cauldron.

## §7. Cauldron & soup  ⚠️ partial

The emotional centre of camp, and the recruitment engine. **Recruitment is never a
button** — the verb is "keep ingredients flowing and protect the newcomers."

**Built today:** the pot fills as you pay, the soup level visibly rises and drops, each
villager who eats takes a serving, and any pot below full can be topped up. A full pot
draws wanderers in from the wild.
*Seams to build on:* `campfire.gd` — `take_serving()`, `_attract_villagers()`, fill level.

**🔮 Future — ingredients.** Cooks auto-haul farmed/hunted/foraged ingredients; the
monarch can personally dump wild ingredients as an early bootstrap and in emergencies.
Ingredients replace coin as the cauldron's input.

**🔮 Future — the supper & upkeep.** This is the pressure valve. At dusk the whole
population eats, not just newcomers. **No soup → morale drops → citizens desert.** Grow
faster than you can feed and the camp unravels.

**🔮 Future — recipes.**

| Soup | From | Effect |
|---|---|---|
| Thin Broth | Water + scraps | Bare survival, minimal morale — **but draws the most wanderers** |
| Hearty Stew | Meat + roots | Strong morale, night-long worker/soldier buff |
| Spiced / Medicinal | Rare herbs | Heals wounded, cures status |
| Feast | Everything, expensive | One night of big morale + defence; burn it before a blood moon |

> Thin Broth drawing the *most* wanderers is **deliberate**, not a typo: the cheapest soup
> attracts mouths you then cannot afford to feed.

**🔮 Future — forward kitchens.** A second cauldron at an outpost sustains and recruits at
the frontier, which is how the camp follows the timber outward.

## §8. Mercenaries  ❌ not built

The coin-fuelled counterweight to slow citizen growth: strong, pre-trained, temporary.

- **Hire:** merc camps in the mid/outer map. Ride out, pay a bounty up front, they follow home.
- **Upkeep:** pay each supper in coin. Miss it and they desert at dawn — and on a bad roll
  they pillage on the way out. Over-hiring is meant to be dangerous.
- **Settling:** a merc paid reliably for many nights may convert to a permanent citizen.
- **Archetypes:** Pikeman (holds chokepoints) · Crossbow (single-target) · Berserker (high
  damage, fragile) · Outrider (mounted, fast) · Siege Engineer (endgame objectives) ·
  Captain (buffs nearby mercs).

> **Blocked on §9.** Hiring is meaningless until there is a night threat. Do not start here.

## §9. Night, threat & the two hearts  ❌ not built

**This is the single biggest gap. Nothing can currently go wrong.** The walls, the
day/night cycle, the archer class and the gates all exist as setup for a threat that
does not exist yet.

**What the enemy does.** Bandits come down corridors at night and:
- **destroy walls and buildings** — damage persists and must be repaired with gold + a crew
- **kill citizens** — the slowest, most expensive loss, since replacing them needs soup

They do **not** drop gold and do **not** steal from the purse. Night is pure cost.

**Repair is construction.** A damaged wall or building becomes a construction site again —
same crew mechanic, same 3-worker cap. This makes repair one of the cheapest features to
add once combat exists, since `build_crew.gd` already does the work.

**Lose conditions — two hearts:**
- **The Crown.** Your body. No health bar. A stealer who takes the crown and sprints it to
  a portal ends the run — but your troops can intercept, and you can chase.
- **The main building.** Walls, huts and districts can fall and be rebuilt; only losing the
  hall is existential.

**Day/night cycle** ✅ is built — continuous sun sweep, eased dusk/dawn, golden hour, and
the campfire genuinely lights the camp. The **dusk supper ritual** ❌ and **night waves**
❌ are not.

## §10. The map run  ❌ not built

**Kingdom Two Crowns structure.** Each map is a region with objectives. You strip its
timber, complete its objectives, and move on — **carrying some progress forward**: the
monarch, some gold, and possibly a few citizens. The settlement itself is left behind.

This is what makes finite timber (§5) work: the clock running down *is* the signal to
leave, not a failure state.

**Open:** what the objectives are, and exactly what carries over. See §12.

---

# PART C — THE RECORD

*Changes often. Read this before proposing anything that contradicts it.*

## §11. Decisions & rationale

Things that look like bugs or oversights but are deliberate. **Do not "fix" these without
reading the reason.**

| Decision | Why |
|---|---|
| Hunting & foraging pay **gold**, not food | Keeps one currency in play until the soup economy (§7) exists. Food is the end state; converting early would leave nothing to spend. |
| Trees never regrow | Depletion is the run clock (§5). Regrowth would remove the reason to move to the next map. |
| No corpse-gold from bandits | Night must be pure cost. Corpse income would make turtling profitable and remove the reason to explore. |
| The purse is uncapped | Testing convenience only. The cap + Treasury is a real future feature, not an oversight. |
| Coins, pips, banners and prompts are 2D sprites in a 3D world | Billboards read from any camera angle. Deliberate, not an unfinished conversion (§4). |
| Adding a **job position** is instant, unlike every other purchase | A job is a decision, not construction. The villager walking over to fill it *is* the delay. |
| Every main-building tier costs a flat 5 | **Testing convenience only**, so play-testing isn't gated behind grinding gold. These are placeholder numbers and will be replaced by a real progression curve — see §12. Do not treat "all tiers cost the same" as a design principle. |
| A crew-built thing can't be bought with **no workers alive** | Otherwise gold vanishes into a site that would never be worked. The prompt says "needs a worker" instead. |
| Getting hit costs no gold | Deferred until the purse cap exists — with an uncapped purse a single hit could scatter an entire run's income. |
| `villager.gd` is one big state machine | The whole civilian life cycle belongs in one readable flow. Keep it commented, don't split it across files. |
| Crew speed is a **percentage**, not flat seconds | So the same rule applies to every build regardless of its base duration. |

## §12. Open questions

Genuine forks. **Do not silently pick one** — raise it.

1. **What are a map's objectives?** "Strip the timber" is the clock, but what actually
   marks a map as *complete*? Destroying bandit camps? Reaching L4 Castle? Something else?
2. **What exactly carries to the next map?** Monarch and gold, certainly. Citizens? How
   many? Does the main building tier reset to L0?
3. **What happens to the purse when the monarch is hit**, once the cap exists? Scatter a
   fixed amount, or the lot?
4. **Do markets and lootable ruins exist as coin sources?** Earlier drafts listed them.
   Corpses are ruled out; these are undecided.
5. **Is there a separate housing building**, or does the main building's tier alone set
   the cap?
6. **Does the day have a fixed length?** The vision says ~6–8 min; the implemented cycle
   length has never been checked against that.
7. **What is the real cost curve for the main building ladder?** Every tier is a flat 5
   right now purely so testing is fast. Real costs should climb enough to make each tier
   feel earned, without turning hold-to-pay into a chore (one coin per ~0.44s, so a
   30-gold tally is 13 seconds of holding `E`).
8. **Do the tier build-times need a curve?** Currently L2 is 25s and L3 is 40s, set by
   feel. L4 Castle will need a number, and the ladder may want a rule rather than
   hand-picked values.

## §13. Build order

Rough priority. Item 1 is what turns this from a toy into a game.

1. **Combat & night waves** — bandits down corridors, archers defend, buildings and
   citizens take losses, and the **two-hearts lose condition** (§9). Everything built so
   far is setup for this.
2. **Damage & repair** — cheap once combat exists; reuses `build_crew.gd` wholesale.
3. **Housing cap** tied to the main building tier (§6), so population has a real ceiling.
4. **The supper ritual + soup upkeep** — morale, desertion, and the pressure valve (§7).
5. **Ingredients** replacing coin as the cauldron's input (§7).
6. **L4 Castle** (§6), and map objectives (§10).
7. **Mercenaries** (§8).
8. **Indirect control polish** — rally banners, bell, horn (§3).
9. **Audio.** There is none at all — no `AudioStreamPlayer` anywhere in the project. The
   cheapest available win for a game whose pitch is atmosphere.

---

## Appendix — retired systems

The coin-recruit **peasant** system (`peasant.gd`, `job_station.gd`, `base_manager.gd`) has
been deleted. It predated the cauldron flow and violated Pillar 2 by recruiting with coin
instead of soup. Do not reintroduce recruitment-for-gold.
