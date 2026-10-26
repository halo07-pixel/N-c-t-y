class_name MenuNav
extends RefCounted
## Turns key events into menu actions: up, down, left, right, confirm, back.
## Both players' game keys work (attack confirms, guard goes back); with
## player_id 0 the standard UI keys (arrows, Enter, Esc) work too.

const DIRECTIONS: Array[StringName] = [&"up", &"down", &"left", &"right"]
const GAME_ACTION := {
	&"up": &"up", &"down": &"down", &"left": &"left", &"right": &"right",
	&"confirm": &"attack", &"back": &"guard",
}
const UI_ACTION := {
	&"up": &"ui_up", &"down": &"ui_down", &"left": &"ui_left", &"right": &"ui_right",
	&"confirm": &"ui_accept", &"back": &"ui_cancel",
}


## Returns the menu action for this event, or &"" when it is not one.
## `player_id` 0 means either player; 1 or 2 means only that player's keys.
static func read(event: InputEvent, player_id: int = 0) -> StringName:
	for action: StringName in GAME_ACTION:
		if _pressed(event, action, player_id):
			return action
	return &""


static func _pressed(event: InputEvent, action: StringName, player_id: int) -> bool:
	var repeats := DIRECTIONS.has(action)
	var players: Array[int] = [1, 2]
	if player_id != 0:
		players = [player_id]
	for id in players:
		var game_action := InputBindings.action_name(id, GAME_ACTION[action])
		if InputMap.has_action(game_action) and event.is_action_pressed(game_action, repeats):
			return true
	return player_id == 0 and event.is_action_pressed(UI_ACTION[action], repeats)
