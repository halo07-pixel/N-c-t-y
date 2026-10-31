extends SceneTree
## Headless test runner.
## Run: godot --headless --path . -s tests/run_tests.gd
## (run `godot --headless --path . --import` once first on a fresh checkout)

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_game_settings.gd",
	"res://tests/test_input_bindings.gd",
	"res://tests/test_camera_framing.gd",
	"res://tests/test_stage.gd",
	"res://tests/test_fighter_movement.gd",
	"res://tests/test_knockback.gd",
	"res://tests/test_move_set.gd",
	"res://tests/test_match_manager.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_specials.gd",
	"res://tests/test_ai.gd",
	"res://tests/test_guard.gd",
	"res://tests/test_balance.gd",
	"res://tests/test_skills.gd",
	"res://tests/test_combos.gd",
	"res://tests/test_roster.gd",
	"res://tests/test_menus.gd",
	"res://tests/test_arcade.gd",
	"res://tests/test_sprites.gd",
	"res://tests/test_fx.gd",
	"res://tests/test_rig.gd",
]


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var total_failures := 0
	var total_assertions := 0
	var total_tests := 0

	for path in TEST_SCRIPTS:
		var suite: TestCase = load(path).new()
		suite.tree = self
		for method in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total_tests += 1
			var failures_before := suite.failures.size()
			await suite.call(method_name)
			var failed := suite.failures.size() - failures_before
			if failed == 0:
				print("PASS  %s::%s" % [path.get_file(), method_name])
			else:
				print("FAIL  %s::%s" % [path.get_file(), method_name])
				for index in range(failures_before, suite.failures.size()):
					print("      - %s" % suite.failures[index])
		total_failures += suite.failures.size()
		total_assertions += suite.assertion_count

	print("")
	print("%d tests, %d assertions, %d failures" % [total_tests, total_assertions, total_failures])
	quit(1 if total_failures > 0 else 0)
