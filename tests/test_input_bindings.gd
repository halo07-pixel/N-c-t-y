extends TestCase

const BINDINGS_SCRIPT := preload("res://scripts/autoload/input_bindings.gd")


func _first_key(action_id: StringName) -> Key:
	var events := InputMap.action_get_events(action_id)
	if events.is_empty():
		return KEY_NONE
	return (events[0] as InputEventKey).physical_keycode


func test_action_names_follow_player_prefix() -> void:
	check_eq(BINDINGS_SCRIPT.action_name(1, &"left"), &"p1_left", "player 1 action name")
	check_eq(BINDINGS_SCRIPT.action_name(2, &"charge"), &"p2_charge", "player 2 action name")


func test_every_action_is_registered_for_both_players() -> void:
	var bindings = BINDINGS_SCRIPT.new()
	bindings.apply_defaults()
	for player_id in [1, 2]:
		for action in BINDINGS_SCRIPT.ACTIONS:
			var action_id: StringName = BINDINGS_SCRIPT.action_name(player_id, action)
			check(InputMap.has_action(action_id), "%s exists" % action_id)
	bindings.free()


func test_player_two_uses_the_numpad_for_actions() -> void:
	var bindings = BINDINGS_SCRIPT.new()
	bindings.apply_defaults()
	check_eq(_first_key(&"p2_attack"), KEY_KP_1, "attack is numpad 1")
	check_eq(_first_key(&"p2_special"), KEY_KP_2, "special is numpad 2")
	check_eq(_first_key(&"p2_guard"), KEY_KP_3, "guard is numpad 3")
	check_eq(_first_key(&"p2_charge"), KEY_KP_5, "charge is numpad 5")
	check_eq(_first_key(&"p2_left"), KEY_LEFT, "move left is the left arrow")
	bindings.free()


func test_player_one_uses_wasd_and_jkli() -> void:
	var bindings = BINDINGS_SCRIPT.new()
	bindings.apply_defaults()
	check_eq(_first_key(&"p1_left"), KEY_A, "left is A")
	check_eq(_first_key(&"p1_up"), KEY_W, "up is W")
	check_eq(_first_key(&"p1_attack"), KEY_J, "attack is J")
	check_eq(_first_key(&"p1_charge"), KEY_I, "charge is I")
	bindings.free()


func test_no_key_is_shared_between_actions() -> void:
	var seen: Dictionary = {}
	var duplicates := 0
	for player_id: int in BINDINGS_SCRIPT.DEFAULT_KEYS:
		var keys: Dictionary = BINDINGS_SCRIPT.DEFAULT_KEYS[player_id]
		for action: StringName in keys:
			var keycode: int = keys[action]
			if seen.has(keycode):
				duplicates += 1
			seen[keycode] = true
	check_eq(duplicates, 0, "default keys are unique across both players")
