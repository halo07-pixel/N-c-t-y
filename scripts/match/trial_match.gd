extends Node2D
## The combo trial practice scene: the player's fighter and a dummy that does not fight back on
## the test stage. The TrialTracker follows the exercise through Events; this scene places the
## fighters, resets after a result and reports to the HUD and the saved progress.

const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")
const DUMMY_KNOCKBACK_SCALE := 0.35
const RESULT_FRAMES := 80

var trial: ComboTrial
var tracker := TrialTracker.new()

var _player: Fighter
var _dummy: Fighter
var _result_frames_left: int = 0

@onready var _stage: Stage = $Stage
@onready var _camera: FightCamera = $FightCamera
@onready var _hud: TrialHud = $TrialHud


func _ready() -> void:
	var character := MatchConfig.character_for(1)
	MatchConfig.p2_index = MatchConfig.p1_index
	MatchConfig.opponent_override = null
	var trials := TrialLibrary.for_character(character)
	trial = trials[clampi(MatchConfig.trial_index, 0, trials.size() - 1)]
	_player = _spawn(1, character)
	_dummy = _spawn(2, character)
	_dummy.knockback_scale = DUMMY_KNOCKBACK_SCALE
	var keys := PlayerInput.new()
	keys.player_id = 1
	_player.set_input_source(keys)
	_dummy.set_input_source(InputSource.new())
	_camera.bounds = _stage.camera_bounds
	var targets: Array[Node2D] = [_player, _dummy]
	_camera.set_targets(targets)

	tracker.setup(trial)
	tracker.step_done.connect(_on_step_done)
	tracker.completed.connect(_on_completed)
	tracker.failed.connect(_on_failed)
	Events.fighter_attack_started.connect(_on_attack_started)
	Events.fighter_hit.connect(_on_hit)
	Events.fighter_dashed.connect(_on_dashed)
	Events.fighter_gauge_cancelled.connect(_on_gauge_cancelled)
	_hud.show_trial(trial)
	_restart()


func _exit_tree() -> void:
	for connection in [
		[Events.fighter_attack_started, _on_attack_started], [Events.fighter_hit, _on_hit],
		[Events.fighter_dashed, _on_dashed], [Events.fighter_gauge_cancelled, _on_gauge_cancelled],
	]:
		if connection[0].is_connected(connection[1]):
			connection[0].disconnect(connection[1])


func _physics_process(_delta: float) -> void:
	if _result_frames_left > 0:
		_result_frames_left -= 1
		if _result_frames_left == 0:
			_restart()
		return
	tracker.tick()
	for fighter in [_player, _dummy]:
		if not _stage.is_inside_blast_zone(fighter.global_position):
			_restart()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Events.screen_requested.emit(&"trial_select")
		return
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
		_restart()


func _spawn(player_id: int, character: CharacterData) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = player_id
	fighter.data = character
	fighter.position = TrialLibrary.PRACTICE_ORIGIN
	fighter.projectile_spawned.connect(_on_projectile_spawned)
	add_child(fighter)
	return fighter


## Puts both fighters back in place, clears shots and starts the exercise from the first step.
func _restart() -> void:
	_result_frames_left = 0
	for node in get_tree().get_nodes_in_group(Projectile.SHOT_GROUP):
		if node.owner_id == 1 or node.owner_id == 2:
			node.queue_free()
	var origin := TrialLibrary.PRACTICE_ORIGIN
	_player.reset_for_practice(origin, 1, trial.start_gauge)
	_dummy.reset_for_practice(origin + Vector2(trial.dummy_distance, 0.0), -1, 0.0)
	tracker.reset()
	_hud.set_progress(0)
	_hud.clear_banner()


func _on_projectile_spawned(projectile: Projectile) -> void:
	add_child(projectile)


func _on_attack_started(player_id: int, move_name: String) -> void:
	tracker.on_attack_started(player_id, move_name)


func _on_hit(attacker_id: int, victim_id: int, _damage: float) -> void:
	tracker.on_hit(attacker_id, victim_id)


func _on_dashed(player_id: int, _spot: Vector2, _direction: int) -> void:
	tracker.on_dashed(player_id)


func _on_gauge_cancelled(player_id: int, _spot: Vector2) -> void:
	tracker.on_gauge_cancelled(player_id)


func _on_step_done(_index: int) -> void:
	_hud.set_progress(tracker.index)


func _on_completed() -> void:
	GameSettings.mark_trial_done(trial.key)
	_hud.show_banner("COMPLETE!", TrialHud.DONE_COLOR)
	_result_frames_left = RESULT_FRAMES


func _on_failed(reason: String) -> void:
	_hud.show_banner("RETRY  -  %s" % reason, Color(0.95, 0.4, 0.4))
	_result_frames_left = RESULT_FRAMES
