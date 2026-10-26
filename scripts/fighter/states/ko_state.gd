extends FighterState
## Knocked out of the blast zone and waiting for the match to respawn us.
## Does nothing on purpose; the fighter is hidden and inert.


func physics_update(_delta: float) -> StringName:
	fighter.velocity = Vector2.ZERO
	return &""
