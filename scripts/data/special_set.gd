class_name SpecialSet
extends Resource
## The four specials of a fighter, picked by the direction held with the
## special button: neutral, forward, up (usually the recovery) and down.

@export var neutral: SpecialData
@export var forward: SpecialData
@export var up: SpecialData
@export var down: SpecialData


func select(direction: Vector2) -> SpecialData:
	match MoveSet.direction_kind(direction):
		&"up":
			return up
		&"down":
			return down
		&"forward":
			return forward
	return neutral
