extends SceneTree
## Developer tool: frame-time probe for the heaviest scene (two CPU fighters, both kept in Bankai
## with full gauges so skills, ultimates, auras and fields keep firing). Prints and saves JSON.
## Needs a display (xvfb-run) so drawing is included; times are CPU/software-GL, so read them
## relatively (before/after, between effects levels), not as absolute FPS on a real GPU.
##
## xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/perf_probe.gd -- out.json [level=3] [frames=900] [chars=0,1] [cpu=3]
##   level: effects level 0..3 (GameSettings.effects_level)

const MATCH_PATH := "res://scenes/match/versus_match.tscn"
const AI_PATH := "res://scripts/ai/ai_input.gd"
const REFILL_EVERY := 90
## Names of the Performance monitors averaged over the run (seconds -> reported in ms).
const MONITORS := {"process_ms": Performance.TIME_PROCESS, "physics_ms": Performance.TIME_PHYSICS_PROCESS}
const WARMUP := 60


## Bisecting aid: `hide=` names (direct children of the match, or `Stage/Fog`-style paths) stop
## drawing, `off=` names stop processing altogether.
func _isolate(match_scene: Node, hide: PackedStringArray, off: PackedStringArray) -> void:
	for path in hide:
		var node := _find(match_scene, path)
		if node != null and "visible" in node:
			node.visible = false
	for path in off:
		var node := _find(match_scene, path)
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED


## A node path, optionally ending in `:N` to take the Nth child of the node it names.
func _find(match_scene: Node, path: String) -> Node:
	var parts := path.split(":")
	var node := match_scene.get_node_or_null(parts[0])
	if node != null and parts.size() > 1 and int(parts[1]) < node.get_child_count():
		return node.get_child(int(parts[1]))
	return node if parts.size() == 1 else null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "perf.json"
	var level := 3
	var frames := 900
	var cpu := 3
	var chars := [0, 1]
	var calm := false
	var hide: PackedStringArray = []
	var off: PackedStringArray = []
	for arg in args:
		if arg.begins_with("level="):
			level = int(arg.substr(6))
		elif arg.begins_with("frames="):
			frames = int(arg.substr(7))
		elif arg.begins_with("cpu="):
			cpu = int(arg.substr(4))
		elif arg.begins_with("hide="):
			hide = arg.substr(5).split(",")
		elif arg.begins_with("off="):
			off = arg.substr(4).split(",")
		elif arg == "calm=1":
			calm = true
		elif arg.begins_with("chars="):
			var parts := arg.substr(6).split(",")
			chars = [int(parts[0]), int(parts[1])]
	root.get_node("ScreenRouter").enabled = false
	var settings := root.get_node("GameSettings")
	settings.effects_level = level
	settings.screen_effects = level > 0
	var config := root.get_node("MatchConfig")
	config.p1_index = chars[0]
	config.p2_index = chars[1]
	var match_scene: Node = (load(MATCH_PATH) as PackedScene).instantiate()
	root.add_child(match_scene)
	await physics_frame
	var fighters: Array = []
	for child in match_scene.get_children():
		if child.has_method("set_input_source"):
			fighters.append(child)
	for index in 2 if not calm else 0:
		var brain = load(AI_PATH).new()
		brain.bind(fighters[index], fighters[1 - index], cpu, 100 + index * 31)
		fighters[index].set_input_source(brain)
	_isolate(match_scene, hide, off)
	var times: Array[float] = []
	var peak_nodes := 0
	var peak_draws := 0
	var peak_objects := 0
	var monitor_sum := {}
	var last := Time.get_ticks_usec()
	for frame in frames + WARMUP:
		if frame % REFILL_EVERY == 0 and not calm:
			for fighter in fighters:
				fighter.set_gauge(100.0)
				fighter.set_reiatsu(300.0)
		await process_frame
		var now := Time.get_ticks_usec()
		if frame >= WARMUP:
			times.append(float(now - last) / 1000.0)
			for key in MONITORS:
				monitor_sum[key] = float(monitor_sum.get(key, 0.0)) + float(Performance.get_monitor(MONITORS[key])) * 1000.0
			peak_nodes = maxi(peak_nodes, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			peak_draws = maxi(peak_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			peak_objects = maxi(peak_objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)))
		last = now
	times.sort()
	var total := 0.0
	for value in times:
		total += value
	var report := {
		"effects_level": level, "frames": times.size(), "chars": chars, "cpu_level": cpu,
		"mean_ms": snappedf(total / float(times.size()), 0.01),
		"p50_ms": snappedf(times[times.size() / 2], 0.01),
		"p95_ms": snappedf(times[int(float(times.size()) * 0.95)], 0.01),
		"p99_ms": snappedf(times[int(float(times.size()) * 0.99)], 0.01),
		"worst_ms": snappedf(times[times.size() - 1], 0.01),
		"peak_nodes": peak_nodes, "peak_draw_calls": peak_draws, "peak_objects": peak_objects,
		"calm": calm,
	}
	for key in monitor_sum:
		report[key] = snappedf(float(monitor_sum[key]) / float(times.size()), 0.01)
	print("PERF ", JSON.stringify(report))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	quit(0)
