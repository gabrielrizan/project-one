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
| `crow_a/b/c.ogg` | day one-shots — 0.8-1.3s drawn-out calls, bursts of 1-3 | iwanPlays, trouxel | CC0 |
| `axe_chop_1..5.ogg` | axe on trunk, 5 takes | super8ude | CC0 |
| `hammer_1..5.ogg` | hammer on build sites, 5 takes | AleXZavesa | ⚠ CC BY 4.0 |
| `coin_1..5.ogg` | one clink per tally pip, 5 takes — muted, climbs in pitch | Anthousai | CC0 |
| `bow_1..3.ogg` | archer looses, 3 takes | Ali_6868 | CC0 |
| `arrow_hit_1..3.ogg` | arrow lands — real archery impacts, tail-trimmed | JoeDinesSound, OwlStorm | CC0 |
| `gate_slam_1/2.ogg` | gate drops into a finished wall, 2 takes | Checkseven, elliott.klein | CC0 |
| `gate_open/close.ogg` | **parked** — gate swing creak, disabled | celadon_noise | CC0 |
| `build_raise_wood_1/2.ogg` | Wooden Hall landing — timber + rubble | rottako, magnuswaker | CC0 |
| `build_raise_stone_1/2.ogg` | Stone Hall landing — stone, long decay | mbezzola | CC0 |
| `tree_fall_1/2.ogg` | a marked tree coming down — **crash aligned to 1.09s** | ecfike, matt_beer | CC0 |
| `fire_light.ogg` | campfire catching — a whoosh, sub stripped | cribbler | CC0 |
| `job_tools_1/2.ogg` | **parked** — taking a post | ldezem, mickyman5000 | CC0 |
| `rain_light.ogg` | drizzle bed, 40s seamless loop | craigsmith | CC0 |
| `rain_heavy.ogg` | downpour bed, 200s seamless loop, stereo | kyles | CC0 |
| `thunder_1..4.ogg` | distant thunder — 4 cuts from **one** recording | richwise | CC0 |
| `ui_click.ogg` | every menu button — parchment page turn | MBPL | CC0 |
| `ui_click_alt_cloth.ogg` | **alternative, not wired** — cloth rustle | Joao_Janz | CC0 |
| `ambience_night_woods_SPARE.ogg` | **held back, not wired** — spare night bed | klankbeeld | ⚠ CC BY 4.0 |

The layering is in `ambience.gd`: two beds crossfaded by the day/night cycle, with
one-shots fired over them at randomised intervals, pitches and positions. Owls
after dark from a random bearing; timber groans by day, out of a real trunk within
earshot — ride into open ground and the woods go quiet.

**Sound follows material.** `wall_side.gd::GATE_SFX` and `building.gd::RAISE_SFX` are
both dictionaries keyed by material (`wood`, `stone`, ...) that fall back to wood for
any tier without its own set. The Wooden Hall and Stone Hall already land on genuinely
different recordings. Adding L4 Castle, or a stone gate, means adding one key — not
rewiring anything.

`wind.gd` is the visual half: every tree leans and rocks along one shared wind
bearing, and gusts blow leaves through camp. **No art was downloaded for it** —
the leaves reuse `MarkFx.particle` with the same chip texture the axe throws.

**Rain is two beds, layered, not one turned up.** A drizzle and a downpour are
different sounds, so `rain_light` fades up across intensity 0.02–0.30 and
`rain_heavy` across 0.35–0.95 — in a downpour both are playing. Rain also
**ducks the day/night bed** by up to 9 dB, because heavy rain really does drown
out birdsong, and without the duck the layers just pile up.

**All four thunders are cut from one recording** (`richwise` 361401). That is
deliberate: thunder taken from four different sources sits in four different
weathers — different distance, air and microphone — and the pool stops sounding
like one storm. The events were located by measuring the source rather than by
ear, and picked for isolation and a spread of lengths.

### Weather visuals — no art was downloaded for these either

`weather.gd` builds all three particle layers in code, and the pools are a
shader on a MultiMesh (`assets/shaders/puddle.gdshader`). The only texture
involved is a **soft radial dot generated at runtime** with `GradientTexture2D`
— flat-alpha quads show their own square edges where they overlap, which turned
the mist layer into a visible grid of rectangles until the falloff went in.

### Audio — where it got to, and what is left

*Not a commitment, just the state of play. `CLAUDE.md` is right that what to build
next is decided fresh each session.*

**Working:** day/night beds crossfaded, tree creaks, owl, positional campfire that
dips by day, axe, hammer, coin tally with a rising crescendo, coin into the purse,
bow + arrow, gate slam on completion, hall tiers landing on material-specific
sounds, tree falling aligned to its animation, campfire lighting, menu buttons.

**Parked** — assets and wiring kept, one flag each:
`CROWS_ENABLED` (the bed already has crows and anything on top reads as a second,
closer bird) · `GATE_SWING_SOUND` (fires constantly, needs to be near-subliminal) ·
`JOB_SOUND_ENABLED` (undecided what taking a post should be).

**Still silent:** marking a tree or bush · a berry bush stripped · an animal
dropping · a villager handing gold over · wall sections going up one by one ·
anything at all for night waves, since there is no combat yet.

**Known gaps in the system, not the clips:**
- No music. Not one note. Bigger question than any single effect.
- No mixing beyond three static bus levels — no ducking, no limiter. When combat
  lands, a night wave will fight the bed with nothing arbitrating.
- The day bed has ~12 bird events a minute baked in, repeating every 212s. Fine
  for now; the first thing to revisit if the loop ever becomes noticeable.
- Per-role kit for jobs, and stone/castle gate sets, both want the material-tier
  pattern that `RAISE_SFX` and `GATE_SFX` already establish.

### Claude can measure audio, even though it can't hear it

`pip install soundfile` (numpy is already there) makes every clip inspectable, and
it has caught things no amount of reading filenames would:

- **Count the events in a one-shot before trusting it.** A file called
  "Crow Call, *Single*" held three calls; another held nine. Layered under a burst
  system that fires 1–3 times, that came out as five or more caws. Onset detection
  on the RMS envelope gives the real count in seconds.
- **Check a bed for baked-in events.** Band-energy ratio (1.6–5 kHz against
  60–600 Hz) over an STFT finds bird calls hiding in a "wind" recording — the day
  bed has ~12 a minute, and they repeat with the loop.
- **Spectral centroid measures "bright vs dull".** Axe chop 3.5 kHz, campfire
  7.7 kHz, a de-gored arrow thump 340 Hz. Useful for "it sounds too X" notes.
- **Editing is allowed and often necessary** — CC0 and CC-BY both permit it. Cut a
  multi-call file into single events, trim tails, pitch down by resampling,
  low-pass to take the top off. Record every edit in the licence file.

None of this substitutes for Andrei's ear. It substitutes for *guessing*.

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
  the file must not. A filename saying "Single" is not evidence; measure it.
- **Then measure how long that one event lasts.** Count and length are different
  failures. The crow pool was wrong twice: first it held sequences (nine calls in a
  file), then it held true singles that were only 0.34s — sharp, close "CAH" sounds
  instead of the drawn-out call wanted. The keeper is 0.8–1.3s *per call*.
- **The gap between repeats has to clear the clip.** Firing a 1.3s call every 0.5s
  stacks them into a racket regardless of how good the clip is.
- **Tight top and tail.** No dead air either side, no fade chopping the sound off.
- **Dry and narrow.** These get positioned in 3D, so baked-in reverb or wide stereo
  fights the positioning and glues them to the speakers.
- **Character beats fidelity.** These play rarely, so a rough characterful crow is
  worth more than a pristine generic one.

**UI / interaction** (built — `menu.gd::_button`)
- **Measure the attack, not the material.** A sound with a ~0ms attack is a *click*
  however woody or leathery the sample is — that is what "sharp clicky mouse wheel"
  means. Want ≥0.05s of attack and some body. A 0.06s wood tick failed; a 0.32s
  page turn (0.112s attack) worked.
- **Short** — under ~400 ms, or the interface feels sluggish.
- **No ringing tail**, and no strong pitch — you will hear this thousands of times.
- **One material family** across hover / click / confirm (all wood, or all cloth).
- **Test twenty in a row.** Anything irritating only reveals itself on repetition.

**Impacts** (axe on trunks, hammer on build sites — both built)
- **The attack sells it**; the tail barely matters.
- **Needs 3–4 variants** or it machine-guns. Both pools carry 5.
- **Real over cinematic** — an actual axe in wood beats a Hollywood whack here.
- **Watch the rate as well as the clip.** These fire off `SWING_TIME` and
  `HAMMER_BEAT` in `villager.gd`, and at their original 0.46s / 0.42s even a good
  five-clip pool machine-gunned. A weighty impact needs room around it.

**Two numbers explain most "it sounds wrong" notes**
- **Attack time** = clicky vs soft. ~0ms is a click whatever the material.
- **Low/high energy ratio** (40–400 Hz against 1.5–6 kHz) = weight vs swish.
  Above ~5 reads as a boom; below ~0.2 reads as watery, thin, no body. The
  campfire was 11.57 ("explosion") and the tree fall 0.13 ("watery") — both were
  fixed by a spectral tilt rather than by re-sourcing.

**Sounds tied to an animation**
- **Align the loudest moment, don't just fire and hope.** Measure where the impact
  sits in the clip, work out when the animation lands, and trim the head so they
  coincide. The tree fall crashes at exactly 1.09s because that is 0.24s of lean
  plus `FALL_TIME`.
- **Which makes the clip a hostage to the timing.** Changing `FALL_TIME` silently
  desyncs it. Anything aligned this way says so in the licence file and in a
  comment at the constant.

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
