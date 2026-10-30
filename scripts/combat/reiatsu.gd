class_name Reiatsu
extends RefCounted
## Tuning values for the spirit-energy meter: three blocks that refill by themselves and pay
## for the powerful versions of special moves (full charges, follow-ups, counter stances).
## The ultimate costs all three blocks and can only be used while transformed.
## The Combat Gauge (see CombatGauge) is a separate meter: it decides when to transform.

const BLOCK := 100.0
const BLOCKS := 3
const MAX := BLOCK * float(BLOCKS)
const ULTIMATE_COST := MAX
## One block every 8 seconds, twice as fast while transformed.
const REGEN_PER_FRAME := BLOCK / (8.0 * 60.0)
const FORM_REGEN_MULTIPLIER := 2.0
## Meter gained per point of damage dealt and taken.
const GAIN_DEALT := 0.6
const GAIN_TAKEN := 0.4
## A perfect guard or dodge gives this much.
const PERFECT_GAIN := 25.0

## Extra invincible frames at the end of an ultimate so it cannot be interrupted.
const ULTIMATE_SAFE_FRAMES := 10
