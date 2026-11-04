extends TestCase

const STAGE_SCENE: PackedScene = preload("res://scenes/stages/test_stage.tscn")


func test_backdrop_has_five_layers_that_trail_the_camera_by_depth() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var backdrop := stage.get_node("Backdrop") as StageBackdrop
	check_eq(backdrop.layers.size(), 5, "sky, stars, far, mid and near layers")
	backdrop.follow(Vector2(100.0, 0.0))
	var sky := backdrop.layers[0]
	var near := backdrop.layers[4]
	check_near(sky.position.x, 100.0, 0.01, "the sky stays locked to the screen")
	check_near(near.position.x, 20.0, 0.01, "the near layer almost moves with the world")
	check(backdrop.layers[2].position.x > backdrop.layers[3].position.x, "deeper layers trail further behind")
	stage.queue_free()


func test_stage_keeps_its_collision_and_drops_the_flat_polygons() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	for path in ["MainPlatform/Shape", "SoftLeft/Shape", "SoftRight/Shape", "SoftTop/Shape"]:
		check(stage.get_node_or_null(path) is CollisionShape2D, "%s still collides" % path)
	check(stage.get_node_or_null("Art") is StageArt, "platforms are drawn by the art node")
	stage.queue_free()


func test_atmosphere_follows_the_effects_setting() -> void:
	var stage := STAGE_SCENE.instantiate() as Stage
	tree.root.add_child(stage)
	var dust := stage.get_node("Dust") as StageAtmosphere
	var before: int = GameSettings.effects_level
	GameSettings.effects_level = GameSettings.EffectsLevel.OFF
	check_eq(dust.amount(), 0.0, "OFF has no dust or fireflies")
	GameSettings.effects_level = GameSettings.EffectsLevel.HIGH
	check(dust.amount() > 1.0, "HIGH has more of them")
	GameSettings.effects_level = before
	stage.queue_free()


func test_atmosphere_has_enough_particles_for_the_highest_effects_level() -> void:
	var atmosphere := StageAtmosphere.new()
	atmosphere.kind = StageAtmosphere.Kind.DUST
	tree.root.add_child(atmosphere)
	var wanted := int(round(StageAtmosphere.DUST_COUNT * minf(GameSettings.EFFECT_AMOUNT.max(), StageAtmosphere.MAX_AMOUNT)))
	check(atmosphere._seeds.size() >= wanted, "a seed for every dust mote at the highest level")
	atmosphere.free()
