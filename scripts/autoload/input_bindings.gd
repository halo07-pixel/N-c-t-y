extends Node
## Registers the keyboard actions of both players in the InputMap.
## Action names look like "p1_left" or "p2_attack". Keys are physical keycodes,
## so the layout does not depend on the keyboard language.

const ACTIONS: Array[StringName] = [
	&"left", &"right", &"up", &"down", &"attack", &"special", &"guard", &"charge",
]

const DEFAULT_KEYS := {
	1: {
		&"left": KEY_A,
		&"right": KEY_D,
		&"up": KEY_W,
		&"down": KEY_S,
		&"attack": KEY_J,
		&"special": KEY_K,
		&"guard": KEY_L,
		&"charge": KEY_I,
	},
	2: {
		&"left": KEY_LEFT,
		&"right": KEY_RIGHT,
		&"up": KEY_UP,
		&"down": KEY_DOWN,
		&"attack": KEY_KP_1,
		&"special": KEY_KP_2,
		&"guard": KEY_KP_3,
		&"charge": KEY_KP_5,
	},
}


static func action_name(player_id: int, action: StringName) -> StringName:
	return StringName("p%d_%s" % [player_id, action])


func _ready() -> void:
	apply_defaults()


func apply_defaults() -> void:
	for player_id: int in DEFAULT_KEYS:
		var keys: Dictionary = DEFAULT_KEYS[player_id]
		for action: StringName in ACTIONS:
			bind_key(player_id, action, keys[action])


func bind_key(player_id: int, action: StringName, keycode: Key) -> void:
	var action_id := action_name(player_id, action)
	if InputMap.has_action(action_id):
		InputMap.action_erase_events(action_id)
	else:
		InputMap.add_action(action_id)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_id, event)
