# Depth & scale — the implementation prompts

Five tasks that fix why the game reads flat and MOBA-like, one session each.

**Run them in order.** Shadows first because they are the cheapest and the largest single
win; scale second because it is the actual error; the camera **last**, deliberately — it is
the only one that is a matter of taste rather than a matter of being wrong, and it should
be judged against a world that is already correctly sized and lit, not before.

Paste one prompt per session, under this preamble:

> Read `CLAUDE.md` before touching anything — especially the gotchas, which cover most of
> what is hard here. Implement **only** this task; if you spot something adjacent worth
> doing, say so and leave it. When it works, hand it to Andrei to play-test with an
> AskUserQuestion report rather than proving it with a long automated run.

---

## The measurements these tasks are built on

Taken from the real models at the scales the game spawns them, so no session needs to
re-derive them:

| Thing | Height in game | vs. a villager |
|---|---|---|
| Monarch, mounted | 1.95 m (footprint 0.62 × 1.60) | 1.6× |
| Villager / worker / archer | 1.20 / 1.26 / 1.32 m | 1.0× |
| **Tent — L1 main building** | **0.88 m** (footprint 1.01) | **0.70×** |
| **Wooden Hall — L2** | **0.70 m** (footprint 0.70) | **0.56×** |
| Workers hut | 0.88 m (footprint 1.01) | 0.70× |
| Archers hut | 1.57 m (footprint 1.20) | 1.25× |
| Stone Hall — L3 | 2.88 m (footprint 2.20) | 2.3× |
| Resource tree | 1.98 m | 1.6× |
| Decor trees | 1.41 – 3.51 m | 1.1 – 2.8× |

The monarch is **not** too big — a mounted rider at 1.95 m is right. The buildings are tiny.
A worker is taller than the hut he works at, and the horse is longer than the Tent is wide.

Trees read acceptably and buildings do not, because a tree has no known size — a 2 m tree
just looks like a small tree — while a building has doors and roofs, which the eye measures
against a person. That is why the error is invisible on one and glaring on the other.

---

## D1 — The sun casts shadows

Nothing in the game casts a shadow. That is the single biggest reason objects read as
stickers on a flat layer rather than things standing on ground.

- `Sun` (`DirectionalLight3D`, `kingdom_demo.tscn`) has no `shadow_enabled`. Turn it on.
  Directional shadows **are** supported under `gl_compatibility`.
- Prefer `directional_shadow_mode = 0` (orthogonal) — the playable map is only ~30 m
  across, so one split is plenty and cheapest. Set `directional_shadow_max_distance` to
  cover the map with room to spare, not the full 100 m slab.
- Tune `shadow_bias` / `shadow_normal_bias` against the flat ground slab: too little and
  the grass gets acne, too much and shadows detach from feet ("peter-panning"). The
  contact point matters more than the shadow's far end — that contact is the whole cue.
- **Re-enable casting on decor**: `world_decor.gd:96` and `:150` explicitly set
  `SHADOW_CASTING_SETTING_OFF`. They were presumably off for performance — turn them on
  and see whether the framerate actually cares before assuming it does.
- **Handle the sun going under the map.** `day_night_cycle.gd` rotates it; at dawn and dusk
  shadows will streak across the entire map, and at night the sun is below the horizon
  where shadows are meaningless. Gate or fade shadow strength on the sun's elevation,
  in `day_night_cycle.gd` — it owns the environment, nothing else should write this.
- Leave the rain, mist and puddle quads non-casting (`puddles.gd:48`, `weather.gd`).
- **Grep the `.tscn` afterwards** to confirm the edit survived — the editor overwrites
  hand-edited scenes (see `CLAUDE.md`).

**Hand-off:** do things feel planted now? Are dawn/dusk shadows too long to live with?
Does the framerate move at all with decor casting?

---

## D2 — The building scale hierarchy

The buildings are between 0.56× and 2.3× a villager. They should be 2× to 6×. Fix the
sizes and the layout that has to grow with them, in one pass.

- **There is a straight bug here: the L2 Wooden Hall (0.70 m) is shorter than the L1 Tent
  it replaces (0.88 m).** Paying to upgrade currently makes the building shrink. Fix it as
  part of this.
- New `model_scale` values in `campfire.gd::_spawn_village` — targets, tune by eye:

  | | now | target height | `model_scale` |
  |---|---|---|---|
  | Tent L1 | 0.88 | ~2.2 m | 1.8 → **4.5** |
  | Workers hut | 0.88 | ~2.4 m | 1.8 → **4.9** |
  | Archers hut | 1.57 | ~2.8 m | 1.2 → **2.1** |
  | Wooden Hall L2 | 0.70 | ~3.5 m | 1.4 → **7.0** |
  | Stone Hall L3 | 2.88 | ~5.0 m | 2.2 → **3.8** |

  Each main-building tier must be a **visible** jump from the last — that silhouette is
  what the upgrade actually buys.
- **`model_height` must move in lockstep** (`building.gd:17` — it seats prompts, the job
  icons and the label). Currently Tent 1.3, Workers 1.4, Archers 2.4, Wooden Hall 2.0,
  Stone Hall 3.4. Stale values leave every banner floating or buried.
- **The layout has to grow.** Footprints go from ~1 m to ~3.5 m; at the current spawn
  positions — Tent `(-3.6, 0, -2.6)`, Workers `(3.6, 0, -2.6)`, Archers `(0, 0, -4.6)`,
  campfire at origin — the buildings will physically intersect. Spread them out.
- Two constraints on that spread, and if they cannot both be met **say so rather than
  quietly moving the palisade**: everything stays inside the walls at ±8 m, and at least
  ~2 m stays clear between footprints so villagers can still path between buildings.
- **Rebake the navmesh** (`NavWorld.rebake`) and check with **F3** that the gaps between
  buildings are still walkable and the cauldron is still reachable — a village that seals
  itself is the failure mode here.
- Leave the costs alone. They are placeholder (a flat 5) on purpose.

**Hand-off:** do the buildings finally read as buildings you could walk into? Does each
hall tier feel like a real step up? Does anyone get stuck pathing round the new footprints?

---

## D3 — Trees and decor to match

With the buildings corrected the forest becomes the thing that is undersized. Mature trees
at 1.4–3.5 m are roughly half what they should be.

- Raise the decor tree ranges in `world_decor.gd::_make_tree` and the resource tree scale
  in `tree.tscn` so mature trees land around **4–7 m** — comfortably taller than the halls,
  so the village reads as a clearing cut *into* a forest.
- **Keep the variance.** The random ranges are what stop the treeline looking like a comb;
  widen them with the scale rather than picking one size.
- The resource tree's collision cylinder and its `TRUNK_Y` / banner heights
  (`tree_resource.gd:18`) need to track the new size, or the axe blaze paints at the wrong
  spot and the prompt floats.
- Berry bushes: **check but probably leave alone.** `CLAUDE.md` documents that bush height
  interacts badly with `cell_height` on the navmesh — a 0.7 m bush once came out as a
  climbable step and villagers oscillated against it. If you touch bush scale, re-bake and
  watch for that signature.
- Rebake the navmesh and confirm the forest is still passable.

**Hand-off:** does the forest tower now? Is the village clearing still readable, or did the
trees swallow it?

---

## D4 — Depth fog

Distant objects are exactly as saturated and contrasty as near ones, so the eye gets no
depth ordering. Aerial perspective fixes that. `gl_compatibility` has no volumetric fog,
but plain depth fog is available and is the intended substitute.

- Enable fog on the `Environment` in `kingdom_demo.tscn`. It currently has only
  `background_mode`, `background_color` and ambient light.
- **Tune the density for a ~30 m world, not a 500 m one.** The playable area is tiny; a
  density copied from an outdoor-vista tutorial will grey out the whole village. It should
  be barely perceptible on the near buildings and clearly softening the treeline.
- **Drive the fog colour from `day_night_cycle.gd`, alongside `background_color`** — never
  from `weather.gd`. `CLAUDE.md` is explicit that two scripts writing the environment in
  one frame fight and flicker; weather already routes through `cycle.storm` / `cycle.flash`
  for exactly this reason, and fog must follow the same path.
- Fog should thicken with `cycle.storm` so rain closes the world in, and blend **after**
  the time-of-day colours so a storm at noon still reads as noon.
- Consider a little height fog pooling on the slab at dawn — cheap, and it sits well with
  the existing mist particle layer. Skip it if it fights the mist.

**Hand-off:** does the treeline recede now? Is the fog invisible at midday and obvious in a
storm, or is it greying out the village?

---

## D5 — The camera lens *(last, and a taste call)*

Only start this once D1–D4 have landed and been played. Everything before this is fixing
something that is *wrong*; this one is choosing a look, and it should be judged against a
world that is already correctly sized and lit.

The camera is `fov = 60` at **8.63 m** from the pivot, pitched **40°** down. That is a wide
lens up close — the MOBA camera. Thronefall and Tiny Glade read as **dioramas** because
they use a long lens far back, which flattens perspective divergence so the world looks
like a physical model.

- Try roughly **`fov` 32–35 at 18–22 m** along the same bearing. For 20 m at the existing
  40° pitch the `Camera3D` local position is about `(0, 12.86, 15.32)`.
- **Keep the 40° pitch.** A high, steep camera is in the north star; this task changes the
  *lens*, not the angle.
- Change `_camera.position` at rest, not a runtime offset: `camera_rig.gd:20` caches
  `_cam_base` and the shake restores to it, so a base that moves out from under the shake
  will fight it.
- **Pulling back will reveal the edge of the world.** The slab is 100 × 100 but decor only
  reaches ±48. Check the horizon at all four Z/X angles for the slab edge or a bald ring
  beyond the treeline.
- Apparent size lands within ~15% of today's with those numbers, so the world-space
  `Label3D` prompts and the billboard sprites (coins, the tally, job icons) should survive
  — but they are the things most likely to need a nudge, so look at them specifically.
- This is reversible and cheap to A/B. **Take screenshots of both and compare** rather than
  arguing it — and if the wide lens turns out to be the better fit for this game, say so.

**Hand-off:** diorama or MOBA — which one does it look like now? Does the world edge show?
Are the prompts and coins still readable at the new distance?

---

## 🔮 D6 — The night camera *(concept only — not scheduled)*

**Not a task.** Nothing here should be built until D1–D5 have landed and been played; it is
recorded so the option is not lost, and because it changes how D5 should be judged.

### The measurement that motivates it

**D5 does not zoom you out.** Distance and field of view move together, so a longer lens
further back buys a diorama look and *no extra coverage at all*. Visible ground width at
frame centre, 16:9:

| Setup | Distance | FOV | Width visible |
|---|---|---|---|
| Today | 8.63 m | 60° | **21.2 m** |
| D5 diorama | 20 m | 33° | **21.1 m** |

The palisade sits at ±8 m — a **16 m** span — so the current camera already frames a whole
wall with margin either side, and depth runs from ~3 m behind the monarch to ~32 m ahead.
Seeing more of the world is a **third** axis, separate from D5, and needs deciding on its
own terms.

### The tension

Combat wants to show the wall, the bandits outside it and the defenders behind it at once.
Everything else in the game wants to be close: the monarch's `MAX_RANGE` is **4 m**, so an
8 m circle is the entirety of his agency, and hold-to-pay — the main verb — is a tally of
pips that is sized to read at today's distance.

| Frame width | Agency circle | Villager @1080p |
|---|---|---|
| 21 m (today) | 38% of screen | ~114 px |
| 30 m | 27% | ~80 px |
| 40 m | 20% | ~60 px |

Characters survive a pull-back further than expected; the **tally breaks first**.

### The argument against zooming out at all

Pillar 1 is indirect control, so a wider view hands you information you **cannot act on** —
you can't reposition archers. Past some distance that converts tension into spectating.

The design has already invested twice in *non-visual* information for exactly this reason:
the watch horn counts (one blast nightfall, two attack, three blood moon), and §9's 🔮
watchtower call announces bearings at dusk. Both are only meaningful because you can't see
everything. Map 1 also has a single opening and therefore a single front (§9), so there is
one gate to watch, not four.

### The proposal

Don't pick one zoom — ride the heartbeat. **Close by day, wide at night.**

- **Day** — building and paying at 4 m range. Intimate; D5's resting distance.
- **Night** — ease out to roughly 26–28 m of width. The wall, the bandits, your archers.

Day = build = close, night = survive = wide: the camera move *is* the mood change, and it
resolves the tension rather than trading it off.

Three constraints if it is ever built:

- **Drive it off `darkness()` crossing a threshold, never off the clock** — the same rule
  the horn follows in `CLAUDE.md`, because the cycle durations are placeholder.
- **Long lerp across dusk, never a snap.** Self-moving cameras read as nausea when quick.
- **Write `_camera.position` directly; the rig will follow.** It used to snap the camera
  back to a base cached in `_ready()` every frame, which stomped any external writer. It
  now adopts the camera's position as its rest pose while `_shake_t <= 0.0`, so a zoom can
  simply move the camera and the shake will still restore to wherever it was left.
- Open the pitch question with it if at all: at 40° you can see wall tops, which is what
  makes §12.19's "perched archers always visible" answerable with *yes*. Going steeper
  silently answers it *no*.
