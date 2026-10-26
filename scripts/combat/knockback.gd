class_name Knockback
extends RefCounted
## The Smash-style math: the more damage a fighter has, the harder they fly.
## Pure functions, so the rules are easy to test and to tune in one place.

## Launch speed is divided by (weight / REFERENCE_WEIGHT): heavy fighters fly less far.
const REFERENCE_WEIGHT := 100.0
## Hitstun lasts one frame per HITSTUN_DIVISOR units of launch speed.
const HITSTUN_DIVISOR := 12.0
const MIN_HITSTUN_FRAMES := 4
const MIN_HITLAG_FRAMES := 3
const MAX_HITLAG_FRAMES := 12


## Launch speed (pixels per second) for a hit on a fighter at `percent` AFTER the hit.
static func magnitude(base: float, growth: float, percent: float, weight: float) -> float:
	var raw := base + growth * percent / 100.0
	return raw * REFERENCE_WEIGHT / maxf(weight, 1.0)


static func hitstun_frames(launch_speed: float) -> int:
	return maxi(int(launch_speed / HITSTUN_DIVISOR), MIN_HITSTUN_FRAMES)


## Freeze frames on impact; stronger hits freeze a little longer.
static func hitlag_frames(damage: float) -> int:
	return clampi(MIN_HITLAG_FRAMES + int(damage / 3.0), MIN_HITLAG_FRAMES, MAX_HITLAG_FRAMES)


## Unit launch direction. Angle 0 points ahead of the attacker, 90 straight up.
static func direction(angle_degrees: float, facing: int) -> Vector2:
	var radians := deg_to_rad(angle_degrees)
	return Vector2(cos(radians) * float(facing), -sin(radians))
