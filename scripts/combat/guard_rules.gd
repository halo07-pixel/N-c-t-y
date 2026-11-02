class_name GuardRules
extends RefCounted
## Tuning values for Guard, Parry and Dash.
## Guard (hold the guard key on the ground) takes a hit for a fraction of the damage and drains the
## guard energy fast; at zero the guard breaks and the fighter is stunned.
## Parry: the first frames of a guard. A hit that lands in that window does nothing to the defender,
## the attacker is held in hitlag, and the defender may attack at once. A thrown projectile is sent
## back at its owner. Throws go through both a guard and a parry.
## Dash: a quick double-tap step on the ground or in the air. It is NOT invincible.

const ENERGY_MAX := 100.0
const ENERGY_MIN_TO_GUARD := 10.0
const DRAIN_PER_FRAME := 0.25 # while holding
const RECOVER_PER_FRAME := 0.4 # while not guarding
const BLOCK_DRAIN_PER_DAMAGE := 3.0
const BREAK_STUN_FRAMES := 40
const BREAK_RESTORE := 30.0

const DAMAGE_SCALE := 0.2
const KNOCKBACK_SCALE := 0.4
const PUSHBACK_SCALE := 0.5

## Parry: how long after pressing guard (on the ground) a hit is parried.
const PARRY_WINDOW_FRAMES := 10
## How long a parried attacker stays frozen.
const PARRY_ATTACKER_HITLAG := 30
## Combat Gauge for a parry, and the share of a blocked hit's damage.
const PARRY_GAUGE := 15.0
const BLOCK_GAUGE_RATIO := 0.1
## Guard is locked this long after guard was tapped and released inside the parry window
## without anything hitting it (anti button-mashing).
const GUARD_LOCK_FRAMES := 20

## Throws: reach, how close a target must be to start one, and the wait between throws.
const THROW_RANGE_X := 36.0
const THROW_RANGE_Y := 26.0
const THROW_COOLDOWN := 120

## Dash: double-tap a direction. Covers DASH_DISTANCE in DASH_FRAMES, cannot turn around,
## and an attack pressed from DASH_ATTACK_FRAME on becomes a dash attack.
const DASH_DISTANCE := 64.0
const DASH_FRAMES := 14
const DASH_ATTACK_FRAME := 8
## Wait (in frames, counted from the start of the dash) before the next dash.
const DASH_COOLDOWN := 34
## Two taps of the same direction closer together than this are a double tap.
const DASH_DOUBLE_TAP_FRAMES := 12
## Share of the dash speed kept by a dash attack.
const DASH_ATTACK_CARRY := 0.6
