# ⚠ Attribution required — put these in the credits

**Everything listed here must be visibly credited in the shipped game** (a credits
screen, an in-game "Credits" menu entry, or an end-of-run scroll). This is a
licence condition, not a courtesy — CC-BY permits commercial use and modification,
but *only* if the author is credited.

Assets **not** listed here are CC0 (public domain) and need no credit. They are
still recorded in the per-source licence files next to this one, so the provenance
of everything stays traceable either way.

**Keep this file current.** Anything added to `assets/audio/` or `assets/3d/` under
a CC-BY (or any attribution-bearing) licence gets a row here in the same commit.

---

## Credits block — paste this into the game's credits screen

```
SOUND

  "Winter forest NL 1112AM 220124_0326" by klankbeeld
      freesound.org/s/616354/ — CC BY 4.0

  "230809_2526_FR_Insects-twilight-pi" by kevp888
      freesound.org/s/700734/ — CC BY 4.0

  "FIREBurn_Campfire.Close.Long.Crackling" by newlocknew
      freesound.org/s/730704/ — CC BY 4.0
```

---

## The full record

| Asset file | Title | Author | Licence | Source |
|---|---|---|---|---|
| `audio/ambience_day.ogg` | Winter forest NL 1112AM 220124_0326 | klankbeeld | CC BY 4.0 | [freesound.org/s/616354](https://freesound.org/s/616354/) |
| `audio/ambience_night.ogg` | 230809_2526_FR_Insects-twilight-pi | kevp888 | CC BY 4.0 | [freesound.org/s/700734](https://freesound.org/s/700734/) |
| `audio/campfire_loop.ogg` | FIREBurn_Campfire.Close.Long.Crackling | newlocknew | CC BY 4.0 | [freesound.org/s/730704](https://freesound.org/s/730704/) |
| `audio/ambience_night_woods_SPARE.ogg` | evening woods 01 NL 151009_0806 | klankbeeld | CC BY 4.0 | [freesound.org/s/324409](https://freesound.org/s/324409/) |

⚠ The `_SPARE` file is **downloaded but deliberately not wired into the game** —
kept on Andrei's instruction as a held-back alternative night bed. It carries no
credit obligation while it is unused, which is why it is absent from the credits
block above. The moment anything references it, its line goes in. If it is
dropped for good, delete the file and this row together.

Not listed above because they are **CC0** and need no credit:
`audio/owl_hoot.ogg` ("Owl Hoot" by Breviceps), and
`audio/tree_creak_a|b|c.ogg` (tree_creak / _02 / _04 by Department64).

---

## What the licences mean

| Licence | Commercial use | Credit needed | Notes |
|---|---|---|---|
| **CC0** | ✅ | ❌ | Public domain. Author waived everything. Simplest possible. |
| **CC-BY** | ✅ | ✅ | Free to use and modify commercially, provided you credit. **This is the one we accept.** It does not affect how you license your own game. |
| **CC-BY-SA** | ✅ | ✅ | Adds *share-alike*: derivative works must carry the same licence. Legally murky for a game. **Avoid.** |
| **CC-BY-NC** | ❌ | ✅ | Non-commercial only. Breaks the moment the game is sold, or arguably even monetised. **Avoid.** |
| **Sampling+** | ⚠ | ✅ | Legacy Freesound licence. Allows commercial use only when transformed, not redistributed as-is. **Avoid** — not worth the ambiguity. |

Credit line format that satisfies CC-BY:

```
"<sound title>" by <author> — <source URL> — licensed CC BY 4.0
```
