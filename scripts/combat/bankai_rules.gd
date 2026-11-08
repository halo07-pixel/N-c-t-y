class_name BankaiRules
extends RefCounted
## The price and the weak point of a Bankai form. Time runs down while it lasts, every landed hit
## adds some back (CombatGauge), and every hit TAKEN burns more of it away. When the form ends on
## its own or is burnt out, the fighter is exhausted for a moment. One ultimate per transformation.

const DRAIN_PER_PERCENT := 4.0 # frames of form lost per percent of damage taken
const DRAIN_MAX_PER_HIT := 120 # a single hit never costs more than 2 s
const EXHAUST_FRAMES := 120 # 2 s of slower movement after the form is gone
const EXHAUST_SPEED := 0.8
const FIELD_FADE_FRAMES := 30


## Frames of form a hit of `damage` percent burns away.
static func drain_for(damage: float) -> int:
	return mini(int(round(damage * DRAIN_PER_PERCENT)), DRAIN_MAX_PER_HIT)


## The form is not entered while the fighter is still exhausted.
static func speed_for_exhaustion(frames_left: int) -> float:
	return EXHAUST_SPEED if frames_left > 0 else 1.0
