extends SceneTree
## Developer tool: plays the versus match with a simple bot and saves a PNG.
## Usage (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/capture_screenshot.gd -- \
##       out.png SCENARIO [P1_CHARACTER_INDEX] [P2_CHARACTER_INDEX]
## Scenarios: idle | hit | ko | end | special | bankai | ultimate
## Menu screens: title | menu | select | select_cpu | settings | controls
## Arcade: select_arcade | story | story_boss | continue | clear | boss | boss_ult (match vs the boss)
## Character indexes follow MatchConfig.ROSTER_PATHS (0 swordsman, 1 archer, 2 noble).
##
## Game classes are deliberately not named in this file: a SceneTree script is
## compiled before the autoloads exist, so naming them would break compilation.

const MATCH_PATH := "res://scenes/match/versus_match.tscn"
const SCRIPTED_INPUT_PATH := "res://scripts/fighter/scripted_input.gd"
const HITBOX_PATH := "res://scripts/combat/hitbox.gd"
const SCREEN_SCENES := {
	"title": "res://scenes/ui/title_screen.tscn",
	"menu": "res://scenes/ui/main_menu.tscn",
	"select": "res://scenes/ui/character_select.tscn",
	"select_cpu": "res://scenes/ui/character_select.tscn",
	"settings": "res://scenes/ui/settings_menu.tscn",
	"controls": "res://scenes/ui/settings_menu.tscn",
	"select_arcade": "res://scenes/ui/character_select.tscn",
	"story": "res://scenes/ui/arcade_story.tscn",
	"story_boss": "res://scenes/ui/arcade_story.tscn",
	"continue": "res://scenes/ui/arcade_continue.tscn",
	"clear": "res://scenes/ui/arcade_clear.tscn",
}
const UPSCALE := 3
const MAX_FRAMES := 1500
const ATTACK_RANGE := 46.0
const ATTACK_COOLDOWN := 40

var _match: Node
var _fighters: Array[Node] = []
var _bot_input: Object
var _boss_input: Object
var _cooldown: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path: String = args[0] if args.size() > 0 else "screenshot.png"
	var scenario: String = args[1] if args.size() > 1 else "hit"
	if SCREEN_SCENES.has(scenario):
		await _capture_screen(output_path, scenario)
		return
	var config := root.get_node("MatchConfig")
	if scenario.begins_with("boss"):
		_start_arcade(true)
	config.p1_index = int(args[2]) if args.size() > 2 else 0
	config.p2_index = int(args[3]) if args.size() > 3 else 1
	if scenario == "end":
		root.get_node("GameSettings").stocks = 1

	_match = (load(MATCH_PATH) as PackedScene).instantiate()
	root.add_child(_match)
	await physics_frame
	_setup_fighters()
	await _play_scenario(scenario)
	await _save(output_path)


func _capture_screen(output_path: String, scenario: String) -> void:
	root.get_node("ScreenRouter").enabled = false
	root.get_node("MatchConfig").cpu_level = 2 if scenario.begins_with("select") else 0
	root.get_node("MatchConfig").arcade = scenario == "select_arcade"
	if scenario in ["story", "story_boss", "continue", "clear"]:
		_start_arcade(scenario == "story_boss" or scenario == "clear")
	var screen: Node = (load(SCREEN_SCENES[scenario]) as PackedScene).instantiate()
	root.add_child(screen)
	await _frames(5)
	if scenario == "select":
		screen.handle_player_action(1, &"confirm")
		screen.handle_player_action(2, &"right")
	elif scenario == "select_cpu":
		screen.handle_player_action(1, &"confirm")
		screen.handle_player_action(1, &"right")
	elif scenario == "settings":
		screen.handle_action(&"down")
	elif scenario == "controls":
		screen.handle_action(&"down")
		screen.handle_action(&"down")
		screen.handle_action(&"down")
		screen.handle_action(&"down")
		screen.handle_action(&"confirm")
	await _frames(3)
	await _save(output_path)


func _start_arcade(boss_fight: bool) -> void:
	var run := root.get_node("ArcadeRun")
	run.start(0)
	if boss_fight:
		run.fight_index = run.FIGHT_COUNT - 1
		run._apply_fight()
	run.continues_used = 2


func _play_scenario(scenario: String) -> void:
	match scenario:
		"hit":
			load(HITBOX_PATH).show_debug = true
			await _play_until(func() -> bool: return _fighters[1].get_state_name() == &"Hitstun")
			await _frames(1)
		"ko":
			_fighters[1].set_percent(180.0)
			await _play_until(func() -> bool: return _fighters[1].is_ko())
			await _frames(20)
		"end":
			_fighters[1].set_percent(180.0)
			await _play_until(func() -> bool: return _match._match_over)
			await _frames(10)
		"special":
			await _frames(30)
			_bot_input.tap_special()
			await _until(func() -> bool: return _count_projectiles() > 0)
			await _frames(14)
		"bankai":
			_fighters[0].set_reiatsu(250.0)
			await _frames(30)
			_bot_input.tap_charge()
			await _frames(30)
		"boss":
			await _frames(60)
		"boss_ult":
			_fighters[1].set_reiatsu(300.0)
			await _frames(30)
			_boss_input.tap_charge()
			await _frames(28)
		"ultimate":
			_fighters[0].set_reiatsu(300.0)
			await _frames(30)
			_bot_input.tap_charge()
			await _frames(28)
		_:
			await _frames(45)


func _setup_fighters() -> void:
	for child in _match.get_children():
		if child.has_method("set_input_source"):
			_fighters.append(child)
	var input_script: GDScript = load(SCRIPTED_INPUT_PATH)
	_bot_input = input_script.new()
	_fighters[0].set_input_source(_bot_input)
	_boss_input = input_script.new()
	_fighters[1].set_input_source(_boss_input)


func _count_projectiles() -> int:
	var count := 0
	for child in _match.get_children():
		if child.has_method("launch"):
			count += 1
	return count


## Runs the bot (player 1 chases and attacks player 2) until `done` or the frame cap.
func _play_until(done: Callable) -> void:
	await _frames(30)
	for _i in MAX_FRAMES:
		_drive_bot()
		await physics_frame
		if done.call():
			return


func _until(done: Callable) -> void:
	for _i in MAX_FRAMES:
		await physics_frame
		if done.call():
			return


func _drive_bot() -> void:
	var gap: float = _fighters[1].global_position.x - _fighters[0].global_position.x
	var toward := signf(gap)
	_bot_input.held_move = Vector2(toward if absf(gap) > 24.0 else 0.0, 0.0)
	_cooldown -= 1
	if absf(gap) <= ATTACK_RANGE and _cooldown <= 0 and not _fighters[1].is_ko():
		_bot_input.held_move = Vector2(toward, 0.0)
		_bot_input.tap_attack()
		_cooldown = ATTACK_COOLDOWN


func _save(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	var error := image.save_png(output_path)
	print("Saved %s (%dx%d), error code %d" % [output_path, image.get_width(), image.get_height(), error])
	quit(0 if error == OK else 1)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
