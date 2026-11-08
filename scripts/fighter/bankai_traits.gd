class_name BankaiTraits
extends RefCounted
## What each Bankai does to the match while it lasts, beyond its stronger skills. Called every
## frame from Fighter._tick_bankai while the form is on; the mechanic of the character picks it.
##  - petals (Senbonzakura): a ring of blades around Byakuya cuts anyone close and eats shots.
##  - hollow (Getsuga charge): every hit landed in the form charges the next shot; at GETSUGA_MIN
##    stacks the next projectile skill is bigger and hits harder, and spends the charge.
##  - heartless (blade lattice): enemies standing between two of Uryu's planted blades are shocked.
##  - frost (Hyōrinmaru-style ice floor): the ground turns slick for enemies standing on it.

const RING_RADIUS := 48.0
const RING_GAP := 24 # frames between ring cuts
const RING_DAMAGE := 1.6
const RING_KNOCKBACK := 80.0
const SLIPPERY_FRICTION := 0.25
const SLIPPERY_HOLD := 4 # frames the slickness lasts after an enemy leaves the field
const GETSUGA_MAX := 5
const GETSUGA_MIN := 3
const GETSUGA_STEP := 0.12 # damage and size per stack on the shot it powers
const LATTICE_MAX_GAP := 220.0
const LATTICE_HEIGHT := 70.0
const LATTICE_DAMAGE := 2.2
const LATTICE_GAP := 30


static func tick(fighter: Fighter) -> void:
	match fighter.data.mechanic:
		&"petals":
			_petal_ring(fighter)
		&"frost":
			_ice_floor(fighter)
		&"heartless":
			_blade_lattice(fighter)


## A hit landed in the form: Ichigo's next Getsuga grows.
static func on_hit_landed(fighter: Fighter) -> void:
	if fighter.data.mechanic != &"hollow":
		return
	fighter.getsuga_stacks = mini(fighter.getsuga_stacks + 1, GETSUGA_MAX)
	if fighter.getsuga_stacks == GETSUGA_MIN:
		Events.mechanic_triggered.emit(fighter.player_id, &"hollow", fighter.global_position + Vector2(0.0, -30.0))


## A skill that throws projectiles spends the charge (when there is enough) to power them.
static func on_special_used(fighter: Fighter, special: SpecialData) -> void:
	fighter.getsuga_boost = 1.0
	if fighter.data.mechanic != &"hollow" or not fighter.is_bankai() or special.projectiles.is_empty():
		return
	if fighter.getsuga_stacks >= GETSUGA_MIN:
		fighter.getsuga_boost = 1.0 + GETSUGA_STEP * float(fighter.getsuga_stacks)
		fighter.getsuga_stacks = 0
		Events.mechanic_triggered.emit(fighter.player_id, &"hollow", fighter.global_position + Vector2(float(fighter.facing) * 20.0, -16.0))


## Pairs of neighbouring planted blades close enough to be joined by lightning: [left, right] global points.
static func lattice_pairs(fighter: Fighter) -> Array:
	var blades: Array[Vector2] = []
	for node in fighter.get_tree().get_nodes_in_group(Projectile.SHOT_GROUP):
		var blade := node as Projectile
		if blade != null and blade.owner_id == fighter.player_id and blade.is_planted_blade() and not blade.is_queued_for_deletion():
			blades.append(blade.position)
	blades.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var pairs := []
	for i in range(blades.size() - 1):
		if blades[i + 1].x - blades[i].x <= LATTICE_MAX_GAP:
			pairs.append([blades[i], blades[i + 1]])
	return pairs


static func _blade_lattice(fighter: Fighter) -> void:
	fighter.trait_cooldown = maxi(fighter.trait_cooldown - 1, 0)
	if fighter.trait_cooldown > 0:
		return
	var pairs := lattice_pairs(fighter)
	if pairs.is_empty():
		return
	for other in _enemies(fighter):
		var body := other.global_position + Vector2(0.0, -14.0)
		for pair in pairs:
			var a: Vector2 = pair[0]
			var b: Vector2 = pair[1]
			var floor_y := maxf(a.y, b.y)
			if body.x > a.x and body.x < b.x and body.y < floor_y + 6.0 and body.y > floor_y - LATTICE_HEIGHT:
				var info := HitInfo.new()
				info.attacker_id = fighter.player_id
				info.damage = LATTICE_DAMAGE
				info.base_knockback = 60.0
				info.knockback_growth = 10.0
				info.direction = Vector2(0.0, -1.0)
				other.hurtbox.receive_hit(info)
				fighter.trait_cooldown = LATTICE_GAP
				Events.mechanic_triggered.emit(fighter.player_id, &"heartless", body)
				break


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
	fighter.trait_cooldown = maxi(fighter.trait_cooldown - 1, 0)
	if fighter.trait_cooldown > 0:
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
		fighter.trait_cooldown = RING_GAP
		Events.mechanic_triggered.emit(fighter.player_id, &"cut", other.global_position + Vector2(0.0, -16.0))


## The floor freezes: enemies on the ground keep their speed far longer (they slide).
static func _ice_floor(fighter: Fighter) -> void:
	for other in _enemies(fighter):
		if other.is_on_floor():
			other.slippery_frames = SLIPPERY_HOLD
