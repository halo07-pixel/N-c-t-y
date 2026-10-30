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
@export var specials: SpecialSet
## Replaces `specials` while Bankai is active.
@export var bankai_specials: SpecialSet
@export var ultimate: SpecialData
## Combat Gauge the fighter starts the match with (0..100).
@export var starting_gauge: float = 0.0
## The big text shown when transforming, e.g. "BANKAI: TENSA ZANGETSU".
@export var transform_title: String = "TRANSFORM"

@export_group("Placeholder look")
## "sword" or "bow": only changes how the placeholder weapon is drawn.
@export var weapon_style: StringName = &"sword"
@export var weapon_color: Color = Color(0.8, 0.85, 0.9)
@export var body_color: Color = Color(0.85, 0.85, 0.9)
@export var accent_color: Color = Color(0.9, 0.5, 0.15)

@export_group("Sprites")
## Folder (res://...) and file prefix of the sprite set, e.g. "res://assets/original/noble/" and
## "noble". When the files are missing the fighter is drawn with the placeholder body.
@export var sprite_dir: String = ""
@export var sprite_id: String = ""

@export_group("Effects")
@export var fx_profile: FxProfile

@export_group("Rig")
## Jointed code-drawn body. When set, BodyFactory draws this fighter with a RigBody.
@export var rig: CharacterRigData
