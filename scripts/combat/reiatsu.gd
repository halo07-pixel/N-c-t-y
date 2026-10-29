class_name Reiatsu
extends RefCounted
## Tuning values for the spirit-energy meter, which only powers the ultimate.
## The meter runs from 0 to MAX. Pressing the charge key (on the ground):
##   transformed and at ULTIMATE_COST -> cinematic ultimate (spends it all)
##   gauge full (see CombatGauge)     -> transformation
##   transformed, below the cost      -> hold the key to charge up

const MAX := 300.0
const ULTIMATE_COST := 300.0
const CHARGE_PER_FRAME := 1.5
## Meter gained per point of damage dealt and taken.
const GAIN_DEALT := 1.5
const GAIN_TAKEN := 1.0

## Extra invincible frames at the end of an ultimate so it cannot be interrupted.
const ULTIMATE_SAFE_FRAMES := 10
