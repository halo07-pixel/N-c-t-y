class_name CombatFx
extends Node2D
## Spawns the combat effects in the world: hit sparks, speed lines and dust. It only listens
## to the Events bus. With GameSettings.screen_effects off it does nothing.


func _ready() -> void:
	Events.hit_impact.connect(_on_hit_impact)
	Events.dust_puff.connect(_on_dust_puff)


func _on_hit_impact(
	hit_position: Vector2, direction: Vector2, damage: float, launch_speed: float, attacker_id: int
) -> void:
	if not GameSettings.screen_effects:
		return
	var spark := HitSpark.new()
	spark.position = hit_position
	spark.direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	spark.power = HitSpark.power_for(damage, launch_speed)
	spark.color = MatchHud.PLAYER_COLORS.get(attacker_id, Color.WHITE).lerp(Color.WHITE, 0.5)
	add_child(spark)


func _on_dust_puff(puff_position: Vector2, strength: float) -> void:
	if not GameSettings.screen_effects:
		return
	var puff := DustPuff.new()
	puff.position = puff_position
	puff.strength = strength
	add_child(puff)
