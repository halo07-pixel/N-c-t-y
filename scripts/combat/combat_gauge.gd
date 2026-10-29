class_name CombatGauge
extends RefCounted
## Tuning values and rules of the Combat Gauge (0..MAX). Dealing and taking damage, KOs and
## losing a stock fill it; it fades when nothing happens. At MAX the fighter may transform
## (Bankai / Quincy form). The form lasts a while, longer with every hit landed, then the
## gauge starts again from zero. The ultimate can only be used while transformed.

const MAX := 100.0
const GAIN_DEALT := 0.45 # per percent of damage dealt, before the combo multiplier
const GAIN_TAKEN := 0.3 # per percent of damage taken
const COMBO_STEP := 0.25 # extra multiplier per consecutive hit
const COMBO_MAX_MULTIPLIER := 2.0
const COMBO_WINDOW_FRAMES := 90 # a hit this soon after the last continues the combo
const KO_BONUS := 15.0 # for knocking a fighter out
const STOCK_LOSS_PITY := 20.0 # for losing a stock
const IDLE_FRAMES := 360 # no combat for this long (6 s) and the gauge starts to fade
const DECAY_PER_FRAME := 0.05

const TRANSFORM_FRAMES := 75 # the cinematic: invincible, opponents frozen, camera zoomed in
const FORM_FRAMES := 900 # 15 s
const HIT_EXTEND_FRAMES := 30 # +0.5 s per hit landed while transformed
const FORM_CAP_FRAMES := 1800 # 30 s
const DAMAGE_SCALE := 1.25
const SPEED_SCALE := 1.15


static func combo_multiplier(combo: int) -> float:
	return minf(1.0 + COMBO_STEP * float(maxi(combo - 1, 0)), COMBO_MAX_MULTIPLIER)


## Gauge gained for landing `damage` as the `combo`-th hit in a row (1 = first).
static func gain_for_hit(damage: float, combo: int) -> float:
	return damage * GAIN_DEALT * combo_multiplier(combo)


## Frames left in the form after one more hit lands.
static func extend_form(frames_left: int) -> int:
	return mini(frames_left + HIT_EXTEND_FRAMES, FORM_CAP_FRAMES)
