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
