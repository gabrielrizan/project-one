class_name BuildCrew
extends RefCounted
## Shared bookkeeping for a crew of workers raising the same thing -- a wall,
## its stone upgrade, an upgrading building. Whoever has a slot walks over; only
## those who have actually reached the site and are swinging count toward the
## pace. Every worker beyond the first adds EXTRA_SPEEDUP to how fast the job
## goes, up to MAX_BUILDERS -- so a lone worker, a pair, and a full crew of
## three go at 1x, 1.3x and 1.6x.
##
## Used by anything with a construction phase (wall_side.gd, building.gd);
## `RefCounted` rather than a scene node since it is just bookkeeping owned by
## whoever is building.

const MAX_BUILDERS := 3
const EXTRA_SPEEDUP := 0.30   # +30% pace per worker beyond the first

var _claimed: Array = []
var _working: Array = []

func needs_more() -> bool:
	_prune()
	return _claimed.size() < MAX_BUILDERS

func claim(who: Node3D) -> bool:
	_prune()
	if _claimed.size() >= MAX_BUILDERS or who in _claimed:
		return false
	_claimed.append(who)
	return true

func release(who: Node3D) -> void:
	_claimed.erase(who)
	_working.erase(who)

## The claimed worker has reached the site and is actually swinging -- only
## these count toward the pace.
func arrived(who: Node3D) -> void:
	if who in _claimed and who not in _working:
		_working.append(who)

## Which numbered station a claimed worker stands at, so a crew spreads out
## rather than stacking on one spot.
func station(who: Node3D) -> int:
	return maxi(0, _claimed.find(who))

func hands() -> int:
	_prune()
	return _working.size()

## Progress per second, as a multiple of the lone-worker rate.
func speed() -> float:
	var h := hands()
	if h <= 0:
		return 0.0
	return 1.0 + EXTRA_SPEEDUP * float(clampi(h, 1, MAX_BUILDERS) - 1)

func _prune() -> void:
	for i in range(_claimed.size() - 1, -1, -1):
		if not is_instance_valid(_claimed[i]):
			_claimed.remove_at(i)
	for i in range(_working.size() - 1, -1, -1):
		if not is_instance_valid(_working[i]):
			_working.remove_at(i)
