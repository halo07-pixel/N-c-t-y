class_name BankaiTraits
extends RefCounted
## What each Bankai does to the match while it lasts, beyond its stronger skills. Called every
## frame from Fighter._tick_bankai while the form is on; the mechanic of the character picks it.
##  - petals (Senbonzakura): a ring of blades around Byakuya cuts anyone close and eats shots.
##  - frost (Hyōrinmaru-style ice floor): the ground turns slick for enemies standing on it.

const RING_RADIUS := 48.0
const RING_GAP := 24 # frames between ring cuts
const RING_DAMAGE := 1.6
const RING_KNOCKBACK := 80.0
const SLIPPERY_FRICTION := 0.25
const SLIPPERY_HOLD := 4 # frames the slickness lasts after an enemy leaves the field


static func tick(fighter: Fighter) -> void:
	match fighter.data.mechanic:
		&"petals":
			_petal_ring(fighter)
		&"frost":
			_ice_floor(fighter)


static func _enemies(fighter: Fighter) -> Array[Fighter]:
	var result: Array[Fighter] = []
	for node in fighter.get_tree().get_nodes_in_group(Fighter.FIGHTER_GROUP):
		var other := node as Fighter
		if other != null and other.player_id != fighter.player_id and not other.is_ko():
			result.append(other)
	return result


## Blades orbit the master: enemies inside take a small cut now and then, enemy shots die on them.
static func _petal_ring(fighter: Fighter) -> void:
	var center := fighter.global_position + Vector2(0.0, -14.0)
	for node in fighter.get_tree().get_nodes_in_group(Projectile.SHOT_GROUP):
		var shot := node as Projectile
		if shot != null and shot.owner_id != fighter.player_id and not shot.is_trap() and not shot.is_queued_for_deletion():
			if shot.position.distance_to(center) <= RING_RADIUS and not shot.can_pass_ring():
				shot.queue_free()
				Events.mechanic_triggered.emit(fighter.player_id, &"cut", shot.position)
	fighter.ring_cooldown = maxi(fighter.ring_cooldown - 1, 0)
	if fighter.ring_cooldown > 0:
		return
	for other in _enemies(fighter):
		if other.global_position.distance_to(center) > RING_RADIUS:
			continue
		var info := HitInfo.new()
		info.attacker_id = fighter.player_id
		info.damage = RING_DAMAGE
		info.base_knockback = RING_KNOCKBACK
		info.knockback_growth = 10.0
		info.direction = Vector2(signf(other.global_position.x - fighter.global_position.x), -0.4).normalized()
		other.hurtbox.receive_hit(info)
		fighter.ring_cooldown = RING_GAP
		Events.mechanic_triggered.emit(fighter.player_id, &"cut", other.global_position + Vector2(0.0, -16.0))


## The floor freezes: enemies on the ground keep their speed far longer (they slide).
static func _ice_floor(fighter: Fighter) -> void:
	for other in _enemies(fighter):
		if other.is_on_floor():
			other.slippery_frames = SLIPPERY_HOLD
