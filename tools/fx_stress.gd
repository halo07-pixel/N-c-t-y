extends SceneTree
## Developer tool: plays a CPU-vs-CPU versus match for a while at each effects level and
## reports the average frame time and the busiest moment (live effect nodes, total nodes).
## The effects level is the only thing that changes between runs, so the difference is the
## cost of the presentation. Needs a display (software GL is slow: read it as a ratio).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/fx_stress.gd -- [frames=900] [p1=0] [p2=2]
##
## Game classes are not named here (SceneTree scripts compile before the autoloads exist).

const MATCH_PATH := "res://scenes/match/versus_match.tscn"
const AI_PATH := "res://scripts/ai/ai_input.gd"
const LEVEL_NAMES := ["OFF", "LOW", "NORMAL", "HIGH"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var frames := 900
	var p1 := 0
	var p2 := 2
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("frames="):
			frames = int(arg.substr(7))
		elif arg.begins_with("p1="):
			p1 = int(arg.substr(3))
		elif arg.begins_with("p2="):
			p2 = int(arg.substr(3))
	var config := root.get_node("MatchConfig")
	config.p1_index = p1
	config.p2_index = p2
	for level in 4:
		var result := await _measure(level, frames)
		print("%-6s avg %.2f ms  worst %.1f ms  peak live fx %d  peak nodes %d" % [
			LEVEL_NAMES[level], result["avg"], result["worst"], result["fx"], result["nodes"]
		])
	quit()


func _measure(level: int, frames: int) -> Dictionary:
	var settings := root.get_node("GameSettings")
	settings.effects_level = level
	var match_scene: Node = (load(MATCH_PATH) as PackedScene).instantiate()
	root.add_child(match_scene)
	await physics_frame
	var ai_script: GDScript = load(AI_PATH)
	var fighters: Array = []
	for child in match_scene.get_children():
		if child.has_method("set_input_source"):
			fighters.append(child)
	for i in fighters.size():
		var brain: Object = ai_script.new()
		brain.bind(fighters[i], fighters[1 - i], 3, 100 + i)
		fighters[i].set_input_source(brain)
		fighters[i].set_gauge(100.0) # transform early: the heaviest presentation
		fighters[i].set_reiatsu(300.0)
	var total := 0.0
	var worst := 0.0
	var peak_fx := 0
	var peak_nodes := 0
	for i in frames:
		var start := Time.get_ticks_usec()
		await process_frame
		var spent := float(Time.get_ticks_usec() - start) / 1000.0
		total += spent
		worst = maxf(worst, spent)
		peak_fx = maxi(peak_fx, _live_fx())
		peak_nodes = maxi(peak_nodes, root.get_tree().get_node_count())
	match_scene.queue_free()
	await process_frame
	return {"avg": total / float(frames), "worst": worst, "fx": peak_fx, "nodes": peak_nodes}


func _live_fx() -> int:
	return int(ClassDB.class_exists("FxBudget")) * 0 + (load("res://scripts/fx/fx_budget.gd") as GDScript).call("live")
