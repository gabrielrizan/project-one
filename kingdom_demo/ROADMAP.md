# Map progression & playtime — roadmap proposal

**Status: proposal, 2026-07-23.** Written by Claude at Andrei's request; nothing here is
canon until Andrei folds it into `GAME_DESIGN.md`. Where this answers an open question
from §12 it says so. Every number is a tuning target, not a promise — costs, yields and
wave sizes in the build are placeholders and stay that way until combat is playable.

**Decided by Andrei, 2026-07-23:** five maps · map 1 single-front and short · the
three-act finale · **knights on map 2**, via a restructured five-tier hall ladder
gated on a purchasable **mine shaft** (R2) · camps destroyed by **archer assault with
fire arrows** (R1) · carry-over is monarch + purse + a tunable handful of citizens
(R5). Still open: R8.

**Anchors** (verified against the Kingdom wiki / community data, not memory):

- A Kingdom Two Crowns day is **4 minutes** (2:45 day / 1:15 night). Ours is the same
  chart scaled ×1.5 — **6 minutes** (247.5s / 112.5s). So K2C day-counts convert to ours
  at roughly **⅔**.
- K2C has **5 islands**: stone unlocks on island 2, iron→knights on island 4 via the
  top-tier castle, and a competent campaign clears in **3–6 hours (~61 in-game days)**.
  Andrei's instinct — stone on map 2, knights off the stone/castle hall — is K2C's own
  ladder.
- Our tech ladder already exists and already couples: hall L1–L4 is built, and **a wall
  level requires the matching hall tier** (`wall_side.gd::LEVELS`). Capping the hall per
  map therefore caps the walls for free — per-map tech gating is **one constant**, not a
  system.

---

## R1. What makes a map "done" — and how long it takes

A map's length is governed by three clocks that should run out together:

1. **The timber capital** (§5 — canon: trees never regrow, depletion is the run clock).
   The finite gold in the map's trees is the ceiling on what you can build.
2. **The camp ladder** — the real objective (Andrei's rule: destroy all camps to leave).
3. **The hall ladder** — the map's tech cap; reaching it is what the timber pays for.

**How a camp dies** *(decided 2026-07-23 — answers §12.1)*: **archers carry the
assault.** The monarch musters a war party and rides out; the party follows, shoots
the camp's defenders, and once the last one falls the archers loose **fire arrows**
into the tents and the camp burns. You never order the volley — proximity and a dead
garrison trigger it. Map 1 works because archers *are* map 1's army; on later maps
camps defend too hard for archers alone, and knights and mercenaries join the same
ride-out. The fire-arrow volley is also simply a great picture — the payoff shot for
every survived night.

**The muster banner** *(decided 2026-07-24)* — how a war party is raised, and the one
new AI behaviour (follow-the-monarch) it needs:

- A **banner stands outside the base** (position per map; name placeholder). Hold-E
  and pay, and a **squad of N** free archers — later knights too — leave their posts
  and **fall in behind the monarch**. Pay again for another squad: the price scales
  with how much army you take, not just whether you go. (N per squad is tuning; the
  tally already sizes the hold to the cost.)
- They follow wherever he rides — the escort *is* the assault mechanic — until he
  returns **inside the walls / behind the banner**, where the party disbands back to
  its posts. No orders ever: you paid, you lead, they follow, coming home dismisses.
- Paying is the point, not just the interface: an assault is an *investment*, priced
  like every other purchase (pillar 2 — coin buys military action), so marching out is
  a decision with a cost rather than a free formation toggle.
- This is **not** §3's rally banner. The movable rally banners remain a separate,
  defensive idea (biasing which walls get manned at night). The muster banner is
  offence: one fixed point, pay to raise the party. Keep the two distinct or the one
  tactical lever stops being legible.

**Playtime target per map:** first map ~40 minutes, growing to ~90 by map 4 (see R7).
Kingdom's own rhythm: a map should end *because its clocks ran out*, not because the
player got bored — so short early maps, and length bought with new systems, not padding.

## R2. The hall ladder — restructured (decided 2026-07-23)

Five tiers replace the current four. The Stone Hall is the first thing in the game
built from a material other than gold:

| Tier | Name | Costs | Unlocks | Pop cap* |
|---|---|---|---|---|
| L1 | Tent | free — lighting the fire | — | 6 |
| L2 | Upgraded Tent | gold | — | 8 |
| L3 | Wooden Town Hall | gold | wood walls | 10 |
| L4 | Stone Hall | gold — **requires the mine shaft** | stone walls · **knights** | 13 |
| L5 | Castle | gold — requires the mine shaft | fortified walls · emplacements (R3) | 16 |

*\*placeholder numbers, same status as every cost.*

**The mine shaft is a purchase, not an economy** *(decided 2026-07-23)* — K2C's
deposit model exactly. A shaft mouth dresses one of the sealing mountains (the gates
get a function beyond blocking); the monarch buys it once with the ordinary hold-E
tally, and from then on the Stone Hall and Castle are buildable — **still paid in
gold**. The shaft itself is cosmetic: no mining job, no hauling, no second resource.
"Built with stone" is the fiction the shaft makes visible, not a currency. Everything
reuses what exists — the shaft is one more interactable with a price on it, and the
gate is a flag exactly like `stone_unlocked` used to be (per map this time).

**Implementation consequence:** the built wall↔hall coupling ("wall level index *is*
the required hall tier", `wall_side.gd`) breaks under five tiers. The remap is twig→L1,
wood→L3, stone→L4, fortified→L5 — an explicit `requires` per wall level. `CLAUDE.md`'s
wall-ladder section changes when this lands.

## R2b. The five maps

Five, matching K2C's five islands and giving every map one new **toy** and one new
**threat**.

| Map | Shape (openings) | Tech cap | New toy | New threat | Camps | Days (6-min) |
|---|---|---|---|---|---|---|
| 1 — The Mountain U | mountain arms, **1** | **L3** Wooden Town Hall · wood wall | the whole game | Thugs | 1 | 6–8 |
| 2 — The River | river at the back, **2** (mouth + ford) | **L4** Stone Hall · stone wall | **the mine shaft → Stone Hall + knights** | Flankers | 2 | 9–11 |
| 3 — The Pass | through-valley, **2 opposed** | **L5** Castle · fortified wall | **Castle + ballista emplacement** | Brutes nightly | 2–3 | 11–13 |
| 4 — The Lowlands | open plain, **3** | L5 | **mercenary camps + catapult** | enemy siege (ram/catapult) · camps re-establish | 3–4 | 13–15 |
| 5 — The Warlord's Vale | *their* mountain U — you outside it, **1 gated citadel** | L5 | everything + 🔮 hermits | the Long Night (R6) | citadel | 10–12 |

Per-map notes:

- **Map 1** is canon already (§9, `COMBAT_PROMPTS.md` P1). Single front, single camp,
  single wall. **Keep it short instead of adding fronts** — see R4. No blood moon except
  possibly as the finale exam (below).
- **Map 2** — the mine shaft is the headline. Its mountain holds the shaft; buying it
  unlocks the Stone Hall, and the hall brings **knights**: a `job_type: "knight"` at
  the hall per §9 — citizens who eat soup and hold the gate line. The second opening
  (a ford or castle-kit bridge) teaches front-and-flank, and Flankers make an unwalled
  side a real cost for the first time. This is the game's biggest single step — stone
  *and* soldiers — which is exactly the shape Andrei asked for.
- **Map 3** — the **Castle** (L5) caps the ladder and mounts the first **ballista**
  (direct-fire, on the fortified wall — R3) just as Brutes start arriving nightly to
  justify it. Two *opposed* openings split the defence for the first time; knights
  from map 2 hold one gate while the walls hold the other.
- **Map 4** — coin's map (pillar 2's second half): **merc camps** (§8 — bounty up
  front, coin at supper, desertion when unpaid) plus the **catapult** (indirect,
  anti-mass — R3). The threat escalates in kind: bandit rams and catapults on blood
  moons, and destroyed camps can re-establish on other bearings (§12.21/23) so
  enclosure finally has to be total.
- **Map 5** — the finale, shape inverted: *they* hold the mountain U and you camp in
  the open before it. See R6.

**Blood moons become per-map data** *(answers §12.15)*: the fixed every-15th-night is
~90 minutes at our cycle — longer than all of map 1. Proposal: map 1 none (or one
scripted as the map's final exam, the night that empties the camp's garrison); map 2
every 10th night; map 3 every 8th; map 4 every 7th; map 5 scripted (R6). The cycle
length stays 6 min — the *cadence* is the number that moves, per map.

## R3. Siege emplacements — the catapult answer

**Yes — a catapult can shoot over a wall, and that is precisely its role.** It is
indirect fire: a ballistic arc needs no line of sight, so the engine sits *behind* the
palisade, safe, and lobs over it. The ballista/crossbow is the opposite: direct fire,
needs line of sight, so it lives *on top* — the fortified wall's battlements or a
watchtower slot. That distinction gives the two weapons different jobs instead of one
being the other's upgrade:

| | Catapult | Ballista / crossbow |
|---|---|---|
| Fire | indirect — over your own wall | direct — needs line of sight |
| Sits | behind the wall, exposed only after a breach | on the fortified wall / tower |
| Targets | the *mass* — area damage at the gate crush | the *big one* — single-target, anti-Brute |
| Weakness | **minimum range** — useless once they're at the wall · slow reload · scatter | a wall section must stand to mount it |

They arrive split across the ladder — **ballista with the Castle on map 3** (the
anti-Brute tool lands with the Brutes), **catapult on map 4** (the anti-mass tool lands
with the mass, and with the enemy siege that answers it). Both obey the constraint
already written into §9: **a paid emplacement that works by itself** — crew-built like
everything else, auto-firing like the archers, never orderable. Auto-targeting: catapult picks the densest cluster beyond minimum range;
ballista picks the highest-HP target in line of sight. No friendly fire (or: refuses to
fire within a few metres of a citizen) — pillar 4 says a bad night is survivable, and
your own catapult wiping your gate line is not that.

**Assets are already in the project**: the castle kit ships catapult and trebuchet
*with demolished variants* (§9 noted this for the enemy versions) — so player
emplacements cost no download, and a destroyed state is free.

**The balance risk to respect:** an outranging defensive battery can trivialise the
gate fight. The counter is the enemy siege ladder arriving on the same map (map 4):
their ram forces your knights to sally, their catapult outranges your walls and forces
*you* to leave the shell. Emplacements should arrive when the enemy can answer them.

## R4. Layout question — one wall or two on map 1?

**One. Map 1 stays the single-entry U** (it is canon in §9, and the reasoning holds):
one door, one wall, one fight is the teaching shape, and the front count *is* each
map's identity — spending it on map 1 flattens the ladder. The worry behind the
question — "is one wall boring?" — is really about *duration*, not fronts: a
single-front map is boring at 15 days, not at 7. So map 1 is deliberately the shortest
map in the game (6–8 days, ~40 min), and the second front arrives 40 minutes in as map
2's whole point. More playtime comes from R7's ladder, not from doubling map 1's spend.

Two-fronts-from-the-start is exactly what maps 2–4 are; by map 4 you hold three
openings with camps that migrate. The player who wants that pressure reaches it inside
the first session.

## R5. What carries over *(decided 2026-07-23 — answers §12.2)*

**The monarch, the purse, a number of archers and a number of workers — and on later
maps a number of knights.** Exact counts deliberately left for tuning (they are the
knob that sets how hard each map's opening is). The settlement itself is left behind;
the hall resets to L0 and tech unlocks travel as knowledge — you *re-climb* a ladder
you already know, faster each time, the K2C rhythm exactly. Implementation picture: the
leavers ride out with you through the exit pass, and walk in as your first arrivals on
the next map — already citizens, no soup owed.

## R6. The ending *(the game-ending objective)*

Map 5 inverts map 1: the Warlord holds a mountain U of his own, and you make camp in
the open before its mouth — your first night since map 1 with no terrain at your back.

1. **Approach** — build a war camp in the open: full 360° threat, everything the game
   taught about enclosure, spent at once.
2. **The Long Night** — a scripted multi-night blood-moon storm (the horn blows ×3 and
   *keeps* blowing). Survive it; the citadel empties itself against your walls — map
   1's garrison rule at final scale.
3. **Dawn** — the gate hangs broken. Ride in past the wreckage, take the Warlord's
   crown from his hall — **hold-E, the game's one verb, as its last act** — and the
   run ends with the Crown that was your lose condition becoming the win.

Cut-scope version if the finale is too much: drop the assault interior; the citadel
burns at dawn after the Long Night and that is the ending. The three-act version is
the target; the cut version is the floor.

## R7. Playtime estimate

At the 6-minute cycle, with map day-counts from R2 (⅔ of K2C's equivalents, per the
1.5× day length):

| Map | Days | Real time |
|---|---|---|
| 1 | 6–8 | 36–48 min |
| 2 | 9–11 | 54–66 min |
| 3 | 11–13 | 66–78 min |
| 4 | 13–15 | 78–90 min |
| 5 | 10–12 | 60–72 min |
| **Campaign** | **49–59** | **~5–6 h clean** |

With deaths, restarts and dawdling a real first campaign lands **6½–8 h** — above
K2C's efficient clear (3–6 h), under its casual one, and honest for the scope. The
levers if it runs short are days-per-map (via camp garrison depth and timber stock),
never padding: a map should end when its clocks run out (R1).

**The economy has to be re-based for any of this to hold.** Today's map holds 19
resource trees at net **+1 gold each** — the entire timber capital is +19 gold, a
rounding error against renewable hunting income, so timber cannot currently function
as the run clock it is designed to be (§5). Target shape (placeholder numbers): 40–80
trees per map, net +3–4 each, so timber is roughly **40% of a map's total budget** —
enough that its depletion is *felt* as the signal to leave — with renewables setting
the daily pace and the map's spend ladder (walls + halls + jobs + repairs + mercs)
sized to consume both by the last camp's fall.

## R8. Still open — Andrei owns these

**Decided 2026-07-23/24:** five maps · map 1 single-front · three-act finale · knights
on map 2 via the five-tier ladder · the mine shaft as a K2C-style cosmetic unlock
purchase, everything still paid in gold, Stone Hall and Castle both gated on it ·
camps destroyed by **archer assault + fire arrows** after the defenders fall ·
the war party is raised at a paid **muster banner** — one payment musters a **squad of
N**, pay again for more — and follows the monarch until he returns behind it (R1) ·
carry-over is monarch + purse + N archers + N workers (+ N knights later), counts TBD.

Open:

1. **What does L2 Upgraded Tent buy?** Population cap alone (cheap early rung), or
   does it carry a small unlock so the rung is felt?
2. **Carry-over counts per map** — the knob that sets each opening's difficulty.
   Deferred to tuning once maps exist.
3. **Do night kills weaken a camp's assault garrison?** If bandits shot at your wall
   permanently deplete the camp they came from, defending well softens the later
   assault — a clean bridge between the two halves of the loop. If not, camp strength
   is fixed and assaults are purely a daytime problem. Tuning question, not structural.
4. **Fire arrows** — the burn volley needs a small effect pass (flaming projectile,
   tent ignition, the camp's ember light dying) and one sound. Reuse-first per §9's
   audio note.

*§12 questions this proposal answers if adopted: 1 (objectives = camps, via garrisons),
2 (carry-over), 6 (day length confirmed at 6 min — in the vision's range), 15 (blood
moons per map), 21/23 (camps re-establish from map 4), and it depends on 16 staying
night-count-based.*
