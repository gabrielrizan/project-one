# kingdom_demo

A Kingdom / Kingdom Two Crowns-style village builder in **Godot 4.7 (GDScript)**. It is a
3D world drawn almost entirely with **billboarded 2D pixel sprites** (`Sprite3D`,
`billboard = 2` / FIXED_Y, `texture_filter = 0`, `alpha_cut = 1`), viewed from a high,
steep camera that the player spins with Z / X.

Main scene: `kingdom_demo/kingdom_demo.tscn`. You play the **monarch**; you never build
anything yourself — you pay gold, and your people do the work.

## Running and verifying

Godot lives at
`C:/Users/andre/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe`.

**Verify changes by driving the actual game**, not by reading code. The pattern that works
well: write a throwaway `_verify_x.gd` in the repo root that `extends SceneTree`,
instantiates the main scene, drives it, asserts, and `quit()`s. Then delete it.

```
godot --headless --path . --script res://_verify_x.gd --fixed-fps 60   # logic
godot            --path . --script res://_verify_y.gd --fixed-fps 60   # + screenshots
```

- `--fixed-fps` makes it run unthrottled, so 30s of game time takes a couple of seconds.
- Set `current_scene = <instance>` after `root.add_child()` — lots of scripts use
  `get_tree().current_scene`.
- Screenshot with `await RenderingServer.frame_post_draw` then
  `root.get_texture().get_image().save_png(...)`. Run windowed (no `--headless`).
- **Look at the screenshots.** Several bugs here were invisible in logs and obvious on
  screen (oversized job icons, coins vanishing mid-spin, a tally spanning half the screen).

## The gameplay loop as built

Start with **100 gold**, a monarch, and an unlit campfire.

1. **Light the campfire** (3) → raises a Tent, a Workers hut and an Archers hut, and puts a
   cauldron out. **Fill the cauldron** (1 x3) → draws 5 wanderers in from the wild.
2. Wanderers **eat → become loyal → take a job** at a hut with an open position.
3. **Add jobs** at a hut (3 each, max 4). Icons over the roof count *open* positions and
   tick down as villagers fill them.
4. **Workers** fell trees the monarch marks. **Archers** hunt and forage, by daylight only.
5. **Build walls** (5 per side) — four sides, each with a gate that opens for your people.
6. **Upgrade the Tent → Wooden Town Hall** (15). `castle_t1.png` / `castle_t2.png` are
   unused and sitting there as obvious next tiers.

### Economy

| Action | Cost | Yield |
| --- | --- | --- |
| Mark a tree | 1 | 2 gold (worker fells it, 6 axe blows) |
| Mark a berry bush | 1 | 2 gold (archer strips it; regrows after 45s) |
| Rabbit | — | 1 gold (archer hunts it) |
| Stag | — | 2 gold |

Wildlife restocks (6 rabbits, 3 stags, one back every 10s) and bushes regrow, so both are
renewable rather than a one-time strip of the map.

## Core conventions

- **Interactables are duck-typed**, not an interface: any node in the `interactable` group
  with `show_prompt()` / `hide_prompt()` / `interact(who)` works. `monarch.gd` finds the
  closest one in its `InteractArea` and drives it.
- **Groups are the wiring**: `monarch`, `game_manager`, `interactable`, `workplace`,
  `villager`, `tree`, `marked_tree`, `bush`, `marked_bush`, `wild_game`, `wall_side`,
  `day_night_cycle`, `camera_rig`.
- **`GoldFx` (autoload)** owns every gold spend — see "the tally" below.
- **`MarkFx`** (`mark_fx.gd`, `class_name`, static helpers) owns the shared visual language
  for anything the monarch marks: paint blaze, floating banner, shake, leaves, debris.
  Used by trees (axe banner) and berry bushes (basket banner).
- **`villager.gd` is one big state machine** for the whole civilian life cycle — eating,
  taking a job, chopping, hunting, foraging, hauling gold home. Resist splitting it across
  files; keep the sections commented instead.

### The tally (agreed vocabulary — use these words)

The row of coin markers that rises over something you are buying is the **tally**; each
marker is a **pip**; the interaction is **hold-to-pay**. (Do not call them "coin slots".)

`await GoldFx.pay(payer, anchor, cost, tally_y)` raises the tally and flies coins in one
per gold. The player must **hold E** the whole way through *and* stay within `MAX_RANGE`
(4m) — let go or walk off and the purchase is cancelled and the gold already handed over
**spills onto the grass** as loose, re-collectable coins. Returns true only when fully paid.

Only one payment runs at a time (`is_paying()`), and `monarch.gd` skips its highlight
update for the duration, so the king stays **locked on target** and a second tally can
never appear.

## Gotchas that have already cost time

- **Billboarded sprites cannot rotate.** FIXED_Y discards node rotation entirely. To rotate
  anything (the falling tree), swap in a non-billboarded copy pinned to the camera's yaw,
  then tween its local Z — see `tree_resource.gd::_topple()`.
- **`alpha_cut = 1` (DISCARD) cannot fade.** Tweening `modulate:a` pops out at the 0.5
  threshold. Anything that fades needs `ALPHA_CUT_DISABLED` — that is what
  `MarkFx.particle()` is for.
- **`get_tree().current_scene` is null during `_ready`.** The wildlife spawner silently
  spawned nothing because of this; it parents animals to itself instead.
- **Asset filenames lie.** `hammer.png` is a **log** and `bow.png` is an **arrow** (hence
  `LOG_TEX` / `ARROW_TEX` in `building.gd`).
- **Source PNGs carry wildly different transparent padding** — `coin.png` is a 24px coin on
  a 128px canvas, `castle_t0.png` has 20px of dead space under the art. Never assume the
  canvas is the sprite; `building.gd::_fit_sprite()` measures opaque rows at runtime so
  buildings actually sit on the grass.
- **World-space `Label3D` prompts are physically large.** A prompt a few words too long
  spans half the screen. Keep them terse and drop `font_size` if you lengthen the text.
- **In a `--script` SceneTree file, autoloads are not resolvable by name** — reach them via
  `root.get_node("/root/GoldFx")`.
- **`Input.action_press()` in a test also drives the monarch's real `_try_interact()`**, so
  he will buy from whatever is in range. Park him somewhere empty or you will chase
  phantom failures. Watch for the same class of false positive in assertions: background
  archer income can make a treasury check pass for the wrong reason.

## Dormant code — do not assume it is live

`base_manager.gd` and `job_station.gd` are referenced by **no scene**. `peasant.gd` /
`peasant.tscn` exist but are not instanced in the main scene; peasants were the pre-village
recruitment system and spend gold directly rather than through the tally.

## Assets

`kingdom_demo/assets/pixel/`, with licences in `assets/licenses/`. Three sources, all
cleared for commercial use: **Tiny Swords** (Pixel Frog), **Pixel Crawler** (Anokolisa),
and **Animated Wild Animals** (ScratchIO, CC0) for the rabbit and stag. Some sprites
(`axe.png`, `mark_x.png`, `wood_chip.png`, `basket.png`) were generated procedurally with
Python, and `berry_bush.png` is a Pixel Crawler bush with berries painted on.

Ask before downloading anything new, and record the licence next to the others.
