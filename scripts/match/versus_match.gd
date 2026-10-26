extends Node2D
## A two-player match on the test stage. Spawns the fighters, applies the
## settings, detects blast-zone KOs and respawns; the rules themselves live in
## MatchManager and everything on screen listens through the Events bus.

const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ROSTER: Dictionary = {
	1: preload("res://resources/characters/placeholder_a.tres"),
	2: preload("res://resources/characters/placeholder_b.tres"),
}

var _fighters: Dictionary = {}
var _match_over: bool = false

@onready var _stage: Stage = $Stage
@onready var _camera: FightCamera = $FightCamera
@onready var _manager: MatchManager = $MatchManager


func _ready() -> void:
	var ids: Array[int] = []
	var targets: Array[Node2D] = []
	for player_id: int in ROSTER:
		var fighter := _spawn_fighter(player_id)
		_fighters[player_id] = fighter
		ids.append(player_id)
		targets.append(fighter)
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
		fighter.enter_ko()
		Events.fighter_left_blast_zone.emit(player_id)


func _unhandled_input(event: InputEvent) -> void:
	if _match_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _spawn_fighter(player_id: int) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = player_id
	fighter.data = ROSTER[player_id]
	fighter.position = _stage.get_spawn_position(player_id)
	fighter.facing = 1 if player_id == 1 else -1
	add_child(fighter)
	var source := PlayerInput.new()
	source.player_id = player_id
	fighter.set_input_source(source)
	return fighter


func _on_respawn_due(player_id: int) -> void:
	var fighter: Fighter = _fighters[player_id]
	fighter.respawn_at(_stage.get_respawn_position(player_id))


func _on_sudden_death_started() -> void:
	for player_id: int in _fighters:
		var fighter: Fighter = _fighters[player_id]
		fighter.set_percent(MatchManager.SUDDEN_DEATH_PERCENT)


func _on_match_ended(_winner_id: int) -> void:
	_match_over = true
	for player_id: int in _fighters:
		var fighter: Fighter = _fighters[player_id]
		fighter.set_input_source(InputSource.new())
