# Assets — inventory & provenance

Read this when working on art. The *rules* (palette, licensing, ask-before-downloading)
live in `CLAUDE.md`; this file is the inventory behind them.

Licences for everything live in `assets/licenses/` — keep that true.

## 3D (`assets/3d/`)

**Third-party**
- **Kenney kits** — castle, survival, game-icons. The bulk of the world: walls, gates,
  doors, fences, tents, towers, tools, trees, rocks, barrels.
- **Kenney Fantasy Town Kit 2.0** (CC0, added 2026-07-22, `kenney_fantasy-town-kit/`) —
  167 GLBs for the main-building ladder. ⚠️ **Entirely modular** — stone and wood wall
  panels, roof panels, doorways, stairs, fences, roads. The only assembled buildings in it
  are `windmill`, `watermill` and `watermill-wide`, so **halls have to be composed from
  pieces**; there is no house model to drop in. Red and green roof panels; the red sits
  with the palette's burgundy.
- **Ultimate Animated Animals** (ScratchIO, CC0) — the stag, which is rigged and keeps
  its walk cycle. The only animated third-party model in the project.
- **Nature pack** (`assets/nature-pack/FBX/`, added 2026-08-02) — 150 stylized FBX: trees
  (Common / Birch / Pine / Willow, each with **green / autumn / snow / dead** coats),
  rocks (plain / moss / snow), bushes, grass, flowers, plants, stumps, logs, and desert
  pieces (cactus, palm) we don't use on this temperate map. This is now the **world's
  vegetation** — the old Kenney/composed trees and rocks are retired from `world_decor.gd`
  and the harvestable `tree.tscn`. Planted through **`NaturePack`** (`nature_pack.gd`),
  which auto-scales each model by its bounding box, and re-skinned per season off
  `weather.gd`'s `season_changed`. ⚠️ **Licence: CONFIRM WITH ANDREI and record in
  `assets/licenses/` before shipping** — looks like a Quaternius CC0 nature pack but the
  source hasn't been logged yet. Embedded diffuse-colour materials, no textures.

**Ours — `assets/3d/characters/` and `assets/3d/props/`**
Generated procedurally: the villager / worker / archer / monarch-on-horse cast, the rabbit
(that pack has no hare), and the ripe / picked berry bushes. Flat-shaded, one material per
palette colour, no textures or rigs.

> ⚠️ **The generator lives in the scratchpad, not the repo.** Regenerating means rewriting
> it from scratch, so treat the GLBs as the source of truth — edit or replace them
> directly rather than trying to re-run generation.

**Medieval Village Pack** (`3d/quaternius_medieval-village/`, added 2026-08-03) — 44 FBX:
ten **assembled buildings** (House_1–4, Inn, Blacksmith, Mill, Sawmill, Stable, Bell Tower)
and 34 props (Well, Bonfire / Bonfire_Lit, Cauldron, Cart, Crate, Barrel, benches, market
stands, hay, fences, paths, rocks). Quaternius, **CC0**, 2.6 MB, licence in
`assets/licenses/quaternius-medieval-village-License.txt`. Approved by Andrei 2026-08-03.

**Why this pack and not a newer one.** Quaternius ships in two eras and only one of them
matches this game: the older **"Ultimate ___ Pack"** line (2020–21) is flat-shaded with
simple named materials and *no texture files at all* — that is the nature pack and the
animals pack you already have. The newer **"MegaKit"** line (2023–25) is PBR with 4K
BaseColor/Normal/ORM trim sheets; its `Chest_Wood.fbx` alone is 10.9 MB. Dropping a MegaKit
model next to these trees makes it the most detailed object in the game by an order of
magnitude, and `gl_compatibility` will not show most of that detail anyway. **Match the era,
not just the creator.**

⚠️ `House_3` and `House_4` are **roofless base pieces**, not small houses, despite living in
the Buildings folder. Measuring gave their heights (2.09 m / 1.07 m) but not what they
*were*; only rendering one did.

### Reskinning: `MarkFx.repaint`, not an image editor

These models **name their materials** (`RoofTiles`, `Plaster`, `Wood`, `Stone_Dark`…), so
bringing an off-palette asset into the palette is a dictionary, not a texture edit:
`MarkFx.repaint(node, {"RoofTiles": ROOF_SLATE})`. It duplicates the material first — FBX
materials are shared resources, so editing one in place repaints every other instance in
the map.

Use it instead of `MarkFx.tint` for anything whose own material set matters; `tint`
flattens a whole model to one colour, which is right for a coin pip and destructive for a
house. **No external program is needed for colour work** — Blender would only be required
for geometry or UV changes, and is not installed.

Quaternius roofs everything in teal, which from this camera is the swimming-pool read
already recorded against the Kenney fantasy-town kit. Repaint to `HallBuilder`'s slate so
every roof in the game agrees.

**Ultimate Modular Ruins Pack** (`3d/quaternius_modular-ruins/`, added 2026-08-03) — 15 of
the pack's 90 FBX, the ones actually used: `Statue_Stag` / `Statue_Fox`, `Column_Round` /
`Column_Square`, `Arch_Round` / `Arch_Gothic`, **`Chest_Gold` / `Chest`**, `Floor_Squares` /
`Floor_Standard`, `Torch`, pots and a bush, plus the pack's two shared textures. Quaternius,
**CC0**, 1.5 MB, licence in `assets/licenses/quaternius-modular-ruins-License.txt`. Downloaded
by Andrei 2026-08-03 (Quaternius routes this one through Google Drive, which needs a browser).

Only the used models were extracted — the full pack is 105 MB across FBX/OBJ/Blends and most
of it is dungeon walls and floors this game has no use for.

**The altar is `Statue_Stag`, not `Statue_Fox`** — the island already has stags in its wood
(`wildlife.gd`), so the shrine is a monument to an animal the player has actually seen.

**Ship Pack** (`3d/quaternius_ships/`, added 2026-08-03) — 3 of the pack's 6 FBX:
`SailShip` (the galleon, Andrei's pick), plus `Boat` and `BoatWSail` unused for now.
Quaternius, **CC0**, 140 KB, licence in `assets/licenses/quaternius-ships-License.txt`.
The cruise ship and inflatable lifeboat were left out.

⚠️ **`SailShip`'s hull mesh carries a `Fabric` surface among its others.** `wreck_site.gd`
finds the sails by **node name** (`BackSail`, `Front Sail`, `MidleSail`) for that reason —
matching on material hid the whole ship, because `visible` is per node and cannot express
"this surface only".

## Textures (`assets/textures/`)

**Watercolor Terrain Textures** (`textures/watercolor/`) — 16 seamless hand-painted
1024×1024 PNGs, four each of Grass / Stone / Dirt / **Water**. Jonas Voland, distributed by
Voxel Core Lab GmbH, **CC0 1.0** — commercial use fine, attribution not required, so it is
deliberately *not* in `ATTRIBUTION-REQUIRED.md`. Downloaded 2026-08-02 with Andrei's
approval; licence in `assets/licenses/voxelcorelab-watercolor-License.txt`.

Only the water is wired, by `assets/shaders/water.gdshader`, which samples one tile twice at
different scales and drift bearings and **divides by the tile's own mean** so it contributes
grain rather than colour — the hue still comes from the sky, which is what keeps the sea
greying under cloud and reddening under a blood moon.

`Water_02` is the pick. **`Water_01` is deliberately unused**: it is the prettiest of the
four and has *fish silhouettes* painted into it, which at a 42 m tile makes a metre-long fish
repeat identically across the whole sea. Grass / Stone / Dirt are kept but unwired —
candidates for the ground slab's flat albedo later. Per-tile notes and the mipmap
requirement are in that folder's `SOURCE.md`.

⚠️ ~29 MB for the pack. If repo size ever matters, the twelve unwired tiles go first.

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
| `tree_creak_b/c.ogg` | day one-shots — 1.8s / 10.9s, faded in, sat back | Department64 | CC0 |
| `tree_creak_a.ogg` | **dropped from the pool** — 0.4s, read as a tick | Department64 | CC0 |
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
| `job_tools_1/2.ogg` | **parked** — taking a post | ldezem, mickyman5000 | CC0 |
| `rain_light.ogg` | drizzle bed — rain on grass, 140s seamless loop | SamsterBirdies | CC0 |
| `rain_heavy.ogg` | downpour bed, 200s seamless loop, stereo | kyles | CC0 |
| `thunder_1..4.ogg` | distant thunder — 4 cuts from **one** recording | richwise | CC0 |
| `thunder_near.ogg` | the near strike — same recording, brightest event | richwise | CC0 |
| `fire_light.ogg` | **removed** — campfire catching; kept for reinstatement | cribbler | CC0 |
| `horn_night.ogg` | watch horn — 1 nightfall / 2 attack / 3 blood moon | Vendarro | CC0 |
| `horn_dawn.ogg` | **superseded** — old horn-daybreak; kept, not wired | Vendarro | CC0 |
| `rooster.ogg` | daybreak — complete crow, pitched down, fixed spot | JarredGibb | CC0 |
| `rooster_alt_b/c.ogg` | **A/B candidates**, not wired — awaiting a pick | JarredGibb, jsbarrett | CC0 |
| `deer_1..3.ogg` | deer out in the woods, low-passed for distance | msantoro11 | CC0 |
| `cauldron_feed.ogg` | broth into the pot — subtle, low-passed | ahriik | CC0 |
| `hoof_1..6.ogg` | the monarch's horse — deepened, fired in gallop pairs | mmacneil | CC0 |
| `horse_snort_1..4.ogg` | the horse while you stand still | craigsmith, o_ciz | CC0 |
| `horse_nicker.ogg` | ditto, the rarer soft one | TheKingOfGeeks360 | CC0 |
| `mark_1..3.ogg` | marking a tree **or** bush — one verb, one sound | acrober | CC0 |
| `bush_pick_1..3.ogg` | a berry bush stripped — foliage rustle | GUS_MAN, Montacue | CC0 |
| `animal_drop_1.ogg` | hunted animal hitting the ground, pitched by species | deleted_user_2104797 | CC0 |
| `gold_hand_1..3.ogg` | **parked** — villager handing gold over | cupido-1 | CC0 |
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

**All five thunders are cut from one recording** (`richwise` 361401). That is
deliberate: thunder taken from five different sources sits in five different
weathers — different distance, air and microphone — and the pool stops sounding
like one storm. The events were located by measuring the source rather than by
ear, and picked for isolation and a spread of lengths.

**`thunder_near` is chosen by distance, never at random.** It only plays when the
sound arrives within 4s of the flash. What makes it read as close is **treble,
not level**: air absorbs high frequencies over distance, so it was picked by
measuring 1–6 kHz content, not loudness — every clip is normalised anyway.

> **Rain on a hard surface rings.** The first light-rain bed was rejected on
> listening as "metallic, like it falls on the gutter", and that is measurable:
> its spectrum was peaky rather than broadband, scoring **0.025** on spectral
> flatness where the replacement scores **0.505**. If a rain candidate ever
> sounds tinny again, measure flatness before hunting by ear — and prefer
> recordings made over grass, leaves or soil to ones made under a roof.

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
`JOB_SOUND_ENABLED` (undecided what taking a post should be) ·
`GOLD_HAND_ENABLED` (see below).

> **A sound is only as good as the animation under it.** The gold handover was
> parked not because the clip is bad but because the villager's handover is a
> quick torso bow — a sharp coin sound landing on it reads as the villager being
> *slapped*. Revisit when there is a real animation to sit on. The same clip may
> well work then.

**Still silent:** wall sections going up one by one · anything at all for night
waves, since there is no combat yet.

**A gallop is pairs, not an even tick.** Two feet land close together, then the
other two, then all four leave the ground. Measured in `monarch.gd`: **0.053 s
inside a pair, 0.131 s between pairs, 0.381 s suspension.** Two earlier versions
were rejected by ear — evenly spaced falls ("T T T T T"), then four bunched but
unpaired falls. The pairing is the whole thing.

**Gaits are data.** `GAITS` in `monarch.gd` holds `at` / `gain` / `stride` per
gait; only `gallop` is used, and walk/trot/canter sit there untuned so adding
one later is a `set_gait()` call and a tuning pass rather than a rewrite. Stride
length scales with real speed, so a faster gallop needs no second set of numbers.

> **A synthesised sine will make anything sound like wood.** The hoof body was
> first built from a decaying sine, which took the clips to a spectral flatness
> of **0.0004** — more tonal than the rain rejected as "metallic" (0.025) — and
> they duly read as landing on stone or wood. **A ring means a hard hollow
> surface; soft ground damps.** The body is now a low-passed *noise* burst on a
> 0.034 s decay plus a turf scuff, giving 0.011–0.050 flatness. Counter-intuitive
> finding: widening or adding more body noise made it *worse*, because a
> narrowband low "noise" is just a rumble at one pitch.
>
> **Small hoof recordings have no low end — build it rather than hunt for it.**
> The raw cuts measured 1.5–2.9 kHz centroid and were rejected as sounding like
> "someone using some cups". Resampling to 0.85, a 2 kHz low-pass and a
> synthesised 95→55 Hz sub mixed at 0.25 took them to **358 Hz centroid, low/high
> 30.7**. A first attempt (0.72 / 900 Hz / 0.55) overshot to 180 Hz and a ratio
> of 500 — a drum, not a horse. **The sub goes under the hoof, it doesn't
> replace it**, and the low-pass has to stay high enough to keep the attack.

**Falls overlap, so hoofbeats need several voices.** They land ~75 ms apart and
the clips run 175 ms, so one player would cut each strike off to start the next
and the gallop would come out clipped. `HOOF_VOICES` spreads them round a ring
and lets them ring over each other, which is how a real gallop sounds.

**The stride clock is independent of the bob animation on purpose** — that
bounce is placeholder and is being replaced. When the real gallop animation
lands, drive it from `monarch.stride_phase()` so picture and sound come off one
clock again.

**Six variants, the biggest pool in the project**, and by far the lowest level
(-25 dB), because this fires more than everything else combined.

> **"There, but not drawing focus" is a level-and-accent problem, not a clip
> problem.** The brief for hoofbeats was that you should never find yourself
> listening to them. Two things do that: dropping the level hard, and
> *flattening the accents* — a strong accent gives the ear a beat to lock onto,
> and a rhythm you can lock onto is one you attend to. The pairing in `at`
> carries the gait on its own, so the gains only need to shade it.
> Softening the attack was tried and dropped: it shifted leading-edge energy
> only 52% → 49%, since after deepening the energy is in the body, not the front.

**The horn counts.** Meaning is carried by the *number of blasts*: **one** at
nightfall, **two** for an attack, **three** for a blood moon (a K2C concept, not
implemented — the count exists so the vocabulary has room). At nightfall the
player waits on the horn to learn what kind of night this is, so the blasts must
be *countable*: `horn_night` is 1.7s under a 2.0s `ALARM_GAP`, leaving real
silence between them. All three fire from the dev overlay (**J / H / K**) since
there are no bandits yet. Combat inherits the whole vocabulary for free.

**Danger and safety are different instruments.** Daybreak is a **rooster**, not a
horn — so the horn only ever means a threat, and its blast-count never competes
with a good-news call. `horn_dawn.ogg` (the old pitched-up horn) is kept on disk
but no longer wired; **L** in the dev overlay fires the rooster.

> **Shorten a sustained note by splicing, never by trimming.** Hard-cutting the
> horn to length put the fade on top of a still-loud sustain and was rejected on
> listening as "ends abruptly, feels sped up then cut". It now keeps the
> recording's own swell crossfaded onto its own decay, shortening only the
> middle, so both ends are genuine.

> **"Too shrill" is a fundamental-frequency problem, not a centroid one.** The
> first rooster was rejected as "too pitchy": its fundamental was 932 Hz, the
> highest of six candidates, where the replacement is ~662 Hz. Spectral centroid
> barely separated them (2284 vs 2096 Hz) — it is dominated by harmonics and
> noise — while autocorrelation on the fundamental separated them completely.
> **Reach for the fundamental whenever the note is about pitch.**

> **Never cut inside a call that has a shape.** A rooster's crow is
> "er-er-er-ERRRR" — build, breath, finish. A 0.74s cut landed mid-build and was
> heard as "sped up", which is exactly what hard-trimming did to the horn. Both
> failures were the same error: *shortening something whose length is part of
> what it is*. Splice or use the whole call; don't slice.

> **A recurring sound should come from the same place.** The rooster's bearing
> was randomised each dawn and read as a noise from nowhere. A bird lives
> somewhere. Fixed at `ROOSTER_AT` until there is a coop to hang it on.

> **Don't let a small sound borrow a big sound's 3D settings.** The rooster was
> reusing the horn's voices (`unit_size` 34, reach 200) — values chosen so a
> signal carries the whole map — and duly arrived enormous and right on top of
> the player. A farmyard bird wants a short reach and fast attenuation.

**It fires off `darkness()`, never off the clock.** Day and night durations are
placeholder and will be retuned; a threshold on how dark it actually *is* keeps
the horn landing at the right moment whatever they become. It also only blows
once the campfire is lit — before that there is no village and nobody to blow it.

**Deer come out of a real animal, like the tree creak comes out of a real
trunk.** `ambience.gd` calls only from wildlife within earshot, never from a
bearing — so the woods can't call from a spot you have already hunted empty, and
the map going quiet as its game is stripped is something you can hear. Rolled off
at 3.2 kHz for distance and kept very sparse: subtle or not at all, by request.

**The cauldron pour is confirmation, not an event.** Low-passed to 2.1 kHz so the
splash doesn't sizzle and mixed to -15 dB, because it fires three times per
cauldron and several cauldrons a night. It rides on the existing `_pour` tween.

**Marking is one sound for two things, on purpose.** `MarkFx.mark_sound()` sits
next to the blaze and the banner because the monarch performs *one verb* on both
trees and bushes — splitting it per target would be the same mistake as giving
them different blazes. Anything marked in future gets it for free.

**One clip pitched by size beats a clip set per species.** `wild_animal.gd`
plays a single body-fall at 1.38 for a rabbit and 0.84 for a stag, the same
trick `villager.gd::JOB_PITCH` uses for worker/archer. Adding a boar costs one
dictionary entry, not a recording session.

> ⚠️ **`gold_hand_*` is a leather purse; the game shows loose coins.** Flagged on
> audition and kept for now. The code calls a villager's carried gold a `_purse`,
> but `_offer_coin` flies the coins across one at a time and there is no pouch
> anywhere on screen — so the sound and the picture disagree. Fix it with a
> loose-coins clip, or by giving carriers a visible pouch. **A sound that
> contradicts what the player is watching is worse than no sound.**

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
- **Spectral flatness catches "metallic".** Geometric mean over arithmetic mean of
  the power spectrum: near 1 is broadband noise, near 0 is resonant and tonal. The
  rain bed rejected by ear as "metallic, like a gutter" scored **0.025**; its
  replacement scores **0.505**. Rain on a hard surface *rings*, and that is
  measurable before it ever reaches Andrei.
- **Distance is measurable too — it is treble, not volume.** Air absorbs high
  frequencies, so a "closer" thunder is one with more 1–6 kHz energy, not a louder
  one. Every clip gets normalised anyway, so level says nothing about distance.
- **Onset detection only works against a quiet floor.** It found 23 events in a
  7-minute thunder recording, but *zero* in a foliage rustle — a sustained sound's
  25th-percentile floor sits so close to its peak that no threshold triggers.
  Sustained clips need trimming and normalising, not cutting.
- **Check for duplicate uploads.** `Rustling foilage 2` and `4` are byte-identical;
  identical measurements across every column is the giveaway. Two "variants" that
  are the same file defeat the point of a pool.

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
