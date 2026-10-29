extends SceneTree
## Balance simulation: every character against every character (CPU vs CPU), several seeded
## matches per pairing, and a report of win rates and how fast the transform gauge fills.
##
## godot --headless --fixed-fps 60 --path . -s tools/balance_sim.gd -- out.json [matches=4] [level=3] [stocks=2]
##   [seconds=90] [chars=swordsman,archer,noble,emperor]
##
## It uses the real fighters, states, hits, guard and gauge; only the match rules are
## simplified (blast-zone KO, respawn after a short delay, most stocks wins, then lowest percent).

const STAGE_SCENE := "res://scenes/stages/test_stage.tscn"
const FIGHTER_SCENE := "res://scenes/fighter/fighter.tscn"
const CHAR_DIR := "res://resources/characters/%s.tres"
const RESPAWN_DELAY := 90
const GAUGE_MAX := 100.0 # CombatGauge.MAX; classes that touch autoloads cannot be named here
const AI_PATH := "res://scripts/ai/ai_input.gd"

var _stage: Node
var _fighters: Array = []
var _stocks: Dictionary = {}
var _respawn_in: Dictionary = {}
var _transforms: Dictionary = {}
var _guards: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "balance.json"
	var matches := 4
	var level := 3
	var stocks := 2
	var seconds := 90
	var names := ["swordsman", "archer", "noble", "emperor"]
	for arg in args:
		if arg.begins_with("matches="):
			matches = int(arg.substr(8))
		elif arg.begins_with("level="):
			level = int(arg.substr(6))
		elif arg.begins_with("stocks="):
			stocks = int(arg.substr(7))
		elif arg.begins_with("seconds="):
			seconds = int(arg.substr(8))
		elif arg.begins_with("chars="):
			names = arg.substr(6).split(",")
	root.get_node("GameSettings").screen_effects = false
	var events := root.get_node("Events")
	events.fighter_bankai_changed.connect(func(id: int, active: bool) -> void:
		if active:
			_transforms[id] = _transforms.get(id, 0) + 1)
	events.fighter_guarded.connect(func(victim: int, _a: int, _p: bool, _s: Vector2) -> void:
		_guards[victim] = _guards.get(victim, 0) + 1)

	var report := {"settings": {"matches": matches, "level": level, "stocks": stocks, "seconds": seconds}, "pairs": {}, "totals": {}}
	var totals := {}
	for name in names:
		totals[name] = {"wins": 0, "games": 0, "gauge_full_frames": [], "transforms": 0, "guards": 0, "ko_frames": []}
	for a in names:
		for b in names:
			if a == b:
				continue
			var wins_a := 0
			var wins_b := 0
			var ties := 0
			for m in matches:
				var result := await _play(a, b, level, stocks, seconds * 60, 1000 + m * 7 + names.find(a) * 131 + names.find(b) * 17)
				match result["winner"]:
					1:
						wins_a += 1
					2:
						wins_b += 1
					_:
						ties += 1
				_collect(totals, a, result, 1)
				_collect(totals, b, result, 2)
				if result["winner"] == 1:
					totals[a]["wins"] += 1
				elif result["winner"] == 2:
					totals[b]["wins"] += 1
			report["pairs"]["%s_vs_%s" % [a, b]] = {"a_wins": wins_a, "b_wins": wins_b, "ties": ties}
			print("%s vs %s: %d - %d (%d ties)" % [a, b, wins_a, wins_b, ties])
	for name in names:
		var t: Dictionary = totals[name]
		var full: Array = t["gauge_full_frames"]
		var avg_full := 0.0
		for f in full:
			avg_full += float(f)
		avg_full = avg_full / float(full.size()) / 60.0 if full.size() > 0 else -1.0
		report["totals"][name] = {
			"win_rate": float(t["wins"]) / float(maxi(t["games"], 1)),
			"games": t["games"],
			"avg_seconds_to_full_gauge": avg_full,
			"matches_reaching_full_gauge": full.size(),
			"transforms": t["transforms"],
			"guards": t["guards"],
		}
		print("%s: win rate %.0f%%, full gauge after %.1fs (%d/%d games), %d transforms, %d guards" % [name, report["totals"][name]["win_rate"] * 100.0, avg_full, full.size(), t["games"], t["transforms"], t["guards"]])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	quit(0)


func _collect(totals: Dictionary, name: String, result: Dictionary, id: int) -> void:
	var t: Dictionary = totals[name]
	t["games"] += 1
	t["transforms"] += result["transforms"].get(id, 0)
	t["guards"] += result["guards"].get(id, 0)
	if result["gauge_full"].has(id):
		t["gauge_full_frames"].append(result["gauge_full"][id])


func _play(a: String, b: String, level: int, stocks: int, max_frames: int, seed_value: int) -> Dictionary:
	_transforms.clear()
	_guards.clear()
	_stocks = {1: stocks, 2: stocks}
	_respawn_in = {}
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	root.add_child(_stage)
	_fighters.clear()
	for index in 2:
		var id := index + 1
		var fighter = (load(FIGHTER_SCENE) as PackedScene).instantiate()
		fighter.player_id = id
		fighter.data = load(CHAR_DIR % (a if id == 1 else b))
		fighter.position = _stage.get_spawn_position(id)
		fighter.facing = 1 if id == 1 else -1
		fighter.projectile_spawned.connect(func(p: Node) -> void: root.add_child(p))
		root.add_child(fighter)
		_fighters.append(fighter)
	for index in 2:
		var brain = load(AI_PATH).new()
		brain.bind(_fighters[index], _fighters[1 - index], level, seed_value + index * 31)
		_fighters[index].set_input_source(brain)
	var gauge_full := {}
	var frame := 0
	var winner := 0
	while frame < max_frames:
		await physics_frame
		frame += 1
		for index in 2:
			var fighter = _fighters[index]
			var id := index + 1
			if not gauge_full.has(id) and (fighter.gauge >= GAUGE_MAX or fighter.is_bankai()):
				gauge_full[id] = frame
			if _respawn_in.has(id):
				_respawn_in[id] -= 1
				if _respawn_in[id] <= 0:
					_respawn_in.erase(id)
					fighter.respawn_at(_stage.get_respawn_position(id))
				continue
			if fighter.is_ko() or _stage.is_inside_blast_zone(fighter.global_position):
				continue
			fighter.enter_ko()
			_stocks[id] -= 1
			if _stocks[id] <= 0:
				winner = 2 if id == 1 else 1
			else:
				_respawn_in[id] = RESPAWN_DELAY
		if winner != 0:
			break
	if winner == 0:
		if _stocks[1] != _stocks[2]:
			winner = 1 if _stocks[1] > _stocks[2] else 2
		elif not is_equal_approx(_fighters[0].percent, _fighters[1].percent):
			winner = 1 if _fighters[0].percent < _fighters[1].percent else 2
	var result := {"winner": winner, "frames": frame, "gauge_full": gauge_full, "transforms": _transforms.duplicate(), "guards": _guards.duplicate()}
	for node in root.get_children():
		if node.has_method("launch"):
			node.free()
	for fighter in _fighters:
		fighter.free()
	_stage.free()
	return result
