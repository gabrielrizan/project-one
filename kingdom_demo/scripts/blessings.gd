class_name Blessings
## What the shrine clearing's two rewards permanently change (ISLAND_PROMPTS F6).
##
## Static, like `NavWorld.surface_offset` and `CameraRig.zoom`: there is exactly one
## kingdom, the effects last the whole run, and a node to hold two booleans would be
## a node to keep in sync.
##
## ## Exactly two, and it must stay exactly two
##
## One altar and one hermit on the map, one blessing each. **This is not a tech tree
## and must not become one** (Pillar 4: the monarch has a tiny verb set and the
## kingdom self-organises; a shopping list of upgrades is the opposite of that). If a
## third reward ever looks tempting, the question to answer first is what it takes
## *away* from the two that exist.
##
## Both are deliberately small. A blessing that doubled income or halved build times
## would make finding it the difference between winning and losing, which turns an
## optional ride into a mandatory one -- and an optional thing you must do is just a
## chore with extra steps.

## The altar: **+2 to the population cap, forever.** Chosen because it is the one
## permanent kingdom-wide effect that cannot violate Pillar 2 -- it buys *room* for
## citizens, it does not recruit them. You still have to fill the pot to get them.
const ALTAR_POP := 2

## The hermit: a citizen who **bends exactly one rule** (`GAME_DESIGN.md` §9). Here
## he is the cook, and the rule he bends is how much the cauldron holds -- one more
## serving per fill, forever. That is the §9 example, and it is the right shape: it
## changes a number the player already understands rather than adding a system.
const HERMIT_SERVINGS := 1

static var altar_taken := false
static var hermit_taken := false

## Reset per run. The statics outlive a scene change, so without this a second run
## in the same session starts already blessed.
static func reset() -> void:
	altar_taken = false
	hermit_taken = false

## How much the altar adds to `campfire.gd::villager_cap()`.
static func pop_bonus() -> int:
	return ALTAR_POP if altar_taken else 0

## How much the hermit adds to the cauldron's capacity.
static func serving_bonus() -> int:
	return HERMIT_SERVINGS if hermit_taken else 0

static func grant(tree: SceneTree) -> void:
	if altar_taken:
		return
	altar_taken = true
	_post(tree, "The altar is lit — your hall will house %d more." % ALTAR_POP)

static func grant_hermit(tree: SceneTree) -> void:
	if hermit_taken:
		return
	hermit_taken = true
	_post(tree, "The hermit takes up the ladle — the pot stretches further.")

## Says so out loud, through whatever the game already uses to say things. A
## permanent change the player cannot see happen is a permanent change they will
## assume did not happen.
static func _post(tree: SceneTree, line: String) -> void:
	print("[blessing] %s" % line)
	if tree == null:
		return
	var gm := tree.get_first_node_in_group("game_manager")
	if gm and gm.has_method("post_notice"):
		gm.post_notice(line)
