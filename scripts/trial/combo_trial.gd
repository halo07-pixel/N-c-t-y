class_name ComboTrial
extends RefCounted
## One combo exercise: an ordered list of steps the player has to land on the practice dummy.
## A step is the display name of an attack that must hit, or one of the TOKEN_ steps below
## (something to do, not something to hit with).

const TOKEN_DASH := "@dash"
const TOKEN_GAUGE_CANCEL := "@gauge_cancel"

var key: String = ""
var title: String = ""
var description: String = ""
var steps: PackedStringArray = PackedStringArray()
## Combat Gauge the exercise starts with (a Gauge Cancel needs 40).
var start_gauge: float = 0.0
## How far in front of the player the dummy stands.
var dummy_distance: float = 24.0


static func is_token(step: String) -> bool:
	return step.begins_with("@")


## What the HUD writes for a step.
static func step_label(step: String) -> String:
	match step:
		TOKEN_DASH:
			return "Dash (double-tap forward)"
		TOKEN_GAUGE_CANCEL:
			return "Gauge Cancel (charge key)"
	return step
