class_name MoveSet
extends Resource
## The eight attacks of a fighter: four on the ground, four in the air.
## The attack button plus the held direction picks one of them.

@export_group("Ground")
@export var ground_neutral: MoveData
@export var ground_forward: MoveData
@export var ground_up: MoveData
@export var ground_down: MoveData

@export_group("Air")
@export var air_neutral: MoveData
@export var air_forward: MoveData
@export var air_up: MoveData
@export var air_down: MoveData


## Which of the four directions the held input means.
static func direction_kind(direction: Vector2) -> StringName:
	if direction.y < -0.5:
		return &"up"
	if direction.y > 0.5:
		return &"down"
	if absf(direction.x) > 0.5:
		return &"forward"
	return &"neutral"


func select(aerial: bool, direction: Vector2) -> MoveData:
	var kind := direction_kind(direction)
	if aerial:
		match kind:
			&"up":
				return air_up
			&"down":
				return air_down
			&"forward":
				return air_forward
		return air_neutral
	match kind:
		&"up":
			return ground_up
		&"down":
			return ground_down
		&"forward":
			return ground_forward
	return ground_neutral
