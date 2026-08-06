# Prototype 1 — Flat Terrain: the implementation prompts

Eight tasks, one session each, for a **fourth map**: a flat, round island surrounded by
water, with black fog of war, a Northgard-style zoom, raids that can come from any bearing,
and exploration rewards. Decided with Andrei on 2026-07-28.

**This is a scope expansion, not drift.** It sits outside the frozen map-1 demo scope, and
F7 un-cuts the §10 map exit that the polish pass had explicitly reserved. That was Andrei's
call, made deliberately. Don't "correct" it back to the demo scope.

**Run them in order.** Each assumes the previous one landed, and each is meant to end in
something Andrei can actually play — so the design gets corrected by playing rather than by
arguing. The one soft dependency: F2 (zoom) is independent of everything and can move
earlier if the island is unpleasant to look at while it's being built.

Paste one prompt per session, under this preamble:

> Read `CLAUDE.md` before touching anything — especially the gotchas, which cover most of
> what is hard here — plus `kingdom_demo/GAME_DESIGN.md` and `kingdom_demo/ROADMAP.md` for
> anything design-shaped. Implement **only** this task; if you spot something adjacent
> worth doing, say so and leave it. Costs, timings and wave sizes are placeholder unless
> stated otherwise. When it works, hand it to Andrei to play-test with an AskUserQuestion
> report rather than proving it with a long automated run.

---

## The decisions, so no task has to re-derive them

| | |
|---|---|
| **Map** | `id = "flat_island"`, title **"Prototype 1 — Flat Terrain"**. Now the *only* entry in `MapCatalog`. Village stays at `Vector3.ZERO`. |
| **The other three maps** | **Deleted (2026-08-06).** Mountain U, Deep Wood and Twin Passes were prototypes and concepts kept compiling and playable as working references until Andrei was happy with the island; that call has now been made and their `MapDef`-building code is gone from `map_catalog.gd`, not just unlisted. |
| **Map picker** | **Stays**, even while the island is the only entry (Andrei, 2026-08-02). Don't "simplify" Play → Choose a Map into a straight launch — it earns its place again as soon as a second real map exists. |
| **Art** | The **nature-pack** (`NaturePack`, `assets/nature-pack/FBX`) and the **season re-skin** merged on 2026-08-02 are the island's art basis — decided by Andrei, not a default to re-argue. **The season reaches the water and the beach too**, not just the ground and the vegetation (see F1). One gap to close first: "The forest is not all one asset pack yet", below. |
| **Shape** | Round-ish island, water on all bearings, **no rock or wood gates at all**. Still one flat slab — no elevation, no ramps. |
| **Fog of war** | Full black. **Permanent reveal**, never re-shrouds. The monarch reveals a larger radius than villagers; roaming archers reveal too. |
| **Camera** | Keep the Z / X spin, add smooth mouse-wheel zoom at a fixed 45° pitch. |
| **Walls** | **Four segments forming a square**, lengthened so the village is bigger: a per-instance `half` (default 8.0) set to **16.0** from map data → a 32×32 square at radius 16, one gate per side. |
| **Camps** | Two, opposite each other about the village. One raiding, one dormant — the existing convention. |
| **Raid bearing** | **Rolled at random across all four walls each night, decoupled from where the camps are.** The threatened walls **light their torches** at dusk; that is the player's cue. Archers split **evenly** across the lit walls. Map 1 caps at **two simultaneous fronts**. |
| **Night schedule** | Night 0 nothing · night 1 one front, one camp's worth · night 2 two fronts. Growth past that keeps the existing curve, clamped to `max_fronts`. |
| **Rewards** | **Ungated** — no portals, no risk tiers. The monarch takes them himself. Chests give gold + currency X. **Exactly one altar and one hermit** on this map, together in a shrine clearing. |
| **Blessings** | Permanent, one per site. The hermit reuses the design already written in `GAME_DESIGN.md` §9: a citizen who bends exactly one rule. |
| **Currency X** | **Undecided.** Ship a neutral internal id (`relic`) with the display name in **one constant**. "Old crowns" and "rune stones" are both still live as concepts; Andrei picks later, and it must be a one-line swap. |
| **Boats** | Two wrecks on the beach, far apart — the **§10 map exit**. Pay → a crew assembles it → ring the bell → citizens board. |
| **Exit gate** | The bell only rings once `game_manager.map_cleared` has fired — `ROADMAP.md` R1, "destroy all camps to leave". |

### Why the fog is allowed to hide the camps

Full black fog hides the camp smoke column and the dusk ember flare until you have scouted
them. That reverses rationale argued in three places — `bandit_camp.gd`'s discovery
docstring, `world_decor.gd`'s road comment, and `CLAUDE.md`'s maps section — all of which
treat the smoke column as the game's only diegetic answer to *"which way is tonight coming
from"*.

**F5's lit torches replace that signal, and replace it with a better one.** Once the raid
bearing is random, the smoke column *cannot* forecast the raid anyway — the walls do, from
inside the village, more precisely, and without the player needing to have explored at all.
So smoke reverts to what it always meant literally: *someone lives out there, that way* — a
scouting lead and a standing objective, not a raid forecast.

**Rewrite those notes in `CLAUDE.md` in the pass that lands them (F3 and F5).** If they are
left standing, a later session will read the old rationale and "fix" the fog back.

### The forest is not all one asset pack yet

The 2026-08-02 nature-pack swap reached **two** of the three tree populations. Verified on
that date, re-check before relying on it:

| Population | Source | Follows the season? |
|---|---|---|
| Solid / markable trees (`tree_resource.gd`) | `NaturePack` | yes |
| `world_decor.gd` scenery ring | `NaturePack` | yes |
| **`map_forest.gd` filler / understory (`_load_filler`)** | **old Kenney GLBs + colormap** | **no** |

⚠️ **This one does not go away with the prototype maps.** `map_forest.gd` is the general
forest system, and **F4 pushes `understory.cap` to ~420** — so on the island that is ~420
Kenney trees standing among nature-pack ones, and in autumn and winter the understory
stays summer-green while every tree around it turns and takes on snow. The understory is
specifically the population that sets how dense the wood *looks*, so it is the most
visible thing on the map.

**Port `_load_filler()` to `NaturePack` as part of F4**, and give it the season hook
`world_decor.gd` already models (`_hook_weather` / `_on_season_changed` / `_variant_for`,
re-growing under a holder with a re-seeded rng so the layout holds and only the coat
changes). Filler carries no script and no collider, so this is cosmetic only — it cannot
touch the navmesh, and `forest.spacing` is unaffected because spacing governs the *solid*
trees.

---

## F1 — The island: map data, the shore seal, and water

The map itself. Nothing here is new mechanics — it is a fourth `MapDef` plus the one
structural thing the data model has never had: a coastline.

### The shore is a shape, not a pile of boxes

Give `MapDef` a **radial shore**: a base radius plus a deterministic low-frequency wobble
(two or three sines in θ, fixed phases) so it reads as round but not machined.

Then **extend `map_def.gd::is_blocked()` to return true outside that shore.** That single
change is the whole design: `is_open`, `gate_kind_at`, `_plantable`, `_scatter`,
`belly_point`, `wildlife.gd` and `world_decor.gd` all become correct with no other edits,
because every one of them already asks the same predicate. Do **not** add a parallel
"is this water" concept that callers have to learn.

`gates` stays supported and stays empty for this map.

### The seal has to be physical

⚠️ **`monarch.gd` has no bounds clamp anywhere in the codebase.** On every existing map the
only thing containing him is a gate collider. With zero gates he rides straight off the
180×180 ground slab and keeps going.

Generate a ring of ~48 invisible box `StaticBody3D` colliders tangent to the shore, in
`mountains.gd`, under a new `MapDef.WATER` kind. Invisible, like every gate box — the
navmesh bakes from static collision, so this contains bodies *and* gives the mesh one clean
edge with no per-prop bookkeeping.

### Water, beach, backdrop

- **Water plane** — a large non-colliding mesh at y ≈ −0.12, shadow casting **off**. Two
  constraints, both learned the hard way and both in `CLAUDE.md`: from this high camera
  standing water reads *lighter* than ground because what you see in it is sky, so mix
  heavily toward the sky colour rather than toward black; and build the chop from **two
  crossed axis waves, never a radial term** — `sin(r * k)` over a round quad draws a
  bullseye. `assets/shaders/puddle.gdshader` is the working reference for both.
- **Beach ring** — sand-coloured flat quads between the forest edge and the shore, reusing
  `world_decor.gd::_add_strip` / `_scatter_patches`. Keep them **non-casting**: they are
  sheets at y≈0.02 and a low sun projects a sheet's silhouette clear across the map.
- **The water and the beach follow the season** (Andrei, 2026-08-02). Build the hook here,
  in F1, even if the winter look is tuned later — retrofitting it once the shader and the
  quads are settled is the expensive order. Use the path that already exists rather than a
  new one: subscribe to `weather.gd`'s **`season_changed`** and tint on `WINTER`, exactly as
  `world_decor.gd::_apply_ground_snow` does for the ground (cache the base colour once, lerp
  toward the winter colour, restore otherwise). The **ring of distant islands** is part of
  the same picture — a green horizon around a white island reads as a bug.
  ⚠️ Whatever winter does to the water must not fight the rule the shader is built on:
  from this camera standing water reads *lighter* than ground because what you see in it is
  **sky**. Push it paler and flatter (less chop, more sky), not darker or grey-blue.
  Exact colours are placeholder — tune by playing, like everything else here.
- ⚠️ **`world_decor.gd::_backdrop()` will put scenery on the sea.** It permits scenery
  anywhere `is_open` is false, which after this change means the entire ocean. Reject
  anything past the shore, and replace the backdrop it loses with a **ring of distant
  islands** out on the water — that is the horizon this map wants anyway.
  Since the 2026-08-02 merge `_backdrop()` gates **bushes as well as trees** (through
  `_backdrop_point`), so a shore test that only covers `_plant` leaves bushes floating.
  `_near_point()` — rocks, ground patches, small detail — needs the same treatment: it
  draws off `MapTerrain.extent()` with no shore test at all.

### Data to start from (all placeholder, tune by playing)

```
extent          62
shore           base 56, wobble ±5
play_min/max    ≈ ±62 (the island bbox — the bake is O(area))
village         Vector3.ZERO      # the campfire is hard-placed at the origin in the .tscn
walls           4 × {radius 16, yaw 0/90/180/270, half 16.0}
camps           bearing 0° and 180°, ~46 m out; one raiding, one dormant
muster          just outside the north gate
spawn_lane      an east beach arc — wanderers walk in off the shore
home            a generous AABB, not the old asymmetric box
```

The ground slab is 180×180, so the island must fit inside it. The water plane may be larger
because it carries no collider.

**Hand-off:** ride the whole coast. Does the island read as an island? Can you get off it
anywhere? Does the shoreline look made or look like a circle?

---

## F2 — Northgard camera zoom

Mouse wheel zooms in and out; Z / X spin is untouched; pitch stays 45°.

- **Add `cam_zoom_in` / `cam_zoom_out` to `project.godot`.** There are only five input
  actions today, and Z / X are raw `Input.is_key_pressed` polls, not actions.
- Slide `_camera.position` along its own back-vector between a near and a far stop. Lerp
  toward a target, don't step. Writing the position directly is safe and intended:
  `camera_rig.gd::_shake_camera` deliberately **adopts** `_camera.position` as its rest pose
  precisely so an external writer isn't stomped — its comment says so.

Three couplings that will break silently if you skip them:

- ⚠️ **Do not move the `AudioListener3D`.** It is pinned to the rig at `(0, 6.645, 5.503)`
  — where the camera sat when every SFX was tuned. Moving it re-tunes every positional
  sound in the game at once. Zoom must leave it exactly where it is; that is the entire
  reason it exists.
- ⚠️ **Counter-scale the `GoldFx` pips and the `Label3D` prompts against zoom.** They are
  sized in **metres**, so zooming rescales them. This has already bitten once: at 0.63×
  apparent size a tally pip fell to ~14 px and you could no longer tell a paid pip from an
  unpaid one — which is the entire readout. `PIP_SCALE` / `PIP_SPACING` were raised ~1.6× to
  compensate for a *static* camera change; a dynamic one needs them driven live.
- ⚠️ **Drive `FOG_NEAR` / `FOG_FAR` (22–55 m) and `directional_shadow_max_distance` (48)
  off the zoom level.** Both are tuned for the shipped frustum. Zoomed out, the fog band
  lands on the ground under the monarch's feet and shadows pop at the frame edge.

Keep `dev_menu.gd`'s `CAM_PRESETS` working — preset 0 must still match what the `.tscn`
ships, or the readout lies.

**Hand-off:** does the zoom range feel like Northgard's? Is the tally still readable at
both stops? Does anything about the fog or shadows change as you scroll?

---

## F3 — Fog of war

Black RTS fog. Explored ground stays explored **forever** — this is memory of a place, not
line of sight, and nothing ever re-shrouds behind you.

### How, given the renderer

`gl_compatibility` has **no decals and no volumetric fog**, so this is a mask plus a shader.

- A CPU-painted **`ImageTexture` mask** (~256², covering the island bbox). Each revealer
  paints a soft brush at its position, **max-blended** so the mask only ever grows.
- Upload **only when dirty, at a low tick (~4 Hz)** — not every frame. A 256² image upload
  per frame is pure waste for something that changes at walking pace.

### Two halves, because one plane cannot work at a 45° pitch

A single black plane above the world would occlude the ground *in front of* it, not the
ground under it. So:

1. **Ground darkening** — the mask drives a shader on a quad at ground level.
2. **Anything that stands up** — hidden by per-object `visible`, via a new `fog_hideable`
   group. This is exactly `bandit_camp.gd`'s existing `DISCOVER_R` pattern generalised;
   fold that code into the mask rather than leaving two discovery systems. Once an object is
   revealed it sets a bool and stops sampling.

### Reveal radii

The monarch reveals a large radius; villagers a small one. **Roaming archers and hunters
must contribute** — Andrei's requirement, and it is what makes the map open up as the
economy grows rather than only when you personally ride somewhere.

### The reversal, recorded

Camp smoke and the ember are now hidden until the camp is revealed. **Update `CLAUDE.md`'s
maps section and `bandit_camp.gd`'s docstring in this pass**, with the reasoning from the
top of this file — F5's torches take over the "which way tonight" job.

Add a dev-overlay reveal-all via the `ACTIONS` list.

**Hand-off:** start a fresh run. Is the black readable or oppressive? Does the island open
up at a good rate as archers roam? Does anything pop in visibly at the reveal edge?

---

## F4 — The forest: dense to look at, free to walk through

Andrei's two requirements are "trees found often, looks like a big forest" and "the monarch
walks freely and easily through it while being seen, and can see berries easily". Those are
only compatible because of the split the codebase already has — **use it, don't rebuild it.**

- **Solid** trees (scripted, collidered, markable) set how much the wood *blocks*;
  **filler** (no script, no collider) sets how dense it *looks*. Push `understory.cap` high
  (~420) for a thick canopy and keep `forest.spacing` at **3.6–3.7**.
- ⚠️ **`spacing` is a walkability guarantee, not a style choice.** A trunk collider is 0.5 m
  and the navmesh erodes 0.3 m each side, so two trunks under ~1.6 m apart leave a gap that
  looks walkable and is not — that is the exact shape of "the character gets stuck
  randomly". **Never go below 2.6 without re-measuring.**
- ⚠️ **Port the filler to `NaturePack` first** — see "The forest is not all one asset pack
  yet" above. `_load_filler()` still loads Kenney GLBs and never changes season, and this
  task is what raises it to ~420 trees. Do it before tuning density, or you will be tuning
  the look of an understory you are about to replace.
- **Berries must be easy to see.** Add a small glade clearance around bush points in
  `_plantable` so bushes sit in openings rather than under canopy.
- `keep_clear` for the shrine clearing and the two beach approaches. `camp_clear` already
  handles the camps. No trees on the beach ring.
- **Verify by measuring, not by looking**: tree count inside `ROADMAP.md` R7's 40–80 target,
  and the *tightest actual gap* across the map — don't trust `spacing` to have been honoured.

**Hand-off:** ride through the thickest part at speed, repeatedly. Do you ever snag? Can you
see yourself? Can you spot a bush without hunting for it?

---

## F5 — Raids from any bearing, and the lit walls

The task that makes a four-sided wall mean something. Today `night_raids.gd` spawns every
wave from the raiding camp, so the bearing is fixed by map layout. Here it is **rolled fresh
each night across the four walls, regardless of where the camps are.**

- **Director.** Each night, pick one or two of the four walls at random as tonight's
  **fronts**. Add a per-map `max_fronts` (map 1 = 2). Spawn each front's bandits at the
  shore on that bearing and march them at the wall — on an island, raiders **coming in off
  the sea** reads perfectly and needs no camp on that side to justify it.
- **Schedule**, replacing the current `FIRST_RAID = 3` grace period:
  **night 0** nothing · **night 1** one front, one camp's worth · **night 2** two fronts.
  Introduce a `CAMP_WAVE` constant as the "one camp's worth" unit. Past night 2, keep the
  existing growth curve, clamped to `max_fronts`. Placeholder numbers like every cost.
- **Lit torches are the cue.** `wall_side.gd` gains an unlit torch per section — use
  `lantern.glb`, already in the survival kit; `campfire-stand.glb` is the fallback if the
  lantern reads too small from the play camera. At dusk the director lights **only** the
  threatened walls; they go out at dawn. **Check legibility at both zoom stops** — a cue you
  can't read zoomed out is not a cue.
- **Archers split evenly across the lit walls.** `villager.gd` currently claims the nearest
  built wall's centre-most free perch (`_perch_wall` / `_perch_index` against
  `wall_side.gd::PERCH_OFFSETS`). Change the preference: only lit walls are claimable, and
  an archer picks the lit wall with the **fewest defenders**, not the closest. An unlit wall
  is never manned.
- Two edges to handle explicitly: **a front on a bearing with no wall built yet** — they
  walk straight in, and that is the lesson, so don't special-case it; and **an odd archer
  count across two fronts** — round down on the second, but never leave anyone unassigned.
- `flare()` on the raiding camp keeps working, but it now means *this camp is active*, not
  *tonight comes from here*. Update `bandit_camp.gd`'s docstring and `CLAUDE.md`.

**Hand-off:** play nights 0 through 4. Is it obvious which wall to run to before anything
arrives? Do the archers visibly redistribute? Does two fronts feel like twice one front, or
like chaos?

---

## F6 — Reward sites: chests, one altar, one hermit

Exploration payoff, **ungated** — no portals, no risk tiers, no gating of any kind. The
monarch rides up and takes them himself. On a 360° map the cost of a reward is simply the
daylight spent riding to it instead of building.

- New **`MapDef.sites: Array[Dictionary]`** — `{pos, kind, clear}`, with `_plantable`
  respecting `clear` exactly as it already does `camp_clear`.
- Follow the **`muster_banner.gd` procedural-interactable template**: a `StaticBody3D` with
  a collider (the monarch's `InteractArea` listens for *bodies*), `add_to_group("interactable")`,
  and duck-typed `show_prompt()` / `hide_prompt()` / `interact(who)`. No base class.
- **Chest** — free, monarch only. It opens and **spills `coin.tscn`** for him to ride over
  and collect (reuse `coin.gd::collect_to`; the spill is already built and already feels
  good), plus one currency X.

  > Note for whoever builds this: it is the **first interactable in the game that gives
  > rather than costs.** Every other one is hold-to-pay. Don't force a tally onto it — but
  > do keep the prompt grammar identical, because "walk up to a thing and press E" is the
  > one verb.

- **Shrine clearing** — a tree-free clearing holding one altar and one hermit's hut, per
  Andrei: *"maybe altars are some stone statues and hermits are next to some house"*.
  `pillar-stone.glb` and `rocks-large.glb` are already owned and suit the statue;
  `tent-canvas.glb` or a small `HallBuilder`-style composition serves the hut.
- **Altar** — costs currency X, grants **one permanent kingdom-wide blessing**. **Hermit** —
  costs gold via `GoldFx.pay`, and joins as a citizen who **bends exactly one rule**
  (`GAME_DESIGN.md` §9's hermit design: a cook adding to the pot, a warden adding a
  station). One of each on this map, so the set stays fixed at two — **this is not a tech
  tree and must not become one** (pillar 4).
- **Currency X**: internal id `relic`, display name in a single constant. HUD gets a counter
  beside the coin counter.
- Every site joins `fog_hideable`.

**Hand-off:** find everything without being told where it is. Does exploring feel repaid?
Is one altar and one hermit enough to be interesting, or does the map want more?

---

## F7 — The wrecks: build a boat, ring the bell, leave

The §10 map exit, on this map only.

- **Download the Kenney Pirate Kit (CC0)** — approved by Andrei on 2026-07-28. No kit in the
  project has a boat or ship of any kind; this was checked. Licence goes into
  `assets/licenses/` **in the same commit**.
- Two wreck sites on the beach, far apart, from `MapDef.sites`.
- A wreck is a **`build_site`**: join the group and implement the existing duck-typed
  surface — `site_active()`, `needs_builders()`, `claim_builder(who)`, `release_builder(who)`,
  `builder_ready(who)`, `build_spot(who)`, `face_point(from)` — owned by a `BuildCrew`. Idle
  workers then walk out and assemble it with no new AI, and the rule that **nothing the
  monarch pays for is built instantly** holds.
- Buildable at any time. **The bell only rings once `game_manager.map_cleared` has fired** —
  `ROADMAP.md` R1, "destroy all camps to leave".
- Ring → citizens walk over and board → end-of-map screen.
- ⚠️ **Stop there, and say so in the hand-off.** Map 2 does not exist. Store the R5
  carry-over (the monarch, the purse, N archers, N workers, currency X) in run state for
  later. **Do not invent map 2** to have somewhere to sail to.

**Hand-off:** build a boat with a real crew while nights are still happening. Does the wreck
read as buildable before you can afford it? Does the bell being dead until the camps burn
feel like a goal or like a lockout?

---

## F8 — Integration and polish

- **Dev overlay** — reveal-all fog, zoom presets, grant currency X, complete a boat, and
  force tonight's fronts to a chosen bearing. Add each via the `ACTIONS` list so the
  hotkeys and the buttons can't drift apart.
- **Audio.** Every new sound gets a row in `kingdom_demo/audio_review.html` **in the same
  pass that wires it** — surf bed, chest, altar, bell, boat construction, torches catching.
  Claude cannot hear anything: cut two or three candidates per role, restate the
  "what to listen for" criteria from `ASSETS.md`, and let Andrei pick. CC0 or CC-BY only.
- **Docs.** Update `CLAUDE.md` (the maps section, the fog-of-war reversal, the camera-zoom
  couplings, the wall `half` change, the new raid-bearing rule) and `ASSETS.md` (the pirate
  kit). These are the notes that stop the next session undoing this one.
- **Measure, don't eyeball** — navmesh bake time (already 67–91 ms on the existing maps and
  synchronous on every felled tree), tightest tree gap, tree count, mask upload cost, and
  frame time with the water plane in shot.

**Hand-off:** a full run start to finish, on the island, with no dev tools. Does it hold up?
