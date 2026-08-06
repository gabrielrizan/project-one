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

**Cousins in §9:** 🔮 **hermits** are the peaceful half of this idea — rescue NPCs found at
the map edge who settle for a one-off price and bend a single rule, rather than fighting
for wages. And 🔮 **destroyable bandit camps** are what mercenaries are *for*: the first
thing worth marching out to do.

## §9. Night, threat & the two hearts  ❌ not built

**This is the single biggest gap. Nothing can currently go wrong.** The walls, the
day/night cycle, the archer class and the gates all exist as setup for a threat that
does not exist yet. This section is the design for that threat; nothing in it is built.

**The fantasy.** Build by day, survive by night. The dusk horn tells you what kind of
night this is. Bandits march up the corridor from a camp you can see on the horizon.
Archers climb the wall and shoot down into them. The rooster ends it, and dawn is for
repairs and re-recruiting the people who were robbed.

### Bandits — who they are

The night's answer to wanderers: raiders who come for your people's **tools**, not your
gold. The purse is never touched (§5), and there is no corpse-gold (§11).

**Visuals are placeholder-then-pack.** For now: `villager.glb` flat-tinted charcoal with
`MarkFx.tint` — the palette-flattening that makes tint wrong for most models is exactly
right here, giving featureless dark silhouettes in Kingdom's Greed register — carrying a
Kenney pickaxe or club scaled into the hands. The final look is a downloaded character
pack, chosen later with Andrei under the usual ask-first, record-the-licence rule.

### The night clock

A raid director (`night_raids.gd`, built like `wildlife.gd`) owns a **night counter**,
ticked off the same `darkness()` threshold the horn watches — **never off the clock**,
since day and night durations are placeholder. Nights 1–2 are a grace period. From night 3
waves grow on a data table: roughly 2 bandits, +1 every couple of nights, capping around 8.

> ⚠️ Those are **placeholder numbers**, exactly like the flat-5 hall costs. Wave sizes are
> a tuning pass, not a design statement.

**Every 15th night is a blood moon.** Horn ×3 at dusk, the night sky blended toward deep
red, waves 2.5–3× arriving in two or three pulses, mixed with Brutes. The red is a `blood`
factor in `day_night_cycle.gd` built exactly parallel to `storm`: the cycle stays the one
owner of the environment, and it is applied *after* the time-of-day blend so a blood moon
still reads as night. At the current cycle length that is roughly an hour of play between
blood moons — see §12 for whether the cadence or the cycle length is the number that moves.

### The dusk horn announces the night

The blast-count vocabulary already exists and was built for exactly this:

| Blasts | Means |
|---|---|
| 1 | a quiet night |
| 2 | a raid is coming |
| 3 | blood moon |

`sound_alarm()` (two blasts) stays available for a mid-night surprise. Telegraphing
*where* is the camp's own fire flaring at dusk — ember particles and an omni light out at
the treeline, no new assets, and nothing volumetric that `gl_compatibility` can't do.

### The map is terrain-gated

Kingdom's world is linear, so it only ever has two fronts. This game gets the same
property by **closing bearings of every map with impassable terrain**: a mountain, a
river, a wood too dense to pass.

Implementation truth: a terrain gate is **one invisible box collider dressed in scenery**.
The navmesh bakes from static collision, so a single hidden box seals a bearing with no
per-prop bookkeeping, and the world stays one flat slab — there is no elevation anywhere,
and a "cliff" is a rock mass standing on flat ground. **Closed bearings carry no wall
offers at all** — their `WallSide` markers are simply not in that map — so every wall you
*can* buy is a wall that can matter.

**The first map is a mountain U with a single entry.** Three bearings sealed by the
mountain, one open corridor, the bandit camp beyond its mouth, and the one surviving
`WallSide` across it. A pure siege map, and the clearest possible teaching shape: one
door, one wall, one fight. Later maps take their identity from how many openings they
have — a two-opening river map plays front-and-flank, a three-opening plain plays thin.

Side effects to honour: wanderers, wildlife and the walk-in ring belong on open ground,
and 🔮 a mountain pass (or a castle-kit bridge on a river map) is the natural place to put
the §10 "leave the map" exit.

### Fronts — where raids come from

Raids never come from nowhere. Every wave marches from a visible **bandit camp** — a
survival-kit tent and fire pit, ember-lit — sitting on an **open** bearing. Map 1 has one
opening, so it has exactly one camp, and its blood moons escalate that same front.

On a multi-opening map a blood moon may establish a **new camp, found smoking at dawn** on
another open bearing; the camp appearing *is* the telegraph. Archers are mobile between
walls, so one corps covers whichever front wakes up.

> 🔮 **The payoff loop: camps become destroyable.** Ride out with mercenaries (§8), burn
> one, and that front closes for good. That is the strongest candidate for the map
> objectives §12 is still missing, and the first reason the military ever leaves home.

### Openings and bandit patience — why the second wall matters

Terrain answers most of the redundancy problem; what is left is the open bearing you have
not walled yet. An unwalled open side is an *entrance*, not scenery — the village centre
is the target, and a raid that starts east can walk in through an open south.

This is staged so walls gain value in the same order you can afford them. Early bandits
are **Thugs**: impatient, they hammer whatever is directly in front of them, so one wall
on the camp's bearing genuinely is enough. Later waves mix in **Flankers**, patient
raiders whose rule is "find an unbuilt open side or a breach and walk in" — a small
targeting rule, since the *movement* is free: the navmesh already flows through any gap
after a re-bake. Enclosing the open bearings becomes a mid-game goal rather than an
up-front tax. **Where a raid starts is the camp's choice; where it gets in is yours.**

Two reinforcements come for free. Timber depletion marches the loggers toward the
treeline — that is, toward the camps — so the bearing you are currently logging is
naturally the hot one, and workers in the field are robbery bait. And 🔮 the archers' hut
is already a tower model, so it can voice the watch at dusk ("camps: E, S") and let you
build exactly what the information justifies.

### What bandits do — priorities

**1. Rob.** Any *employed* citizen within reach is knocked down, and their tools are torn
off: the model swaps back to the bare villager, the workplace's `filled` count drops so
its vacancy icon returns, and the victim gets up as a hungry wanderer who must eat again
before working. Wanderers carry nothing and are ignored — your **workforce** is the
target, and a posted archer is the richest prize on the map. A thief who succeeds
shoulders the bundle and **leaves, satisfied**: every bandit wants one theft.

**2. Smash what blocks the way.** Paths route through gateways, so it is the *shut gate*
that physically stops a raider — which makes the gate the weak point with no targeting
code at all. Raiders hammer whatever they are wedged against (the wants-to-move-but-isn't
signature `_unstick` already detects), and a crowded gate spills onto the wall sections
either side.

**3. Vandalise.** Inside, with nothing robbable in sight, they attack the nearest
building. Huts fall and are rebuilt; **the hall falling is existential** (below).

**4. Rout at dawn.** At first light survivors turn and run for their camp, and despawn at
the edge. Being shot in the back on the way out is fine and satisfying.

Bandits **ignore the monarch entirely** for now — the crown is the Stealer's job, and that
archetype waits on the purse cap (§11).

### Structure damage, breach, repair

Walls, gates, huts and the hall carry HP, scaled by material. Damage is **visible per
section**: wood sections tilt and sink away (the reverse of how they went up), and stone
swaps `wall.glb` for `wall-half.glb`, which the castle kit ships as a ready-made ruin. A
gate at zero loses its leaves; a wall arc at zero loses its collision box. Either way
`NavWorld.rebake()` makes the hole real and raiders stream through it.

**Repair is construction.** A damaged thing re-enters `build_site` at a progress equal to
the fraction still standing, and costs `ceil(build cost × missing fraction)` — a
percentage rule, per the house rules, so one rule covers every structure in the game.
`build_crew.gd` does the rest unchanged, which is what makes this cheap. Paying for
repairs *during* a raid is allowed, dramatic, and dangerous.

### Citizens at night

They organise themselves — pillar 1 applies to fear as much as to work. At the dusk horn
idle civilians drift inside the walls and toward the fire; a bandit within a few metres
sends any civilian running for it, the same way wildlife spooks. Workers on a paid site
keep working. Anyone knocked down gets up a few seconds later and flees as a wanderer.

### The army

**v1 — archers mount the walls.** When the dusk horn counts a raid, or bandits turn up
mid-night, free archers claim **wall perches**: predefined spots along the top of each
built wall side, **six per side, filled centre-first**. The literal centre is the gate
opening, so the spots flank it — and fire concentrates exactly where raiders mass.
Claiming runs through the same duck-typed flow as every other errand; there is never a
player order.

Getting up there is a walk to the wall's inner face on the ground mesh, then a **scripted
climb tween** onto the marker. Perches are parked stations, **never walkable navmesh**
(§11). From up top the existing hunt loop does the shooting, against the `bandit` group at
a longer defensive range; the height means arrows clear the wall with no special casing.

**When the last bandit falls or flees they climb down** and drift back to the fire. On a
quiet night they never mount at all — so *archers on the walls* is itself the picture that
says a raid is coming. With no wall on the raided side they ring the campfire instead: the
fire is the last line. If the section under a perch breaks, or a bandit reaches them after
a breach, an archer hops down and flees like any civilian, re-posting once it is clear —
so a fallen wall scatters your army, the Kingdom disaster spiral, out of two simple rules.

> ⚠️ **The wood tier will look wrong first.** The wood palisade's visual is `fence.glb` at
> 0.52m against a 1.5m collision box, so an archer perched on it half-floats. Either the
> wood wall's visual gets raised in an art pass or the float is accepted as placeholder
> until the stone upgrade, whose `wall.glb` has a real parapet and reads perfectly. §12.
> The perch *system* is identical either way.

**🔮 Watchtowers.** A later flank upgrade per wall side, crew-built from the castle-kit
tower stack, exposing two elevated stations each. Posting stays automatic and claim-based:
archers fill **every tower's first slot before any tower's second**, and overflow takes
the wall perches — so three towers and four archers puts one archer on each tower and the
fourth doubled up or on a wall. Entry is the same walk-then-climb-tween; still no wall-top
navmesh, ever. Archers are **visibly parked** up there, because a garrison whose window
merely spits arrows costs you the ability to see your own defence. Perks: more range, and
melee immunity until siege units exist to threaten them.

**🔮 Knights.** A later melee job — `job_type: "knight"` drops straight into the existing
workplace string system — from a Barracks or a hall unlock, holding the gateway line.
Waits on the same character-pack decision as the bandits.

**🔮 The one tactical lever** remains the rally banner (§3): when it exists, planting one
biases which sides get posted. Not designed further here.

### 🔮 Escalation roster

Archetypes as a stat-block dictionary, the way `GAITS` and the animal species already
work — adding one should cost an entry, not a rewrite.

| Archetype | When | What it does |
|---|---|---|
| **Thug** | from night 3 | The baseline. Impatient: hits what is in front of it. |
| **Flanker** | mid-game | Patient. Seeks unbuilt open sides and breaches — the reason full enclosure earns its gold. |
| **Prowler** | any night, 1–2 | Circles and probes off-front sides. Never breaches a wall; robs stragglers on open ones. |
| **Brute** | blood moons | ~1.3× scale, slow, several arrows to drop, heavy structure damage. |
| **Stealer** | with the purse cap | Fast, avoids fights, snatches loose coin — and eventually the Crown itself. The reserved lose-condition-#1 threat. |
| **Siege** | late blood moons | A crewed ram for gates, perhaps a catapult lobbing from range. The castle kit ships ram, catapult and trebuchet **with demolished variants**, so a destroyed state costs nothing. |

> Player-side artillery, if it ever exists, must be a paid emplacement that works by
> itself. An orderable siege unit is an RTS unit (§2).

**🔮 Hermits.** Rescue NPCs found at the map edge by day: ride out, pay their asking
price, and they settle by the fire and bend exactly one rule — a mage lighting arrows, a
warden adding a station to each tower, a cook adding to the pot. Same
buy-by-standing-in-front-of-it grammar as everything else, and a close cousin of the merc
camps in §8.

### Audio

Most of a bad night can be built from clips already in the project: the horn's two- and
three-blast signals (wired), bow and arrow-hit, the axe pool pitched down for blows on
timber, `animal_drop` near unity pitch for a body hitting the ground, `tree_fall` for a
wall section going over, and the gate slam as breach punctuation.

Genuinely missing, and to be sourced with Andrei when the time comes: stone impacts, a
breach crash, a knockdown thump, bandit vocalisations, and a blood-moon layer under the
night bed. `ASSETS.md`'s standing warning applies — there is no ducking and no limiter, so
a night wave will fight the ambience beds with nothing arbitrating between them.

### Lose conditions — two hearts

- **The Crown.** Your body. No health bar. A stealer who takes the crown and sprints it to
  a portal ends the run — but your troops can intercept, and you can chase. **Not in v1:**
  bandits ignore the monarch until the Stealer archetype and the purse cap exist.
- **The main building.** Walls, huts and districts can fall and be rebuilt; only losing the
  hall is existential.

**Day/night cycle** ✅ is built — continuous sun sweep, eased dusk/dawn, golden hour, and
the campfire genuinely lights the camp. The **dusk supper ritual** ❌ and **night waves**
❌ are not.

### Dev tools

Waves and blood moons are minutes apart, so every one of them needs to be reachable
instantly from the F1 overlay — one `ACTIONS` entry each: raid now · blood moon now ·
clear all bandits · advance the night counter. The readout gains the night number and how
many nights until the next blood moon.

## §10. The map run  ❌ not built

**Kingdom Two Crowns structure.** Each map is a region with objectives. You strip its
timber, complete its objectives, and move on — **carrying some progress forward**: the
monarch, some gold, and possibly a few citizens. The settlement itself is left behind.

This is what makes finite timber (§5) work: the clock running down *is* the signal to
leave, not a failure state.

**Open:** what the objectives are, and exactly what carries over. See §12.

## §10a. Weather & seasons  ⚠️ partial

*Numbered `10a` so §11–§13 keep the numbers the rest of the docs reference.*

**Rain, overcast skies, water pools and distant thunderstorms, gated by a season clock.**
Built, and **atmosphere only** — it is seen and heard, and changes nothing you can play.
That was a deliberate scoping call, not an oversight.

The register is the same one §4 sets for everything else: **stylised, not photoreal.** The
renderer has no volumetric fog, so the haze is depth fog plus a drifting mist layer, and
the pools are shader-driven quads rather than decals. That is a fit with the art direction
rather than a compromise forced by it — the storm is art-directable, which a physical one
would not be.

**Seasons currently gate rain and nothing else.** Four of them, three day/night cycles
each. Spring is wet and mild, summer rarer but violent and thundery, autumn steady and
grey, and **winter is dry** — a placeholder standing in for snow, which is not built.
Seasons have no visual identity yet: no tree recolouring, no palette shift. Andrei's call
was to keep it simple for now and let snow and colour come later.

**🔮 Future:** snow and per-season colour · the gameplay hooks in §12 · weather as a
*told* thing rather than only a seen one (a horn, villagers reacting), if it ever earns a
gameplay role.

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
| Weather is **atmosphere only** | Scoped that way on purpose. Rain that slows building or spoils food is a real balance decision and belongs in §12, not smuggled in alongside the visuals. |
| **Winter has no weather at all** | It is a placeholder for snow, which isn't built. A dry season is the honest stand-in; faking winter with rain would be worse. |
| Wetness is a **separate clock** from rain intensity | Pools that appear and vanish with the rain read as a light switch. Lagging saturation is what gives a shower an aftermath. |
| Rain leans along the **existing** wind bearing | `wind.gd` already owns one shared bearing for the trees and leaves. A storm with its own direction would read as two weathers at once. |
| All thunder clips come from **one** recording | Thunder from several sources sits in several different distances and airs, and the pool stops sounding like a single storm. |
| A storm **swells and eases** rather than holding at its peak | Otherwise every storm has the same shape — up, flat, down — and only its height and length differ, which is what makes weather feel canned. |
| Most storms **never reach full intensity** | Peak is drawn per storm from the season's band, and only summer's reaches 1.0. A true downpour should be an event, not the default. |
| The near thunder is picked by **distance, not at random** | The one clip with a crack on it would otherwise land on a storm sitting on the horizon. A sharp report arriving nine seconds after the flash contradicts what you just saw. |
| Lighting the campfire has **no sound of its own** | Andrei's call. The crackle loop starting is enough of an event; a whoosh on top read as a sound effect rather than a fire. |
| Bandits **rob citizens, they don't kill them** | Recoverable losses are what pillar 4 asks for. Each robbery costs a serving of soup and the walk back, so night pressure drains the cauldron — a legible economic wound rather than a body count. **Supersedes** an earlier draft of §9 in which bandits killed citizens outright. |
| A thief who has robbed someone **leaves** | Every bandit wants one theft, so a wave resolves without requiring total slaughter. That is the Kingdom rhythm: you are surviving a night, not clearing a level. |
| Bandit art is **placeholder-then-pack** | The character generator is gone, so nothing new can be generated. Tinted villager silhouettes unblock the whole design while the character-pack choice goes through the ask-first licence flow. |
| The **gate is the weak point by physics**, not by script | Bakes route paths through gateways and the shut gate is what stops bodies, so raiders mass there on their own. Writing a "target the gate" rule would be re-implementing something the navmesh already does. |
| The **dusk horn announces the night type** (1 / 2 / 3) | The blast-count vocabulary was built for exactly this, and the gap between blasts was tuned so it stays countable. The player waits on the horn to learn what kind of night this is. |
| Archers fight from **wall perches**: centre-first, six a side, combat only | Centre-first concentrates fire over the gate raiders mass at. Mounting only on raid nights makes archers-on-the-wall itself the danger signal. The cap stops one side soaking up the whole corps once a map has several fronts. |
| **Wall tops are perches, never navmesh** | The 0.5m-deep wall erodes to zero walkable cells at a 0.3 agent radius; `filter_ledge_spans` and the deliberately tiny `agent_max_climb` both exist to fix documented bugs and would need re-tuning; and no villager has Y-axis movement at all. A parked shooter needs no pathfinding, and with fixed posts, walking the parapet buys nothing. Revisit only if *patrolling* walls ever becomes a design need. |
| Maps are **terrain-gated**, and closed bearings carry no wall offers | Kingdom's linear world rebuilt in 3D: the map limits how many fronts exist, so every wall you can buy is one that can matter. A gate is one invisible box collider dressed in scenery — free to the navmesh, which bakes from static collision — and the slab stays flat: there is no elevation anywhere. |
| Raids come from **visible camps**, never a random bearing | A random bearing makes every wall mandatory and every unwalled side a nightly coin-flip — the redundancy problem inverted. A camp you can see makes a wall an informed bet, new camps re-price that bet mid-run, and destroyable camps eventually give the military something to do offensively. |
| Early bandits are impatient; **Flankers arrive with escalation** | One wall on the camp's bearing genuinely works early, and patient flankers later make every open side a liability. Walls gain value in the same order the player can afford them, so enclosure is a goal rather than an up-front tax. |
| Rejected: tear-down refunds · random-bearing raids · walls with economic bonuses | The three tempting answers to wall redundancy. Refunds invite min-maxing against the spirit of committed building; random bearings make all walls mandatory; giving walls a second, economic job is forced justification for a defensive structure. |
| **Bandits ignore the monarch** for now | The crown threat belongs to the Stealer archetype, which waits on the purse cap — consistent with getting hit costing no gold for the same reason. |
| **Blood moon every 15th night**, as a fixed constant | Andrei's requested cadence. It is tunable, and how it interacts with cycle length is an open question (§12), not a principle. |

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
9. **Should weather ever affect play, and how much?** It is atmosphere only today
   (§10a). The candidates, roughly in order of how much they'd change the game: archers
   not hunting in rain · builders slower or sheltering · the campfire guttering and
   needing tending · rain helping or hindering a night attack once combat exists. The
   risk is the pillar in §1.3 — the day/night cycle is the heartbeat, and a second
   uncontrollable clock that gates your economy could easily feel like being punished by
   the sky rather than being tested by it. **A weather effect the player can do nothing
   about is a tax, not a mechanic.** Anything adopted here probably needs a response the
   monarch can actually buy.
10. **What is winter?** Snow is the obvious answer, but snow is a bigger job than rain
    (ground cover, tree caps, a palette shift) and it raises the same question as §12.9 —
    does a season *do* anything, or is it only a change of clothes? Right now winter is
    simply a dry spell.
11. **How long should a season be?** Three day/night cycles (~12 min) was picked so a
    test session sees more than one, not from any feel for pacing. It has never been
    played against the map run in §10.
12. **Which character pack for bandits and knights?** Nothing can be generated any more
    (§ASSETS), so this is a download decision: Andrei's approval, a licence recorded. And
    does a pack sit *beside* the procedural cast, or eventually replace it wholesale?
    A rigged, detailed pack next to tween-animated villagers may not sit right.
13. **Should a recovered bundle re-kit its victim?** Killing a fleeing thief drops nothing
    today. Letting the bundle come back — restoring the robbed citizen's job without
    another bowl of soup — would reward defending hard, at the cost of softening the
    robbery's whole point.
14. **Do gates hold shut when a bandit is near?** Bolting them (say, within 6m) protects
    the interior and creates a real "get everyone home before dark" ritual, which is
    exactly what the lead-wanderers-home verb in §3 wants — but it locks latecomers out
    to be robbed. Lean: yes, bolt them.
15. **Blood-moon cadence versus cycle length.** Fifteen nights is about an hour of play at
    the current placeholder durations. If that is too long a wait, which number moves —
    the cadence, or the day length §12.6 has never checked?
16. **Does wave size scale on anything but the night count?** Village wealth or hall tier
    would make a rich camp a bigger target, which is either good pressure or a punishment
    for playing well.
17. **How much combat audio gets sourced up front?** The reuse set (axe, arrow, tree-fall,
    gate slam) can carry a first pass, but stone impacts, a breach crash and bandit
    vocalisations are genuinely missing. Related and unavoidable: the mix has no ducking
    and no limiter, and a night wave is the first thing that will really fight the beds.
18. **How long is the grace period, and does night 2 teach?** Two quiet nights is a guess.
    A single-bandit "lesson raid" on night 2 might teach the horn and the walls better
    than silence does.
19. **Are perched archers always visible?** Lean: yes — seeing your own defence is worth a
    lot. But a garrison model (archer enters, arrows come out of a window) is cheaper and
    fine for any structure whose top the camera cannot see.
20. **What fixes the wood-tier perch float?** `fence.glb` is 0.52m tall, so an archer
    standing on the wood palisade floats. Raise the wood wall's visual (a fortified fence,
    stacked sections), or accept it as placeholder until the stone upgrade?
21. **How do camps multiply on a multi-opening map?** Does every blood moon roll for a new
    one or follow a schedule — and should camps stay off the bearing wanderers walk in
    from, so recruitment and raids never share a side? (Map 1 has one opening, so this
    only bites later.)
22. **Which bearing is the first map's mouth, and where is the exit?** South is proposed,
    which keeps the rooster's fixed north-east spot clear of the corridor. And when §10
    exists, is the way out a mountain pass or a bridge?
23. **Do camps migrate, and do Prowlers exist early?** Both are optional layers on the
    redundancy answer: a camp that packs up and reappears on another open bearing makes
    already-built walls value-in-waiting, and early prowlers would make off-front walls
    petty-theft insurance rather than dead weight.
24. **Where do wanderers actually come from?** Raised by Andrei playing the island
    (2026-08-02) and **deliberately left open** — he chose to revisit it after F6/F7
    rather than answer it now. On the land maps "they walk in from the wild" is
    unexamined but not wrong; ring the map with water and the player *will* ask, because
    a spawn lane on a beach has no visible cause. Three answers on the table, and they
    are not exclusive:
    * **By boat.** A rowboat lands, two or three get out, it leaves. Costs no new
      mechanic — the walk-in lane already exists and only gains a cause — and F7 is
      bringing a boat kit in anyway. Makes the sea a *source* as well as a wall.
    * **Survivor camps on the island.** The Kingdom-canon answer: small vagrant camps
      found by exploring, which makes scouting pay before §F6's chests exist. But the
      population is finite unless something refills them, so it cannot be the only tap.
    * **Shipwreck survivors**, tied to F7's two wrecks, which already imply people came
      ashore and never left.
    Whatever is chosen has to keep Pillar 2 intact: soup recruits, coin never does.

## §13. Build order

Rough priority. Item 1 is what turns this from a toy into a game.

1. **Combat & night waves** — now designed in full (§9), and broken into eight
   playtest-sized tasks in **`COMBAT_PROMPTS.md`**, which is the working plan:

   | | |
   |---|---|
   | **P1** | The mountain map — terrain gates, one corridor, one wall side |
   | **P2** | The bandit body — marches, piles at the shut gate |
   | **P3** | The raid director — night counter, wave table, camp, the horn that counts |
   | **P4** | Archers mount the walls — perches, the climb, the combat shot |
   | **P5** | Robbery — knockdown, tools taken, the victim re-recruited |
   | **P6a** | Walls break and mend — HP, breach, repair-as-construction |
   | **P6b** | The hall can fall — the lose condition |
   | **P7** | The blood moon — every 15th night, red sky, Brutes |
   | **P8** | The sound of a bad night — reuse wired, gaps listed |

   *(Damage & repair used to be item 2 here; it is P6a/P6b now, since it is the same
   feature as combat rather than a follow-up to it.)*
2. **Housing cap** tied to the main building tier (§6), so population has a real ceiling.
3. **The supper ritual + soup upkeep** — morale, desertion, and the pressure valve (§7).
4. **Ingredients** replacing coin as the cauldron's input (§7).
5. **L4 Castle** (§6), and map objectives (§10) — where destroyable camps (§9) are the
   leading candidate for what an objective actually is.
6. **Mercenaries** (§8), which combat finally gives a reason to exist.
7. **Indirect control polish** — rally banners, bell, horn (§3).
8. **Music.** Still not one note — see `ASSETS.md`. Effects are well past "none" now, but
   a game pitched on atmosphere has no score, and a night wave has nothing to lift it.

---

## Appendix — retired systems

The coin-recruit **peasant** system (`peasant.gd`, `job_station.gd`, `base_manager.gd`) has
been deleted. It predated the cauldron flow and violated Pillar 2 by recruiting with coin
instead of soup. Do not reintroduce recruitment-for-gold.
