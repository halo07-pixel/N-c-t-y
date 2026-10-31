class_name SpecialSet
extends Resource
## The four specials of a fighter, picked by the direction held with the
## special button: neutral, forward, up (usually the recovery) and down.

@export var neutral: SpecialData
@export var forward: SpecialData
@export var up: SpecialData
@export var down: SpecialData


@export_group("Special 2")
@export var alt_neutral: SpecialData
@export var alt_forward: SpecialData
@export var alt_up: SpecialData
@export var alt_down: SpecialData


func select_alt(direction: Vector2) -> SpecialData:
	match MoveSet.direction_kind(direction):
		&"up":
			return alt_up
		&"down":
			return alt_down
		&"forward":
			return alt_forward
	return alt_neutral


func select(direction: Vector2) -> SpecialData:
	match MoveSet.direction_kind(direction):
		&"up":
			return up
		&"down":
			return down
		&"forward":
			return forward
	return neutral
