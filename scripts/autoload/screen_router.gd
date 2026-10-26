extends Node
## Changes screens when someone emits Events.screen_requested. Menus and matches
## never load each other's scenes; they only announce where they want to go.

const SCREENS := {
	&"title": "res://scenes/ui/title_screen.tscn",
	&"main_menu": "res://scenes/ui/main_menu.tscn",
	&"character_select": "res://scenes/ui/character_select.tscn",
	&"settings": "res://scenes/ui/settings_menu.tscn",
	&"arcade_story": "res://scenes/ui/arcade_story.tscn",
	&"arcade_continue": "res://scenes/ui/arcade_continue.tscn",
	&"arcade_clear": "res://scenes/ui/arcade_clear.tscn",
	&"versus_match": "res://scenes/match/versus_match.tscn",
}

## Tests switch this off so emitting a request does not replace the test scene.
var enabled: bool = true


func _ready() -> void:
	Events.screen_requested.connect(_on_screen_requested)


static func path_for(screen: StringName) -> String:
	return SCREENS.get(screen, "")


func _on_screen_requested(screen: StringName) -> void:
	var path := path_for(screen)
	if not enabled or path == "":
		return
	get_tree().change_scene_to_file.call_deferred(path)
