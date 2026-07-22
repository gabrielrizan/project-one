# Combat — the implementation prompts

Eight tasks that build the combat design in `GAME_DESIGN.md` §9, one session each.

**Run them in order.** Each assumes the previous one landed. Each is meant to end in
something Andrei can actually play, so the design gets corrected by playing rather than by
arguing — which is why "bandits that can't hurt you" and "archers that shoot" are separate
tasks from "walls that break".

Paste one prompt per session, under this preamble:

> Read `kingdom_demo/GAME_DESIGN.md` §9 and `CLAUDE.md` before touching anything —
> especially the gotchas, which cover most of what is hard here. Implement **only** this
> task; if you spot something adjacent worth doing, say so and leave it. Costs and
> timings are placeholder unless §9 says otherwise. When it works, hand it to Andrei to
> play-test with an AskUserQuestion report rather than proving it with a long automated
> run.

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
- Move any tree or berry bush now inside the rock, and bias the wanderer walk-in
  (`campfire.gd::_attract_villagers`) and the wildlife ring (`wildlife.gd`) onto open
  ground — a wanderer spawning inside a mountain is stuck forever.
- **Grep the `.tscn` afterwards** to confirm the edits survived (the editor overwrites
  hand-edited scenes — see `CLAUDE.md`).

Verify by riding the perimeter with **F3** navmesh debug on: no walkable polygons inside
the rock, no path through it, and a clean path down the corridor.

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
  all at once.
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
- The archer floating over the 0.52m wood fence is **accepted placeholder** (§9, §12) —
  don't fix the wall art in this pass.

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

- Every 15th night. Dusk horn **×3** (P3 left the hook).
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
