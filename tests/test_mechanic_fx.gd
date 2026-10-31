extends TestCase
## The look of the character mechanics: bursts, the standing aura and the effects level.

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")
const FIGHTER_SCENE: PackedScene = preload("res://scenes/fighter/fighter.tscn")

var _saved_level: int = 2


func _begin() -> void:
	_saved_level = GameSettings.effects_level
	GameSettings.effects_level = GameSettings.EffectsLevel.NORMAL
	FxBudget.reset()


func _end() -> void:
	GameSettings.effects_level = _saved_level
	FxBudget.reset()


func _fighter(character: String) -> Fighter:
	var fighter := FIGHTER_SCENE.instantiate() as Fighter
	fighter.player_id = 1
	fighter.data = load("res://resources/characters/%s.tres" % character)
	fighter.position = Vector2(0.0, 50.0)
	tree.root.add_child(fighter)
	return fighter


func test_each_mechanic_has_its_own_colors() -> void:
	var hollow := MechanicBurst.palette(&"hollow")
	var heartless := MechanicBurst.palette(&"heartless")
	var steal := MechanicBurst.palette(&"steal")
	check(hollow[0] != heartless[0] and heartless[0] != steal[0] and hollow[0] != steal[0], "three distinct looks")


func test_a_mechanic_event_spawns_a_burst_that_cleans_itself_up() -> void:
	_begin()
	var fx := CombatFx.new()
	tree.root.add_child(fx)
	Events.mechanic_triggered.emit(1, &"hollow", Vector2(10.0, 0.0))
	check_eq(fx.get_child_count(), 1, "a burst appears")
	check_eq(FxBudget.live(), 1, "and it counts against the effect budget")
	await wait_frames(50)
	check_eq(fx.get_child_count(), 0, "it removes itself")
	check_eq(FxBudget.live(), 0, "and gives the budget back")
	fx.free()
	_end()


func test_no_burst_with_effects_off() -> void:
	_begin()
	GameSettings.effects_level = 0
	var fx := CombatFx.new()
	tree.root.add_child(fx)
	Events.mechanic_triggered.emit(1, &"heartless", Vector2.ZERO)
	check_eq(fx.get_child_count(), 0, "effects off: nothing is drawn")
	fx.free()
	_end()


func test_the_steal_beam_ends_at_the_thief() -> void:
	_begin()
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var thief := _fighter("emperor")
	thief.global_position = Vector2(80.0, 50.0)
	var fx := CombatFx.new()
	tree.root.add_child(fx)
	Events.mechanic_triggered.emit(1, &"steal", Vector2.ZERO)
	var burst := fx.get_child(0) as MechanicBurst
	check(burst != null and burst.to_point.distance_to(Vector2(80.0, 34.0)) < 1.0, "the beam flies to Yhwach")
	fx.free()
	thief.free()
	stage.free()
	_end()


func test_hollow_aura_shows_only_while_charged() -> void:
	_begin()
	var fighter := _fighter("swordsman")
	var aura := _aura_of(fighter)
	await wait_frames(3)
	check(not aura.visible, "hidden by default")
	fighter.empowered = true
	await wait_frames(3)
	check(aura.visible, "the Hollow flames show while the boost is charged")
	fighter.empowered = false
	await wait_frames(3)
	check(not aura.visible, "and go out when it is used")
	fighter.free()
	_end()


func test_streak_and_petal_zone_show() -> void:
	_begin()
	var archer := _fighter("archer")
	var aura := _aura_of(archer)
	archer._on_projectile_hit(_hit())
	archer._on_projectile_hit(_hit())
	await wait_frames(3)
	check_eq(archer.arrow_streak(), 2, "two arrows in a row")
	check(aura.visible, "the Quincy crosses show over Uryu")
	archer.free()
	var noble := _fighter("noble")
	var zone := _aura_of(noble)
	var data := ProjectileData.new()
	data.commandable = true
	data.lifetime_frames = 300
	data.velocity = Vector2.ZERO
	data.size = Vector2(8.0, 8.0)
	var petal := Projectile.new()
	petal.launch(data, noble.data.moveset.ground_neutral, 1, 1, 1.0, noble.global_position + Vector2(20.0, -14.0))
	tree.root.add_child(petal)
	await wait_frames(5)
	check(MechanicAura.is_showing(noble), "next to his petals the zone counts as showing")
	check(zone.visible, "the petal ring is drawn")
	petal.free()
	noble.free()
	_end()


func _aura_of(fighter: Fighter) -> MechanicAura:
	for child in fighter.get_children():
		if child is MechanicAura:
			return child
	return null


func _hit() -> HitInfo:
	var info := HitInfo.new()
	info.damage = 5.0
	info.base_knockback = 200.0
	return info
