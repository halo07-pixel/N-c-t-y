extends Node2D
## A two-player match on the test stage. Spawns the fighters from MatchConfig,
## applies the settings, detects blast-zone KOs and respawns; the rules live in
## MatchManager and everything on screen listens through the Events bus.

const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")

var _fighters: Dictionary = {}
var _match_over: bool = false
var _winner_id: int = 0

@onready var _stage: Stage = $Stage
@onready var _camera: FightCamera = $FightCamera
@onready var _manager: MatchManager = $MatchManager


func _ready() -> void:
	var ids: Array[int] = []
	var targets: Array[Node2D] = []
	for player_id in [1, 2]:
		var fighter := _spawn_fighter(player_id)
		_fighters[player_id] = fighter
		ids.append(player_id)
		targets.append(fighter)
	_setup_inputs()
	_camera.bounds = _stage.camera_bounds
	_camera.set_targets(targets)

	Events.fighter_respawn_due.connect(_on_respawn_due)
	Events.sudden_death_started.connect(_on_sudden_death_started)
	Events.match_ended.connect(_on_match_ended)

	var seconds := 0 if GameSettings.is_time_unlimited() else GameSettings.time_limit_seconds()
	_manager.setup(ids, GameSettings.stocks, seconds)


func _physics_process(_delta: float) -> void:
	for player_id: int in _fighters:
		var fighter: Fighter = _fighters[player_id]
		if fighter.is_ko() or _stage.is_inside_blast_zone(fighter.global_position):
			continue
		var ko_position := fighter.global_position
		fighter.enter_ko()
		Events.fighter_ko.emit(player_id, ko_position)
		Events.fighter_left_blast_zone.emit(player_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		ArcadeRun.quit_run()
		Events.screen_requested.emit(&"main_menu")
	elif _match_over and event.is_action_pressed(&"ui_accept"):
		if ArcadeRun.active:
			Events.screen_requested.emit(ArcadeRun.finish_match(_winner_id == 1))
		else:
			get_tree().reload_current_scene()


func _spawn_fighter(player_id: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = player_id
	fighter.data = MatchConfig.character_for(player_id)
	fighter.position = _stage.get_spawn_position(player_id)
	fighter.facing = 1 if player_id == 1 else -1
	fighter.projectile_spawned.connect(_on_projectile_spawned)
	add_child(fighter)
	return fighter


## Player 1 is always on the keyboard; player 2 is on the keyboard or the CPU.
func _setup_inputs() -> void:
	var first: Fighter = _fighters[1]
	var second: Fighter = _fighters[2]
	first.set_input_source(_keyboard_input(1))
	if MatchConfig.cpu_level == MatchConfig.CPU_OFF:
		second.set_input_source(_keyboard_input(2))
		return
	var cpu := AIInput.new()
	cpu.bind(second, first, MatchConfig.cpu_level)
	second.set_input_source(cpu)


func _keyboard_input(player_id: int) -> PlayerInput:
	var source := PlayerInput.new()
	source.player_id = player_id
	return source


func _on_projectile_spawned(projectile: Projectile) -> void:
	add_child(projectile)


func _on_respawn_due(player_id: int) -> void:
	var fighter: Fighter = _fighters[player_id]
	fighter.respawn_at(_stage.get_respawn_position(player_id))


func _on_sudden_death_started() -> void:
	for player_id: int in _fighters:
		var fighter: Fighter = _fighters[player_id]
		fighter.set_percent(MatchManager.SUDDEN_DEATH_PERCENT)


func _on_match_ended(winner_id: int) -> void:
	_match_over = true
	_winner_id = winner_id
	for player_id: int in _fighters:
		var fighter: Fighter = _fighters[player_id]
		fighter.set_input_source(InputSource.new())
