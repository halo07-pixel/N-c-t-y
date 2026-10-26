class_name CharacterSelect
extends MenuScreen
## Pick fighters. Two players: each picks with their own keys and confirms.
## Versus CPU: player 1 picks their fighter, then the opponent and CPU level.

const PANEL_SIZE := Vector2(190.0, 150.0)
const PANEL_TOP := 62.0
const PANEL_X := {1: 30.0, 2: 260.0}
const PREVIEW_SCALE := 1.8
const SPEED_MAX := 160.0
const WEIGHT_MAX := 120.0

## True while player 1 is choosing the CPU's fighter (CPU mode only).
var picking_opponent: bool = false
var confirmed := {1: false, 2: false}
var _bodies := {}


func _ready() -> void:
	super()
	for player_id in [1, 2]:
		# The body repositions itself every frame, so a holder carries the place and scale.
		var holder := Node2D.new()
		holder.position = Vector2(PANEL_X[player_id] + PANEL_SIZE.x * 0.5, PANEL_TOP + 98.0)
		holder.scale = Vector2.ONE * PREVIEW_SCALE
		add_child(holder)
		var body := PlaceholderBody.new()
		holder.add_child(body)
		_bodies[player_id] = body
	_refresh_bodies()


func is_cpu_mode() -> bool:
	return MatchConfig.cpu_level > MatchConfig.CPU_OFF


func _unhandled_input(event: InputEvent) -> void:
	for player_id in [1, 2]:
		var action := MenuNav.read(event, player_id)
		if action != &"":
			handle_player_action(player_id, action)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_cancel"):
		handle_player_action(1, &"back")
		get_viewport().set_input_as_handled()


## One menu action from one player's keys.
func handle_player_action(player_id: int, action: StringName) -> void:
	if is_cpu_mode():
		_handle_cpu_mode(player_id, action)
	else:
		_handle_two_players(player_id, action)
	_refresh_bodies()
	queue_redraw()


func _handle_two_players(player_id: int, action: StringName) -> void:
	match action:
		&"left", &"right":
			if not confirmed[player_id]:
				MatchConfig.step_character(player_id, -1 if action == &"left" else 1)
		&"confirm":
			confirmed[player_id] = true
			if confirmed[1] and confirmed[2]:
				go_to(&"versus_match")
		&"back":
			if confirmed[player_id]:
				confirmed[player_id] = false
			else:
				go_to(&"main_menu")


## In CPU mode only player 1's keys act; player 2 is the computer.
func _handle_cpu_mode(player_id: int, action: StringName) -> void:
	if player_id != 1:
		return
	var chooser := 2 if picking_opponent else 1
	match action:
		&"left", &"right":
			MatchConfig.step_character(chooser, -1 if action == &"left" else 1)
		&"up", &"down":
			if picking_opponent:
				MatchConfig.step_cpu(1 if action == &"up" else -1)
		&"confirm":
			if picking_opponent:
				go_to(&"versus_match")
			else:
				picking_opponent = true
		&"back":
			if picking_opponent:
				picking_opponent = false
			else:
				go_to(&"main_menu")


func _refresh_bodies() -> void:
	for player_id in [1, 2]:
		var body: PlaceholderBody = _bodies.get(player_id)
		if body == null:
			continue
		body.setup(MatchConfig.character_for(player_id), player_id)
		body.sync_to(&"Idle", 1 if player_id == 1 else -1, Vector2.ZERO)


func _draw_content() -> void:
	draw_centered("CHOOSE YOUR FIGHTER", Vector2(SCREEN.x * 0.5, 40.0), 18, WHITE)
	for player_id in [1, 2]:
		_draw_panel(player_id)
	draw_centered(_hint(), Vector2(SCREEN.x * 0.5, 256.0), 8, DIM)


func _hint() -> String:
	if is_cpu_mode():
		if picking_opponent:
			return "Left / Right: opponent    Up / Down: CPU level    Attack: fight    Guard: back"
		return "Left / Right: choose    Attack: confirm    Guard: back"
	return "Left / Right: choose    Attack: ready    Guard: undo / back"


func _draw_panel(player_id: int) -> void:
	var character := MatchConfig.character_for(player_id)
	var color := RED if player_id == 1 else BLUE
	var origin := Vector2(PANEL_X[player_id], PANEL_TOP)
	var active := _is_active(player_id)
	draw_rect(Rect2(origin, PANEL_SIZE), Color(0.0, 0.0, 0.0, 0.4))
	draw_rect(Rect2(origin, PANEL_SIZE), color if active else DIM, false, 2.0 if active else 1.0)
	draw_left(_panel_title(player_id), origin + Vector2(8.0, 16.0), 11, color)
	draw_centered(character.display_name.to_upper(), origin + Vector2(PANEL_SIZE.x * 0.5, 118.0), 14, WHITE)
	_draw_bar("SPEED", origin + Vector2(8.0, 134.0), character.run_speed / SPEED_MAX, color)
	_draw_bar("WEIGHT", origin + Vector2(100.0, 134.0), character.weight / WEIGHT_MAX, color)
	if confirmed[player_id]:
		draw_left("READY!", origin + Vector2(PANEL_SIZE.x - 64.0, 16.0), 11, WARM)


func _panel_title(player_id: int) -> String:
	if player_id == 2 and is_cpu_mode():
		return "CPU  LEVEL %d" % MatchConfig.cpu_level
	return "PLAYER %d" % player_id


func _is_active(player_id: int) -> bool:
	if is_cpu_mode():
		return (player_id == 2) == picking_opponent
	return not confirmed[player_id]


func _draw_bar(label: String, origin: Vector2, fill: float, color: Color) -> void:
	draw_left(label, origin - Vector2(0.0, 4.0), 7, DIM)
	var bar := Rect2(origin, Vector2(82.0, 6.0))
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), color)
