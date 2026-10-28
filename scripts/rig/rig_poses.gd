class_name RigPoses
extends RefCounted
## The pose library shared by every rigged fighter. A pose is a dictionary of joint
## angles in degrees, in "facing right" terms:
##   limbs (arm_*, thigh_*): 0 hangs straight down, +90 points forward, +180 up.
##   elbow_* / knee_*: bend. Elbow bends the forearm forward; knee bends the shin back.
##   torso, head, body: positive leans forward.
##   blade: where the weapon points, absolute, using the same scale as the limbs.
## Missing keys fall back to NEUTRAL. `target()` returns the pose to move toward for
## an animation plus how fast to move (the body smooths toward it every frame).

const NEUTRAL := {
	"hip_x": 0.0, "hip_y": 0.0, "body": 0.0, "torso": 2.0, "head": 0.0,
	"arm_f": 20.0, "elbow_f": 35.0, "blade": 125.0,
	"arm_b": -12.0, "elbow_b": 18.0,
	"thigh_f": 8.0, "knee_f": 14.0, "foot_f": 0.0,
	"thigh_b": -8.0, "knee_b": 10.0, "foot_b": 0.0,
}

const RUN_CYCLES_PER_SECOND := 2.4
const ANIMATIONS: Array[StringName] = [
	&"idle", &"run", &"jump", &"fall", &"land", &"guard", &"hitstun", &"ko", &"charge",
	&"attack_neutral", &"attack_forward", &"attack_up", &"attack_down", &"air_attack", &"special",
]

## Hand-posed keyframes. Attacks have a pose for each phase.
const POSES := {
	&"jump": {
		"thigh_f": 42.0, "knee_f": 72.0, "thigh_b": -8.0, "knee_b": 62.0, "torso": 4.0,
		"arm_f": 70.0, "elbow_f": 25.0, "blade": 150.0, "arm_b": -55.0, "elbow_b": 30.0,
	},
	&"fall": {
		"thigh_f": 16.0, "knee_f": 22.0, "thigh_b": -16.0, "knee_b": 30.0, "torso": -2.0,
		"arm_f": 85.0, "elbow_f": 20.0, "blade": 120.0, "arm_b": -70.0, "elbow_b": 20.0,
	},
	&"land": {
		"thigh_f": 46.0, "knee_f": 88.0, "thigh_b": -20.0, "knee_b": 80.0, "torso": 22.0,
		"arm_f": 30.0, "elbow_f": 40.0, "blade": 100.0, "arm_b": -30.0, "elbow_b": 30.0,
	},
	&"guard": {
		"thigh_f": 18.0, "knee_f": 30.0, "thigh_b": -14.0, "knee_b": 24.0, "torso": 8.0,
		"arm_f": 82.0, "elbow_f": 85.0, "blade": 175.0, "arm_b": 70.0, "elbow_b": 90.0,
	},
	&"hitstun": {
		"thigh_f": 34.0, "knee_f": 44.0, "thigh_b": -30.0, "knee_b": 40.0, "torso": -16.0, "head": -18.0,
		"arm_f": 120.0, "elbow_f": 25.0, "blade": 60.0, "arm_b": 130.0, "elbow_b": 15.0,
	},
	&"ko": {
		"thigh_f": 40.0, "knee_f": 50.0, "thigh_b": -36.0, "knee_b": 46.0, "torso": -28.0, "head": -26.0,
		"arm_f": 140.0, "elbow_f": 10.0, "blade": 40.0, "arm_b": 150.0, "elbow_b": 10.0,
	},
	&"charge": {
		"thigh_f": 34.0, "knee_f": 60.0, "thigh_b": -26.0, "knee_b": 52.0, "torso": 12.0,
		"arm_f": 100.0, "elbow_f": 25.0, "blade": 172.0, "arm_b": 105.0, "elbow_b": 25.0,
	},
	&"attack_forward": {
		&"startup": {
			"torso": -12.0, "arm_f": 165.0, "elbow_f": 40.0, "blade": 205.0, "hip_x": -2.0,
			"thigh_f": 20.0, "knee_f": 30.0, "thigh_b": -26.0, "knee_b": 20.0, "arm_b": -40.0, "elbow_b": 30.0,
		},
		&"active": {
			"torso": 16.0, "arm_f": 96.0, "elbow_f": 8.0, "blade": 92.0, "hip_x": 3.0,
			"thigh_f": 32.0, "knee_f": 42.0, "thigh_b": -24.0, "knee_b": 6.0, "arm_b": -60.0, "elbow_b": 25.0,
		},
		&"recovery": {
			"torso": 8.0, "arm_f": 70.0, "elbow_f": 22.0, "blade": 80.0, "hip_x": 1.0,
			"thigh_f": 20.0, "knee_f": 30.0, "thigh_b": -16.0, "knee_b": 16.0, "arm_b": -30.0, "elbow_b": 20.0,
		},
	},
	&"attack_neutral": {
		&"startup": {
			"torso": -6.0, "arm_f": 40.0, "elbow_f": 70.0, "blade": 195.0,
			"thigh_f": 16.0, "knee_f": 24.0, "thigh_b": -20.0, "knee_b": 16.0,
		},
		&"active": {
			"torso": 10.0, "arm_f": 100.0, "elbow_f": 6.0, "blade": 100.0, "hip_x": 2.0,
			"thigh_f": 22.0, "knee_f": 30.0, "thigh_b": -18.0, "knee_b": 8.0, "arm_b": -45.0,
		},
		&"recovery": {
			"torso": 4.0, "arm_f": 60.0, "elbow_f": 30.0, "blade": 95.0,
			"thigh_f": 14.0, "knee_f": 22.0, "thigh_b": -12.0, "knee_b": 14.0,
		},
	},
	&"attack_up": {
		&"startup": {
			"torso": -4.0, "arm_f": 50.0, "elbow_f": 60.0, "blade": 100.0,
			"thigh_f": 30.0, "knee_f": 50.0, "thigh_b": -20.0, "knee_b": 40.0,
		},
		&"active": {
			"torso": -9.0, "arm_f": 172.0, "elbow_f": 4.0, "blade": 178.0,
			"thigh_f": 10.0, "knee_f": 12.0, "thigh_b": -10.0, "knee_b": 8.0, "arm_b": 150.0, "elbow_b": 10.0,
		},
		&"recovery": {
			"torso": -2.0, "arm_f": 125.0, "elbow_f": 20.0, "blade": 150.0,
			"thigh_f": 14.0, "knee_f": 20.0, "thigh_b": -12.0, "knee_b": 14.0,
		},
	},
	&"attack_down": {
		&"startup": {
			"torso": 4.0, "arm_f": 125.0, "elbow_f": 60.0, "blade": 175.0,
			"thigh_f": 40.0, "knee_f": 70.0, "thigh_b": -20.0, "knee_b": 60.0,
		},
		&"active": {
			"torso": 24.0, "arm_f": 58.0, "elbow_f": 6.0, "blade": 52.0, "hip_x": 2.0,
			"thigh_f": 44.0, "knee_f": 74.0, "thigh_b": -22.0, "knee_b": 64.0, "arm_b": -40.0,
		},
		&"recovery": {
			"torso": 14.0, "arm_f": 40.0, "elbow_f": 20.0, "blade": 50.0,
			"thigh_f": 32.0, "knee_f": 56.0, "thigh_b": -18.0, "knee_b": 48.0,
		},
	},
	&"air_attack": {
		&"startup": {
			"torso": -8.0, "arm_f": 160.0, "elbow_f": 40.0, "blade": 200.0,
			"thigh_f": 48.0, "knee_f": 72.0, "thigh_b": 6.0, "knee_b": 70.0,
		},
		&"active": {
			"torso": 12.0, "arm_f": 96.0, "elbow_f": 8.0, "blade": 94.0,
			"thigh_f": 50.0, "knee_f": 70.0, "thigh_b": 12.0, "knee_b": 68.0, "arm_b": -55.0,
		},
		&"recovery": {
			"torso": 4.0, "arm_f": 70.0, "elbow_f": 22.0, "blade": 82.0,
			"thigh_f": 40.0, "knee_f": 60.0, "thigh_b": 0.0, "knee_b": 56.0,
		},
	},
	&"special": {
		&"startup": {
			"torso": -14.0, "arm_f": 70.0, "elbow_f": 60.0, "blade": 215.0, "hip_x": -3.0,
			"thigh_f": 36.0, "knee_f": 66.0, "thigh_b": -22.0, "knee_b": 54.0, "arm_b": -60.0,
		},
		&"active": {
			"torso": 22.0, "arm_f": 96.0, "elbow_f": 4.0, "blade": 92.0, "hip_x": 5.0,
			"thigh_f": 52.0, "knee_f": 24.0, "thigh_b": -42.0, "knee_b": 6.0, "arm_b": -70.0,
		},
		&"recovery": {
			"torso": 10.0, "arm_f": 70.0, "elbow_f": 24.0, "blade": 84.0, "hip_x": 2.0,
			"thigh_f": 30.0, "knee_f": 40.0, "thigh_b": -20.0, "knee_b": 20.0,
		},
	},
}

## How quickly the body moves toward the target, per second (higher is snappier).
const RATES := {
	&"idle": 12.0, &"run": 34.0, &"jump": 16.0, &"fall": 12.0, &"land": 24.0, &"guard": 20.0,
	&"hitstun": 26.0, &"ko": 20.0, &"charge": 14.0,
}
const PHASE_RATES := {&"startup": 15.0, &"active": 55.0, &"recovery": 11.0}
## Animations where the lowest foot is kept on the ground (the others float).
const AIRBORNE: Array[StringName] = [&"jump", &"fall", &"hitstun", &"ko", &"air_attack"]


## The pose (every joint filled in) a body should move toward, with its smoothing rate and
## whether the feet are planted on the ground. `time` is seconds since the animation began
## (run cycles use it); `phase` is the attack phase for attack animations.
static func target(animation: StringName, time: float, phase: StringName = &"active") -> Dictionary:
	var pose := NEUTRAL.duplicate()
	var rate: float = RATES.get(animation, 14.0)
	match animation:
		&"idle":
			_idle(pose, time)
		&"run":
			_run(pose, time)
		_:
			var entry: Dictionary = POSES.get(animation, {})
			if entry.has(&"startup"):
				pose.merge(entry.get(phase, entry[&"active"]), true)
				rate = PHASE_RATES.get(phase, 14.0)
			else:
				pose.merge(entry, true)
	return {"pose": pose, "rate": rate, "plant": not AIRBORNE.has(animation)}


static func _idle(pose: Dictionary, time: float) -> void:
	var breath := sin(time * 2.6)
	pose["torso"] = 2.0 + breath * 1.2
	pose["head"] = -breath * 0.8
	pose["arm_f"] = 20.0 + breath * 2.0
	pose["arm_b"] = -12.0 - breath * 2.0
	pose["thigh_f"] = 8.0 + breath * 0.6
	pose["knee_f"] = 14.0 + breath * 1.2
	pose["knee_b"] = 10.0 + breath * 1.2


## Run cycle as a smooth function of the cycle phase (equivalent to many keyframes).
static func _run(pose: Dictionary, time: float) -> void:
	var phase := time * RUN_CYCLES_PER_SECOND * TAU
	pose["torso"] = 11.0
	pose["head"] = -4.0
	pose["thigh_f"] = 40.0 * sin(phase)
	pose["thigh_b"] = -40.0 * sin(phase)
	pose["knee_f"] = 30.0 + 30.0 * cos(phase)
	pose["knee_b"] = 30.0 - 30.0 * cos(phase)
	pose["foot_f"] = -10.0 * cos(phase)
	pose["foot_b"] = 10.0 * cos(phase)
	pose["arm_b"] = -38.0 * sin(phase)
	pose["elbow_b"] = 40.0 + 18.0 * sin(phase)
	pose["arm_f"] = 30.0 - 10.0 * sin(phase)
	pose["elbow_f"] = 45.0
	pose["blade"] = 110.0 + 6.0 * sin(phase)


## Weapon angle relative to the forearm that gives the wanted absolute `blade` angle.
static func weapon_relative(pose: Dictionary) -> float:
	var forearm: float = pose["arm_f"] + pose["elbow_f"] - pose["torso"] - pose["body"]
	return pose["blade"] - forearm
