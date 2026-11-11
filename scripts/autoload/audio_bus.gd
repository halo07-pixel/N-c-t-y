extends Node
## Plays sound effects in answer to Events signals. Nothing in the game calls this directly
## ("signal up"): fighters and the match emit signals, this node listens and chooses a sound.
## Sounds are synthesised by SfxSynth; volume follows the settings (sfx_volume 0..10).

const SFX_BUS := &"SFX"
const MUSIC_BUS := &"Music"
## Screens that play the fight track; every other screen plays the menu track.
const FIGHT_SCREENS := [&"versus_match", &"trial_match", &"training_match"]
const POOL_SIZE := 10
## Minimum gap (ms) between two plays of the same sound, so rapid hits do not stack into noise.
const MIN_GAP_MS := {&"swing": 60, &"hit_light": 40, &"hit_heavy": 40, &"land": 120, &"jump": 80, &"dash": 80}
const DEFAULT_GAP_MS := 30
const HEAVY_DAMAGE := 12.0
const HEAVY_LAUNCH := 600.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play_ms := {}
## Every sound requested so far, newest last (kept short); lets tests check what was played.
var recent: Array[StringName] = []
var _music_player: AudioStreamPlayer
var current_track: StringName = &""


func _ready() -> void:
	MusicSynth.warm_up()
	_ensure_bus(SFX_BUS)
	_ensure_bus(MUSIC_BUS)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	Events.screen_requested.connect(func(screen: StringName) -> void: play_music(track_for_screen(screen)))
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	Events.settings_changed.connect(_apply_volume)
	Events.hit_impact.connect(_on_hit_impact)
	Events.attack_swing.connect(func(_a: int, _c: Vector2, _s: Vector2, _f: int) -> void: play(&"swing"))
	Events.fighter_guarded.connect(func(_v: int, _a: int, parried: bool, _p: Vector2) -> void: play(&"parry" if parried else &"guard"))
	Events.fighter_guard_broken.connect(func(_id: int) -> void: play(&"guard_break"))
	Events.fighter_jumped.connect(func(_id: int, _air: bool) -> void: play(&"jump"))
	Events.fighter_landed.connect(func(_id: int) -> void: play(&"land"))
	Events.fighter_dashed.connect(func(_id: int, _p: Vector2, _d: int) -> void: play(&"dash"))
	Events.fighter_ko.connect(func(_id: int, _p: Vector2) -> void: play(&"ko"))
	Events.transform_started.connect(func(_id: int, _t: String, _f: int) -> void: play(&"transform"))
	Events.ultimate_started.connect(func(_id: int, _f: int, _t: String) -> void: play(&"ultimate"))
	Events.match_started.connect(func() -> void:
		play(&"match_start")
		play_music(&"fight"))
	Events.match_ended.connect(func(_w: int) -> void:
		play(&"match_end")
		play_music(&"menu"))
	_apply_volume()


## Which impact sound a hit makes.
static func hit_sound(damage: float, launch_speed: float) -> StringName:
	return &"hit_heavy" if damage >= HEAVY_DAMAGE or launch_speed >= HEAVY_LAUNCH else &"hit_light"


## Bus volume (dB) for a 0..10 setting; 0 is silent.
static func volume_db_for(setting: int) -> float:
	if setting <= 0:
		return -80.0
	return linear_to_db(float(setting) / float(GameSettings.MAX_VOLUME))


func play(kind: StringName) -> void:
	if not SfxSynth.has_recipe(kind):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(kind, -100000)) < int(MIN_GAP_MS.get(kind, DEFAULT_GAP_MS)):
		return
	_last_play_ms[kind] = now
	recent.append(kind)
	if recent.size() > 32:
		recent.pop_front()
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = SfxSynth.stream_for(kind)
	player.play()


## Which music track a screen uses.
static func track_for_screen(screen: StringName) -> StringName:
	return &"fight" if FIGHT_SCREENS.has(screen) else &"menu"


## Starts a looping track (no-op when it is already the one playing).
func play_music(track: StringName) -> void:
	if track == current_track or not MusicSynth.has_track(track):
		return
	current_track = track
	_music_player.stream = MusicSynth.stream_for(track)
	_music_player.play()


func _on_hit_impact(_pos: Vector2, _dir: Vector2, damage: float, launch_speed: float, _attacker: int) -> void:
	play(hit_sound(damage, launch_speed))


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) == -1:
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")


func _apply_volume() -> void:
	var sfx := AudioServer.get_bus_index(SFX_BUS)
	if sfx != -1:
		AudioServer.set_bus_volume_db(sfx, volume_db_for(GameSettings.sfx_volume))
	var music := AudioServer.get_bus_index(MUSIC_BUS)
	if music != -1:
		AudioServer.set_bus_volume_db(music, volume_db_for(GameSettings.music_volume) - 6.0) # sits under the effects
