class_name CharacterData
extends Resource
## Everything that makes one fighter feel different from another.
## Adding a character means adding a .tres of this resource, not new code.

@export var display_name: String = "Placeholder"

@export_group("Body")
@export var body_size: Vector2 = Vector2(14.0, 30.0)
@export var weight: float = 100.0

@export_group("Ground movement")
@export var run_speed: float = 130.0
@export var ground_accel: float = 900.0
@export var ground_friction: float = 1100.0

@export_group("Air movement")
@export var air_speed: float = 100.0
@export var air_accel: float = 500.0
@export var air_friction: float = 200.0
@export var gravity: float = 980.0
@export var max_fall_speed: float = 260.0
@export var fast_fall_speed: float = 420.0

@export_group("Jumps")
@export var jump_velocity: float = 330.0
@export var air_jump_velocity: float = 290.0
@export var max_air_jumps: int = 1

@export_group("Combat")
@export var moveset: MoveSet

@export_group("Placeholder look")
@export var body_color: Color = Color(0.85, 0.85, 0.9)
@export var accent_color: Color = Color(0.9, 0.5, 0.15)
