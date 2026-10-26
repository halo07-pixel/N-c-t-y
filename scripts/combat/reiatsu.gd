class_name Reiatsu
extends RefCounted
## Tuning values for the spirit-energy meter, Bankai and the ultimate.
## The meter runs from 0 to MAX. Pressing the charge key (on the ground):
##   at ULTIMATE_COST or more -> cinematic ultimate (spends it all)
##   at BANKAI_COST or more   -> Bankai transformation (spends BANKAI_COST)
##   otherwise                -> hold the key to charge up

const MAX := 300.0
const BANKAI_COST := 200.0
const ULTIMATE_COST := 300.0
const CHARGE_PER_FRAME := 1.5
## Meter gained per point of damage dealt and taken.
const GAIN_DEALT := 1.5
const GAIN_TAKEN := 1.0

const BANKAI_FRAMES := 1200 # 20 seconds
const BANKAI_DAMAGE_SCALE := 1.25
const BANKAI_SPEED_SCALE := 1.15
const TRANSFORM_FRAMES := 45
## Extra invincible frames at the end of an ultimate so it cannot be interrupted.
const ULTIMATE_SAFE_FRAMES := 10
