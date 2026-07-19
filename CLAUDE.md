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
title + pause menus, settings persist.

**⚠️ Nothing can go wrong yet.** There are no enemies, no night waves, no combat, and no
lose condition. The walls, gates, archers and day/night cycle are all *setup* for a threat
that does not exist. That is the single biggest gap — see `GAME_DESIGN.md` §9.

**Also not built:** L4 Castle · soup upkeep / morale / desertion · housing cap · mercenaries
· map objectives and moving to the next map · any audio at all.

**Placeholder numbers:** hall tier costs are a flat 5 so testing is fast, not a tuned curve.

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
  `build_site`, `day_night_cycle`, `camera_rig`.
- **Models face +Z with feet/base at y = 0**, and live under a `Model` holder node the
  script populates. Scripts turn them with `atan2(vel.x, vel.z)` and animate them by
  moving/rotating that holder. `villager.gd::_set_model()` swaps which model is worn — a
  wanderer carries no tools; taking a job swaps in the one that does.
- **`GoldFx` (autoload)** owns every gold spend — see "the tally".
- **`Settings` (autoload)** holds volume + fullscreen, saved to `user://settings.cfg`.
- **`menu.gd` is one scene used twice**: the title screen, and (with `pause_mode = true`,
  instanced under the game's `UI` layer) the Escape pause menu. Its layout is built in code,
  so there is no big hand-authored UI `.tscn` to keep in sync.
- **`MarkFx`** (`mark_fx.gd`, `class_name`, static helpers) owns the shared visual language
  for anything the monarch marks: paint blaze, floating banner, shake, leaves, debris.
- **`villager.gd` is one big state machine** for the whole civilian life cycle — eating,
  taking a job, chopping, hunting, foraging, building, hauling gold home. Resist splitting
  it across files; keep the sections commented instead.
- **Villagers have no pathfinding.** They steer straight at a goal, so a building square in
  the way pins them — `move_and_slide` has nothing to slide along on a dead-on hit.
  `_unstick()` sidesteps after 0.45s of trying-but-not-moving. Placing anything new in the
  village interior can create a new pin point.

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
- **Holding "interact" for a fixed 1–2s is not enough for a big tally.** Each coin takes
  `COIN_FLIGHT + COIN_GAP` ≈ 0.44s, so a 30-gold purchase needs ~14s of holding. Size the
  hold off the cost or the purchase silently never completes.

## Assets

Full inventory and provenance: **`kingdom_demo/ASSETS.md`**. The rules:

- Licences for everything live in `assets/licenses/` — keep that true.
- **Ask before downloading anything new**, and record the licence next to the others.
- Everything must land in the palette above; tint off-palette assets rather than accepting
  them as-is.
- `assets/3d/characters/` and `assets/3d/props/` are **ours**, generated procedurally. The
  generator is gone — treat the GLBs as the source of truth.
