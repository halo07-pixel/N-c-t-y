class_name TrialTracker
extends RefCounted
## Follows one ComboTrial from Events: which step is next, did the player do the right thing, did
## they take too long. It only listens (feed it the events); the practice scene shows the result.

signal step_done(index: int)
signal completed
signal failed(reason: String)

## Frames allowed between two steps once the exercise has started.
const TIMEOUT_FRAMES := 90

var trial: ComboTrial
var player_id: int = 1
var dummy_id: int = 2
## The next step to do; equals the step count when the exercise is complete.
var index: int = 0
var finished: bool = false

var _idle_frames: int = 0
var _current_attack: String = ""
var _last_done_attack: String = ""


func setup(new_trial: ComboTrial, player: int = 1, dummy: int = 2) -> void:
	trial = new_trial
	player_id = player
	dummy_id = dummy
	reset()


func reset() -> void:
	index = 0
	finished = false
	_idle_frames = 0
	_current_attack = ""
	_last_done_attack = ""


func expected() -> String:
	return trial.steps[index] if trial != null and index < trial.steps.size() else ""


## Call once per physics frame.
func tick() -> void:
	if finished or index == 0:
		return
	_idle_frames += 1
	if _idle_frames > TIMEOUT_FRAMES:
		_fail("Too slow")


func on_attack_started(id: int, move_name: String) -> void:
	if id == player_id:
		_current_attack = move_name


func on_dashed(id: int) -> void:
	if id == player_id and not finished and expected() == ComboTrial.TOKEN_DASH:
		_advance()


func on_gauge_cancelled(id: int) -> void:
	if id == player_id and not finished and expected() == ComboTrial.TOKEN_GAUGE_CANCEL:
		_advance()


## A hit landed on a fighter. Only our hits on the dummy count.
func on_hit(attacker: int, victim: int) -> void:
	if finished or attacker != player_id or victim != dummy_id:
		return
	if _current_attack == expected():
		_last_done_attack = _current_attack
		_advance()
	elif _current_attack == _last_done_attack:
		return # another hit of the move that was just done (a multi-hit skill)
	else:
		_fail("Wrong move: %s" % _current_attack)


func _advance() -> void:
	_idle_frames = 0
	index += 1
	step_done.emit(index - 1)
	if index >= trial.steps.size():
		finished = true
		completed.emit()


func _fail(reason: String) -> void:
	finished = true
	failed.emit(reason)
