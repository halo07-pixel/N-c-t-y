class_name SfxSynth
extends RefCounted
## Builds every sound effect from a small recipe (no audio files): a tone that can sweep in
## pitch, mixed with noise, shaped by a decay envelope. Pure data in, `AudioStreamWAV` out.

const MIX_RATE := 22050

## Per sound: duration (s), freq_start/freq_end (Hz, tone sweep), wave ("sine" | "square" | "saw"),
## tone (0..1 tone level), noise (0..1 noise level), decay (envelope sharpness), gain (0..1).
const RECIPES := {
	&"swing": {"duration": 0.12, "freq_start": 900.0, "freq_end": 300.0, "wave": "sine", "tone": 0.1, "noise": 0.8, "decay": 3.0, "gain": 0.35},
	&"hit_light": {"duration": 0.09, "freq_start": 260.0, "freq_end": 120.0, "wave": "square", "tone": 0.5, "noise": 0.6, "decay": 5.0, "gain": 0.5},
	&"hit_heavy": {"duration": 0.22, "freq_start": 150.0, "freq_end": 45.0, "wave": "saw", "tone": 0.7, "noise": 0.7, "decay": 4.0, "gain": 0.75},
	&"guard": {"duration": 0.1, "freq_start": 700.0, "freq_end": 520.0, "wave": "square", "tone": 0.6, "noise": 0.2, "decay": 6.0, "gain": 0.4},
	&"parry": {"duration": 0.28, "freq_start": 1500.0, "freq_end": 1900.0, "wave": "sine", "tone": 0.8, "noise": 0.05, "decay": 4.5, "gain": 0.55},
	&"guard_break": {"duration": 0.3, "freq_start": 500.0, "freq_end": 90.0, "wave": "saw", "tone": 0.6, "noise": 0.6, "decay": 3.5, "gain": 0.7},
	&"jump": {"duration": 0.09, "freq_start": 330.0, "freq_end": 560.0, "wave": "sine", "tone": 0.6, "noise": 0.0, "decay": 3.0, "gain": 0.25},
	&"land": {"duration": 0.07, "freq_start": 120.0, "freq_end": 70.0, "wave": "sine", "tone": 0.4, "noise": 0.5, "decay": 5.0, "gain": 0.3},
	&"dash": {"duration": 0.14, "freq_start": 600.0, "freq_end": 200.0, "wave": "saw", "tone": 0.2, "noise": 0.7, "decay": 3.0, "gain": 0.35},
	&"ko": {"duration": 0.7, "freq_start": 320.0, "freq_end": 40.0, "wave": "saw", "tone": 0.7, "noise": 0.5, "decay": 2.2, "gain": 0.85},
	&"transform": {"duration": 1.0, "freq_start": 220.0, "freq_end": 880.0, "wave": "sine", "tone": 0.9, "noise": 0.15, "decay": 1.6, "gain": 0.7},
	&"ultimate": {"duration": 0.9, "freq_start": 90.0, "freq_end": 30.0, "wave": "saw", "tone": 0.8, "noise": 0.6, "decay": 1.8, "gain": 0.9},
	&"match_start": {"duration": 0.4, "freq_start": 440.0, "freq_end": 660.0, "wave": "square", "tone": 0.6, "noise": 0.0, "decay": 3.0, "gain": 0.45},
	&"match_end": {"duration": 0.9, "freq_start": 660.0, "freq_end": 330.0, "wave": "sine", "tone": 0.8, "noise": 0.0, "decay": 2.0, "gain": 0.6},
}

static var _cache := {}


static func has_recipe(kind: StringName) -> bool:
	return RECIPES.has(kind)


## The stream for a sound, built once and reused.
static func stream_for(kind: StringName) -> AudioStreamWAV:
	if not _cache.has(kind):
		_cache[kind] = _build(kind)
	return _cache[kind]


static func _build(kind: StringName) -> AudioStreamWAV:
	var recipe: Dictionary = RECIPES[kind]
	var count := int(float(recipe["duration"]) * float(MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) # same noise every build, so the sound is stable
	var phase := 0.0
	for i in count:
		var t := float(i) / float(count)
		var freq := lerpf(float(recipe["freq_start"]), float(recipe["freq_end"]), t)
		phase += freq / float(MIX_RATE)
		var tone := _wave(String(recipe["wave"]), phase) * float(recipe["tone"])
		var noise := rng.randf_range(-1.0, 1.0) * float(recipe["noise"])
		var envelope := pow(1.0 - t, float(recipe["decay"]))
		var attack := minf(float(i) / 40.0, 1.0) # a few samples of ramp-in avoid clicks
		var sample := (tone + noise) * envelope * attack * float(recipe["gain"])
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _wave(wave: String, phase: float) -> float:
	var cycle := phase - floorf(phase)
	match wave:
		"square":
			return 1.0 if cycle < 0.5 else -1.0
		"saw":
			return cycle * 2.0 - 1.0
		_:
			return sin(cycle * TAU)
