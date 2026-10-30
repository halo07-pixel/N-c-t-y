class_name FxBudget
extends RefCounted
## A cap on how many short-lived effect nodes (sparks, dust, streaks) exist at once, so a
## frantic match cannot flood the screen or the frame time. The cap follows the effects level.

const CAPS: Array[int] = [0, 10, 24, 40]

static var _live: int = 0


static func cap() -> int:
	return CAPS[clampi(GameSettings.effects_level, 0, CAPS.size() - 1)]


static func live() -> int:
	return _live


## Adds `effect` under `parent` when there is room; otherwise the effect is dropped (and freed).
static func spawn(parent: Node, effect: Node) -> bool:
	if _live >= cap():
		effect.queue_free()
		return false
	_live += 1
	effect.tree_exited.connect(_release, CONNECT_ONE_SHOT)
	parent.add_child(effect)
	return true


static func reset() -> void:
	_live = 0


static func _release() -> void:
	_live = maxi(_live - 1, 0)
