class_name BankaiField
extends Node2D
## The stage reacts while a Bankai is out: drifting motes in the fighter's color whose shape follows
## its mechanic (embers, snow, petals, sparks), plus a faint wash over the sky. It fades in and out.
## Purely visual; it only listens to Events.bankai_field_changed.

const COUNT := 40
const AREA := Rect2(-640.0, -260.0, 1280.0, 480.0)
const FADE_SECONDS := 0.6

var _fields: Dictionary = {} # player_id -> {kind, tint, level, active}
var _time: float = 0.0
var _seeds: Array[Vector4] = []


func _ready() -> void:
	z_index = -4
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in COUNT:
		_seeds.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.4, 1.0), rng.randf() * TAU))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	Events.bankai_field_changed.connect(_on_field_changed)


func _on_field_changed(player_id: int, kind: StringName, tint: Color, active: bool) -> void:
	var field: Dictionary = _fields.get(player_id, {"level": 0.0})
	field["kind"] = kind
	field["tint"] = tint
	field["active"] = active
	_fields[player_id] = field


## 0..1 how strongly a player's field shows.
func level_of(player_id: int) -> float:
	return float(_fields.get(player_id, {}).get("level", 0.0))


func is_showing() -> bool:
	for id: int in _fields:
		if float(_fields[id]["level"]) > 0.0:
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	var any := false
	for id: int in _fields:
		var field: Dictionary = _fields[id]
		var target := 1.0 if field["active"] else 0.0
		field["level"] = move_toward(float(field["level"]), target, delta / FADE_SECONDS)
		any = any or float(field["level"]) > 0.0
	visible = any and GameSettings.screen_effects
	if visible:
		queue_redraw()


func _draw() -> void:
	var amount := minf(GameSettings.effect_amount(), 1.5)
	for id: int in _fields:
		var field: Dictionary = _fields[id]
		var level := float(field["level"])
		if level <= 0.0:
			continue
		var tint: Color = field["tint"]
		draw_rect(AREA, Color(tint.r, tint.g, tint.b, 0.05 * level))
		var count := int(round(COUNT * amount * 0.5))
		for i in count:
			_draw_mote(StringName(field["kind"]), _seeds[(i + id * 7) % COUNT], tint, level)


func _draw_mote(kind: StringName, s: Vector4, tint: Color, level: float) -> void:
	var rise := -1.0
	var sway := 10.0
	match kind:
		&"frost":
			rise = 1.0 # snow falls
		&"petals":
			rise = 0.6
			sway = 26.0
		&"hollow", &"zeal", &"reach":
			rise = -1.6 # embers climb
		&"heartless":
			rise = 0.0
			sway = 6.0
	var x := AREA.position.x + s.x * AREA.size.x + sin(_time * 0.8 * s.z + s.w) * sway
	var y := AREA.position.y + fposmod(s.y * AREA.size.y + _time * 22.0 * s.z * rise, AREA.size.y)
	var color := Color(tint.r, tint.g, tint.b, (0.35 + 0.4 * s.z) * level)
	var at := Vector2(x, y)
	match kind:
		&"petals":
			draw_line(at, at + Vector2(3.0, 2.0).rotated(_time + s.w), color, 2.0)
		&"heartless":
			var pulse := 0.5 + 0.5 * sin(_time * 3.0 + s.w)
			draw_line(at - Vector2(3.0, 0.0), at + Vector2(3.0, 0.0), color * Color(1, 1, 1, pulse), 1.0)
			draw_line(at - Vector2(0.0, 3.0), at + Vector2(0.0, 3.0), color * Color(1, 1, 1, pulse), 1.0)
		&"frost":
			draw_circle(at, 1.0 + s.z, color)
		_:
			draw_circle(at, 0.8 + s.z * 0.8, color)
