# Combat — the implementation prompts

Eleven tasks, one session each: a prerequisite restructure (P0), the combat design from
`GAME_DESIGN.md` §9 (P1–P8), and the map-objective loop from `ROADMAP.md` (P9–P10).

**`ROADMAP.md` now governs map progression** — five maps, a five-tier hall ladder,
knights on map 2, camps burned by mustered archers. These prompts were revised against
it on 2026-07-24; where it and §9 disagree, the roadmap is newer and wins.

**Run them in order.** Each assumes the previous one landed. Each is meant to end in
something Andrei can actually play, so the design gets corrected by playing rather than by
arguing — which is why "bandits that can't hurt you" and "archers that shoot" are separate
tasks from "walls that break". The two exceptions to strict order: P9 needs only P4, and
P10 needs P3 + P9 — the objective loop can land before P6–P8 if a playable map 1 matters
sooner than breakable walls.

Paste one prompt per session, under this preamble:

> Read `kingdom_demo/GAME_DESIGN.md` §9, `kingdom_demo/ROADMAP.md` and `CLAUDE.md`
> before touching anything — especially the gotchas, which cover most of what is hard
> here. Implement **only** this task; if you spot something adjacent worth doing, say so
> and leave it. Costs and timings are placeholder unless §9 says otherwise. When it
> works, hand it to Andrei to play-test with an AskUserQuestion report rather than
> proving it with a long automated run.

---

## P0 — The five-tier ladder *(prerequisite — not combat, but everything below assumes it)*

The hall restructure decided in `ROADMAP.md` R2: **L1 Tent (free) → L2 Upgraded Tent →
L3 Wooden Town Hall → L4 Stone Hall → L5 Castle.** Knights later hang off L4 and
emplacements off L5; neither is built here — this task is the ladder itself.

- Target heights ~1.5 / 1.75 / 2.0 / 2.5 / 3.0 m and pop caps `[6, 8, 10, 13, 16]`
  (`TIER_CAPS`) — placeholder like every cost. L2's model: survival-kit tents composed
  bigger than L1 and visibly smaller than L3's composed hall; it only has to read as a
  rung. L3–L5 keep their `HallBuilder` compositions.
- `building.gd` holds three flat upgrade slots (`upgrade_*`, `upgrade2_*`, `upgrade3_*`).
  **Don't add `upgrade4_*`** — four copies of five exports is past the pattern's limit.
  Refactor to a tier *array* (the `LEVELS`-table shape `wall_side.gd` already uses), and
  move `campfire.gd`'s spawn args, `hall_tier()` and `villager_cap()` onto it.
- **The wall gating remap.** "Wall level index *is* the required hall tier" breaks at
  five tiers. `wall_side.gd::LEVELS` gains an explicit `requires` per level: twig→**L1**,
  wood→**L3**, stone→**L4**, fortified→**L5**. `hall_tier()` now returns 1–5. Update
  `CLAUDE.md`'s wall-ladder section in the same pass — it documents the old invariant as
  the reason there is no requires field.
- **Per-map tech cap**: one constant for now (`hall_cap`), respected by the upgrade
  checks; map 1 ships `hall_cap = 3`, so stone and fortified are simply unreachable —
  the upgrade prompt never appears past the cap. The **mine shaft** (map 2's L4 gate) is
  *not* built here; it is a map-2 task and is a per-map flag exactly like
  `stone_unlocked` used to be.
- While in there: `game_manager.stone_unlocked` and `building.upgrade2_unlocks_stone`
  are already dead (see `CLAUDE.md`'s wall-ladder note) — this refactor is the natural
  moment to delete both.

**Hand-off:** climb the whole ladder with dev gold. Does each rung read as growth from
the last? Does wood unlock at L3 and the wall prompts respect the remap? Does map 1's
cap refuse quietly (no prompt), not confusingly?

---

## P1 — The mountain map

Reshape the first map into the U from §9: the village sits in a mountain's arms with a
single entry.

- Seal three bearings with **invisible box colliders** (`StaticBody3D` + `CollisionShape3D`,
  no mesh), inside `NavWorld.EXTENT` (26m) so they actually bake. Dress them with
  scaled-up Kenney rock masses — **decorative only, no colliders on the props**; the boxes
  do the blocking, so the navmesh has one clean edge instead of fifty.
- Leave the remaining bearing open as a corridor, at least 8m clear.
- The world stays **one flat slab**. No elevation, no ramps: a mountain here is a rock
  wall standing on flat ground.

  > **Real elevation was considered and deliberately deferred** (decided 2026-07-22, with
  > the depth work). The long-term intent is terrain-gated maps — a village in a hill's
  > arms, a river closing the back — and the U here is the flat stand-in for that. Revisit
  > it as its own project, not inside a combat task, because the cost is not the ground
  > mesh:
  >
  > - **The navmesh is tuned flat on purpose.** `nav_world.gd` runs `cell_height = 0.1`
  >   and `agent_max_climb = 0.2`, both at the floor *because* nothing has height. Slopes
  >   force them up into exactly the range where a 0.7m bush once came out as a climbable
  >   step and villagers oscillated against it — and "the navmesh and physics disagree
  >   about what is solid" is the signature of the worst bug class in this project.
  > - **~103 sites across 19 scripts assume the ground is y = 0** — wanderer walk-in,
  >   the wildlife ring, decor scatter, puddles, building placement, spilled coins. Each
  >   becomes a ray-to-ground.
  >
  > For reference, Thronefall does use real authored elevation, but it also uses **fixed
  > build slots** and **fixed enemy lanes**, so it never places a building on an arbitrary
  > slope or paths freely over terrain. Copying the look means copying that authoring
  > model too. If elevation is ever picked up, adopt fixed build slots in the same move.
- Delete the three `WallSide` nodes on the closed bearings from `kingdom_demo.tscn`; keep
  the one across the corridor. Closed bearings offer no walls (§11).
- **Map 1 is capped at L3 Wooden Town Hall** (P0's `hall_cap`) — wood walls are this
  map's ceiling, and no mine shaft exists here (map 2 feature, `ROADMAP.md` R2b). One of
  the sealing mountains should still *read* as minable-someday: bare rock, no dressing
  trees, so map 2's shaft has a family resemblance to come home to.
- Move any tree or berry bush now inside the rock, and bias the wanderer walk-in
  (`campfire.gd::_attract_villagers`) and the wildlife ring (`wildlife.gd`) onto open
  ground — a wanderer spawning inside a mountain is stuck forever.
- **Grep the `.tscn` afterwards** to confirm the edits survived (the editor overwrites
  hand-edited scenes — see `CLAUDE.md`).

Verify by riding the perimeter with **F3** navmesh debug on: no walkable polygons inside
the rock, no path through it, and a clean path down the corridor.

### What a new map actually touches (checked 2026-07-23)

Most systems don't care where the map is — day/night, shadows, weather, fog, the hall and
wall ladders, hold-to-pay, the camera and its presets all read the world at runtime or
follow the monarch. Building a new map is mostly **moving nodes and retuning a handful of
constants**, not reworking systems:

- **Place nodes:** the four `WallSide`s, the `Campfire`, the `Monarch` start, the ground
  mesh + collider. The village now spawns as **offsets from the campfire**
  (`campfire.gd::_spawn_village`), so moving the fire moves the whole village — you no
  longer hand-place three buildings per map.
- **Retune constants:** `world_decor.gd` (`inner_radius`/`outer_radius`, plus its three
  hardcoded path strips and four hill spots — this is map dressing, expect to rewrite it),
  `campfire.gd::WANDER_IN` (walk-in ring), `wildlife.gd` (`INNER`/`OUTER` spawn ring).
- **⚠️ `nav_world.gd::EXTENT = 26.0`** is the bake half-extent. If the playable area grows
  past ~52×52 m you **must** raise it or the navmesh silently stops at the old edge.
- Everything tuned for the *camera* (fog band 22–55 m, `GoldFx` pip scale, world-space
  prompt `pixel_size`) only moves if the **camera** changes, not if the map does.

**Hand-off:** does the mountain read from all four camera angles (Z/X)? Is the corridor
the obvious way in? Anything spawning stuck?

---

## P2 — The bandit body

One bandit that walks. No spawner, no combat, no damage.

- `bandit.gd` + `bandit.tscn`: `CharacterBody3D` with a `NavigationAgent3D` and a
  `NavMover`, built like `villager.tscn`. Group: `bandit`.
- Placeholder look (§11 — placeholder-then-pack): `villager.glb` flat-tinted charcoal with
  `MarkFx.tint`, plus a Kenney `tool-pickaxe` scaled into the hands. Model under a `Model`
  holder facing +Z, with the villager's walk bob.
- Two states: **MARCH** (path to the hall, falling back to the campfire) and **IDLE** on
  arrival. That is all.
- Two dev overlay `ACTIONS` entries: spawn a bandit at the corridor mouth, and clear all
  bandits.

Verify: spawn several. They should walk up the corridor and **pile up against a shut
gate** — the navmesh routes them through the gateway and the closed gate physically stops
them, with no targeting code. If they walk *through* the gate, the gate is opening for
them: it should only open for `monarch` and `villager`.

**Hand-off:** does the march read as menacing at this pace? Is charcoal-on-green readable
at night, or do they vanish?

---

## P3 — The raid director, and the horn that counts

Nights become different from each other.

- `night_raids.gd`, a node in the main scene, built like `wildlife.gd`.
- A **night counter ticked off `darkness()` crossing a threshold — never off the clock**
  (durations are placeholder; this is why the horn already works that way).
- Grace on nights 1–2. From night 3 a wave table: ~2 bandits, +1 every couple of nights,
  cap ~8. **Comment it as placeholder**, like the flat-5 hall costs.
- A **camp** at the corridor mouth: survival-kit tent, fire pit, and an ember `OmniLight3D`
  whose fire flares at dusk when a raid is coming. Waves spawn here, staggered rather than
  all at once. Build it as its own scene (`bandit_camp.tscn`, group `bandit_camp`) rather
  than loose nodes, and have the director read camps **from the group** — P10 makes camps
  burnable and maps 2+ have several, so the camp is an object with a lifecycle, not
  scenery.
- Extend `ambience.gd::_watch_the_light` to ask the director what tonight is, and blow the
  dusk horn accordingly: **×1 quiet, ×2 raid**. Leave the ×3 path for P7. `sound_alarm()`
  stays for a mid-night surprise.
- At the dawn threshold, survivors turn and run for the camp, then despawn.
- Dev `ACTIONS`: raid now, advance the night counter. The readout gains "night N".

**Hand-off:** listen at dusk — can you tell one blast from two, and does knowing a raid is
coming change what you do with the last minute of daylight?

---

## P4 — Archers mount the walls

The village fights back.

- Six perch markers along the top of each built `WallSide`, flanking the gate (roughly
  ±1.6, ±4.0, ±6.4 along the run), claimed **centre-first**, six per side.
- Archers mount when the dusk horn counts a raid or bandits exist; claiming goes through
  the same duck-typed station flow as every other errand — **never a player order** (§1).
- Getting up: walk to the wall's inner face on the ground mesh, then a **scripted climb
  tween** onto the marker. **Do not put navmesh on the walls** — §11 explains why at
  length, and the erosion maths means it cannot work anyway.
- The shot: new `villager.gd` states reusing `_stalk` / `_take_aim` / `_loose_arrow`
  against the `bandit` group, at a longer defensive range (~7). Keep it in `villager.gd` —
  one state machine for the civilian life cycle, including the part where they defend it.
- `bandit.take_arrow(from)` mirrors `wild_animal.gd`: knockback, squash, die. **No gold
  drops** (§5 — night is pure cost). One arrow kills a Thug for now.
- Dismount when no bandits remain, and drift back to the fire. With no wall on the raided
  side, ring the campfire instead.
- **Perches exist from the wood level up.** A 0.75m twig fence is something you step
  over, not man — if the wall is still twig when a raid lands, archers use the no-wall
  fallback (ring the campfire). Perch height reads the built level's real height
  (`wall_side.gd::LEVELS` — 1.05m wood on this map). §9/§12.20's "archer floats over the
  0.52m fence" worry is **stale**: the wall ladder replaced the fence visual with a real
  wood panel, so the float problem mostly died with it.

**Hand-off:** do the middle perches fill first? Does the fight over the gate feel like a
defence, or a shooting gallery? Are six per side too many to read at once?

---

## P5 — Robbery

The cost of a bad night.

- A bandit within ~2m of an **employed** citizen robs them: knockdown tween plus
  `MarkFx.hit_flash`, the model swaps back to bare `villager.glb`, and the workplace's
  `filled` count drops so its vacancy icon returns.
- The victim is down ~3s, then gets up and flees to the fire **as a hungry wanderer** —
  the existing cauldron flow re-recruits them, which is what makes a robbery cost soup.
- Wanderers carry nothing and are ignored. Posted archers are fair game if reached.
- The thief shoulders a bundle prop (the carried-purse pattern in `villager.gd`) and
  **leaves for the camp** — one theft each, then out (§11).
- Killing a fleeing thief **drops nothing**. The recovered-bundle idea is §12; don't
  build it.
- Civilians flee any bandit within ~4m at night, the way wildlife spooks
  (`wild_animal.gd::_check_spook`). Workers on an active build site keep working.

**Hand-off:** watch one full loop — robbed, fled, fed, back at work. Does it read as
*robbed* rather than killed? Is losing a worker to the pot's queue a real sting?

---

## P6a — Walls break, walls mend

- HP on `wall_side.gd`, scaled by material (stone tougher than wood), with a smaller
  separate pool for the gate.
- Bandit melee: the villager swing tween mirrored, the axe pool pitched down (~0.85) for
  blows on timber, `hit_flash` and debris on the struck section. Raiders hit whatever they
  are wedged against — the wants-to-move-but-isn't signature `_unstick` already detects.
- Visible damage per section: wood tilts and sinks away (the reverse of `_raise_section`),
  stone swaps `wall.glb` → `wall-half.glb`, which the kit ships as a ruin.
- Gate at zero: leaves blown off, gate collision disabled, `NavWorld.rebake()`.
  Wall arc at zero: that collision box disabled, `NavWorld.rebake()`. Either way the hole
  is real and raiders stream through.
- **Repair is construction**: the damaged side re-joins `build_site` at a progress equal
  to the fraction still standing, costing `ceil(cost × missing fraction)` — a percentage,
  per the house rules. `BuildCrew` unchanged. Repairing mid-raid stays possible.

**Hand-off:** break the gate, pay for the repair, watch the crew mend it under fire. Does
a breach feel like a disaster or an inconvenience?

---

## P6b — The hall can fall

- HP on `building.gd`. Bandits with nothing robbable in sight attack the nearest building.
- A hut at zero collapses into a repair site; its jobs are suspended until it is mended.
- **The hall at zero ends the run** — an end screen built the way `menu.gd` builds its
  layout, and back to the title.
- The crown-loss condition stays reserved for the Stealer; bandits still ignore the
  monarch (§11).

**Hand-off:** let a big raid in undefended and watch it end. Is the loss legible — do you
understand *why* you lost, and what you'd do differently?

---

## P7 — The blood moon

- **Cadence is per-map data, not a global 15th** (`ROADMAP.md` R2b supersedes §9/§11
  here): a per-map constant alongside P0's `hall_cap`. **Map 1 ships with no scheduled
  blood moon** — at the 6-minute cycle a 15-night cadence is ~90 minutes, longer than
  all of map 1; later maps run roughly every 10th/8th/7th night. Build the mechanism and
  the constant; the dev key is map 1's only trigger.
- Dusk horn **×3** (P3 left the hook).
- The night sky blends toward deep red via a `blood` factor in `day_night_cycle.gd`, built
  **exactly parallel to `storm`**: the cycle owns the environment, and it applies after
  the time-of-day blend so a blood moon still reads as night.
- The wave is 2.5–3× in two or three pulses from the camp, mixed with **Brutes**: an
  archetype stat dictionary in the `GAITS` spirit — ~1.3× scale, slower, several arrows to
  drop, heavy structure damage. Adding an archetype should cost an entry.
- Dev `ACTIONS`: blood moon now. The readout gains "blood moon in N".

**Hand-off:** count the blasts — is three distinguishable from two? Does the red read as a
terrible night, or just as a broken sunset?

---

## P8 — The sound of a bad night

- Wire the reuse set: bandit blows on timber = the axe pool pitched down; a body landing =
  `animal_drop` near unity pitch; a wall section going over = `tree_fall`; a breach = the
  gate slam.
- **Every sound wired or re-purposed gets a row in `audio_review.html` in this same
  pass** — a sound that isn't on the listening desk can't be reviewed (house rule).
- List what is genuinely missing — stone impacts, a breach crash, a knockdown thump,
  bandit vocalisations, a blood-moon layer for the night bed — with the per-role listening
  criteria from `ASSETS.md`, restated, so Andrei can audition candidates. **Ask before
  downloading anything**; CC0 or CC-BY only.
- Surface the mix problem rather than solving it unasked: there is no ducking and no
  limiter, and a night wave is the first thing that will genuinely fight the beds.

**Hand-off:** play a full raid at the volume you'd really play at. What is missing, what
is too loud, and can you still hear the horn over the fighting?

---

## P9 — The muster banner *(needs P4)*

The offence half of the loop (`ROADMAP.md` R1, decided 2026-07-24): pay at a banner,
a squad follows the monarch, coming home dismisses them. Never an order in either
direction.

- A **banner outside the gate** (position is map data; placeholder look: castle-kit
  pennant pole, flattened to the monarch's burgundy like the wall pennants). In
  `interactable`; prompt "Hold E  Muster (cost)".
- **One payment = one squad of N free archers** (constant, ~3 placeholder). They enter a
  FOLLOW state in `villager.gd` — same file, same state machine, per the house style —
  trailing the monarch at 2–3m. The wanderer walk-in already walks toward a moving
  target, so the movement shape exists. **Pay again for another squad**; the tally
  already sizes the hold to the cost, so a bigger army is a longer hold.
- Followers keep P4's defensive shot live while following: **you never order an attack —
  you walk, and they fight what you walk them into.** That sentence is the mechanic.
- **Disband**: the monarch coming back within ~R of the banner (or the campfire)
  releases everyone to their old posts. No dismiss button. Night doesn't auto-disband —
  marching at night is legal, dangerous, and the player's own idea.
- The cost of marching out is built in: every squad out is a squad missing from the
  walls if a raid lands. Don't soften that — it is the design working.
- Dev `ACTIONS`: dismiss the party. Readout gains "party N".

**Hand-off:** pay, ride a lap of the map, come home. Do they keep up at a gallop? Does
disband-by-returning feel natural, or did you look for a button? Is one squad's cost a
real decision by map-1 economy standards?

---

## P10 — Burning the camps *(needs P3 + P9 — the map objective)*

Camps die by archer assault with fire arrows (`ROADMAP.md` R1). All camps burned is
what completes a map.

- The P3 camp gains a **standing garrison**: 2–3 bandits idling at the fire by day —
  same bodies as the night waves, just home. They fight back like any bandit when the
  party arrives.
- Escorted archers engage them through P4's shot, nothing new. When **no live defender
  remains near the camp** and an escorted archer is in range, the squad looses a
  **fire-arrow volley**: the arrow prop with an ember trail (`MarkFx.particle`), a
  beat, then the tents ignite — flame sprites, the ember light flaring and dying — and
  the camp swaps to a **burned state** (charcoal-tinted wreck) and leaves `bandit_camp`.
- A burned camp spawns nothing, forever; the director already reads the group, so raids
  from that front just stop. **No loot** (§5 — a paying camp would make assault
  farming; the reward *is* the silence).
- **All camps burned = the map objective**: a `map_cleared` signal and a modest on-screen
  line for now — the §10 exit (leaving the map) is its own future task, not this one.
- Not built here, deliberately: camp re-establishment (map 4 — §12.21/23), night-kill
  garrison depletion (`ROADMAP.md` R8), the exit itself, and any fire-arrow *sound* —
  P8's missing-list gains "fire-arrow whoosh + camp burn" instead, per the ask-first
  audio rule.

**Hand-off:** the full loop — survive nights, muster, march, burn, silence. Does the
assault feel *earned* after the defending? Does the volley read as the payoff shot? And
is the map suddenly, satisfyingly quiet — or just empty?
