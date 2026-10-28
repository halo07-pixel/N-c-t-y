extends SceneTree
## Developer tool: draws the key frames of every animation of a rigged fighter on one sheet.
## Usage (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 -s tools/rig_sheet.gd -- out.png CHARACTER.tres [page]
## Page 0 = movement, page 1 = attacks. Game classes are loaded at run time, not named here.

const COLUMNS := 8
const CELL := Vector2(90.0, 100.0)
const FIGURE_SCALE := 2.1
const UPSCALE := 2
const MOVEMENT := [
	["idle", 0.0, ""], ["idle", 1.2, ""], ["run", 0.0, ""], ["run", 0.1, ""], ["run", 0.21, ""], ["run", 0.31, ""],
	["jump", 0.0, ""], ["fall", 0.0, ""], ["land", 0.0, ""], ["guard", 0.0, ""], ["hitstun", 0.0, ""],
	["ko", 0.0, ""], ["charge", 0.0, ""],
]
const ATTACKS := [
	["attack_neutral", 0.0, "startup"], ["attack_neutral", 0.0, "active"], ["attack_neutral", 0.0, "recovery"],
	["attack_forward", 0.0, "startup"], ["attack_forward", 0.0, "active"], ["attack_forward", 0.0, "recovery"],
	["attack_up", 0.0, "startup"], ["attack_up", 0.0, "active"], ["attack_up", 0.0, "recovery"],
	["attack_down", 0.0, "startup"], ["attack_down", 0.0, "active"], ["attack_down", 0.0, "recovery"],
	["air_attack", 0.0, "startup"], ["air_attack", 0.0, "active"], ["air_attack", 0.0, "recovery"],
	["special", 0.0, "startup"], ["special", 0.0, "active"], ["special", 0.0, "recovery"],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0]
	var rig_path: String = args[1]
	var page: int = int(args[2]) if args.size() > 2 else 0
	var frames: Array = ATTACKS if page == 1 else MOVEMENT
	var character: Resource = load("res://resources/characters/noble.tres").duplicate()
	character.rig = load(rig_path)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.3, 0.25, 0.4)
	backdrop.size = Vector2(720.0, 405.0)
	root.add_child(backdrop)
	for index in frames.size():
		var column := index % COLUMNS
		var row := index / COLUMNS
		var origin := Vector2(column * CELL.x + CELL.x * 0.5, row * CELL.y + CELL.y - 18.0)
		var ground := ColorRect.new()
		ground.color = Color(0.15, 0.13, 0.22)
		ground.position = origin + Vector2(-CELL.x * 0.5 + 2.0, 0.0)
		ground.size = Vector2(CELL.x - 4.0, 2.0)
		root.add_child(ground)
		var holder := Node2D.new()
		holder.position = origin
		holder.scale = Vector2.ONE * FIGURE_SCALE
		root.add_child(holder)
		var body: Node2D = load("res://scripts/rig/rig_body.gd").new()
		body.setup(character, 1)
		holder.add_child(body)
		var entry: Array = frames[index]
		body.preview(StringName(entry[0]), entry[1], StringName(entry[2]) if entry[2] != "" else &"active")
		var label := Label.new()
		label.text = "%s %s" % [str(entry[0]).replace("attack_", "a_"), entry[2] if entry[2] != "" else ("%.1f" % entry[1])]
		label.add_theme_font_size_override("font_size", 8)
		label.position = Vector2(column * CELL.x + 3.0, row * CELL.y + CELL.y - 14.0)
		root.add_child(label)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(image.get_width() * UPSCALE, image.get_height() * UPSCALE, Image.INTERPOLATE_NEAREST)
	print("Saved ", output, " error ", image.save_png(output))
	quit(0)
