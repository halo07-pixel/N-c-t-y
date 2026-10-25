extends SceneTree
## Developer tool: plays the test arena for a moment and saves a PNG.
## Usage (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/capture_screenshot.gd -- out.png [idle|action]
##
## Game classes are deliberately not named in this file: a SceneTree script is
## compiled before the autoloads exist, so naming them would break compilation.

const ARENA_PATH := "res://scenes/dev/test_arena.tscn"
const SCRIPTED_INPUT_PATH := "res://scripts/fighter/scripted_input.gd"
const UPSCALE := 3


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output_path: String = args[0] if args.size() > 0 else "screenshot.png"
	var scenario: String = args[1] if args.size() > 1 else "action"

	var arena: Node = (load(ARENA_PATH) as PackedScene).instantiate()
	root.add_child(arena)
	await physics_frame

	var fighters: Array[Node] = []
	for child in arena.get_children():
		if child.has_method("set_input_source"):
			fighters.append(child)
	var input_script: GDScript = load(SCRIPTED_INPUT_PATH)
	var player_one: Node = input_script.new()
	var player_two: Node = input_script.new()
	fighters[0].set_input_source(player_one)
	fighters[1].set_input_source(player_two)

	if scenario == "action":
		await _frames(30)
		player_one.held_move = Vector2(1.0, 0.0)
		player_two.held_move = Vector2(-1.0, 0.0)
		await _frames(15)
		player_one.tap_up()
		player_two.tap_up()
		await _frames(12)
	else:
		await _frames(45)

	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	var error := image.save_png(output_path)
	print("Saved %s (%dx%d), error code %d" % [output_path, image.get_width(), image.get_height(), error])
	quit(0 if error == OK else 1)


func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
