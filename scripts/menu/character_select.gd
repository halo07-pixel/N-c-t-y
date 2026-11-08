class_name CharacterSelect
extends MenuScreen
## Fighter select: a grid of portrait tiles (every roster fighter, then Random) with one cursor per
## player. Two players: each moves and readies with their own keys, and when both are ready a short
## FIGHT countdown starts. Versus CPU: player 1 picks, then picks the opponent, and the Skill key
## changes the CPU level. Arcade: player 1 picks and the run starts.
## The cursor logic (slots, ready, countdown) is kept apart from the drawing below.

signal fight_started

const TILE := Vector2(40.0, 40.0)
const TILE_GAP := 5.0
const GRID_TOP := 62.0
const PREVIEW_X := {1: 66.0, 2: 414.0}
const PREVIEW_FEET_Y := 168.0
const PREVIEW_SCALE := 2.0
const PANEL_SIZE := Vector2(226.0, 72.0)
const PANEL_TOP := 180.0
const ROW_GAP := 12.0
const PANEL_X := {1: 10.0, 2: 244.0}
const SPEED_MAX := 160.0
const WEIGHT_MAX := 120.0
const COUNTDOWN_FRAMES := 45
const ROLE_COLORS := {
	"zone": Color(0.4, 0.75, 1.0), "rush": Color(1.0, 0.55, 0.3), "combo": Color(1.0, 0.85, 0.3),
	"heavy": Color(0.95, 0.3, 0.3), "defend": Color(0.5, 0.9, 0.5), "area": Color(0.75, 0.5, 1.0),
	"recover": Color(0.8, 0.8, 0.9),
}

## True while player 1 is choosing the CPU's fighter (CPU mode only).
var picking_opponent: bool = false
var confirmed := {1: false, 2: false}
## The grid slot each player's cursor is on.
var slots := {1: 0, 2: 1}
## Frames left before the match starts; -1 while nobody has started it.
var countdown: int = -1
var grid: RosterGrid
var _characters: Array[CharacterData] = []
var _bodies := {}
var _shown := {}
var _holders := {}
var _started := false


func _ready() -> void:
	super()
	for player_id in [1, 2]:
		# The body repositions itself every frame, so a holder carries the place and scale.
		var holder := Node2D.new()
		holder.scale = Vector2.ONE * PREVIEW_SCALE
		holder.position = Vector2(PREVIEW_X[player_id], PREVIEW_FEET_Y)
		add_child(holder)
		_holders[player_id] = holder
	_refresh_bodies()


func _init() -> void:
	# Tests build the screen without adding it to the tree, so the grid exists from the start.
	_characters = MatchConfig.roster()
	grid = RosterGrid.new(_characters.size())
	for player_id in [1, 2]:
		slots[player_id] = _slot_of(player_id)


func is_arcade() -> bool:
	return MatchConfig.arcade


## Where the fight goes: the training room, or a versus match.
func _match_screen() -> StringName:
	return &"training_match" if MatchConfig.training else &"versus_match"


func is_cpu_mode() -> bool:
	return MatchConfig.cpu_level > MatchConfig.CPU_OFF


func _slot_of(player_id: int) -> int:
	if MatchConfig.is_random(player_id):
		return grid.random_slot()
	return clampi(MatchConfig.p1_index if player_id == 1 else MatchConfig.p2_index, 0, grid.character_count - 1)


## Whose cursor the keys of `player_id` move right now, or 0 when they move nothing.
func _chooser_for(player_id: int) -> int:
	if is_cpu_mode():
		if player_id != 1:
			return 0
		return 2 if picking_opponent else 1
	return player_id if not confirmed[player_id] else 0


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


func _physics_process(_delta: float) -> void:
	advance(1)


## Runs the FIGHT countdown by `frames`; the match starts when it reaches zero.
func advance(frames: int) -> void:
	if countdown < 0 or _started:
		return
	countdown = maxi(0, countdown - frames)
	queue_redraw()
	if countdown == 0:
		_started = true
		fight_started.emit()
		go_to(_match_screen())


## One menu action from one player's keys.
func handle_player_action(player_id: int, action: StringName) -> void:
	if _started:
		return
	if is_cpu_mode():
		_handle_cpu_mode(player_id, action)
	else:
		_handle_two_players(player_id, action)
	_refresh_bodies()
	queue_redraw()


func _handle_two_players(player_id: int, action: StringName) -> void:
	match action:
		&"left", &"right", &"up", &"down":
			if _chooser_for(player_id) != 0:
				_move_cursor(player_id, action)
		&"confirm":
			if not confirmed[player_id]:
				MatchConfig.lock_in(player_id)
				slots[player_id] = _slot_of_locked(player_id)
				confirmed[player_id] = true
			if confirmed[1] and confirmed[2] and countdown < 0:
				countdown = COUNTDOWN_FRAMES
		&"back":
			if countdown >= 0:
				countdown = -1
				confirmed[player_id] = false
			elif confirmed[player_id]:
				confirmed[player_id] = false
			else:
				go_to(&"main_menu")


## In CPU mode only player 1's keys act; player 2 is the computer.
func _handle_cpu_mode(player_id: int, action: StringName) -> void:
	if player_id != 1:
		return
	var chooser := _chooser_for(1)
	match action:
		&"left", &"right", &"up", &"down":
			_move_cursor(chooser, action)
		&"skill":
			if picking_opponent:
				MatchConfig.cpu_level = MatchConfig.cpu_level % MatchConfig.CPU_MAX_LEVEL + 1
		&"confirm":
			MatchConfig.lock_in(chooser)
			slots[chooser] = _slot_of_locked(chooser)
			if is_arcade():
				ArcadeRun.start(MatchConfig.p1_index)
				go_to(ArcadeRun.SCREEN_STORY)
			elif picking_opponent:
				go_to(_match_screen())
			else:
				picking_opponent = true
		&"back":
			if picking_opponent:
				picking_opponent = false
			else:
				go_to(&"main_menu")


func _slot_of_locked(player_id: int) -> int:
	return clampi(MatchConfig.p1_index if player_id == 1 else MatchConfig.p2_index, 0, grid.character_count - 1)


const DIRECTIONS := {
	&"left": Vector2i(-1, 0), &"right": Vector2i(1, 0), &"up": Vector2i(0, -1), &"down": Vector2i(0, 1),
}


## Moves `chooser`'s cursor one step and records the pick (a Random tile is an undecided pick).
func _move_cursor(chooser: int, action: StringName) -> void:
	if chooser == 0:
		return
	var slot := grid.move(slots[chooser], DIRECTIONS[action])
	slots[chooser] = slot
	var index := MatchConfig.RANDOM_PICK if grid.is_random_slot(slot) else slot
	if chooser == 1:
		MatchConfig.p1_index = index
	else:
		MatchConfig.p2_index = index


## The fighter under a cursor, or null on the Random tile.
func hovered(player_id: int) -> CharacterData:
	var slot: int = slots[player_id]
	return null if grid.is_random_slot(slot) else _characters[slot]


func _refresh_bodies() -> void:
	for player_id in [1, 2]:
		var holder: Node2D = _holders.get(player_id)
		if holder == null:
			continue
		_show_character(player_id, holder)
		holder.visible = (player_id == 1 or not is_arcade()) and hovered(player_id) != null


## Shows the fighter under the cursor standing in its holder.
func _show_character(player_id: int, holder: Node2D) -> void:
	var character := hovered(player_id)
	if _shown.get(player_id) == character and _bodies.get(player_id) != null:
		return
	if _bodies.get(player_id) != null:
		_bodies[player_id].queue_free()
		_bodies[player_id] = null
	_shown[player_id] = character
	if character == null:
		return
	var body := BodyFactory.create(character, player_id)
	holder.add_child(body)
	body.sync_to(&"Idle", 1 if player_id == 1 else -1, Vector2.ZERO)
	_bodies[player_id] = body


# --- drawing -----------------------------------------------------------------------------------

func _draw_content() -> void:
	var title := "ARCADE - CHOOSE YOUR FIGHTER" if is_arcade() else "CHOOSE YOUR FIGHTER"
	if MatchConfig.training:
		title = "TRAINING - YOU, THEN THE DUMMY"
	draw_centered(title, Vector2(SCREEN.x * 0.5, 30.0), 16, WHITE)
	_draw_grid()
	for player_id in [1, 2]:
		if player_id == 1 or not is_arcade():
			_draw_panel(player_id)
	if countdown >= 0:
		_draw_countdown()
	draw_centered(_hint(), Vector2(SCREEN.x * 0.5, 264.0), 7, DIM)


func _grid_origin() -> Vector2:
	var width := grid.columns * TILE.x + (grid.columns - 1) * TILE_GAP
	return Vector2((SCREEN.x - width) * 0.5, GRID_TOP)


func _tile_rect(slot: int) -> Rect2:
	var at := grid.cell(slot)
	var step := TILE + Vector2(TILE_GAP, ROW_GAP)
	# A short last row is centred under the full ones.
	var shift := (grid.columns - grid.row_length(at.y)) * step.x * 0.5
	return Rect2(_grid_origin() + Vector2(at.x * step.x + shift, at.y * step.y), TILE)


func _draw_grid() -> void:
	for slot in grid.slot_count():
		var rect := _tile_rect(slot)
		draw_rect(rect, Color(0.05, 0.03, 0.1, 0.96))
		draw_rect(rect, DIM, false, 1.0)
		if grid.is_random_slot(slot):
			draw_centered("?", rect.position + Vector2(TILE.x * 0.5, 27.0), 20, WARM)
			draw_centered("RANDOM", rect.position + Vector2(TILE.x * 0.5, 38.0), 6, DIM)
		else:
			var character := _characters[slot]
			PortraitArt.draw_portrait(self, rect.position + Vector2(TILE.x * 0.5, 17.0), 11.0, character, character.accent_color)
			draw_centered(character.display_name.to_upper(), rect.position + Vector2(TILE.x * 0.5, 37.0), 6, WHITE)
	for player_id in [2, 1]:
		if player_id == 1 or not is_arcade():
			_draw_cursor(player_id)


func _draw_cursor(player_id: int) -> void:
	var color := RED if player_id == 1 else BLUE
	var rect := _tile_rect(slots[player_id])
	var inset := 0.0
	if player_id == 2 and slots[1] == slots[2] and not is_arcade():
		inset = 3.0 # both cursors on one tile: player 2's frame sits inside player 1's
	var framed := rect.grow(-inset)
	var ready_now: bool = confirmed[player_id] and not is_cpu_mode()
	draw_rect(framed, color, false, 3.0 if _chooser_for(player_id) != 0 or ready_now else 1.5)
	var tag := "CPU" if player_id == 2 and is_cpu_mode() else "P%d" % player_id
	var tag_x := 0.0 if player_id == 1 else TILE.x - 16.0
	draw_rect(Rect2(rect.position + Vector2(tag_x, -9.0), Vector2(16.0, 9.0)), color)
	draw_left(tag, rect.position + Vector2(tag_x + 2.0, -2.0), 7, WHITE)


func _panel_active(player_id: int) -> bool:
	if is_arcade():
		return true
	return _chooser_for(player_id if not is_cpu_mode() else 1) == player_id


func _draw_panel(player_id: int) -> void:
	var color := RED if player_id == 1 else BLUE
	var origin := Vector2(PANEL_X[player_id], PANEL_TOP)
	var active := _panel_active(player_id)
	draw_rect(Rect2(origin, PANEL_SIZE), Color(0.05, 0.03, 0.1, 0.96))
	draw_rect(Rect2(origin, Vector2(PANEL_SIZE.x, 3.0)), color if active else DIM)
	draw_rect(Rect2(origin, PANEL_SIZE), color if active else DIM, false, 2.0 if active else 1.0)
	var character := hovered(player_id)
	draw_left(_panel_title(player_id), origin + Vector2(6.0, 14.0), 8, color)
	if confirmed[player_id] and not is_cpu_mode():
		draw_left("READY", origin + Vector2(PANEL_SIZE.x - 40.0, 14.0), 9, WARM)
	if character == null:
		draw_left("RANDOM", origin + Vector2(10.0, 36.0), 14, WARM)
		draw_left("a fighter is drawn when you confirm", origin + Vector2(10.0, 52.0), 7, DIM)
		return
	PortraitArt.draw_portrait(self, origin + Vector2(20.0, 38.0), 12.0, character, color)
	draw_left(character.display_name.to_upper(), origin + Vector2(38.0, 32.0), 12, WHITE)
	_draw_bar("SPEED", origin + Vector2(38.0, 40.0), character.run_speed / SPEED_MAX, color)
	_draw_bar("WEIGHT", origin + Vector2(38.0, 49.0), character.weight / WEIGHT_MAX, color)
	_draw_skill_icons(character, origin + Vector2(134.0, 25.0))
	draw_left(SkillGuide.signature_for(character), origin + Vector2(8.0, PANEL_SIZE.y - 4.0), 6, WARM)


func _panel_title(player_id: int) -> String:
	if player_id == 2 and is_cpu_mode():
		return "CPU  LEVEL %d" % MatchConfig.cpu_level
	return "PLAYER %d" % player_id


## Up to three skill icons: a square in the skill's role colour and the role's name.
func _draw_skill_icons(character: CharacterData, origin: Vector2) -> void:
	var shown := 0
	if character.specials == null:
		return
	for skill: SpecialData in [character.specials.neutral, character.specials.forward, character.specials.up, character.specials.down]:
		if skill == null or skill.role == "" or shown >= 3:
			continue
		var at := origin + Vector2(0.0, shown * 11.0)
		var role_color: Color = ROLE_COLORS.get(skill.role, DIM)
		draw_rect(Rect2(at, Vector2(9.0, 9.0)), role_color)
		draw_rect(Rect2(at, Vector2(9.0, 9.0)), PortraitArt.OUTLINE, false, 1.0)
		draw_left(skill.role.to_upper(), at + Vector2(13.0, 8.0), 7, WHITE)
		shown += 1


func _draw_bar(label: String, origin: Vector2, fill: float, color: Color) -> void:
	draw_left(label, origin + Vector2(0.0, 6.0), 6, DIM)
	var bar := Rect2(origin + Vector2(30.0, 0.0), Vector2(60.0, 6.0))
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), color)


func _draw_countdown() -> void:
	draw_rect(Rect2(Vector2(0.0, 108.0), Vector2(SCREEN.x, 36.0)), Color(0.0, 0.0, 0.0, 0.55))
	draw_centered("FIGHT!", Vector2(SCREEN.x * 0.5, 134.0), 26, WARM)


func _hint() -> String:
	if is_arcade():
		return "Arrows: move    Attack: start Arcade (4 fights)    Guard: back"
	if is_cpu_mode():
		if picking_opponent:
			return "Arrows: dummy    Attack: start training    Guard: back" if MatchConfig.training else "Arrows: opponent    Skill: CPU level    Attack: fight    Guard: back"
		return "Arrows: move    Attack: confirm    Guard: back"
	return "Arrows: move    Attack: ready    Guard: cancel / back"
