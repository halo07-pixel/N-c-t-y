class_name RosterGrid
extends RefCounted
## The layout and cursor movement of the select screen's grid: every roster character in order,
## then one Random slot at the end. Pure logic, no drawing, so it can be tested on its own.

var character_count: int
var columns: int


func _init(characters: int) -> void:
	character_count = characters
	columns = columns_for(characters + 1)


## Slots a grid needs for `slots` cells: wider than tall, like a fighting game roster.
static func columns_for(slots: int) -> int:
	return clampi(ceili(sqrt(float(slots) * 2.0)), 1, 6)


func slot_count() -> int:
	return character_count + 1


func random_slot() -> int:
	return character_count


func is_random_slot(slot: int) -> bool:
	return slot == character_count


func rows() -> int:
	return ceili(float(slot_count()) / float(columns))


func cell(slot: int) -> Vector2i:
	return Vector2i(slot % columns, slot / columns)


func slot_at(column: int, row: int) -> int:
	var slot := row * columns + column
	return slot if column >= 0 and column < columns and row >= 0 and slot < slot_count() else -1


## How many cells row `row` has (the last row may be short).
func row_length(row: int) -> int:
	return mini(columns, slot_count() - row * columns)


## The slot reached by moving one step (`direction` is -1/0/1 on each axis) from `slot`. Moving
## sideways wraps inside the row, moving vertically wraps inside the column and skips the empty
## cells of a short last row.
func move(slot: int, direction: Vector2i) -> int:
	var at := cell(slot)
	if direction.x != 0:
		var length := row_length(at.y)
		return slot_at(posmod(at.x + direction.x, length), at.y)
	if direction.y != 0:
		var row := at.y
		for _step in rows():
			row = posmod(row + direction.y, rows())
			var found := slot_at(at.x, row)
			if found != -1:
				return found
	return slot
