class_name CpuTactics
extends RefCounted
## What the CPU does with a skill's second press, decided from what the skill is for (its data)
## and from the situation, not at random: a binding follows a dash at once, a release is saved for
## when the fighter is healthy, a wall goes up when the opponent is attacking, and so on.
## Pure functions: the situation goes in as a dictionary, the plan comes out.
##   situation: distance (float), target_attacking (bool), self_percent, target_percent (float),
##              released (bool: already in a release)
##   plan:      use (bool), delay (frames until the second press), hold (frames to hold special after)

const RELEASE_MAX_PERCENT := 100.0
const NEAR := 80.0
const WALL_MIN := 45.0
const WALL_MAX := 150.0
const PULL_MIN := 70.0
const STREAM_MIN := 100.0
const SPIN_MAX := 70.0


## The plan for pressing special again after `skill`.
static func plan(skill: SpecialData, situation: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var none := {"use": false, "delay": -1, "hold": 0}
	if skill == null or skill.follow_up == null:
		return none
	var follow := skill.follow_up
	var distance: float = situation.get("distance", 100.0)
	var attacking: bool = situation.get("target_attacking", false)
	var soon := skill.startup_frames + 2
	var latest := skill.startup_frames + maxi(3, skill.follow_up_window - 4)
	if follow.bind_frames > 0: # Rikujōkōrō: right after the dash, while they are close
		return {"use": distance <= NEAR + 30.0, "delay": soon + rng.randi_range(0, 2), "hold": 0}
	if follow.release_frames > 0: # Eyepatch Release: only when healthy enough to pay for it
		var healthy: bool = float(situation.get("self_percent", 0.0)) <= RELEASE_MAX_PERCENT and not situation.get("released", false)
		return {"use": healthy, "delay": soon + rng.randi_range(0, 6), "hold": 0}
	if _is_wall(follow): # Kōri no Kabe: when they attack or rush from mid range
		return {"use": distance >= WALL_MIN and distance <= WALL_MAX and (attacking or distance <= NEAR + 20.0), "delay": soon + rng.randi_range(0, 3), "hold": 0}
	if follow.armor: # Armored Rush: through an attack, or to finish a close fight
		return {"use": attacking or distance <= NEAR, "delay": soon + rng.randi_range(0, 3), "hold": 0}
	if follow.is_spin(): # Zabimaru Whirl: only when they are within the ring
		return {"use": distance <= SPIN_MAX, "delay": soon + rng.randi_range(0, 4), "hold": follow.spin_frames}
	if follow.is_stream(): # Ginrei Kojaku: a long volley from a distance
		var shots := maxi(1, follow.stream_max_shots - 1)
		return {"use": distance >= STREAM_MIN, "delay": soon + rng.randi_range(0, 4), "hold": follow.stream_interval * shots}
	if follow.command_recall: # Seele Schneider: call the blades home late, when the opponent has walked up
		return {"use": distance <= NEAR + 40.0, "delay": maxi(soon, latest - rng.randi_range(0, 8)), "hold": 0}
	if _is_pull(follow): # Zabimaru Pull: a chain to drag in someone keeping away
		return {"use": distance >= PULL_MIN, "delay": soon + rng.randi_range(0, 3), "hold": 0}
	if _is_cross(follow): # Getsuga Jūjishō: right behind the first wave, from a distance
		return {"use": distance >= NEAR, "delay": soon + rng.randi_range(0, 4), "hold": 0}
	return {"use": rng.randf() < 0.6, "delay": soon + rng.randi_range(0, maxi(1, latest - soon)), "hold": 0}


static func _is_wall(skill: SpecialData) -> bool:
	return not skill.projectiles.is_empty() and skill.projectiles[0].solid


static func _is_pull(skill: SpecialData) -> bool:
	return not skill.projectiles.is_empty() and skill.angle_degrees > 150.0 and skill.base_knockback > 0.0


static func _is_cross(skill: SpecialData) -> bool:
	if skill.projectiles.size() != 2:
		return false
	var a: Vector2 = skill.projectiles[0].size
	var b: Vector2 = skill.projectiles[1].size
	return (a.x > a.y) != (b.x > b.y)


## True while an attack press would link "perfectly" (Ichigo's rhythm): the beat just after the hit.
static func rhythm_press(move: MoveData, frame: int, active_end: int, rng: RandomNumberGenerator) -> bool:
	if move == null or move.rhythm_bonus <= 0.0:
		return false
	if not NormalRiders.is_perfect(frame, active_end):
		return false
	return rng.randf() < 0.45
