class_name RenderScale
extends RefCounted
## The screen is drawn at 1.5x the resolution the game world is simulated in
## (720x405 pixels for a 480x270-unit view). One world unit is therefore 1.5
## screen pixels, which lets 1:1 pixel-art sprites sit on a world whose physics
## and data never had to change.

const FACTOR := 1.5


## Scale for anything laid out in the 480x270 menu and HUD space.
static func ui() -> Vector2:
	return Vector2(FACTOR, FACTOR)


## Scale that makes a sprite pixel one screen pixel at the camera's base zoom.
static func sprite() -> float:
	return 1.0 / FACTOR
