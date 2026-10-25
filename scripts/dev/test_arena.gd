extends Node2D
## Development arena for the foundation phase: two fighters on the test stage.
## Falling out of the blast zone just respawns them (stocks come with combat).

const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ROSTER: Dictionary = {
	1: preload("res://resources/characters/placeholder_a.tres"),
	2: preload("res://resources/characters/placeholder_b.tres"),
}

var _fighters: Array[Fighter] = []

@onready var _stage: Stage = $Stage
@onready var _camera: FightCamera = $FightCamera


func _ready() -> void:
	var targets: Array[Node2D] = []
	for player_id: int in ROSTER:
		var fighter := FIGHTER_SCENE.instantiate() as Fighter
		fighter.player_id = player_id
		fighter.data = ROSTER[player_id]
		fighter.position = _stage.get_spawn_position(player_id)
		fighter.facing = 1 if player_id == 1 else -1
		add_child(fighter)

		var source := PlayerInput.new()
		source.player_id = player_id
		fighter.set_input_source(source)

		_fighters.append(fighter)
		targets.append(fighter)
	_camera.bounds = _stage.camera_bounds
	_camera.set_targets(targets)


func _physics_process(_delta: float) -> void:
	for fighter in _fighters:
		if not _stage.is_inside_blast_zone(fighter.global_position):
			Events.fighter_left_blast_zone.emit(fighter.player_id)
			fighter.respawn_at(_stage.get_spawn_position(fighter.player_id))
