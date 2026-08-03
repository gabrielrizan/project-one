# Art pipeline — how polished art gets made here

*Decided with Andrei 2026-08-03. Forward-looking: this is how art **gets made**, where
`ASSETS.md` is what we **have**. Nothing in here has been downloaded or built yet — the
house rule (ask before downloading any asset) still applies to every recommendation below.*

---

## Part A — the road from placeholder to polished

### Install Blender: yes, but know what it buys

**Not installed** (checked 2026-08-03: no `blender` on PATH, no Blender Foundation
directory). What *is* available: **Python 3.12 + PIL 10.4 + numpy 2.1**. No `trimesh`,
no `pygltflib` — both pip-installable if wanted.

Blender is free, ~1 GB, and **fully scriptable headless** (`blender --background --python`),
which is the mode that matters: Claude drives it by writing `bpy` scripts, renders the
result, looks at the render, and iterates.

**What it unlocks — all of it geometry or UV work, none of it reachable from GDScript:**

- **Authoring bespoke meshes.** The wall ladder is the case in point (see Part C).
- **UVs.** Currently impossible; required for any custom texture.
- **Mesh joining.** `HallBuilder` stamps a hall tier from 20–96 nodes. Merging each tier
  to one mesh is a real draw-call win that changes nothing visually.
- **Vertex-colour AO baking.** The one that matters most for this style. `gl_compatibility`
  has no SSAO worth having (measured: 0.3% of frame — see `CLAUDE.md`), but AO *baked into
  vertex colours* costs nothing at runtime and gives flat-shaded geometry the contact
  darkening SSAO couldn't.
- **Batch normalisation.** 380 FBX → GLB, one metric scale standard, decimating outliers.

**What it does not unlock.** Claude still cannot art-direct — no sculpting, no judging a
silhouette by eye. The script → render → look → iterate loop converges, but slowly, and it
is not a substitute for taste. Blender also cannot fix **form-language** mismatch between
packs; it unifies colour and scale, never what a roof pitch says.

### Where polish actually comes from in this style

Flat-shaded low-poly is the style where a scripted pipeline can reach genuinely shipped
quality, because **there are no hand-painted textures to forge**. Polish here is
**coherence + light**, and both are engineering problems. This repo already learned it the
hard way: post-process didn't move the needle, geometry and light did (`CLAUDE.md`, the
SSAO and clear-day-fog post-mortems).

**Ranked, highest visible delta per hour first:**

1. **Coherence pass** — one palette dictionary across every kit, one scale standard, kill
   the teal roofs everywhere at once. Mostly *doesn't need Blender*.
2. **Blender batch pass** — format normalise, merge composed buildings, bake AO to vertex
   colours. Turns "placeholder" into "shipped" without redesigning anything.
3. **Bespoke parametric geometry** — the wall ladder, hall tiers that read as one building
   growing. This is where installing Blender pays for itself on *future* assets.
4. **Light, camera, shadow** — Andrei's eye, Claude's iteration.

### Two reskinning routes, and which kit takes which

Corrects an earlier over-claim that the colormap remap was the universal lever. It isn't —
it is kit-specific:

| Source | How its colour works | Palette tool |
|---|---|---|
| **Kenney kits** (castle, fantasy-town, survival) | one shared `colormap.png` atlas, UV'd | edit the PNG with PIL → **every model in the kit shifts at once** |
| **Quaternius "Ultimate" line** (nature, village, ruins, ships) | **named materials, no texture files at all** | `MarkFx.repaint(node, {...})` — already built, see `ASSETS.md` |

So half this job is already tooled. The Kenney atlas remap is the untooled half.

### Where to buy or commission instead

**Characters.** Organic, animated, and the things on screen most. Procedural geometry does
not produce a good character and neither does Claude driving Blender. Everything
architectural can be taken to a finished state in-house; **characters are the honest
ceiling** — the same conclusion `ASSETS.md` already reached about the hermit's hut.

### ⚠️ The era rule governs every future asset

From `ASSETS.md`: **match the era, not just the creator.** Under `gl_compatibility` a 4K PBR
trim sheet is wasted bytes that *also* makes the object the most detailed thing in the game
by an order of magnitude. Quaternius's older flat-shaded "Ultimate ___ Pack" line (2020–21)
is the target; the "MegaKit" line (2023–25) is not.

---

## Part B — animation

### The root cause, measured

**Every character model is unrigged.** Parsed the glTF JSON chunk of each
(2026-08-03):

| File | nodes | meshes | **skins** | **animations** |
|---|---|---|---|---|
| `archer.glb` | 1 | 1 | **0** | **0** |
| `villager.glb` | 1 | 1 | **0** | **0** |
| `worker.glb` | 1 | 1 | **0** | **0** |
| `monarch_horse.glb` | 1 | 1 | **0** | **0** |
| `rabbit.glb` | 1 | 1 | **0** | **0** |

They are **single-mesh solid blobs with no skeleton**. Nothing can bend, because there is
nothing to bend — no limbs exist as separable things. Every bit of current motion is code
moving the whole model node rigidly:

- `monarch.gd:170` — `model.position.y = _base_y + abs(sin(_bob)) * 0.06`, a bob.
- `villager.gd:517` — the axe swing is, in its own comment, *"the whole body rocking"*.

**This is the ceiling, and no tuning raises it.** "The animations look bad" is not a
parameter problem; it is the absence of rigs.

### What good looks like — and it is already in the repo

The **Ultimate Animated Animals** pack (already owned, already licensed) measures:

```
Alpaca.gltf   skins 1   anims: Attack_Headbutt, Attack_Kick, Death, Eating, Gallop,
                               Gallop_Jump, Idle, Idle_2, Idle_Headlow, Idle_HitReact1,
                               Idle_HitReact2, Jump_toIdle, Walk
```

**13 clips on a real skeleton**, identical across all 12 animals, same creator and same
flat-shaded era as the nature pack. That is the standard to match.

### Can Claude animate? Three different answers

1. **Procedural / code animation** — what is happening now. Genuinely strong at this;
   `stride_phase()` and `_swing_axe()` are the evidence. **Ceiling: rigid-body motion.**
   Right for a spinning coin or a bobbing purse, wrong for a walk cycle.
2. **Hand-keyframing a rig via `bpy` scripts** — technically possible, and the **weakest**
   option on this list. Typing bone rotations numerically to build a good walk cycle is
   exactly where a human's eye beats a script. Don't plan around this.
3. **Retargeting an existing animation library onto a rig** — **the right answer.** Mapping
   proven clips onto the characters, which is bookkeeping, not art.

**What Claude requires either way: a rigged character** — an armature with a skeleton and
skinned weights. Acquiring that is the whole task.

### Free animation sources — yes, this is very much a thing

- **Quaternius Ultimate Animated Character Pack** — CC0, pre-rigged **and** pre-animated,
  and in the *same era family* as the nature pack, animals pack and village pack already in
  use. Best style match available, and free. **Recommended first stop.**
- **Mixamo** (Adobe, free account) — the standard indie path. Upload a humanoid mesh, their
  auto-rigger fits a skeleton, then download from thousands of mocap clips (walk, run, idle,
  axe swing, bow draw, death). Humanoid **only** — no horse, no rabbit.
  ⚠️ **A different licence class from everything else here.** Not CC0; free and royalty-free
  for use, but delivered per-account rather than as a redistributable pack. Verify the terms
  directly before shipping and record the outcome in `assets/licenses/` like anything else.
  ⚠️ The auto-rigger needs a mesh in T/A pose with **distinguishable limbs** — the current
  blobs may well not qualify, which is another argument for replacing rather than rigging.
- **Kenney** — some CC0 animated character packs (e.g. Blocky Characters).
- **Godot 4's own retargeting** — bone maps / `SkeletonProfileHumanoid` let a clip authored
  for one humanoid rig drive a different one, in-engine, with no external tool.

### Recommended route

**Don't try to rig the existing blobs. Replace them with pre-rigged CC0 characters from the
same Quaternius era family**, then fill gaps from Mixamo. One step buys correct style match,
real skeletons, and a clip library, for free.

**The horse is nearly solved already.** `monarch_horse.glb` is a combined monarch-and-horse
mesh, and the animated animals pack **already contains `Horse` and `Horse_White`, rigged,
with `Gallop` / `Walk` / `Idle`** — owned and licensed. Splitting the rider from the mount
and seating him on the rigged horse is the obvious first move.

### ⚠️ The code is already waiting for this

`monarch.gd:58-61` says it outright: the bob is placeholder, and **the real gallop animation
should be driven from `stride_phase()`**, not the other way round — so picture and hoof-fall
audio share one clock. The stride clock was deliberately built independent of the bob for
exactly this handover. Honour that direction when the rigs land, or the gallop audio
(`GALLOP_AT`, `GALLOP_GAIN`) silently desyncs from the animation.
