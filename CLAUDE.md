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

*Backward-looking on purpose. There is no roadmap — what to build next is decided fresh
each session. `GAME_DESIGN.md` §13 lists rough priorities, but treat it as ideas, not a plan.*

**Working:** monarch rides and buys via hold-to-pay · campfire → village → cauldron draws
wanderers → they eat, become citizens, take jobs · workers fell marked trees · archers hunt
and forage by daylight · crew construction for walls, wall→stone, and both hall tiers ·
main building L1 Tent → L2 Wooden Hall → L3 Stone Hall · day/night with real camp lighting ·
**weather: rain, overcast skies, water pools, distant thunderstorms, on a season clock** ·
navmesh pathfinding round everything solid, re-baked as the village changes ·
title + pause menus, settings persist · **a dev overlay on F1** for reaching any of it
instantly.

**⚠️ Nothing can go wrong yet.** There are no enemies, no night waves, no combat, and no
lose condition. The walls, gates, archers and day/night cycle are all *setup* for a threat
that does not exist. That is the single biggest gap — see `GAME_DESIGN.md` §9.

**Also not built:** L4 Castle · soup upkeep / morale / desertion · mercenaries
· map objectives and moving to the next map · **music of any kind** · any mixing beyond
static bus levels (no limiter, no ducking except rain over the beds).

**Audio is well past "none"** — beds, weather, work, the monarch's horse and a watch horn.
`ASSETS.md` holds the inventory and the per-role criteria; `audio_review.html` is the
listening desk. Several clips are placeholders chosen to get a feel, not finals.

**Placeholder numbers:** hall tier costs are a flat 5 so testing is fast, not a tuned curve.

**Population is capped by the hall's tier** — 6 at L1 Tent, 9 at L2, 12 at L3
(`campfire.gd::TIER_CAPS`). Room to grow is what the upgrade buys. The cap gates *drawing
new wanderers*, not filling the pot: a batch of five outnumbers the cauldron's three
servings, so refusing the sale at cap would strand the last arrivals hungry for good.

## The two docs

- **`CLAUDE.md`** (this file) — what the code *is*, and how to work here. Loaded every
  session. Claude keeps the factual parts current without asking.
- **`kingdom_demo/GAME_DESIGN.md`** — what the game is *for*. Pillars in full, future
  systems, decisions-with-rationale, open questions. Read before design-shaped work.
- **`kingdom_demo/ASSETS.md`** — asset inventory, provenance, model quirks. Read when
  working on art.

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
`wall_side.gd` (`BUILD_COST`, `STONE_COST`) · `tree_resource.gd` / `berry_bush.gd`
(`MARK_COST`) · `build_crew.gd` (crew cap and speedup) · `game_manager.gd` (starting gold).

Facts that *don't* drift:
- **Gold is the monarch's purse, not a treasury.** `game_manager.coins` is what he is
  physically carrying; workers and archers hand their take over when they meet him.
  Uncapped for now — a cap plus a Treasury building is planned, not missing.
- **Wildlife and bushes renew; trees never do.** Timber is finite and its depletion is the
  run clock pacing the move to the next map. Don't add regrowth (`GAME_DESIGN.md` §11).
- **Vocabulary:** a **citizen** is a loyal villager who has eaten and taken a job; a
  **wanderer** has been drawn in but hasn't eaten and isn't yours yet.

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

**The season clock gates rain and nothing else.** Four seasons, `CYCLES_PER_SEASON` day/night
cycles each, with their own rain odds, strength and thunder odds. **Winter is dry** — that
is a placeholder for snow, not a design statement. Seasons have *no visual identity yet*:
no tree recolouring, no snow, palette unchanged. That was Andrei's call — keep it simple
for now.

`day_night_cycle.gd` owns the environment; weather never writes it directly. It sets
`cycle.storm` and `cycle.flash` and the cycle blends them in **after** the time-of-day
colours, so a storm at noon still reads as noon. Two scripts writing `background_color`
in one frame would fight and flicker.

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
| **F2** | skip to night / day |
| **F4** | step rain: off → light → steady → downpour |
| **F5** | lightning now |
| **F6** | next season |
| **F7** | dry the ground (F4-off leaves pools to dry on their own) |
| **J / H / K** | horn — 1 blast (nightfall) / 2 (attack) / 3 (blood moon). Needs the fire lit |
| **L** | rooster — daybreak. Needs the fire lit |
| F3 | navmesh debug — **already taken** by `nav_world.gd` |

**Every tool is a clickable button too**, built from the same `ACTIONS` list that binds
the keys, so the two can't drift. Add a tool by adding one entry and one method.

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
  dead. After editing a `.tscn` by hand, **grep it back** to confirm the change survived.
- **`gl_compatibility` has no volumetric fog, no decals and no SSR** (`project.godot`
  sets the renderer; confirmed against the 4.7 docs). Anything "atmospheric" has to be
  faked: depth+height fog and a mist particle layer instead of volumetrics, flat quads on
  the slab instead of decals. Depth texture, screen texture, glow and SSAO *are* available.
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
