class_name Stage
extends Node2D
## A fighting stage: platforms, spawn points and the blast zone that decides
## when a fighter has been knocked out.

## Leaving this rectangle (in stage space) costs a stock.
@export var blast_zone: Rect2 = Rect2(-380.0, -260.0, 760.0, 520.0)
## The camera may not show anything outside this rectangle.
@export var camera_bounds: Rect2 = Rect2(-420.0, -300.0, 840.0, 600.0)


func get_spawn_position(player_id: int) -> Vector2:
	var marker := get_node_or_null("Spawns/P%d" % player_id) as Marker2D
	if marker == null:
		push_warning("Stage has no spawn point for player %d" % player_id)
		return global_position
	return marker.global_position


func is_inside_blast_zone(point: Vector2) -> bool:
	return blast_zone.has_point(to_local(point))
