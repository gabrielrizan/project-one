# Assets — inventory & provenance

Read this when working on art. The *rules* (palette, licensing, ask-before-downloading)
live in `CLAUDE.md`; this file is the inventory behind them.

Licences for everything live in `assets/licenses/` — keep that true.

## 3D (`assets/3d/`)

**Third-party**
- **Kenney kits** — castle, survival, game-icons. The bulk of the world: walls, gates,
  doors, fences, tents, towers, tools, trees, rocks, barrels.
- **Ultimate Animated Animals** (ScratchIO, CC0) — the stag, which is rigged and keeps
  its walk cycle. The only animated third-party model in the project.

**Ours — `assets/3d/characters/` and `assets/3d/props/`**
Generated procedurally: the villager / worker / archer / monarch-on-horse cast, the rabbit
(that pack has no hare), and the ripe / picked berry bushes. Flat-shaded, one material per
palette colour, no textures or rigs.

> ⚠️ **The generator lives in the scratchpad, not the repo.** Regenerating means rewriting
> it from scratch, so treat the GLBs as the source of truth — edit or replace them
> directly rather than trying to re-run generation.

## 2D (`assets/pixel/`)

What's left of the sprite layer, after the world went 3D: coins, `mark_x.png`,
`wood_chip.png`, `axe.png` and `basket.png` (job banners), and HUD icons.

From **Tiny Swords** (Pixel Frog), **Pixel Crawler** (Anokolisa), or generated with Python.

## Audio (`assets/audio/`)

Sourced CC0 or CC-BY only — never `-SA` or `-NC` (see
`assets/licenses/ATTRIBUTION-REQUIRED.md` for why, and for the credits checklist).

All Freesound, fetched as public 192 kbps OGG previews. ⚠ = must be credited.

| File | Role | Author | Licence |
|---|---|---|---|
| `ambience_day.ogg` | day bed — winter forest, 212s | klankbeeld | ⚠ CC BY 4.0 |
| `ambience_night.ogg` | night bed — twilight insects, 219s | kevp888 | ⚠ CC BY 4.0 |
| `campfire_loop.ogg` | campfire positional loop, 157s | newlocknew | ⚠ CC BY 4.0 |
| `owl_hoot.ogg` | night one-shot, 4.4s | Breviceps | CC0 |
| `tree_creak_a/b/c.ogg` | day one-shots — 0.4s / 1.8s / 10.9s | Department64 | CC0 |
| `ambience_night_woods_SPARE.ogg` | **held back, not wired** — spare night bed | klankbeeld | ⚠ CC BY 4.0 |

The layering is in `ambience.gd`: two beds crossfaded by the day/night cycle, with
one-shots fired over them at randomised intervals, pitches and positions. Owls
after dark from a random bearing; timber groans by day, out of a real trunk within
earshot — ride into open ground and the woods go quiet.

`wind.gd` is the visual half: every tree leans and rocks along one shared wind
bearing, and gusts blow leaves through camp. **No art was downloaded for it** —
the leaves reuse `MarkFx.particle` with the same chip texture the axe throws.

### What to listen for when auditioning

*Andrei does the ear test — Claude can't hear anything. These are the criteria to
judge against, by role. Restate them whenever a new batch goes out for audition.*

**Beds** (the loop that plays forever, underneath everything)
- **Is it boring?** Twenty seconds in, try to describe it. If you can name an event
  — "there's a bird at 0:08", "a car goes past" — it is not bed material. That event
  will repeat until the end of time.
- **Landmarks are the enemy.** Planes, dogs, voices, a distinctive bird phrase, one
  dramatic gust. A landmark is precisely what the ear uses to detect a loop.
- **Even energy throughout.** If it starts calm and builds to a gale, looping it
  pumps. Same intensity at 0:10 and 2:00.
- **Hiss and rumble.** Cheap recorders add constant hiss; wind on a bare mic thumps.
  Both become exhausting when they never stop.
- **Do the ends match?** Compare the first and last five seconds. Different-sounding
  ends means an audible click at the loop point.
- **The real test:** set it to the quiet volume it will actually play at, then go do
  something else for two minutes. If you forget it is on, it is a good bed.

**Campfire / positional loops**
- Everything above, plus:
- **Just the fire.** No crickets, no wind, no voices baked in — it layers *on top of*
  the bed, and any extra content will fight it (a fire recording with crickets in it
  will clash with the night bed).
- **No big discrete events.** A log collapsing or one loud pop becomes comedy on a
  timer. Continuous small crackle is what carries.
- **Mid-close, not roaring.** Crackle detail without a bonfire's roar.
- **Indoors is wrong.** Fireplace recordings carry room reverb that reads as "inside".

**One-shots** (single bird call, crow, owl, creak — the anti-loop layer)
- Requirements are the *opposite* of a bed.
- **Clean isolation is everything.** Background in the clip is the number one killer:
  it switches on and off with the sound and instantly reads as a layer, not a bird.
- **One event, not a sequence.** One caw, not eight — the randomiser owns the rhythm,
  the file must not.
- **Tight top and tail.** No dead air either side, no fade chopping the sound off.
- **Dry and narrow.** These get positioned in 3D, so baked-in reverb or wide stereo
  fights the positioning and glues them to the speakers.
- **Character beats fidelity.** These play rarely, so a rough characterful crow is
  worth more than a pristine generic one.

**UI / interaction** (not built yet)
- **Short** — under ~200 ms, or the interface feels sluggish.
- **No ringing tail**, and no strong pitch — you will hear this thousands of times.
- **One material family** across hover / click / confirm (all wood, or all cloth).
- **Test twenty in a row.** Anything irritating only reveals itself on repetition.

**Impacts** (axe, hammer — not built yet)
- **The attack sells it**; the tail barely matters.
- **Needs 3–4 variants** or it machine-guns.
- **Real over cinematic** — an actual axe in wood beats a Hollywood whack here.

**Always:** audition at the quiet volume it will really play at, on the headphones or
speakers you actually play on. Everything sounds convincing loud and once.

## Model quirks worth knowing

- **Asset filenames lie.** `hammer.png` is a **log**; `bow.png` is an **arrow** (hence
  `LOG_TEX` / `ARROW_TEX` in `building.gd`).
- **Kenney tools are tiny.** `tool-hammer.glb` is 0.15m tall — it needs ~5x scale to read
  as a banner next to the 0.90m `axe_marker.glb`.
- **`fence.glb` is only 0.52m tall**, while the wall collision box is 1.5m. The palisade
  reads much lower than it blocks.
- **Castle-kit pennants ship blue**, which is nowhere in the palette — `wall_side.gd`
  flattens them to burgundy with `MarkFx.tint()`.
- **Source PNGs carry wildly different transparent padding** — `coin.png` is a 24px coin
  on a 128px canvas. Never assume the canvas is the sprite.
- Measure a model before guessing its scale: instantiate it and merge the `get_aabb()` of
  every `MeshInstance3D` under it.
