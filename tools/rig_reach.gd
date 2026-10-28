extends SceneTree
## Developer tool: compares where each move's hitbox is with where the weapon tip is in the
## strike pose, for every rigged fighter. Prints one line per move. Use it to tune weapon
## lengths and arm poses (the hitbox data in the .tres stays the source of truth).
##   godot --headless --path . -s tools/rig_reach.gd

const CHARACTERS := [
	"res://resources/characters/swordsman.tres", "res://resources/characters/archer.tres",
	"res://resources/characters/noble.tres", "res://resources/characters/emperor.tres",
]
const SLOTS := {
	"ground_neutral": "attack_neutral", "ground_forward": "attack_forward",
	"ground_up": "attack_up", "ground_down": "attack_down",
	"air_neutral": "air_attack", "air_forward": "air_attack",
	"air_up": "air_up", "air_down": "air_down",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in CHARACTERS:
		var character: Resource = load(path)
		var body: Node2D = load("res://scripts/rig/rig_body.gd").new()
		body.setup(character, 1)
		root.add_child(body)
		print("== ", character.display_name)
		for slot: String in SLOTS:
			var move: Resource = character.moveset.get(slot)
			body.preview(StringName(SLOTS[slot]), 0.0, &"active")
			var tip: Vector2 = body.weapon_tip()
			var box := Rect2(move.hitbox_offset - move.hitbox_size * 0.5, move.hitbox_size)
			var gap := _distance_to_rect(tip, box)
			var far_edge := _far_edge_gap(tip, box, move.direction)
			print("REACH %s %s %.2f %.2f" % [character.resource_path.get_file().get_basename(), slot, tip.x, tip.y])
			print("%-15s tip (%5.1f, %6.1f)  hitbox x %5.1f..%5.1f y %6.1f..%6.1f  outside by %4.1f  short of far edge %5.1f" % [
				slot, tip.x, tip.y, box.position.x, box.end.x, box.position.y, box.end.y, gap, far_edge,
			])
		body.queue_free()
	quit(0)


static func _distance_to_rect(point: Vector2, box: Rect2) -> float:
	var dx := maxf(maxf(box.position.x - point.x, 0.0), point.x - box.end.x)
	var dy := maxf(maxf(box.position.y - point.y, 0.0), point.y - box.end.y)
	return Vector2(dx, dy).length()


## How far the tip stops short of the hitbox's far edge in the direction of the swing
## (positive: the hitbox reaches past the blade).
static func _far_edge_gap(tip: Vector2, box: Rect2, direction: StringName) -> float:
	match direction:
		&"up":
			return tip.y - box.position.y
		&"down":
			return box.end.y - tip.y
	return box.end.x - tip.x
