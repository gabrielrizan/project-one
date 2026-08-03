# kingdom_demo — The Last Monarch

A Kingdom / Kingdom Two Crowns-style village builder in **Godot 4.7 (GDScript)**, aiming at
the Thronefall / Tiny Glade look: **stylized flat-shaded low-poly 3D**, viewed from a high,
steep camera the player spins with Z / X.

Main scene is **`kingdom_demo/scenes/menu.tscn`** (title screen); the game itself is
`kingdom_demo/kingdom_demo.tscn`.

---

## The north star — read this before proposing anything

*Compressed from `kingdom_demo/GAME_DESIGN.md` Part A. That file has the full version and
is the source of truth; this block exists so the guardrails are always in context.*

**You play the monarch. You never build anything yourself — you pay, and your people do
the work.** Every feature should reinforce that.

**Pillars**, with what each one forbids:
1. **Indirect control.** The monarch has a tiny verb set; the kingdom self-organizes.
   → *Never* unit selection, build menus, right-click commands, or micromanaging a villager.
2. **Two economies that never substitute.** Coin buys construction and mercenaries; soup
   recruits citizens. → *Never* a coin↔soup exchange, or one fully replacing the other.
3. **One day/night is the heartbeat.** Build by day, survive by night.
   → *Never* pause, fast-forward, or skipping the night.
4. **Two hearts** — the Crown and the main building — so a bad night is survivable.
   → *Never* a single kingdom health bar or an instant-loss that isn't one of those two.

**What this is not:** not an RTS · not a menu city-builder (you buy by standing in front of
a thing) · not survival crafting (no inventory screen, no hunger bar) · not a tech tree.

**Palette (canon):** moss / forest / sage / olive greens · oak and walnut browns · linen ·
stone · charcoal · muted gold · ember · **burgundy** — the red complement that makes the
monarch the focal point against all that green. Off-palette assets get tinted into it.

**The 2D/3D split is deliberate.** Everything diegetic (cast, animals, trees, bushes,
buildings, decor) is a 3D model. Everything that is really UI wearing a costume (coins, the
tally, the paint blaze, job banners, `Label3D` prompts) stays a camera-facing 2D sprite.
Don't "finish the conversion" — they are billboards on purpose so they read from any angle.

---

## Where the build is now

*Backward-looking on purpose — this section records what exists. Direction lives in
**`kingdom_demo/ROADMAP.md`** (map progression, the five-tier hall ladder, unlocks and
playtime targets — decided with Andrei 2026-07-23/24) and the task lists in
`COMBAT_PROMPTS.md` and `DEPTH_PROMPTS.md`. `GAME_DESIGN.md` §13 still lists priorities.*

**Working:** monarch rides and buys via hold-to-pay · campfire → village → cauldron draws
wanderers → they eat, become citizens, take jobs · workers fell marked trees · archers hunt
and forage by daylight · crew construction for every wall rung and every hall tier ·
main building L1 Tent → L2 Wooden Hall → L3 Stone Hall → L4 Castle · day/night with real
camp lighting ·
**sun shadows gated on the sun's elevation, and depth fog that thickens with the storm** ·
**weather: rain, overcast skies, water pools, distant thunderstorms, on a season clock** ·
navmesh pathfinding round everything solid, re-baked as the village changes ·
title + pause menus, settings persist · **four selectable full-scale maps** picked from the
title screen, including **a round island ringed by sea** · **a dev overlay on F1** for
reaching any of it instantly.

**Combat is now built — `COMBAT_PROMPTS.md` P1–P10, bar P8's audio pass.** Charcoal bandits
(`bandit.gd`, archetypes Thug/Brute) march on the village from camps out on the map. A raid
director (`night_raids.gd`) counts nights off `darkness()` and sends growing waves, blowing
the dusk horn ×1 quiet / ×2 raid / ×3 blood moon. Archers mount wall perches and shoot; bandits rob
employed citizens (who flee and must be re-fed), smash walls/gates to breach (repair is
construction), and vandalise buildings — **the hall at zero ends the run** (end screen in
`game_manager.gd`). Every 15th night is a **blood moon**: red sky (`blood` factor in
`day_night_cycle.gd`, parallel to `storm`), a 2.5× wave in pulses mixed with Brutes.

**The offensive loop (P9–P10) closes it.** The **muster banner** (`muster_banner.gd`) outside
the gate raises a squad of free archers that trail the monarch and fight what he rides them
into (a `FOLLOW` state in `villager.gd`); coming home to the fire disbands them — never an
order in either direction. Each `BanditCamp` keeps a **standing garrison** (idle bandits at
its fire) the party must shoot down; with no defender left and an escorted archer in range the
squad looses a **fire-arrow volley** (`villager.gd::loose_fire_arrow`), the tents ignite, and
the camp burns to a charcoal wreck and leaves `bandit_camp` — so raids from that front stop.
**All camps burned fires `game_manager.map_cleared`** and posts a line; actually *leaving* the
map (the §10 exit) is still a future task. Numbers throughout (HP, wave/garrison sizes, damage)
are **placeholder**, like the flat-5 hall costs.

**Not built: `COMBAT_PROMPTS.md` P8** — the night audio pass. Bandit blows reuse the axe
pool pitched down and the breach reuses the gate slam, but the missing set (stone impacts,
a breach crash, a knockdown thump, bandit voices, a blood-moon night bed, **and a fire-arrow
whoosh + camp-burn** from P10) isn't sourced, and nothing is on `audio_review.html` yet. The
mix still has no ducking or limiter.

**Also not built:** soup upkeep / morale / desertion · mercenaries · the Stealer (bandits
still ignore the monarch, so the Crown lose-condition is reserved) · the map exit / moving to
the next map · camp re-establishment and night-kill garrison depletion (`ROADMAP.md` R8) ·
**music of any kind**.

**Audio is well past "none"** — beds, weather, work, the monarch's horse and a watch horn.
`ASSETS.md` holds the inventory and the per-role criteria; `audio_review.html` is the
listening desk. Several clips are placeholders chosen to get a feel, not finals.

**Placeholder numbers:** hall tier costs are a flat 5 so testing is fast, not a tuned curve.

**Population is capped by the hall's tier** — 6 at L1 Tent, 9 at L2, 12 at L3, 16 at L4
(`campfire.gd::TIER_CAPS`). Room to grow is what the upgrade buys. The cap gates *drawing
new wanderers*, not filling the pot: a batch of five outnumbers the cauldron's three
servings, so refusing the sale at cap would strand the last arrivals hungry for good.

## The docs

- **`CLAUDE.md`** (this file) — what the code *is*, and how to work here. Loaded every
  session. Claude keeps the factual parts current without asking.
- **`kingdom_demo/GAME_DESIGN.md`** — what the game is *for*. Pillars in full, future
  systems, decisions-with-rationale, open questions. Read before design-shaped work.
- **`kingdom_demo/ROADMAP.md`** — where the game is *going*: five maps, the five-tier
  hall ladder, per-map unlocks, the camp-assault objective loop, playtime targets.
  Decided with Andrei; where it and `GAME_DESIGN.md` §9 disagree, the roadmap is newer
  and wins. `COMBAT_PROMPTS.md`'s tasks assume it.
- **`kingdom_demo/ISLAND_PROMPTS.md`** — the eight tasks (F1–F8) building the island map:
  shore and water, camera zoom, fog of war, forest density, raids from any bearing, reward
  sites, the boat exit, polish. Decided with Andrei 2026-07-28. **F1–F7 have landed**;
  F8 (integration and polish) is the last. It deliberately expands past the frozen
  map-1 demo scope; that was his call, not drift.
- **`kingdom_demo/ASSETS.md`** — asset inventory, provenance, model quirks. Read when
  working on art.
- **`kingdom_demo/ART_PIPELINE.md`** — how polished art *gets made*: the Blender question,
  the four-layer polish order, the two reskinning routes, and **the animation plan** (the
  characters are unrigged — that is why the animation looks bad, and it is not tunable).
  Read before art-pipeline or animation work; `ASSETS.md` is what we have, this is how it
  gets built.

Before changing behaviour that looks wrong, check **`GAME_DESIGN.md` §11 (Decisions &
rationale)** — several things that read as bugs are deliberate. Before picking a direction
on an unresolved fork, check **§12 (Open questions)** and raise it rather than choosing.

## House rules — owned by Andrei

*Claude: propose changes to this section, don't make them.*

- **Percentages, not flat seconds**, for anything that scales with worker count, so one
  rule covers every build regardless of base duration.
- **Don't spawn subagents** unless explicitly asked.
- **Implement the mechanic asked for.** Don't redesign adjacent systems in the same pass;
  surface the idea instead.
- **Ask before downloading any new asset**, and record its licence in `assets/licenses/`.
- **Audio is CC0 or CC-BY only** — never `-SA` or `-NC`. Claude cannot hear anything, so
  Andrei does every ear test: send candidates out for audition with the per-role criteria
  from `ASSETS.md` ("What to listen for"), restated each batch.
- **Every new sound gets a row in `kingdom_demo/audio_review.html`** in the same pass that
  wires it. That page is Andrei's listening desk — open it in a browser and every clip in
  the game plays inline, with how often it fires and where it came from. A sound that isn't
  on it can't be reviewed.
- **No full end-to-end tests.** Go straight at the feature; don't re-verify things that
  already worked. See "Running and verifying".
- **Hand finished features to Andrei to play-test**, and ask him to report back using the
  AskUserQuestion format rather than proving it yourself with a long headless run.

## Running and verifying

Godot lives at
`C:/Users/andre/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.

**Andrei play-tests features himself.** When you finish a feature, tell him what to try and
ask him to report back — don't prove it with a long automated run.

**Test the feature, never the pipeline that reaches it.** Reach straight into the thing
under test: call its methods, set its state, skip the flow that would normally lead there.
Do *not* bootstrap campfire → wanderers → jobs → marked trees just to reach a building
upgrade. Assume already-working features still work; re-proving them buys nothing, and
those full runs take minutes or hang outright.

```gdscript
hall._open_upgrade_site(1)          # yes -- straight at it
hall._progress = 1.0
hall._finish_upgrade()
```

When a small check *is* worth writing: a throwaway `_verify_x.gd` in the repo root that
`extends SceneTree`, sets up the minimum, asserts, and `quit()`s. Then delete it — and
delete the `.uid` Godot drops beside it.

```
godot --headless --path . --script res://_verify_x.gd --fixed-fps 60   # logic
godot            --path . --script res://_verify_y.gd --fixed-fps 60   # + screenshots
```

- `--fixed-fps` makes it run unthrottled, so 30s of game time takes a couple of seconds.
- Load `kingdom_demo.tscn` **directly** — the project's main scene is the menu.
- Set `current_scene = <instance>` after `root.add_child()` — lots of scripts use
  `get_tree().current_scene`.
- Screenshot with `await RenderingServer.frame_post_draw` then
  `root.get_texture().get_image().save_png(...)`. Run windowed (no `--headless`) —
  `frame_post_draw` never fires headless and the run hangs forever.
- **Look at the screenshots.** Several bugs here were invisible in logs and obvious on
  screen (oversized job icons, coins vanishing mid-spin, a tally spanning half the screen).
- Kill stray Godot processes between runs; a hung one makes the next run's output look empty.

## How the game fits together

Start with 100 gold, a monarch and an unlit campfire. Light the fire → it raises the Tent
(L1), a Workers hut and an Archers hut, and puts the cauldron out. Feed the cauldron →
wanderers come in from the wild → they eat, become **citizens**, and take a job at a hut
with an opening. Job icons over a roof count *vacancies* and tick down as they fill.

**Workers** fell trees the monarch marks and raise anything under construction. **Archers**
hunt and forage, daylight only. Both haul their take to the monarch.

**Costs and timings live in the code, not here** — they drift as we tune. Look at:
`campfire.gd` (light, feed, hall tiers) · `building.gd` (`JOB_COST`, tier build times) ·
`wall_side.gd` (`LEVELS`) · `tree_resource.gd` / `berry_bush.gd`
(`MARK_COST`) · `build_crew.gd` (crew cap and speedup) · `game_manager.gd` (starting gold).

Facts that *don't* drift:
- **Gold is the monarch's purse, not a treasury.** `game_manager.coins` is what he is
  physically carrying; workers and archers hand their take over when they meet him.
  Uncapped for now — a cap plus a Treasury building is planned, not missing.
- **Wildlife and bushes renew; trees never do.** Timber is finite and its depletion is the
  run clock pacing the move to the next map. Don't add regrowth (`GAME_DESIGN.md` §11).
- **Vocabulary:** a **citizen** is a loyal villager who has eaten and taken a job; a
  **wanderer** has been drawn in but hasn't eaten and isn't yours yet.

### Maps (`map_def.gd` · `map_catalog.gd` · `map_terrain.gd`)

**A map is data, not code.** `MapDef` holds one map's shape — extent, the gate boxes that
seal bearings, the **shore**, wall offers, camps, muster point, carve lanes, forest config,
the wanderer walk-in lane, and `keep_clear` arteries. `MapCatalog` holds the built ones and
which is selected; **`MapTerrain` is the static facade everything else still reads through**,
so `mountains.gd`, `campfire.gd`, `wildlife.gd`, `night_raids.gd`, `muster_banner.gd` and
`bandit.gd` never learned that maps are swappable.

**Four maps, chosen from the title screen** (Play → Choose a Map; persisted in
`Settings.selected_map`):

| | Shape | Teaches |
|---|---|---|
| **The Mountain U** | rock on three sides, one 16 m corridor north | the canon §9 shape: one door, one wall, one fight |
| **The Deep Wood** | a clearing walled by forest, one trail out | the second camp is reachable **only by felling a lane** through the wood |
| **The Twin Passes** | a rock spine splits the north into two passes | two gates, but only one is hot — read the dusk fires |
| **Prototype 1 — Flat Terrain** | a round island in open water, no sealed bearing at all | every bearing is a bearing — the answer is a wall on all four sides |

The island is **much bigger than the land maps**: its coast runs 76–94 m out (~180 m across
against their 110–120), with camps 60 m from the fire — a **12 s ride** each way. That is
what the ground slab was grown from 180 m to **240 m** for, and the slab is shared, so it
now has ~25 m of headroom before the coast would run off it.

⚠️ **The first three are temporary.** They are the 2026-07 land prototypes; Andrei deletes
them once he is happy with the island, and **not on a task boundary** — don't remove them as
part of the island work. The map picker stays either way, even while the island is the only
entry. `ISLAND_PROMPTS.md` (F1–F8) is the island's build order; **F1 has landed.**

### The island (`ISLAND_PROMPTS.md` F1)

**The coastline is one predicate, not a pile of boxes.** `MapDef.shore` is `{base, wobble,
beach}` and `shore_at(theta)` is a base radius plus three fixed sines — **no rng anywhere in
it**, which is the only reason the collider ring, the water mesh, the beach and every
plantability test can each compute it independently and still agree. `is_blocked()` answers
true past it, and that single change made `is_open`, `gate_kind_at`, `_plantable`,
`_scatter`, `belly_point`, `wildlife.gd` and `world_decor.gd` sea-aware with no edit between
them. **Don't add a parallel "is this water" concept** — `beyond_shore()` exists only for
*point generation*, which needs to tell sea from a rock gate (both are blocked; only one is
where the backdrop belongs).

**The seal is physical, and it has to be.** `monarch.gd` carries no bounds clamp anywhere,
so on every other map the only thing containing him is a gate collider. `mountains.gd::
_shore_ring()` stamps 48 invisible boxes tangent to the shore under `MapDef.WATER` — a kind
that **dresses nothing at all**, unlike ROCK and WOOD. Measured overlap between neighbours
is ~20 m, so there is no sliver to thread.

**The sea wears a hand-painted coat.** `water.gdshader` samples a seamless watercolour tile
(Voxel Core Lab, CC0 — see `ASSETS.md`) **twice, at different scales and drift bearings**,
and **divides each sample by the tile's own mean** so what survives is the paper grain and
tonal drift, not the tile's colour. The hue still comes from `sky_color`, which is what keeps
the sea greying under cloud, reddening under a blood moon and going near-black at night. One
layer reads as wallpaper the moment two tiles are in frame, and on a 640 m sheet they always
are. The coat and the chop both fade with `length(VERTEX)` — past ~150 m a tile is sub-pixel
and aliases into shimmer rather than vanishing.

**`sea.gd` + `water.gdshader` draw everything and none of it is solid.** The water is a
**ring lying above the ground, not a plane below it**: the slab is 240 m square and the
island is ~180 m across, so green would show past the coast on every bearing — the ring
starts at the shore, runs to a 320 m horizon, and covers the slab (and the slab's own edge,
which is now under water level and can never come into shot). The beach is a sand annulus at
the same width `MapDef` uses as its planting setback, so sand and treeline are one number.
Both follow `weather.gd`'s `season_changed`, and so does the **ring of distant islands** —
which is not decoration but the replacement for the backdrop `world_decor.gd` correctly
loses, since on an island "past the map edge" is the entire ocean.

Three things this cost, all of which will bite again:
- **A ring mesh has to be wound counter-clockwise seen from above**, even with culling off.
  A double-sided material flips `NORMAL` on a back face, so a ring wound the other way takes
  no sun at all — the sand came out dark olive-brown at noon, which reads as a badly chosen
  colour rather than as a lighting bug. Cost two passes to spot.
- **Flat sheets need far more vertical clearance than they look like they do.** Beach 6 cm
  over the slab, water 4 cm over that, distant islands 30 cm — anything tighter z-fought into
  dashed stripes the moment the coast was seen from a distance.
- **The puddles' crossed-axis-wave trick does not scale to an ocean.** A *product* of an x
  wave and a z wave is zero along both axes of every cell, so from height it draws a visible
  plaid grid across the whole sea. Summing directional waves on bearings that share no common
  factor is the fix. Chop is also damped by `length(VERTEX)`, because past ~150 m the waves
  are sub-pixel and alias into moiré bands rather than disappearing.

**Walls carry a per-instance `half`** (`wall_side.gd`, default 8.0), written by
`map_walls.gd` **before `add_child`** because `_ready` lays the run out. The island passes
16.0: four 32 m walls at radius 16, one gate per side, enclosing a 32×32 village square
instead of plugging a 16 m doorway. `GATE_HALF` and `PERCH_OFFSETS` deliberately do not
scale — a gate stays a gate and archers still mass at it. `MapDef._plantable` measures
distance to a wall's **run**, not its centre, which a 32 m wall makes necessary.

**These are real scale, not prototype**: 110–120 m across (the old map was 52 m), camps
45–58 m out, which is a 9–12 s ride at the monarch's 5 m/s. Riding to a camp is an
expedition you plan against daylight. Verified tree counts land at 72 / 49 / 71, inside
`ROADMAP.md` R7's 40–80 target.

**Every map carries two camps, far apart, and only one raids.** The dormant one garrisons,
smokes and must still be burned to clear the map, but it never queues a wave and **never
flares at dusk** — so the flare stops being decoration and becomes the answer to "which way
is tonight coming from". Burning the *raiding* camp ends the nights even while the other
still stands.

**A camp is composed from three owned kits** (`bandit_camp.gd::_build`), the way
`HallBuilder` and `reward_site.gd` compose theirs: survival-kit tents, fire pit, bedrolls
and loot crates; a fantasy-town cart tinted walnut; a castle-kit pennant tinted the
bandits' own slate, standing 2.8 m so it reads from outside the clearing. **Nothing was
downloaded** — there is no CC0 bandit-camp pack in any of the usual sources (Quaternius,
Kenney and KayKit all have medieval kits; none has an encampment).

⚠️ **`tent.glb` is a bare A-frame with no canvas** — four poles and a ridge beam. The
camps were built from it for months, which is most of why they read as scaffolding rather
than as a place. The kit's real tent is **`tent-canvas.glb`**; `tent-canvas-half.glb` is
the lean-to. Their bounding boxes are identical to three decimals because the canvas hangs
*inside* the frame, so **measuring cannot tell them apart — only rendering them can.**
Every camp scale was also ~half what it should have been (a 0.98 m tent against a 1.2 m
villager), the same class of error as the F5 lanterns: kit models are ~0.5 m pieces, so a
plausible-looking multiplier lands nowhere near a plausible size.

⚠️ **A ragged palisade was tried behind the camp and removed.** A broken fence is mostly
gaps, so an arc of them reads as debris scattered behind the tents, not as a boundary —
`reward_site.gd`'s hermit-hut lesson again: neither kit contains a palisade, and no
arrangement of a garden fence becomes one.

⚠️ **Two hiding mechanisms is the bug.** `_build` starts `_props` hidden because on the
land maps `_check_discovery` un-hides it at `DISCOVER_R`. Handing that job to the fog
mask stood the check down — and **the mask writes `visible` on the camp node, never on a
child** — so `_props` stayed false forever and the island's camps were an ember, a smoke
column and three bandits standing in an empty clearing, for as long as fog has existed.
`_ready` now sets `_props.visible = true` whenever fog owns the hiding. Anything else that
hides itself *and* joins `fog_hideable` has the same trap waiting.

⚠️ **The camp's smoke was a 4–7 m slab.** `MarkFx.particle`'s `px` is `Sprite3D.pixel_size`
— metres per texel — and `wood_chip.png` is 8×8, so a puff is **eight times** the number
written; at 0.5–0.85 the tween grew it past 15 m, and the 8×8 texture was magnified enough
to read as brown blocks. It is 0.11–0.17 now (0.9–1.4 m, about twice the hermit's one-man
chimney). This is the third time this exact trap has been paid for — measure the texture,
then divide.

**A camp is a rumour until you ride out to it.** On the **land maps**, its structures and
its garrison stay hidden until the monarch has been within `BanditCamp.DISCOVER_R` (26 m)
while the smoke column and the ember stay visible from anywhere. 26 m is sized against the
camera, not the map: `battle 45` reaches ~15 m ahead of the monarch, so a camp is always
already revealed before it could enter frame. **Drop it below ~16 m and the reveal happens
on screen, which reads as a bug.**

⚠️ **On the island, fog of war owns this and the old rationale is reversed.** The whole
camp — smoke and ember included — is hidden until the ground it stands on has been
explored, and `_check_discovery` stands down. What used to be written here, in this file
and in `bandit_camp.gd` and `world_decor.gd`, was that smoke saying *something is out
there, that way* and the dusk flare saying *and tonight it is that one* were the game's
only diegetic answer to "which way is the raid coming from", so a shroud that swallowed
them would leave a quest marker in its place. **F5 moves that job to the walls.** Once the
raid bearing is rolled fresh each night across the four walls regardless of where the camps
are, a smoke column *cannot* forecast a raid — it is no longer connected to one. The lit
torches say it instead, from inside the village, more precisely, and without the player
having explored at all. So smoke reverts to its literal meaning: *someone lives out there,
that way* — a scouting lead and a standing objective. `flare()` still means something, but
it now means *this camp is active*, not *tonight comes from here*.

Discovery is **permanent** either way — memory of a place, not line of sight, so nothing
re-shrouds behind you. Hiding is cosmetic only: garrison bandits keep their colliders and
stay in the `bandit` group, which costs nothing because every engagement happens inside
10 m.

⚠️ **Smoke puffs are parented to the scene, not to the camp** (they must not inherit its
transform), so `visible = false` on a camp cannot reach them — `_smoke()` carries its own
`if not visible: return`. Without it the tents vanish under fog and the column goes on
rising out of black ground, which is exactly the tell the fog exists to remove.

**Hiding a camp is distance and route, not wall height.** Mountain peaks were pushed to
16–34 m to force occlusion; it worked and cost far more than it bought — a 16 m corridor
flanked by 30 m cones is a grey slot canyon, and riding out of the gate meant staring at rock
with no sky in frame. Heights are back to 12–24 m; what keeps a camp unseen is that it sits
**~36 m+ out** (the play camera shows ~28 m of ground past the monarch) and the route to it
bends. The peak *count* increase was kept — a ridge of a few 12 m-radius cones reads as
scattered boulders rather than terrain.

Two rules the layouts must keep, both of which have already bitten:
- **A wall goes *inside* the pinch, never south of it.** A wall set where the map is still
  80 m wide plugs nothing and raiders walk round its ends. All three had this bug; a flank
  test (is the ground solid 8.6 m either side of the wall centre?) caught it.
- **`keep_clear` reserves the arteries.** The forest is biased outward, so it will happily
  drop a stand in a 16 m corridor, and a stand that seals one strands the whole map — no
  wanderers in, no raid out, nothing in the logs.

### Forests, and why density and passability are separate knobs

Two tree populations share the playfield, and the split is what lets a wood be **dense to
look at and safe to walk through at the same time** — Andrei's two requirements, which are
only compatible because of it.

**All three tree populations come from `NaturePack` and all three turn with the season**
(2026-08-02). The understory was the last holdout — it loaded Kenney GLBs through a colour
tint, two of which the survival kit's colormap paints *orange* whatever tint you give them,
so a third of every wood stood summer-green-and-ember year-round among trees that had all
turned. `map_forest.gd::_grow_filler` draws its **positions once at `_ready` and only remakes
the models** on a season change, so the wood keeps its exact shape all year. Filler carries
no script and no collider, so a re-skin can never reach the navmesh.

| | Solid (`map_forest.gd` → `tree.tscn`) | Filler (`map_forest.gd::_filler`) |
|---|---|---|
| Script + collider | yes | **neither** |
| Markable | yes | no |
| Blocks / bakes into the navmesh | yes | no — walked through |
| Sets | how much the wood **blocks** | how dense the canopy **looks** |
| Count | 21–110 (`forest.cap`) | 76–1100 (`understory.cap`) |

So filler can be packed arbitrarily tight — nothing collider-free can wedge anybody — while
the solid trees are held apart by **`forest.spacing` (3.4–3.7 m), which is a walkability
guarantee, not a style choice.** A trunk collider is 0.5 m and the navmesh erodes 0.3 m each
side, so **two trunks under ~1.6 m apart leave a gap that looks walkable and is not** — that
is the exact shape of "the character gets stuck randomly". Measured tightest gap across the
three maps is 3.4–3.7 m, i.e. **1.8–2.1 m of genuinely clear width.** Never tune `spacing`
below 2.6 without re-measuring.

`understory.cap = 0` gives the sparse look; raising it thickens the wood. **Neither touches
how the map plays** — that is the whole point of the split.

**Placement is blue noise, not stands.** Even coverage with a minimum-distance rule, radius
drawn `sqrt(u)` so it is uniform *by area*. Stands (clumps with travel between) were tried
first and read as blobs of trees separated by suspiciously empty lawn.

### Three populations, one grid, and the order is the design (F4)

`MapDef.forest_plan()` places **bushes, then solid trees, then filler**, all against one
shared exclusion grid. Bushes go first and register demanding a **glade** of clearance, so
every other tree keeps back and each bush ends up in an opening. That is not a nicety:
"you can spot a bush without hunting for it" is one of the two things this wood is for, and
no amount of density tuning delivers it — a bush under a closed canopy is a bush you find
by walking into it, at any density.

Each point carries **two** clearances: `gap`, what it wants from its own kind, and `demand`,
what it asks of everyone placed later. That is why `forest.spacing` can stay a wide
walkability guarantee (3.7 m trunk to trunk) while `solid_demand` only asks filler for 2.4 —
holding filler a full trunk-spacing away bored a bald ring round every sellable tree.

⚠️ **Anything that reserves ground must be a fraction of the ground available.** A flat 6 m
glade is fine on the island and catastrophic on `deep_wood`: eight of them come to 680 m² and
that map's whole forest ring is 540, so the bushes ate the wood and it fell from 30 trees to
9. `_bush_rules()` scales the glade, the spread and the band off the band's own area, capped
at `GLADE_SHARE` (25%) of it.

⚠️ **A spatial hash only works if everyone agrees on the bucket size.** `_scatter` used to
derive its cell from its own gap, so the solid pass keyed the grid at 3.7 m and the filler
pass read the same dictionary at 2.1 — different keys for the same ground. The filler
therefore **never saw a single solid tree**, and the "no sprite growing out of a markable
trunk" guarantee documented here had never once held. One cell for the whole plan now,
sized to the largest clearance in play.

**Measured on the island** (F4, 2026-08-03; bushes re-measured 2026-08-04): 80 solid at a
tightest *actual* trunk gap of 4.06 m, 1100 filler, 14 bushes standing in **3.1–5.2 m**
pockets, 5.0 ms/frame and 455 draw calls with the whole wood in shot. Measure the tightest
gap; never trust `spacing` to have been honoured.

⚠️ **A bush wants a pocket, not a paddock.** `bush_glade` was 6 m — a 12 m opening round a
0.7 m bush, which reads as a clearing somebody made and put berries in rather than as
berries growing in a wood. The island sets **3.0**, which still holds every trunk far
enough off to spot one without walking into it. `_bush_rules`' `sep` ceiling came down
12 → 8 in the same pass: it only ever bound here, and a minimum separation that large
against 14 bushes stops being a minimum and becomes a lattice — the one arrangement
random placement never produces.

**A camp stands in the wood, and its clearing faces home.** `camp_clear` is the radius and
**`camp_clear_bias` shifts that same disc toward the village** (island: 10 and 3.5, so 6.5 m
behind the tents and 13.5 m in front — *less* bald ground than the old concentric 12, all of
it on the side the monarch arrives from). The assault is archers shooting a garrison, so the
fighting ground has to be where the fight is; trunks among the tents mean blocked shots and a
payoff you can't see. `night_raids.gd` **turns the camp to match** — the tent's mouth is at
local +Z, so an unturned camp has its back to its own clearing. That read correctly by luck
on the one camp due north of the village and had the southern one facing out to sea.

⚠️ **The island reserves no roads, and that is deliberate** (`keep_clear = []`). It used to
lane 12 m out to each camp, which drew two strips of lawn through the wood pointing at the
thing you were meant to discover. Nothing here needs one: raids land at the coast on a rolled
bearing, wanderers come up the east beach, and `forest.spacing` guarantees the wood is
walkable. **This is particular to the island** — on a map with corridors, `keep_clear` is
what stops a stand of trees sealing one and stranding the map silently.

⚠️ **Scenery trees never stand on open ground, and never on a rock gate.** `world_decor.gd`
fills only past the map edge and on **wood** gates; `mountains.gd` dresses wood gates. Two
separate bugs live here: scenery on reachable ground makes the player ride tree to tree
finding duds, and scenery inside a *rock* box comes out as pines sprouting from a cliff face.
**The nature-pack swap made the first one unavoidable rather than merely likely**: harvestable
trees (`tree_resource.gd`) and scenery trees now spawn from the *same* `NaturePack.tree()`
models, so there is no visual tell left at all. **Scenery bushes obey the same gate**, against
`berry_bush.gd`. Rocks, ground patches and small detail (grass, stumps, logs) are exempt and
belong on open ground — none of them is markable, so none can be mistaken for a purchase.

⚠️ **The navmesh bake runs on a background thread** (`nav_world.gd`), and has since the
island landed. Measured across all four maps the cost is a flat **~11 ms per 1000 m² of
bake volume** — 86–94 ms on the land maps, **~520 ms on the island** — so it is the map's
*area* that is expensive and **nothing about what seals the edge**: rock, wood and sea all
voxelise the same. Synchronous, that was half a second of dead screen every time a tree fell.
`bake_navigation_mesh(true)` leaves the frame paying **only 0–6 ms** (Godot parses the
scene's colliders on the main thread inside that window, which is also why there is no
scene-tree race) and Recast finishes on its own thread. The mesh is therefore ~0.5 s stale
after a change, which is fine — nothing needs it instantly. Two things follow and both are easy to break: **the gates stay lifted
until `bake_finished`** (re-enabling them on the next line now runs *before* Recast reads
anything, and the village bakes sealed), and `surface_offset` is measured in the callback.
A rebake requested mid-bake is re-armed, not run concurrently.

The bake volume is trimmed to reachable ground (`MapDef.play_min/play_max`), and a **round
map is the worst case for a box filter** — the island's box corners are 22% open sea that
cannot be trimmed. Don't set `play_*` from `extent`: extent has to clear the coast with room
to spare, and every spare metre there is ~11 ms. **A coarser cell is still not the lever** —
`CELL_SIZE` is 0.15 to fix a documented bush-oscillation bug.

### Fog of war (`fog_of_war.gd` · `ISLAND_PROMPTS.md` F3)

**Per map** (`MapDef.fog`), on for the island and off for the three land prototypes —
those are laid out to be *read*, and shrouding them argues with what each was built to
demonstrate. **Explored ground stays explored forever**: memory of a place, not line of
sight, no re-shrouding, no "visible but remembered" middle state.

**Two halves, because one plane cannot do it at a 45° pitch.** A single plane above the
world occludes the ground *in front of* it, never the ground under it, so a tree at the
frame's far edge would stand clear of its own fog — there is no shader answer to that.
1. **The ground** is darkened by a flat shroud reading a CPU-painted mask.
2. **Anything that stands up** is hidden by its own `visible`, through the `fog_hideable`
   group. Spawners call `FogOfWar.hide_until_found(node)` — one unconditional line, a
   no-op off-map. When the mask catches up the node is shown and **leaves the group**, so
   the sweep gets cheaper as the map opens and costs nothing once it's fully explored.
   ~730 nodes join at start on the island.

**The mask** is one 256² R8 image over the map's extent (~0.84 m/px), held as a raw
`PackedByteArray` and written **by index** — `Image.set_pixel` is a method call per pixel
and a monarch's brush is ~6 400 of them. Brushes are precomputed per radius and
**max-blended**, which makes "explored stays explored" a property of the data rather than
a rule to remember. Repainted and uploaded at 4 Hz, and only for revealers that have moved
`REPAINT_AFTER` since last time — a villager at a workbench costs nothing.

**Villagers reveal too, and that's the important part** (monarch **25 m**, villagers
**15 m**, tightened from 34/14 after play-testing): archers hunt and forage across the map
by daylight, so the island opens up as the economy grows rather than only when the player
goes sightseeing. At 34 the monarch unrolled the map faster than he could look at it and
the frontier was always off-screen; at 25 it sits near the edge of frame, so riding
somewhere and the map opening are the same motion.

⚠️ **The shroud is island-shaped, not a square.** A plane over the extent hangs a hard
black rectangle out over open water — it's cut to `shore_at()`, the same curve the collider
ring, the beach and the water mesh use. **The sea is deliberately not fogged**: it isn't
explorable, so shrouding it would only delete the horizon and the distant islands in
exchange for no information the player could act on. What you get is better — a dark island
in a bright sea, whose outline you can see and whose contents you cannot.

⚠️ The initial paint is **deferred**, and seeds the *village* as well as the monarch. This
node readies before the Monarch does, so an immediate paint finds nobody in the `monarch`
group and the run opens on a black village.

**One dev tool: `G` toggles the fog off and on.** A *view override* — it does not touch the
mask, so switching it back puts the frontier exactly where it was rather than wherever the
camera has been; hidden nodes are shown but kept in the group so they can be re-hidden. The
overlay prints `FOG OFF` while it is active, for the same reason it only shows the speed
multiplier when it isn't ×1: a bypass you forgot about must not be mistakable for a map you
explored.

A second "explore everything permanently" tool briefly existed on P and was **removed**
(Andrei, 2026-08-03). `FogOfWar.reveal_all()` survives, unwired, because nothing else can
produce a genuinely-explored mask — but it was never worth a key: nothing in the game reads
the mask except visibility, so a filled mask and a hidden shroud look and play identically,
and only one of them is undoable. Two tools you cannot tell apart by their effects are one
tool and a way to get confused.

### The camera, and the zoom (`camera_rig.gd` · `ISLAND_PROMPTS.md` F2)

The rig follows the monarch, spins on Z / X, and **zooms on the mouse wheel**
(`cam_zoom_in` / `cam_zoom_out`). The wheel slides the camera along **its own
back-vector**, which is the one motion that changes how much ground is in frame while
leaving the pitch, the aim point and the framing of the monarch alone — verified, the
pitch holds at exactly 45° at both stops. Steps are multiplicative (a fixed metre step
is coarse zoomed in and useless zoomed out) and the level eases toward its target.

**`CameraRig.zoom` is a static**, 1.0 being exactly what `kingdom_demo.tscn` ships —
that identity is what keeps `CAM_PRESETS[0]` honest. Stops are 0.55×–3.0×, which is
~15 m of ground to ~84 m. Deliberately **not** enough to hold the whole island; reading
the map from above is the `map 45` preset's job, not something the player does mid-run.

⚠️ **Three systems must read the zoom in the same frame, and all three fail silently
if they don't:**
- **`gold_fx.gd`** re-lays the tally out live, because pips are sized in *metres* — at
  0.63× apparent size a pip once fell to ~14px and you could no longer tell paid from
  unpaid, which is the entire readout. Re-applied every frame while a tally is up, not
  just at spawn: a 30-gold hold is 14 seconds and the player can scroll at any point.
- **`camera_rig.gd::_scale_prompts`** counter-scales `Label3D` prompts. They're authored
  in metres across half a dozen scenes, so each label's own `pixel_size` is remembered
  the first time it's seen and scaled from there — walking the `interactable` group, so
  no scene had to join a new one.
- **`day_night_cycle.gd`** scales `FOG_NEAR`/`FOG_FAR` and `directional_shadow_max_distance`.
  Fixed, the fog band lands on the grass under the monarch's feet when zoomed out. The
  shadow distance is **capped at 110** where the fog isn't: the shadow map is a fixed
  resolution, so stretching it 3× trades every contact shadow in the village for shadows
  at the frame edge nobody is looking at.

⚠️ **Zoom must never move the `AudioListener3D`.** It's pinned to the rig at a fixed
offset so camera distance and audio distance are separate things — that's the whole
reason it exists. Everything in the zoom path writes `_camera.position` and nothing else.

`_shake_camera` no longer *adopts* `_camera.position` as its rest pose. It used to, so
that "any future dynamic zoom" wouldn't be stomped; the future arrived, zoom owns
`_cam_base` directly, and adopting mid-shake would bake the shake offset in as the new
rest.

### The main-building ladder (`hall_builder.gd`)

**Five tiers (P0 / `ROADMAP.md` R2): L1 Tent (free) → L2 Upgraded Tent → L3 Wooden Town
Hall → L4 Stone Hall → L5 Castle.** L1–L2 are survival-kit tents (L2 the same tent grown a
rung); **L3–L5 are `HallBuilder` compositions**. `building.gd` holds the rungs as a **tier
array** (`tiers`, each `{model, name, scale, height, cost}`) rather than the old three flat
`upgrade_*` slots — five tiers needed an array, not a fourth copy. `campfire.gd` builds that
array in `_spawn_village` and reads the current rung through `hall.tier()` (1–5). A per-map
**`hall_cap`** (`campfire.gd`, map 1 = 3) stops the upgrade offer past the cap, so stone and
fortified walls are simply unreachable on map 1 — the prompt never appears. Pop caps are
`TIER_CAPS = [6, 8, 10, 13, 16]`.

**The hall tiers are composed from kit modules at runtime, not loaded.** The Kenney Fantasy
Town Kit has no house in it — all 167 pieces are modular wall/roof/doorway panels, and the
only assembled buildings are a windmill and two watermills — so `HallBuilder.build(cx, cz,
storeys, stone)` stamps a perimeter of walls and caps it with a flat roof and parapet.

**Every module is a 1 m cell with its panel on the cell's +X face**, and walls are exactly
1 m tall — measured, not assumed. So the composed specs in `campfire.gd` (`HALL_L3` etc.)
read directly as metres, which is the entire point: footprints and heights are comparable to
a 1.2 m villager instead of being guessed through a `model_scale` multiplier. Composed tiers
therefore carry `model_scale = 1.0`.

Two deliberate choices. The roof is **flat with a parapet** because a pitched roof needs its
slope panels oriented per edge and gets corners wrong on any non-square footprint, whereas a
flat cap cannot be oriented wrongly. And the roof panels are **tinted slate**, because the
kit bakes them turquoise, which from this camera reads as a swimming pool on every roof —
not burgundy, since the palette keeps red for the monarch.

`building.gd` takes a `PackedScene` per tier, so `HallBuilder.packed()` packs the composed
node rather than the interface being changed; it stamps `owner` on the direct children,
which is what `pack()` needs to keep them. A tier is 20–96 nodes, so the ladder is a few
hundred draw calls — fine at this map size, worth remembering if it ever isn't.

⚠️ **These are placeholders sized for depth, not final art.** They are capped at 4×4 so the
current spawn positions still clear each other; growing them further needs the village laid
out again (D2 in `DEPTH_PROMPTS.md`).

### The way off the island (`wreck_site.gd` · `ISLAND_PROMPTS.md` F7 · §10 exit)

**Two wrecks on opposite beaches**, from `MapDef.sites` with `kind = WRECK`. The map
entry gives a *bearing*; `map_sites.gd` resolves the actual spot against
`MapTerrain.beach_point()` and lays the hull tangent to the coast — "a wreck lies on
the sand" is a rule, so retuning the shore can never strand one inland.

**One model, two states.** The wreck *is* the ship: `SailShip` careened over 28°, sunk
into the sand, sails struck and timber repainted weathered grey. Repairing rights her
progressively as the crew works, so progress reads from across the beach with no bar.

**She is a `build_site`, which is the whole integration.** Joining that group and
answering the same seven duck-typed calls `wall_side.gd` answers is all it took —
idle workers already walk to anything in the group and swing at it, and `villager.gd`
never learns what a wreck is. It also keeps Pillar 1: the monarch commissions, his
people build.

**The bell is dead until every camp has burned** (`ROADMAP.md` R1). She can be rebuilt
from night one, and a finished ship with a silent bell states the map's objective in
one object. Ringing walks everyone aboard and banks `GameManager.carry_over`.

⚠️ **This is where the island ends.** Map 2 does not exist; the carry-over is *stored*,
not spent, and inventing a destination is explicitly not this task's job.

### Reward sites (`reward_site.gd` · `map_sites.gd` · `ISLAND_PROMPTS.md` F6)

**`MapDef.sites`** is `{pos, kind, clear}`, stamped by `map_sites.gd` the way
`map_walls.gd` stamps walls — a map with no sites builds nothing, so the land
prototypes are untouched. `clear` keeps trees off, exactly as `camp_clear` does: a
reward you can't see from two paces isn't a reward, it's a scavenger hunt.

**Ungated, and that is the design.** No portals, no risk tiers, no keys. On a map you
can leave in every direction, the cost of a reward is the daylight spent riding to it
instead of building — a real price, paid in the one currency the monarch can't make
more of, needing no mechanism to enforce it.

**Five finds on five bearings, none near another** (altar due west, hermit ESE, three
chests on the remaining quarters; radii 58–63 m so the set isn't a ring). The altar and
the hermit **used to share one clearing** 13 m apart, on the theory that two
stone-and-hearth things read as a shrine precinct — what it did was make the whole west
one destination and the other three quarters chests-only. Riding out and finding a second
reward in the same glade is one trip paying twice, which is the opposite of what an
ungated reward is for: the price is supposed to be the daylight.

⚠️ **Measure new sites against the wrecks too.** They're placed by *bearing* against the
live coastline, not by the coordinate written in `sites`, so they're easy to forget — the
first spread put a chest 18 m off a hull. Nothing non-wreck is now within 25 m of anything.

⚠️ **The chest is the first interactable in the game that gives rather than costs.**
Two calls follow: **no tally** — `GoldFx.pay` is the grammar of *spending* and running
it backwards would say the wrong thing, so the chest spills real `coin.tscn` coins to
ride over and collect; and **the same prompt grammar anyway**, because "walk up and
press E" is *the* verb and nobody should have to learn a second one to discover this
one is free.

**A chest sparkles until it's opened, and motion is what makes it findable — not bald
ground.** It's the smallest thing on the map (a 1 m box) and the one you ride furthest
for; `clear` was 7 m, which put it at the centre of a 14 m lawn and made it read as a
monument rather than as treasure. `clear` is now **4** and `GLINT_EVERY` does the work.
Glints are small and fast (a catch of light, not smoke — slow gold billboards read as the
chest being on fire) and stop dead on `_taken`, because a spent chest that still twinkles
is a reward the player rides back across the map to collect twice. **No `OmniLight3D` on
it**, however tempting at night: `gl_compatibility` caps omni lights per object, the ground
is one object, and that's the documented bug that silently killed the F5 wall lanterns.

**Currency X is `relic`** — internal id neutral, and every word the player reads comes
from `GameManager.RELIC_NAME`, so settling the name is one line. It is **not a third
economy**: it buys exactly one thing, the altar's blessing. The HUD counter stays
hidden until the first one is found, because a zero beside an unexplained icon on
night one is a question the game can't yet answer.

**All three sites are composed from owned kit modules**, the way `HallBuilder` composes
the halls — no kit has a shrine, a cottage or an open chest. The altar is a
`fountain-round-detail` plinth ringed by `pillar-stone` uprights; the hut is
`HallBuilder.build(3, 3, 1, false)`; the chest is `chest.glb` on a pivot node that
serves as its hinge. **Every model was measured first** — they run from a 26 cm chest
to a 2 m fountain ring, so one shared "looks right" multiplier gives doll's-house
furniture. Kit attributions in the briefs are unreliable: `pillar-stone.glb` is in the
fantasy-town kit, not the castle kit, and `crate.glb` doesn't exist anywhere.

⚠️ **The hermit's hut is the honest ceiling of these kits.** Hand-building it without
`HallBuilder`'s parapet was tried on the theory that a battlement round a one-room
cabin is what makes it read as a crate — it came out **worse**, because from a 45°
camera a 1 m tall, 3 m wide box is almost entirely roof and the parapet is the only
thing giving that slab an edge. A hut that reads as a *home* is an asset problem, not a
composition one: the fantasy-town kit's only assembled buildings are a windmill and two
watermills.

**FX are ambient, not decoration.** The hermit's chimney smokes — the same job the
bandit camps' column does, saying *somebody lives here* from further off than the
building itself reads. The altar drifts slow motes, because a shrine with no motion
reads as inert stone, and carries a low warm light so it can be found at night. Both
puffs are parented to the **scene**, not the site, so they need the same
`if not visible: return` guard `bandit_camp.gd` carries or they smoke out of unexplored
black ground.

⚠️ **`Sprite3D.pixel_size` is metres per texel, and `wood_chip.png` is 8×8** — so a
sprite is *eight times* whatever you write. 0.20 is a 1.6 m sheet, which is what the
first two passes drew: a translucent grey tarpaulin lying on the grass. Measure the
texture, then divide.

**Two blessings, and it must stay two** (`blessings.gd`, static like `CameraRig.zoom`).
The altar gives **+2 population cap** — the one permanent kingdom-wide effect that
can't violate Pillar 2, since it buys *room* for citizens rather than recruiting them.
The hermit is §9's cook, and the one rule he bends is **+1 cauldron serving**. Both are
deliberately small: a blessing that doubled income would make finding it the difference
between winning and losing, which turns an optional ride into a mandatory one. **This
is not a tech tree** (Pillar 4) — if a third reward looks tempting, first answer what
it takes away from the two that exist.

### Raids come from any bearing (`night_raids.gd` · `ISLAND_PROMPTS.md` F5)

**The raid bearing is rolled fresh each night across the map's wall offers, with no
regard for where the camps are.** While waves marched out of the raiding camp the
bearing was fixed by layout — fine with one opening, and badly wrong on a map walled
all the way round, where it would make three of the four walls decoration.

Per-map **`MapDef.max_fronts`**: 1 on the land prototypes (which leaves them exactly as
they were), 2 on the island. Schedule: **night 0 quiet · night 1 one front · night 2 two
fronts**, then the existing growth curve clamped to `max_fronts`. Waves are counted in
`CAMP_WAVE` units — "one camp's worth" per front — so two fronts is literally twice one
front, and the queue is dealt round-robin so both walls are hit together.

**Where a front lands is the map's business.** `MapDef.front_landing()` puts raiders
ashore at the coast on that wall's bearing, which needs no camp on that side to justify
it — that is what makes a random bearing honest. A landlocked map answers the village
instead, and the director takes the hint and marches them out of a camp as before.
Fronts are drawn from **wall offers, not walls built**: a front on a bearing you haven't
walled walks straight in, and that is the lesson, not an edge case.

**Lit lanterns are the cue**, and they are what pay for the fog swallowing the camp
smoke. `wall_side.gd` stands `lantern.glb` posts along each run — from the **fantasy
town kit**, the same kit the wall panels come from, so a lit wall is one piece of art.
The director lights only tonight's fronts at dusk and douses everything at dawn.

⚠️ **Nothing in the survival kit is the right model here.** F5's brief said to use
`lantern.glb` "already in the survival kit"; it isn't there, and the fallback it named,
`campfire-stand.glb`, measures **0.41 × 0.28 m** — a cooking tripod, invisible from the
play camera, so for two passes only its glow ever read. The fantasy-town lantern is a
**1.56 m standing post**, taller than a villager. That matters beyond looks: an *unlit*
wall's posts are still visible, so "those two are burning and those two aren't" is a
contrast rather than an absence. Measure a kit model before building around it. It is
tinted walnut, because the kit paints it blue and blue is nowhere in the palette.

⚠️ **The light is geometry, not lights.** `gl_compatibility` caps omni lights per object
and the ground is one object, so six lit lanterns across two fronts silently dropped all
but the nearest two and the outer half of every wall stayed dark. Each lantern now lays a
**flat firelight pool** on the ground — an additive quad with a runtime `GradientTexture2D`
radial falloff, the same trick the mist layer uses — plus an unshaded flame at the lamp
head. Only the two lanterns flanking the gate carry an actual `OmniLight3D`. A glowing
*sphere* in the air was tried first and was worse than nothing: low-poly reads as a hard
octagon up close, and additive on a night sky reads as an opaque disc.

**Archers man lit walls only, emptiest first.** `villager.gd::_claim_defense_post` used to
take the *nearest* wall with a free perch, which was the same thing as "the only wall"
until there were four. Now an unlit wall is never manned however close it is, and archers
go to whichever lit wall has the fewest defenders — so they split across two fronts with
nobody issuing an order, distance only breaking ties. The odd archer lands wherever is
behind when they ask, so no one is left unassigned.

### The wall ladder (`wall_side.gd`)

**Four levels — twig · wood · stone · fortified stone — each gated on the hall tier it
needs.** You cannot ring a tent with a castle wall; the defences can never outrun the hall
they defend, which is what stops walls being a way to skip the ladder. The old invariant
"the level index *is* the required hall tier" broke when the hall went to five tiers (P0),
so `LEVELS` now carries an explicit **`requires`**: twig→**L1**, wood→**L3** (Wooden Town
Hall), stone→**L4** (Stone Hall), fortified→**L5** (Castle).

Heights climb **0.75 → 1.05 → 1.35 → 1.64 m** against a 1.2 m villager: something you step
over, then hide behind, then man. Each rung is its own purchase opening its own site, and
nothing converts for free — a wall left at twig stays twig however grand the hall gets.

Gating reads `campfire.gd::hall_tier()` (1–5) against each level's `requires`. The old
`game_manager.stone_unlocked` / `building.gd::upgrade2_unlocks_stone` flags are **deleted**
(P0) — the wall reads the live hall tier, so there is nothing to keep in sync.

⚠️ Sections are spaced `STAKE_SPACING` = 1 m but the scaled models are 1.05–1.35 m wide, so
the upper rungs **overlap slightly**. That is deliberate — butted opaque panels read as a
continuous wall — but it means per-level spacing can't be introduced without also remapping
`_section_plan()`, which upgrades rely on to convert sections in place.

### Crew construction (`build_crew.gd`)

**Nothing the monarch pays for is built instantly.** Paying opens a **construction site**
(joins the `build_site` group) that idle workers walk over and claim. `BuildCrew` (a small
`RefCounted`, owned by whatever is building) caps a site at **3 workers**, each one past the
first adding **+30% pace** (1x / 1.3x / 1.6x) — nobody on site, no progress at all.

A site exposes the same duck-typed surface whatever it belongs to: `site_active()`,
`needs_builders()`, `claim_builder(who)`, `release_builder(who)`, `builder_ready(who)`,
`build_spot(who)`, `face_point(from)`. `villager.gd`'s `_claim_build_site()` only ever talks
to that interface, so `wall_side.gd` and `building.gd` don't know about each other.

**Adding a job position is the one instant purchase** — a job is a decision, not
construction, and the villager walking over is the delay. Anything crew-built refuses the
sale outright when no worker is alive to build it ("needs a worker"), so gold can't vanish
into a site that would never be worked.

### Weather & seasons (`weather.gd`)

One node drives rain, sky, pools, mist and lightning off a single **intensity** (0..1),
the same way `wind.gd` sweeps every tree. It is **atmosphere only — nothing about it
touches gameplay yet**, by decision, not oversight.

Two clocks, deliberately separate: **`intensity()`** is what is falling right now;
**`wetness()`** is how saturated the ground is and lags a long way behind, so pools keep
filling after a shower peaks and are still there well after the last drop. Tying pools
straight to intensity made rain look like a light switch.

**Overcast is not proportional to rainfall.** `cycle.storm` is driven off
`pow(intensity, OVERCAST_CURVE)`, not off intensity directly — drizzle falls from a sky
that is already covered, and what separates it from a downpour is how much water comes
down, not how much cloud is up there. Linear was wrong at the bottom of the range: light
rain dimmed the sun only 16%, so it read as bright midday sun with a few pale streaks
painted over it and the rain was invisible against lit grass. The curve lifts the low end
(0.35 → 0.56) and leaves a downpour exactly where it was. A *floor* says the same thing but
pops, because intensity ramps up from zero through the gathering phase.

**The season clock gates rain, and now dresses the world.** Four seasons,
`CYCLES_PER_SEASON` day/night cycles each, with their own rain odds, strength and thunder
odds. **Winter is still dry** (snow is a look, not precipitation yet). Seasons now carry a
**visual identity** (2026-08-02): `weather.gd` fires a **`season_changed(season)`** signal,
and the world re-skins off it — `world_decor.gd` re-grows its forest, rocks and bushes in
the season's coat (green in spring/summer, **autumn** colours, **snow-laden** in winter,
plus a whitened ground), harvestable trees (`tree_resource.gd`) swap their trunk to match,
and `wildlife.gd` thins game hard in winter. All the scenery is the imported **nature-pack**
(`assets/nature-pack/FBX`), planted through **`NaturePack`** (`nature_pack.gd`), which
auto-scales each raw FBX to a target height by its own bounding box — so model size is one
number at the call site, not a per-asset guess.

`day_night_cycle.gd` owns the environment; weather never writes it directly. It sets
`cycle.storm` and `cycle.flash` and the cycle blends them in **after** the time-of-day
colours, so a storm at noon still reads as noon. Two scripts writing `background_color`
in one frame would fight and flicker. **Depth fog follows the same rule and the same
path** — it lives in `day_night_cycle.gd`, and its colour is always the *final* `bg`, so
the haze can never disagree with the horizon in front of it at any hour, under any storm,
or during a lightning flash.

**Fog is weather, not atmosphere** — `fog_enabled` is `storm > 0.002`, so a clear day has
none at all. Clear-day fog was tried at four strengths and never earned its place: too weak
to see, or strong enough to read and then bleaching the treeline pale rather than pushing
it back. Depth fog can only tint toward one flat colour, and against this palette that
reads as *washed out*, not *far away*. Under rain it works, because obscured distance is
what rain actually does. Don't re-add it as a clear-weather effect without a new idea.

### The clock (`day_night_cycle.gd`)

**A cycle is 6 minutes, split 2.2 : 1 in daylight's favour** — 247.5s of day, 112.5s of
night. The proportions come from a reference day chart and the **named instants are the
source of truth**: `SUNRISE_AT` 30 · `NOON_AT` 135 · `SUNSET_AT` 247.5 · `MIDNIGHT_AT`
307.5, with dawn at t = 0. `DAY_DURATION` and the sun's arc are *derived* from those, so
retiming the day means editing five numbers and nothing else.

The sun is piecewise through those four instants rather than one linear sweep, because the
reference day isn't symmetric (sunrise→noon is shorter than noon→sunset). Verified: the sun
sits at 0° elevation at sunrise and sunset, 90° at noon, −90° at midnight. It is still one
continuous 360° across the cycle, so nothing snaps when the clock wraps.

`DUSK` (30s, from sunset) and `DAWN` (42s, up to sunrise) are **not** derived — they are how
long the sky takes to change, a readability call rather than an astronomical one. Dawn stays
the longer of the two.

Nothing outside this file knows how long a day is; everything reads `darkness()` or
`is_night()`. Weather's "three cycles per season" detects the clock wrapping, so it survives
any retime — a season is simply 18 minutes now.

### Shadows (`day_night_cycle.gd`)

**Gated on the sun's real elevation, never on the clock** — the same rule as the horn,
because the phase durations are placeholder. Below **8°** shadows are off outright (a sun
under the map would cast them *upward*, and it saves the pass for half of every cycle);
they fade to full by **28°**.

**That fade is the only honest control over shadow length.** Length is set by the sun's
arc, and the arc is the day — you cannot shorten a low-sun shadow without lying about
where the sun is. What you can do is make the longest ones faint, which is also what
really happens: a shallower sun travels through more atmosphere and casts softer, weaker
shadows. At 19° a 4.5m tree throws ~13m of shadow across the whole frame, and the fade
drops it to 0.57 strength so it reads as a smear rather than a bar. Widened from 5–20°
after the trees doubled in size and made the problem much more visible.

**Nothing weather draws casts** — gated once in `weather.gd::_add_layer()`, so rain,
splashes, mist and any layer added later inherit it. Ditto the puddle field
(`puddles.gd`). The flat ground quads in `world_decor.gd` (`_add_strip`, `_scatter_patches`)
must also stay non-casting: they are sheets lying at y≈0.02, and a low sun projects a
sheet's silhouette clear across the map.

**Rain leans along `wind.gd`'s bearing**, which is why `wind` is now a group — a storm
blowing across the wind reads as two weathers at once.

**A storm breathes while it falls.** Its intensity wanders between `1-SWELL` and its full
peak on two sine rates that don't divide into each other — the same trick `wind.gd::gust()`
uses, so there is no period to notice. Without it a storm ramped up, held *dead flat* until
its timer expired, then ramped down, and every storm in the game had an identical shape.
The swell only pulls **down** from the peak, so the peak stays the storm's ceiling, and it
is applied only in `RAINING` — gathering and clearing must be left to run to their ends.

**Peak intensity is drawn per storm from the season's band, so most rain is partial.** Only
summer's band reaches 1.0; spring caps at 0.72 and autumn at 0.85. A true downpour is
meant to be rare. When measuring the swell, sample **only while `state_name() == "raining"`**
— a long window runs off the end of the storm and measures it clearing, which looks
exactly like a swell to nothing.

### Dev overlay (`dev_menu.gd`) — F1

Weather is random and nightfall is minutes away, so tuning either by waiting is hopeless.
Every key reaches into a system directly:

| Key | |
|---|---|
| **F1** | show/hide the overlay (live time, season, weather readout) |
| **F2** | skip to night / day — lands *after* dusk and *at* sunrise, not on the phase boundary, which is still fully lit |
| **C** | camera preset — **three now**: the shipped `battle 45°` (perspective, fov 34, ~28m of ground), `iso 30°` (**orthographic**, size 16, ~32m), and `map 45°` (ortho 150, ~212m). The five D5 framing lenses are gone; that question is settled. The live A/B is projection: ortho gives the pixel-art isometric read — parallel edges stay parallel, no size falloff across the frame, and the horizon can never enter shot (every ortho ray sits at exactly the pitch), which is why 30° is safe here where a 30° *perspective* pitch would break the `FOG_PALE` seam rule. **`map 45` is a tool, not a lens** — it holds the whole island in one frame so the shape of the land can be read without a throwaway screenshot script, and fog and shadows are simply wrong in it by construction. A preset with `size` is ortho, one with `fov` is perspective; index 0 must stay in sync with the scene's camera or the readout lies. Presets go through **`CameraRig.set_rest_pose`**, never straight onto `Camera3D.position` — the wheel rewrites that every frame, so a direct write survives one frame |
| **wheel** | zoom (not a dev tool — shipped, see below) |
| **T** | speed ×1 → ×2 → ×4 → ×8 → ×16. `Engine.time_scale`, so the whole game moves, not just the clock. Audio keeps its own clock and stacks up badly past ×4; `max_physics_steps_per_frame` is raised alongside it or anything past ×8 silently runs slower than the label claims |
| **F4** | step rain: off → light → steady → downpour |
| **F5** | lightning now |
| **F6** | next season |
| **F7** | dry the ground (F4-off leaves pools to dry on their own) |
| **J / H / K** | horn — 1 blast (nightfall) / 2 (attack) / 3 (blood moon). Needs the fire lit |
| **L** | rooster — daybreak. Needs the fire lit |
| **G** | fog on ↔ off — a view toggle that leaves the mask alone, so the frontier is where you left it |
| **N / M** | spawn one bandit at the mouth / clear all bandits |
| **R / Y / U** | raid now / advance the night counter / blood moon now |
| **V** | walk tonight's fronts round the walls — the roll is random, so this is how you check the braziers read from every bearing |
| **O / I** | dismiss the war party (P9) / burn the nearest camp (P10, skips the assault) |
| **P** | copy the monarch's spot to the clipboard as `Vector3(x, 0, z)` — see below |
| F3 | navmesh debug — **already taken** by `nav_world.gd` |

**The `place` line is the map-authoring loop.** A map is data — camps, walls, sites, the
muster point and the spawn lane are all literal `Vector3`s in one function in
`map_catalog.gd` — and choosing a coordinate used to mean guessing a number, relaunching,
and going to look at where the thing landed. The overlay's first line reads
`place  Vector3(-54, 0, -7)   W 54m  ·  open`: ride to the spot, read it off, **P** to
paste it. `y` is forced to 0 because the world is one flat slab and every coordinate in
that file sits at zero. The ground word comes from `MapTerrain`, so `open` / `WATER` /
`ROCK` / `WOOD` / `off-map` is the *same* answer the spawners will give — which is what
stops a camp that looks fine in the file turning out to be three metres out to sea. It is
deliberately **first** in the readout: the lines under it rewrap as the weather and the
fronts change, so anything below them moves under the cursor while you're reading it.

**Every tool is a clickable button too**, built from the same `ACTIONS` list that binds
the keys, so the two can't drift. Add a tool by adding one entry and one method.

**The tool list scrolls**, because at 19 actions it outgrew the window and the last few
were simply unreachable. Only the list scrolls — the header and the readout stay pinned.
⚠️ Its height is set by **measuring the panel's actual overflow**, not by adding up the
chrome around it: an autowrapping label's height isn't known until it has been laid out at
its final width, and the readout rewraps with the map, the weather and the zoom, so the
arithmetic came out 130 px short. And it re-fits **on `visibility_changed`**, not just at
`_ready` — Godot doesn't lay out a hidden Control, and the overlay starts hidden, so the
startup fit measures a panel of size zero every time.

⚠️ It is a **dev tool with no release gate**. Wrap it in `OS.is_debug_build()` before
shipping.

### The tally (agreed vocabulary — use these words)

The row of coin markers that rises over something you are buying is the **tally**; each
marker is a **pip**; the interaction is **hold-to-pay**. (Do not call them "coin slots".)

`await GoldFx.pay(payer, anchor, cost, tally_y)` raises the tally and flies coins in one per
gold. The player must **hold E** the whole way through *and* stay within `MAX_RANGE` (4m) —
let go or walk off and the purchase is cancelled and the gold already handed over **spills
onto the grass** as loose, re-collectable coins. Returns true only when fully paid.

Only one payment runs at a time (`is_paying()`), and `monarch.gd` skips its highlight update
for the duration, so the king stays **locked on target** and a second tally can never appear.

## Core conventions

- **Interactables are duck-typed**, not an interface: any node in the `interactable` group
  with `show_prompt()` / `hide_prompt()` / `interact(who)` works. `monarch.gd` finds the
  closest one in its `InteractArea` and drives it.
- **Groups are the wiring**: `monarch`, `game_manager`, `interactable`, `workplace`,
  `villager`, `tree`, `marked_tree`, `bush`, `marked_bush`, `wild_game`, `wall_side`,
  `build_site`, `day_night_cycle`, `camera_rig`, `wind`, `weather`, `wind_sway`.
- **The watch horn counts.** Meaning lives in the *number of blasts*: **one** at nightfall,
  **two** for an attack, **three** for a blood moon (concept only). The blasts must stay
  countable, so `horn_night` (1.7s) is deliberately shorter than `ALARM_GAP` (2.0s) —
  overlapping them was the bug that made two indistinguishable from one. **Daybreak is a
  *rooster*, not a horn**, so the horn only ever means danger and its count never competes
  with a good-news call. Fired off `darkness()` crossing a threshold, **never off the
  clock** (the durations are placeholder); silent until the campfire is lit.
- **Ambient calls come out of a real emitter, never a bare bearing**, when there is a thing
  on screen they could come from. The tree creak plays out of a trunk within earshot and
  the deer out of a live animal in `wild_game`; both go silent when nothing qualifies, so
  the audio can't contradict the picture, and a wood you have hunted or logged empty
  audibly quietens. Reserve thrown-to-a-bearing calls (owl, thunder) for things genuinely
  offscreen.
- **A gait is a bunch of beats and then a gap, never an even tick.** `monarch.gd` runs a
  **stride clock** (`_advance_stride`) scaled by real speed; `GALLOP_AT` says where each
  hoof falls as a fraction of a stride and `GALLOP_GAIN` accents the lead hoof, and
  everything after the last entry is the suspension. Evenly spaced strikes read as
  "T T T T T" — the silence is what makes it a gallop. Changing gait is those two arrays
  and nothing else. Two constraints: falls inside a stride are ~75ms apart against a
  175ms clip, so strikes **must** be spread over several players (`HOOF_VOICES`) or each
  one cuts off the last; and the clock is deliberately **independent of the placeholder
  bob animation** — when the real gallop animation lands, drive it from `stride_phase()`
  so picture and sound share one clock.
- **Models face +Z with feet/base at y = 0**, and live under a `Model` holder node the
  script populates. Scripts turn them with `atan2(vel.x, vel.z)` and animate them by
  moving/rotating that holder. `villager.gd::_set_model()` swaps which model is worn — a
  wanderer carries no tools; taking a job swaps in the one that does.
- **`GoldFx` (autoload)** owns every gold spend — see "the tally".
- **`Settings` (autoload)** holds volume + fullscreen, saved to `user://settings.cfg`.
- **`menu.gd` is one scene used twice**: the title screen, and (with `pause_mode = true`,
  instanced under the game's `UI` layer) the Escape pause menu. Its layout is built in code,
  so there is no big hand-authored UI `.tscn` to keep in sync.
- **`MarkFx`** (`mark_fx.gd`, `class_name`, static helpers) owns the shared language for
  anything the monarch marks: paint blaze, floating banner, shake, leaves, debris — **and
  the mark sound**. Marking is *one verb*, so a tree and a bush get the same sound the same
  way they get the same blaze. Anything markable added later inherits it for free.
- **`villager.gd` is one big state machine** for the whole civilian life cycle — eating,
  taking a job, chopping, hunting, foraging, building, hauling gold home. Resist splitting
  it across files; keep the sections commented instead.
- **Everything that walks paths through the navmesh** (`nav_world.gd`, `nav_mover.gd`).
  `NavWorld` is a `NavigationRegion3D` in the main scene that bakes from the world's
  *static collision*, so anything solid is an obstacle with no bookkeeping — nothing
  registers itself. Put a collider up or take one down and call `NavWorld.rebake(self)`;
  requests coalesce and the bake is synchronous (~15ms). Bodies own a `NavigationAgent3D`
  plus a `NavMover`, which turns a destination into a steering direction — so `_seek()`
  and `_move_to()` kept their shape and every caller is unchanged. **F3** toggles path
  lines and pathfinding logs. `_unstick()` survives as a backstop for the two cases the
  mesh can't cover: another villager in the doorway, and a goal that isn't on the mesh.

## Gotchas that have already cost time

- **Billboarded sprites cannot rotate.** FIXED_Y discards node rotation entirely. Applies to
  every marker, banner and coin, which are still sprites.
- **3D models have no `modulate`.** A per-instance colour needs a material override, which
  flattens the model's own palette. Use motion instead — `MarkFx.hit_flash()` squash-pulses
  a model where it would flash a sprite.
- **`alpha_cut = 1` (DISCARD) cannot fade.** Tweening `modulate:a` pops out at the 0.5
  threshold. Anything that fades needs `ALPHA_CUT_DISABLED` — that's what
  `MarkFx.particle()` is for.
- **`get_tree().current_scene` is null during `_ready`.** The wildlife spawner silently
  spawned nothing because of this; it parents animals to itself instead.
- **World-space `Label3D` prompts are physically large.** A prompt a few words too long
  spans half the screen. Keep them terse and drop `font_size` if you lengthen the text.
  This bit again when the wall ladder landed: "Hold E  Upgrade to Fortified Wall (12)" is
  38 characters of 3D text lying across the village. The verb was dropped and every
  prompt's `pixel_size` cut ~25% for the pulled-back camera.
- **Everything world-space is coupled to the camera, and the tally breaks first.** Prompts,
  labels and the `GoldFx` pips are all sized in *metres*, so a camera change rescales them
  all. The pull-back to 26m/fov34 is 0.63× apparent size: prompts (already too big) got
  better, but a tally pip fell to ~14px and you could no longer tell a paid pip from an
  unpaid one — which is the entire readout. `PIP_SCALE` / `PIP_SPACING` went up ~1.6× to
  compensate. **Any future camera change has to revisit both, in opposite directions.**
- **3D audio was coupled to the camera too, and pulling it back silenced the short-range
  emitters.** Godot uses the current `Camera3D` as the audio listener, so the 26m pull-back
  put every `AudioStreamPlayer3D` 26m from the action — past the `max_distance` of the horse
  (22/26m), the cauldron feed (18m), and coin/clink/mark/berry — and they went dead silent
  (a source is fully cut off beyond `max_distance`). `camera_rig.gd::_setup_listener()` now
  pins a dedicated **`AudioListener3D`** to the rig at `(0, 6.645, 5.503)` — where the camera
  sat when the SFX were tuned — and `make_current()`s it, so audio range is decoupled from
  the camera. It hangs off the rig, so Z / X spin still pans the field; only distance is
  fixed. **A camera move no longer touches audibility — but changing this listener's offset
  re-tunes every positional sound at once.**
- **In a `--script` SceneTree file, autoloads are not resolvable by name** — reach them via
  `root.get_node("/root/GoldFx")`.
- **`Input.action_press()` in a test also drives the monarch's real `_try_interact()`**, so
  he will buy from whatever is in range. Park him somewhere empty or you'll chase phantom
  failures. Same class of false positive in assertions: background archer income can make a
  purse check pass for the wrong reason.
- **Worked-out things leave their group.** `tree_resource.gd::_fell()` does
  `remove_from_group("tree")` (and `"marked_tree"`); a picked bush leaves `marked_bush`. So
  `for t in get_nodes_in_group("tree"): if t.felled` **always counts zero** — the felled ones
  are already gone. Measure the group *shrinking*, not a flag on members. This produced a
  confident false bug report at least once.
- **A short obstacle can quietly become a step.** Recast measures climb in whole
  `cell_height` cells. At a 0.25 cell with `agent_max_climb = 0.5`, a 0.7m berry bush came
  out exactly two cells tall — i.e. a step you walk up — so bushes vanished from the mesh
  while keeping their collision. Peasants heading for the cauldron were routed *through* a
  bush, bounced off it, and shuffled back and forth against it all day. The world is one
  flat slab, so `cell_height` and `agent_max_climb` are both as small as they go. **If the
  navmesh and physics ever disagree about what is solid, units oscillate** — that is the
  signature of this class of bug.
- **A baked navmesh does not sit on the ground.** Recast lays polygons on top of the voxel
  column, so the surface comes out `2 × cell_height` (0.5m here) above the collider face
  bodies stand on. `NavigationAgent3D` measures "have I reached this waypoint" in all three
  axes, so an agent at y=0 decides it has *never* arrived and stalls one step into its path
  — moving, but at a crawl, with no error anywhere. `NavWorld` measures the offset after
  each bake and every agent wears it as `path_height_offset`. Cost an afternoon.
- **Baking takes collision at face value, including a shut gate.** A closed gate is a solid
  box across the only gap in the palisade; baked in, it seals the village and nothing ever
  gets out. `NavWorld._lift_gates()` drops them for the bake and puts them straight back.
  Anything else that is solid-but-meant-to-be-passable needs the same treatment.
- **The editor will silently overwrite your `.tscn` text edits.** The godot-ai MCP plugin
  keeps an editor session open; when it saves, it writes the scene from *its* in-memory
  copy and everything you edited by hand is gone. This ate the `Weather` and `DevMenu`
  nodes once — scripts all present on disk, feature simply not in the scene and therefore
  dead. It later moved the shipped camera from 18.38 m to 60.58 m, which silently made
  `CAM_PRESETS[0]` a lie about what the game ships with. After editing a `.tscn` by hand,
  **grep it back** — and check the lines you *didn't* touch too, since a save rewrites the
  whole file. The tell is float precision: `0.7071068` coming back as `0.70710677` is the
  editor re-serialising, not a hand edit.
- **A second writer can disable your feature outright, and the symptom is that *no*
  value you set changes anything.** `weather.gd` already owned `fog_enabled` and tied it
  to `_intensity > 0.02`, so fog was switched off whenever it wasn't raining. The new
  clear-day fog wrote density and colour onto a disabled environment every frame — so
  raising density from 0.55 to 0.72 to 1.0 all looked identical, and only storms ever
  showed haze, which looked exactly like "fog works, it just needs tuning". Two hours went
  into tuning a value that could not have mattered. **When a change has no visible effect
  at any magnitude, stop tuning and grep for another writer of the same property** —
  measure the pixels rather than eyeballing gradients (`get_image().get_pixel()` with the
  feature on vs. off settles it in one run). The rule that `day_night_cycle.gd` is the
  environment's only writer exists precisely because of this failure mode.
- **Fog has to differ from the ground in *luminance*, not just hue.** Mixing toward a
  midday sky blue over sunlit lime grass moves the pixel almost not at all, because the
  two are nearly the same brightness — which is why density alone could never make
  clear-day fog read. `FOG_PALE` lifts the haze toward white in clear daylight and is what
  actually makes it visible. It is free because **a 40° camera never shows the horizon**
  (the top of the frame is ~10° below it), so fog that doesn't match the sky exactly has no
  seam to give it away. Revisit if the pitch ever changes.
- **A clipped channel is invisible in a screenshot and obvious in a measurement.** The
  ground's green sat pinned at exactly **1.000 across the whole frame** at noon under a
  1.2-energy sun — 100% of sampled pixels — so midday carried *no shading information at
  all* and read as flat fluorescent green. It looked like "the art is too saturated"; it
  was actually an **exposure** bug. Fixed by `DAY_ENERGY` 1.2 → 0.9 alone — noon now lands
  at 0.949 with 0.3% clipped, and the tree canopies get their shading bands back.
  **When something looks over-saturated, sample the pixels before touching the palette.**
  Desaturating the ground albedo was tried first and was the wrong fix: it changed the
  grass to a washed grey-green that Andrei spotted immediately, because the hue was never
  the problem. The palette is canon (see the north star) — reach for exposure, not hue.
  If midday still needs taking down, the next lever is the **ambient** term, which
  contributes ~43% of the noon green and is what flattens the shading.
- **Tune fog to what the camera sees, not to the size of the map.** The first depth-fog
  pass used an 18–65m band for a "~30m world" and did nothing at all on screen — at the
  camera of the day the far edge of the frame was only ~32m out, so two thirds of the band
  sat behind the horizon. **The camera has since moved** (now `battle 45`: 18.38m up, 45°,
  fov 34), and the visible ground is a *slant* range of **21–39m**, not 3–32m — so the old
  band would now fog the grass under the monarch's feet. Band is 22–55m to match. Any
  camera change moves these again: work out the slant distance at the top and bottom of the
  frame first, then set the band inside it.
- **The `.tscn` writes a basis row-major; the GDScript `Transform3D(...)` constructor takes
  columns.** Decoding a hand-written scene transform with the constructor's convention
  transposes it and makes a camera that looks *down* appear to look *up*. The shipped
  camera is `rotation_degrees.x = -45`; in the file that is `(1,0,0, 0,cos,sin, 0,-sin,cos)`.
- **A flat ground slab gets shadow acne the moment the sun rakes it.** At ~14° elevation
  the whole field came out banded with moiré stripes. The fix that worked was **more
  shadow-map density, not more bias**: `directional_shadow_max_distance` was 70m for a
  camera that sees 32m, so halving it to 48 sharpened every texel. `shadow_normal_bias`
  2.5 finished it. Reach for distance first — bias buys the same thing at the cost of
  peter-panning, and the contact point at the feet is the entire cue.
- **SSAO was tried and removed — don't re-add it.** It changed **0.3%** of the frame at
  sensible settings and still only **0.8%** cranked to intensity 6 with a 2.5m radius;
  side-by-side crops at 3× zoom were indistinguishable. Three reasons, all structural: the
  world is convex objects on a flat plane, and AO needs *concavity* to bite; flat-shaded
  low-poly has no small-scale detail to shade; and the camera is 26m out, so what little
  effect exists lands on a handful of pixels. The deeper mistake was that **the sun's
  shadows had already solved the problem SSAO was being added to solve** — contact
  darkening is redundant next to a real cast shadow at the feet. It is a per-frame
  screen-space pass; it was costing that for nothing.
- **Post-process is not where this game's depth comes from.** Fog and SSAO both failed for
  the same underlying reason: a flat-shaded palette on a flat slab gives screen-space
  effects nothing to work with. What has actually moved the needle is **geometry and
  light** — cast shadows, the scale hierarchy, and the camera. Reach for those first, and
  be suspicious of any effect that has to be argued for rather than being obvious on sight.
- **Depth of field does nothing under `gl_compatibility`** — measured 0.000 pixel change at
  full strength, against SSAO 0.18, glow 0.47, saturation 0.15 and depth fog 0.68 in the
  same test. So **blur is not an option** for depth here. Two traps on the way: in Godot 4
  DOF is *not* on `Environment`, it moved to `CameraAttributesPractical` on the camera — and
  setting the old `Environment.dof_blur_*` names silently kills the coroutine and hangs the
  run, which looks exactly like a slow test.
- **`gl_compatibility` has no volumetric fog, no decals and no SSR** (`project.godot`
  sets the renderer; confirmed against the 4.7 docs). Anything "atmospheric" has to be
  faked: depth+height fog and a mist particle layer instead of volumetrics, flat quads on
  the slab instead of decals. Depth texture, screen texture and glow *are* available; SSAO
  is too, but see above — it does nothing useful in this game.
  Compatibility is also the **only renderer that exports to web**, so switching to Forward+
  costs a browser demo as well as a full re-tune of `day_night_cycle.gd`.
- **A failed `assert()` in a `--script` SceneTree hangs the run forever.** It kills the
  coroutine, so `quit()` is never reached, and the process sits there until killed —
  taking every buffered `print` with it, so the output looks empty and you blame the
  wrong thing. In throwaway verify scripts **collect failures and print them**, don't
  assert. Also don't test `AudioStreamPlayer.playing` headless: the dummy audio driver
  makes it unreliable. Assert on `volume_db`, which is pure logic.
- **A radial term in a shader draws concentric rings.** `sin(r * k)` over a round quad is
  a bullseye — the puddles looked like scorch marks with targets painted on them until
  the chop was rebuilt from two crossed axis waves instead.
- **Standing water reads *lighter* than the ground, not darker.** From a high steep camera
  what you see in a puddle is the sky, so the shader mixes heavily toward the sky colour.
  The first version used a near-black tint at high alpha and looked like burn marks.
- **A flat-alpha quad shows its own square edges where it overlaps another.** With 90 mist
  quads the haze came out as a grid of visible rectangles. Soft particles need a radial
  alpha falloff — `GradientTexture2D` with `FILL_RADIAL` generates one at runtime, no
  asset and no licence.
- **Lightning has to lift the *ambient*, not the sun.** Driving a flash through
  `light_energy` only brightens faces pointing at the sun, does nothing at night when the
  sun is under the map, and turns the grass fully saturated so it reads as the clouds
  parting. A blue-white ambient lift is both truer and far more readable.
- **A new `.ogg` imports with `loop=false`, and a bed that doesn't loop dies silently.**
  The rain beds played once and then never again — which looks like intermittent,
  unreproducible "sometimes there's no rain sound", because it only bites after the clip's
  length has elapsed. The existing beds had `loop=true` set by hand in the editor; anything
  imported from the command line does not. **After adding any looping audio, check
  `loop=` in its `.ogg.import` and flip it**, then re-run `--import`. One-shots must stay
  `false`.
- **Godot's editor eats `F8` (Stop Project) even when the game window has focus**, so a
  dev hotkey bound there just closes the game. `F5`/`F6` are Run shortcuts — leave them be.
  `dev_menu.gd` now drives its tools from one `ACTIONS` list that builds both the hotkeys
  and clickable buttons, so prefer adding a button over inventing another keybind.
- **`sf.write()` segfaults on long OGG encodes** (libsndfile, ~8s+ at 48 kHz). Write
  block-wise through `sf.SoundFile` instead. Relevant whenever audio is being cut up.
- **Holding "interact" for a fixed 1–2s is not enough for a big tally.** Each coin takes
  `COIN_FLIGHT + COIN_GAP` ≈ 0.44s, so a 30-gold purchase needs ~14s of holding. Size the
  hold off the cost or the purchase silently never completes.

## Assets

Full inventory and provenance: **`kingdom_demo/ASSETS.md`**. The rules:

- Licences for everything live in `assets/licenses/` — keep that true.
- **Anything requiring attribution goes in `assets/licenses/ATTRIBUTION-REQUIRED.md`**, in the
  same commit that adds the asset. That file is the shipping checklist for the credits
  screen; a CC-BY asset that never reaches it is a licence violation waiting to happen.
- **Ask before downloading anything new**, and record the licence next to the others.
- Everything must land in the palette above; tint off-palette assets rather than accepting
  them as-is.
- `assets/3d/characters/` and `assets/3d/props/` are **ours**, generated procedurally. The
  generator is gone — treat the GLBs as the source of truth.
