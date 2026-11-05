extends Node2D
## Training mode: your fighter and a dummy that cannot be KO'd on the test stage. The rules live
## in TrainingRules (combo count, damage wipe, dummy behaviour); this scene places the fighters,
## keeps resources full, and respawns anyone who leaves the stage at once.

const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const ORIGIN := TrialLibrary.PRACTICE_ORIGIN
const DUMMY_GAP := 120.0

var rules := TrainingRules.new()

var _player: Fighter
var _dummy: Fighter
var _dummy_input: DummyInput

@onready var _stage: Stage = $Stage
@onready var _camera: FightCamera = $FightCamera
@onready var _hud: TrainingHud = $TrainingHud


func _ready() -> void:
	MatchConfig.opponent_override = null
	_player = _spawn(1, MatchConfig.character_for(1))
	_dummy = _spawn(2, MatchConfig.character_for(2))
	var keys := PlayerInput.new()
	keys.player_id = 1
	_player.set_input_source(keys)
	_apply_mode()
	_camera.bounds = _stage.camera_bounds
	var targets: Array[Node2D] = [_player, _dummy]
	_camera.set_targets(targets)
	rules.combo_changed.connect(_on_rules_changed)
	rules.combo_ended.connect(_on_rules_changed)
	rules.percent_reset_due.connect(_on_percent_reset_due)
	Events.fighter_hit.connect(_on_hit)
	_reset_positions()


func _exit_tree() -> void:
	if Events.fighter_hit.is_connected(_on_hit):
		Events.fighter_hit.disconnect(_on_hit)


func _physics_process(_delta: float) -> void:
	for fighter in [_player, _dummy]:
		if not _stage.is_inside_blast_zone(fighter.global_position):
			_put_back(fighter)
	if rules.infinite_resources:
		_player.set_reiatsu(Reiatsu.MAX)
		_player.reset_cooldowns()
	rules.tick(_dummy.percent)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Events.screen_requested.emit(&"main_menu")
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			_reset_positions()
		KEY_T:
			rules.next_mode()
			_apply_mode()
			_on_rules_changed()
		KEY_Y:
			rules.toggle_resources()
			_on_rules_changed()


func _spawn(player_id: int, character: CharacterData) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = player_id
	fighter.data = character
	fighter.position = ORIGIN
	fighter.projectile_spawned.connect(_on_projectile_spawned)
	add_child(fighter)
	return fighter


## What the dummy does now: the CPU for the CPU modes, otherwise the simple dummy input.
func _apply_mode() -> void:
	var level := rules.cpu_level()
	if level > 0:
		var cpu := AIInput.new()
		cpu.bind(_dummy, _player, level)
		_dummy.set_input_source(cpu)
	else:
		_dummy_input = DummyInput.new() # the fighter frees the source it replaces
		_dummy_input.mode = rules.mode()
		_dummy.set_input_source(_dummy_input)


func _reset_positions() -> void:
	for node in get_tree().get_nodes_in_group(Projectile.SHOT_GROUP):
		if node.owner_id == 1 or node.owner_id == 2:
			node.queue_free()
	_player.reset_for_practice(ORIGIN, 1, 0.0)
	_dummy.reset_for_practice(ORIGIN + Vector2(DUMMY_GAP, 0.0), -1, 0.0)
	rules.reset()


## Whoever left the stage comes straight back at the start spot, with no stock lost.
func _put_back(fighter: Fighter) -> void:
	var spot := ORIGIN if fighter == _player else ORIGIN + Vector2(DUMMY_GAP, 0.0)
	fighter.reset_for_practice(spot, 1 if fighter == _player else -1, 0.0)


func _on_percent_reset_due() -> void:
	_dummy.set_percent(0.0)


func _on_hit(attacker_id: int, victim_id: int, amount: float) -> void:
	rules.on_hit(attacker_id, victim_id, amount)


func _on_rules_changed(_hits: int = 0, _damage: float = 0.0) -> void:
	_hud.show_rules(rules)


func _on_projectile_spawned(projectile: Projectile) -> void:
	add_child(projectile)
