# Watercolor Terrain Textures — Voxel Core Lab

16 seamless hand-painted 1024×1024 PNGs: four each of Grass, Stone, Dirt and Water.

- **Author:** Jonas Voland · distributed by Voxel Core Lab GmbH
- **Source:** https://voxelcorelab.itch.io/watercolor-terrain-textures
- **Licence:** **CC0 1.0 Universal** — commercial use fine, **attribution not required**.
  Full text in `assets/licenses/voxelcorelab-watercolor-License.txt`. Because CC0 needs no
  attribution, this pack deliberately does **not** appear in `ATTRIBUTION-REQUIRED.md`.
- Downloaded 2026-08-02, approved by Andrei.

## What is actually used

Only the **water** tiles are wired up so far, by `assets/shaders/water.gdshader`:

| | |
|---|---|
| `Water_02` / `Water_04` | **In use.** Near-flat watercolour washes — paper grain and gentle tonal drift with no structure to repeat. That is exactly what a 640 m sheet needs: they add hand-painted texture without stamping a pattern across the sea. |
| `Water_03` | A third wash, greener. Spare. |
| `Water_01` | **Deliberately not used.** It is a lovely shallow-lagoon texture with *fish silhouettes* in it — at our tile scale a fish is about a metre long and would repeat identically every 40 m, which reads as a printing error rather than as a shoal. |

Grass / Stone / Dirt are **kept but unwired**. They are candidates for replacing the ground
slab's flat albedo and for dressing the beach later; nothing reads them today.

⚠️ These are ~1.8 MB each at 1024², ~29 MB for the pack. If repo size ever matters, the
twelve unwired tiles are the first thing to drop.

## Import settings that matter

The water tiles are sampled across a 640 m mesh, so they **must** have mipmaps generated
(`mipmaps/generate=true` in the `.import`). Without them the sea aliases into shimmering
noise at any distance — the same class of problem the shader's own `length(VERTEX)` chop
damping exists to solve.
