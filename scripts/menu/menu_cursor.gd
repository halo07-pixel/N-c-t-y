class_name MenuCursor
extends RefCounted
## A selection index over a list of menu items. It wraps around and skips
## disabled items.

var count: int = 0
var index: int = 0
var disabled: Array[int] = []


func _init(item_count: int, disabled_items: Array[int] = []) -> void:
	count = item_count
	disabled = disabled_items
	if is_disabled(index):
		step(1)


func is_disabled(item: int) -> bool:
	return disabled.has(item)


## Moves one enabled item up (-1) or down (+1).
func step(direction: int) -> void:
	if count <= 0:
		return
	for _i in count:
		index = posmod(index + direction, count)
		if not is_disabled(index):
			return
