class_name CombatFx
extends Node2D
## Spawns the combat effects in the world: hit sparks, speed lines and dust. It only listens
## to the Events bus. With GameSettings.screen_effects off it does nothing.


func _ready() -> void:
	Events.hit_impact.connect(_on_hit_impact)
	Events.dust_puff.connect(_on_dust_puff)
	Events.fighter_guarded.connect(_on_guarded)
	Events.fighter_dodged.connect(_on_dodged)
	Events.fighter_shunpo.connect(_on_shunpo)


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


func _on_guarded(_victim: int, _attacker: int, perfect: bool, spot: Vector2) -> void:
	if not GameSettings.screen_effects:
		return
	var spark := HitSpark.new()
	spark.position = spot
	spark.power = 0.9 if perfect else 0.25
	spark.color = Color(1.0, 0.9, 0.5) if perfect else Color(0.5, 0.8, 1.0)
	add_child(spark)


func _on_dodged(_victim: int, _attacker: int, spot: Vector2) -> void:
	if not GameSettings.screen_effects:
		return
	var spark := HitSpark.new()
	spark.position = spot
	spark.power = 0.7
	spark.color = Color(0.9, 0.95, 1.0)
	add_child(spark)


func _on_shunpo(_id: int, start: Vector2, direction: int) -> void:
	if not GameSettings.screen_effects:
		return
	var streak := ShunpoStreak.new()
	streak.from_point = start
	streak.to_point = start + Vector2(float(direction) * GuardRules.SHUNPO_DISTANCE, 0.0)
	add_child(streak)
	var puff := DustPuff.new()
	puff.position = start
	puff.strength = 0.8
	add_child(puff)
