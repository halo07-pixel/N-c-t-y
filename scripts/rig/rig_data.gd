class_name CharacterRigData
extends Resource
## How a fighter's jointed body looks: proportions, colors, hair, weapon and cape.
## Every fighter shares one skeleton and one pose library (RigPoses); only this
## data differs, so all characters move alike and are tuned in one place.
## Lengths are world units; the body stands about 34 units tall.

@export_group("Proportions")
@export var head_size: Vector2 = Vector2(11.0, 10.5)
@export var torso_size: Vector2 = Vector2(9.0, 9.0)
## Upper and lower arm length.
@export var arm_length: Vector2 = Vector2(4.6, 4.6)
@export var arm_width: float = 2.6
## Thigh and shin length.
@export var leg_length: Vector2 = Vector2(5.6, 5.6)
@export var leg_width: float = 3.3
@export var foot_size: Vector2 = Vector2(4.6, 2.0)

@export_group("Colors")
@export var skin: Color = Color(0.93, 0.78, 0.65)
@export var cloth: Color = Color(0.2, 0.18, 0.28)
@export var cloth_dark: Color = Color(0.14, 0.12, 0.2)
@export var accent: Color = Color(0.9, 0.75, 0.85)
@export var hair: Color = Color(0.1, 0.08, 0.12)
@export var outline: Color = Color(0.06, 0.05, 0.09)

@export_group("Hair")
## "spiky", "long", "short" or "none".
@export var hair_style: StringName = &"short"
## Length of the loose hair behind the head (0 for none), in two swinging segments.
@export var hair_tail: float = 0.0

@export_group("Weapon")
## "katana", "greatsword" or "bow".
@export var weapon: StringName = &"katana"
@export var weapon_length: float = 15.0
@export var weapon_width: float = 1.8
@export var weapon_color: Color = Color(0.9, 0.92, 0.97)
@export var grip_color: Color = Color(0.15, 0.12, 0.2)

@export_group("Cape")
## Length of the cape or scarf behind the shoulders (0 for none), in two segments.
@export var cape_length: float = 0.0
@export var cape_color: Color = Color(0.9, 0.9, 0.95)


## Standing height in world units (feet to top of the head).
func height() -> float:
	return leg_length.x + leg_length.y + torso_size.y + head_size.y
