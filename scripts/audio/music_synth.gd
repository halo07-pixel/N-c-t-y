class_name MusicSynth
extends RefCounted
## Builds the looping background music from a tiny score (no audio files): a chord progression
## played as pad, bass and arpeggio, with drums on the fight track. Output is a looping
## `AudioStreamWAV`. Low sample rate keeps generation quick and gives it a chiptune feel.

const MIX_RATE := 11025
const BEATS_PER_BAR := 4

## Per track: bpm, bars_per_chord, roots (MIDI notes of each chord, minor/major from `minor`),
## pad / bass / arp / drums toggles. Each chord is held for `bars_per_chord` bars.
const TRACKS := {
	&"menu": {
		"bpm": 84.0, "bars_per_chord": 2, "roots": [45, 41, 48, 43], "minor": [true, false, false, false],
		"pad": 0.16, "bass": 0.0, "arp": 0.07, "drums": false, "arp_steps": 2,
	},
	&"fight": {
		"bpm": 148.0, "bars_per_chord": 2, "roots": [45, 43, 41, 40], "minor": [true, false, false, false],
		"pad": 0.08, "bass": 0.16, "arp": 0.07, "drums": true, "arp_steps": 4,
	},
}

static var _cache := {}
static var _lock := Mutex.new()


static func has_track(track: StringName) -> bool:
	return TRACKS.has(track)


static func stream_for(track: StringName) -> AudioStreamWAV:
	_lock.lock()
	var cached: AudioStreamWAV = _cache.get(track)
	_lock.unlock()
	if cached == null:
		cached = _build(track) # built outside the lock; a racing duplicate build is harmless
		_lock.lock()
		_cache[track] = cached
		_lock.unlock()
	return cached


## Builds every track on a worker thread so the first play does not hitch the game.
static func warm_up() -> void:
	WorkerThreadPool.add_task(func() -> void:
		for track in TRACKS:
			stream_for(track))


## Seconds one full loop of a track lasts.
static func loop_seconds(track: StringName) -> float:
	var spec: Dictionary = TRACKS[track]
	var bars: int = (spec["roots"] as Array).size() * int(spec["bars_per_chord"])
	return float(bars * BEATS_PER_BAR) * 60.0 / float(spec["bpm"])


static func midi_to_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


static func _build(track: StringName) -> AudioStreamWAV:
	var spec: Dictionary = TRACKS[track]
	var beat := 60.0 / float(spec["bpm"])
	var beat_samples := int(beat * float(MIX_RATE))
	var roots: Array = spec["roots"]
	var chord_beats: int = int(spec["bars_per_chord"]) * BEATS_PER_BAR
	var total := roots.size() * chord_beats * beat_samples
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(track)
	for chord in roots.size():
		var root: int = roots[chord]
		var third := root + (3 if bool((spec["minor"] as Array)[chord]) else 4)
		var chord_notes := [root + 12, third + 12, root + 19]
		var start := chord * chord_beats * beat_samples
		if float(spec["pad"]) > 0.0:
			for note in chord_notes:
				_tone(buffer, start, chord_beats * beat_samples, midi_to_hz(note), "triangle", float(spec["pad"]), 0.6)
		if float(spec["bass"]) > 0.0:
			for step in chord_beats * 2: # eighth notes
				var note := root if step % 4 != 3 else root + 7
				_tone(buffer, start + step * beat_samples / 2, beat_samples / 2, midi_to_hz(note), "square", float(spec["bass"]), 6.0)
		if float(spec["arp"]) > 0.0:
			var steps_per_beat: int = int(spec["arp_steps"])
			for step in chord_beats * steps_per_beat:
				var note: int = chord_notes[step % 3] + 12 * int((step / 3) % 2)
				_tone(buffer, start + step * beat_samples / steps_per_beat, beat_samples / steps_per_beat, midi_to_hz(note), "square", float(spec["arp"]), 5.0)
		if bool(spec["drums"]):
			for b in chord_beats:
				var at := start + b * beat_samples
				_kick(buffer, at)
				_hat(buffer, at + beat_samples / 2, rng)
				if b % 2 == 1:
					_hat(buffer, at, rng, 0.5)
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buffer[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total
	return stream


static func _tone(buffer: PackedFloat32Array, start: int, length: int, freq: float, wave: String, gain: float, decay: float) -> void:
	var end := mini(start + length, buffer.size())
	var phase := 0.0
	for i in range(start, end):
		var t := float(i - start) / float(length)
		phase += freq / float(MIX_RATE)
		var cycle := phase - floorf(phase)
		var sample := sin(cycle * TAU)
		match wave:
			"square":
				sample = 1.0 if cycle < 0.5 else -1.0
			"triangle":
				sample = absf(cycle * 4.0 - 2.0) - 1.0
		var attack := minf(float(i - start) / 60.0, 1.0)
		var release := minf(float(end - i) / 60.0, 1.0)
		buffer[i] += sample * gain * pow(1.0 - t, decay * 0.5) * attack * release


static func _kick(buffer: PackedFloat32Array, start: int) -> void:
	var length := int(0.14 * float(MIX_RATE))
	var phase := 0.0
	for i in mini(length, buffer.size() - start):
		var t := float(i) / float(length)
		phase += lerpf(150.0, 40.0, t) / float(MIX_RATE)
		buffer[start + i] += sin(phase * TAU) * 0.32 * (1.0 - t)


static func _hat(buffer: PackedFloat32Array, start: int, rng: RandomNumberGenerator, level: float = 1.0) -> void:
	var length := int(0.04 * float(MIX_RATE))
	for i in mini(length, buffer.size() - start):
		buffer[start + i] += rng.randf_range(-1.0, 1.0) * 0.08 * level * (1.0 - float(i) / float(length))
