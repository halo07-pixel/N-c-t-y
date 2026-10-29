class_name GuardRules
extends RefCounted
## Tuning values for Guard and Shunpo. Guard (hold the guard key on the ground) takes a hit for
## a fraction of the damage and drains the guard energy; at zero the guard breaks and the
## fighter is stunned. Pressing guard just before a hit lands is a Perfect Guard: no damage,
## no knockback, the attacker is held in hitlag. Guard plus a direction is a Shunpo, a quick
## teleport-step that cannot be hit at its start; being "missed" by it is a Perfect Dodge.

const ENERGY_MAX := 100.0
const ENERGY_MIN_TO_GUARD := 10.0
const DRAIN_PER_FRAME := 0.25 # while holding
const RECOVER_PER_FRAME := 0.4 # while not guarding
const BLOCK_DRAIN_PER_DAMAGE := 2.0
const BREAK_STUN_FRAMES := 40
const BREAK_RESTORE := 30.0

const DAMAGE_SCALE := 0.3
const KNOCKBACK_SCALE := 0.4
const PUSHBACK_SCALE := 0.5

const PERFECT_WINDOW_FRAMES := 6
const PERFECT_ATTACKER_HITLAG := 14
## Combat Gauge for a perfect guard / dodge, and the share of a blocked hit's damage.
const PERFECT_GAUGE := 8.0
const BLOCK_GAUGE_RATIO := 0.1

const SHUNPO_DISTANCE := 60.0
const SHUNPO_FRAMES := 12
const SHUNPO_DODGE_FRAMES := 8
const SHUNPO_COOLDOWN := 40
