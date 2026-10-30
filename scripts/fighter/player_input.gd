class_name PlayerInput
extends InputSource
## Reads the keyboard actions registered by the InputBindings autoload.

@export var player_id: int = 1


func get_frame() -> InputFrame:
	var frame := InputFrame.new()
	frame.move = Vector2(
		Input.get_axis(_action(&"left"), _action(&"right")),
		Input.get_axis(_action(&"up"), _action(&"down"))
	)
	frame.up_just_pressed = Input.is_action_just_pressed(_action(&"up"))
	frame.down_just_pressed = Input.is_action_just_pressed(_action(&"down"))
	frame.down_held = Input.is_action_pressed(_action(&"down"))
	frame.attack_just_pressed = Input.is_action_just_pressed(_action(&"attack"))
	frame.special_just_pressed = Input.is_action_just_pressed(_action(&"special"))
	frame.special_held = Input.is_action_pressed(_action(&"special"))
	frame.guard_just_pressed = Input.is_action_just_pressed(_action(&"guard"))
	frame.guard_held = Input.is_action_pressed(_action(&"guard"))
	frame.charge_held = Input.is_action_pressed(_action(&"charge"))
	frame.charge_just_pressed = Input.is_action_just_pressed(_action(&"charge"))
	return frame


func _action(action: StringName) -> StringName:
	return InputBindings.action_name(player_id, action)
