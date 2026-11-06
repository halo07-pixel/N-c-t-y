class_name NormalRiders
extends RefCounted
## What a normal attack can carry besides damage. Three riders, one per fighter style, none of them
## a skill mechanic (no charging, no second skill press, no traps):
##   rhythm (Ichigo)  - pressing attack in the beat right after a hit ends (not mashing) links the next hit "perfectly": it hits harder.
##   cut (Byakuya)    - a hit on the far part of the blade leaves cut marks that burst a moment later.
##   recoil (Uryu)    - a hit that lands throws the attacker back (and up), twice as far on a second hit.

## Perfect link: the press lands in the beat right after the hit ends (not while it is still swinging).
const PERFECT_EARLY := 0
const PERFECT_LATE := 7
const RHYTHM_REIATSU := 8.0

## Cut marks: a hit past this share of the blade's reach marks; marks burst after CUT_FRAMES.
const CUT_MIN_REACH := 0.6
const CUT_FRAMES := 70
const CUT_DAMAGE := 2.0
const CUT_MAX := 4

## Recoil: a second hit within this many frames throws the attacker back further.
const RECOIL_WINDOW := 45
const RECOIL_STACK := 1.6


## True when an attack press made on `press_frame` of a move whose hit ends at `active_end` is on time.
static func is_perfect(press_frame: int, active_end: int) -> bool:
	return press_frame >= active_end - PERFECT_EARLY and press_frame <= active_end + PERFECT_LATE


## Marks a hit leaves: the move's own count when the target stood on the far part of its reach.
static func marks_for(move: MoveData, reach_fraction: float) -> int:
	if move.cut_marks <= 0 or reach_fraction < CUT_MIN_REACH:
		return 0
	return move.cut_marks


static func burst_damage(marks: int) -> float:
	return CUT_DAMAGE * float(mini(marks, CUT_MAX))


## The velocity a hit gives the attacker: backwards (`facing` is the direction they attack in) and up.
static func recoil_velocity(move: MoveData, facing: int, stacked: bool) -> Vector2:
	var scale := RECOIL_STACK if stacked else 1.0
	return Vector2(-float(facing) * move.recoil_speed * scale, -move.recoil_lift * scale)
