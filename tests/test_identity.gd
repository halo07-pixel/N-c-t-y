extends TestCase
## Every fighter has something on the face or head that makes them recognisable at a glance.

const KEYS := ["swordsman", "archer", "noble", "lieutenant", "ice", "brute"]


func _markers(rig: CharacterRigData) -> PackedStringArray:
	var found := PackedStringArray()
	if rig.glasses:
		found.append("glasses")
	if rig.eyepatch:
		found.append("eyepatch")
	if rig.hair_bells:
		found.append("bells")
	if rig.brow_marks:
		found.append("brow tattoos")
	if rig.forelock:
		found.append("forelock")
	if rig.scowl:
		found.append("scowl")
	if rig.headwear != &"":
		found.append("headwear " + String(rig.headwear))
	return found


func test_every_fighter_has_a_face_or_head_marker() -> void:
	for key in KEYS:
		var data := load("res://resources/characters/%s.tres" % key) as CharacterData
		check(not _markers(data.rig).is_empty(), "%s has a signature on the face or head" % data.display_name)


func test_the_new_markers_belong_to_the_right_fighters() -> void:
	var renji := load("res://resources/characters/lieutenant.tres") as CharacterData
	check_eq(renji.rig.headwear, &"headband", "Renji's headband")
	check(renji.rig.brow_marks, "and his brow tattoos")
	var rukia := load("res://resources/characters/ice.tres") as CharacterData
	check(rukia.rig.forelock and rukia.rig.form_look.forelock, "Rukia's lock of hair, in both looks")
	var byakuya := load("res://resources/characters/noble.tres") as CharacterData
	check_eq(byakuya.rig.headwear, &"kenseikan", "Byakuya's kenseikan")
	var ichigo := load("res://resources/characters/swordsman.tres") as CharacterData
	check(ichigo.rig.scowl, "Ichigo's scowl")


func test_every_head_draws_without_errors_in_each_expression() -> void:
	for key in KEYS:
		var data := load("res://resources/characters/%s.tres" % key) as CharacterData
		var body := BodyFactory.create(data, 1)
		tree.root.add_child(body)
		for expression in [&"calm", &"fierce", &"hurt", &"ko", &"happy", &"sad"]:
			body._head.look = expression
			body._head.queue_redraw()
		await wait_frames(2)
		check(body._head.is_inside_tree(), "%s's head is alive" % data.display_name)
		body.free()


func test_every_fighter_changes_clothes_when_transformed() -> void:
	for key in KEYS:
		var data := load("res://resources/characters/%s.tres" % key) as CharacterData
		var look := data.rig.form_look
		check(look != null, "%s has a transformed look" % data.display_name)
		if look == null:
			continue
		check(look.form_look == null, "%s's form look does not nest another one" % data.display_name)
		var changed := look.cloth != data.rig.cloth or look.accent != data.rig.accent or look.weapon_color != data.rig.weapon_color
		check(changed, "%s's colours really change in the form" % data.display_name)
		var body := BodyFactory.create(data, 1)
		tree.root.add_child(body)
		body.set_bankai(true)
		check(body._look == look and body._head.rig == look and body._weapon.rig == look, "%s wears it from head to weapon" % data.display_name)
		body.set_bankai(false)
		check(body._look == data.rig and body._head.rig == data.rig, "%s is back to normal afterwards" % data.display_name)
		body.free()


func _interactive(skill: SpecialData) -> bool:
	return skill.is_chargeable() or skill.follow_up != null or skill.limit_active > 0 or skill.command_speed > 0.0 or skill.counter_move != null


func test_every_skill_of_the_redone_fighters_can_be_played_with() -> void:
	for key in ["lieutenant", "ice", "brute"]:
		var data := load("res://resources/characters/%s.tres" % key) as CharacterData
		for set: SpecialSet in [data.specials, data.bankai_specials]:
			for skill: SpecialData in [set.neutral, set.forward, set.up, set.down]:
				check(_interactive(skill), "%s: %s has a second press, a charge or a trap" % [data.display_name, skill.display_name])


func test_every_fighter_has_at_least_three_interactive_skills() -> void:
	for key in KEYS:
		var data := load("res://resources/characters/%s.tres" % key) as CharacterData
		var count := 0
		for skill: SpecialData in [data.specials.neutral, data.specials.forward, data.specials.up, data.specials.down]:
			if _interactive(skill):
				count += 1
		check(count >= 3, "%s has %d interactive skills" % [data.display_name, count])
