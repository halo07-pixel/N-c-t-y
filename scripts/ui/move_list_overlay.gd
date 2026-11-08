class_name MoveListOverlay
extends CanvasLayer
## The move list of both fighters, shown with F3 during a match: every attack with its button,
## the specials with their cooldowns, throw, parry, dash, form and ultimate. It reads the characters'
## data only, so it is always in step with the game.

const FONT_SIZE := 8
const TITLE_SIZE := 12
const LINE_HEIGHT := 9.0
const SCREEN := Vector2(480.0, 270.0)
const COLUMN_WIDTH := 232.0
const PAGE_NAMES := ["KỸ NĂNG (Skill)", "ĐÒN THƯỜNG & CƠ BẢN", "DẠNG BANKAI"]

const GOLD := Color(1.0, 0.85, 0.4)
const TEXT := Color(0.93, 0.95, 1.0)
const DIM := Color(0.68, 0.72, 0.86)
const ROLE_COLORS := {
	"zone": Color(0.45, 0.85, 1.0), "rush": Color(1.0, 0.6, 0.3), "combo": Color(1.0, 0.9, 0.4),
	"heavy": Color(1.0, 0.4, 0.4), "defend": Color(0.5, 0.95, 0.6), "area": Color(0.8, 0.6, 1.0),
	"recover": Color(0.8, 0.85, 1.0),
}
const ROLE_MEANING := "ZONE tầm xa · RUSH áp sát · COMBO nối đòn · HEAVY nặng · DEFEND phòng thủ · AREA khống chế · RECOVER về sân"

var _canvas: Control
## Per fighter, the pages of the list: arrays of entries (dictionaries with a "kind").
var _characters: Array = []
var _page: int = 0


func _ready() -> void:
	layer = 110 # above the debug overlay
	scale = RenderScale.ui()
	visible = false
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F3:
		toggle()
	elif visible and key_event.keycode == KEY_RIGHT:
		show_page(_page + 1)
	elif visible and key_event.keycode == KEY_LEFT:
		show_page(_page - 1)


func toggle() -> void:
	visible = not visible
	if visible:
		_page = 0
		_characters.clear()
		for player_id in [1, 2]:
			var character := MatchConfig.character_for(player_id)
			if character != null:
				_characters.append({"character": character, "pages": pages_for(character, player_id)})
	_canvas.queue_redraw()


func show_page(page: int) -> void:
	_page = posmod(page, PAGE_NAMES.size())
	_canvas.queue_redraw()


func current_page() -> int:
	return _page


func _on_draw() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), Color(0.03, 0.02, 0.08, 0.97))
	var font := UiFont.get_font()
	_canvas.draw_string(font, Vector2(8.0, 11.0), "F3  ·  %s  (%d/%d)" % [PAGE_NAMES[_page], _page + 1, PAGE_NAMES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, GOLD)
	for index in _characters.size():
		var x := 8.0 + float(index) * (SCREEN.x * 0.5)
		var character: CharacterData = _characters[index]["character"]
		var pages: Array = _characters[index]["pages"]
		_draw_column(font, x, character, pages[_page])
	_canvas.draw_line(Vector2(SCREEN.x * 0.5, 16.0), Vector2(SCREEN.x * 0.5, SCREEN.y - 14.0), Color(1.0, 1.0, 1.0, 0.12), 1.0)
	if _page == 0:
		_canvas.draw_multiline_string(font, Vector2(8.0, SCREEN.y - 15.0), ROLE_MEANING, HORIZONTAL_ALIGNMENT_LEFT, SCREEN.x - 16.0, FONT_SIZE - 1, -1, DIM)
	_canvas.draw_string(font, Vector2(8.0, SCREEN.y - 5.0), "← → đổi trang   ·   F3 đóng", HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, DIM)


func _draw_column(font: Font, x: float, character: CharacterData, entries: Array) -> void:
	var tone := character.fx_profile.primary if character.fx_profile != null else GOLD
	var y := 28.0
	for entry: Dictionary in entries:
		match entry["kind"]:
			"title":
				_canvas.draw_rect(Rect2(x - 3.0, y - 10.0, 2.0, 12.0), tone)
				_canvas.draw_string(font, Vector2(x + 2.0, y), entry["text"], HORIZONTAL_ALIGNMENT_LEFT, COLUMN_WIDTH, TITLE_SIZE, tone.lightened(0.35))
				y += 12.0
			"head":
				y += 3.0
				_canvas.draw_string(font, Vector2(x, y), entry["text"], HORIZONTAL_ALIGNMENT_LEFT, COLUMN_WIDTH, FONT_SIZE, GOLD)
				_canvas.draw_line(Vector2(x, y + 2.0), Vector2(x + COLUMN_WIDTH, y + 2.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 1.0)
				y += LINE_HEIGHT + 1.0
			"skill":
				y = _draw_skill(font, x, y, entry)
			"row":
				var label: String = entry["label"]
				_canvas.draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, 62.0, FONT_SIZE, GOLD)
				y = _draw_wrapped(font, x + 64.0, y, entry["text"], COLUMN_WIDTH - 64.0, TEXT)
			"note":
				y = _draw_wrapped(font, x, y, entry["text"], COLUMN_WIDTH, DIM)


## A skill: key chip, name, cooldown and role tag on one line, its explanation under it.
func _draw_skill(font: Font, x: float, y: float, entry: Dictionary) -> float:
	var indent := 8.0 if entry["sub"] else 0.0
	var key: String = entry["key"]
	var chip_width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x + 6.0
	var role: String = entry["role"]
	var tint: Color = ROLE_COLORS.get(role, DIM)
	_canvas.draw_rect(Rect2(x + indent, y - 8.0, chip_width, 10.0), Color(tint.r, tint.g, tint.b, 0.22))
	_canvas.draw_string(font, Vector2(x + indent + 3.0, y), key, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, tint)
	var name_x := x + indent + chip_width + 4.0
	_canvas.draw_string(font, Vector2(name_x, y), entry["name"], HORIZONTAL_ALIGNMENT_LEFT, COLUMN_WIDTH - (name_x - x) - 52.0, FONT_SIZE, TEXT)
	var tag: String = entry["tag"]
	if tag != "":
		_canvas.draw_string(font, Vector2(x + COLUMN_WIDTH - 50.0, y), tag, HORIZONTAL_ALIGNMENT_RIGHT, 50.0, FONT_SIZE, tint)
	y += LINE_HEIGHT
	return _draw_wrapped(font, x + indent + 4.0, y, entry["text"], COLUMN_WIDTH - indent - 4.0, DIM) + 1.0


## Wrapped text starting at baseline `y`; returns the baseline of the next line.
func _draw_wrapped(font: Font, x: float, y: float, text: String, width: float, color: Color) -> float:
	var size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE)
	_canvas.draw_multiline_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, -1, color)
	return y + maxf(size.y, LINE_HEIGHT)


static func _key(player_id: int, action: StringName) -> String:
	return MatchHud.skill_key_label(player_id, action)


static func _seconds(frames: int) -> String:
	return "%.1fs" % (float(frames) / 60.0)


static func _skill_entry(key: String, skill: SpecialData, sub: bool) -> Dictionary:
	var tag := ""
	if skill.role != "":
		tag = "[%s]" % skill.role.to_upper()
	var name := skill.display_name
	if skill.cooldown_frames > 0:
		name += "  " + _seconds(skill.cooldown_frames)
	return {"kind": "skill", "key": key, "name": name, "tag": tag, "role": skill.role, "sub": sub, "text": SkillGuide.text_for(skill)}


## One slot of the skill list: the skill, then what its second press does.
static func _slot_entries(key: String, skill: SpecialData) -> Array:
	var entries: Array = []
	if skill == null:
		return entries
	entries.append(_skill_entry(key, skill, false))
	var follow := skill.follow_up
	if follow != null:
		var again := _skill_entry("+ lần 2", follow, true)
		again["text"] = ("(%s) " % SkillGuide.trigger_for(skill)) + again["text"]
		entries.append(again)
		if follow.follow_up != null:
			var third := _skill_entry("+ lần 3", follow.follow_up, true)
			third["text"] = ("(%s) " % SkillGuide.trigger_for(follow)) + third["text"]
			entries.append(third)
	if skill.counter_move != null:
		var strike := _skill_entry("trả đòn", skill.counter_move, true)
		strike["name"] = skill.counter_move.display_name + " (chém trả)"
		strike["text"] = "%d sát thương, hất văng đối thủ." % int(round(skill.counter_move.damage))
		entries.append(strike)
	return entries


## The two pages of a character's list: the skills, then the basics. Each page is a list of entries.
static func pages_for(character: CharacterData, player_id: int) -> Array:
	var attack := _key(player_id, &"attack")
	var special := _key(player_id, &"special")
	var guard := _key(player_id, &"guard")
	var charge := _key(player_id, &"charge")
	var moves := character.moveset
	var kit := character.specials
	var skills: Array = [{"kind": "title", "text": character.display_name.to_upper()}]
	skills.append_array(_slot_entries(special, kit.neutral))
	skills.append_array(_slot_entries("%s + Tiến" % special, kit.forward))
	skills.append_array(_slot_entries("%s + Lên" % special, kit.up))
	skills.append_array(_slot_entries("%s + Xuống" % special, kit.down))

	var jab := moves.ground_neutral
	var second := jab.next_in_chain
	var basics: Array = [{"kind": "title", "text": character.display_name.to_upper()}]
	basics.append({"kind": "head", "text": "ĐÒN THƯỜNG"})
	basics.append({"kind": "row", "label": attack, "text": "%s > %s > %s" % [jab.display_name, second.display_name, second.next_in_chain.display_name]})
	basics.append({"kind": "row", "label": "Đòn 2 +", "text": "Lên: %s · Xuống: %s" % [second.chain_up.display_name, second.chain_down.display_name]})
	basics.append({"kind": "row", "label": "%s + hướng" % attack, "text": "Tiến: %s · Lên: %s · Xuống: %s" % [moves.ground_forward.display_name, moves.ground_up.display_name, moves.ground_down.display_name]})
	basics.append({"kind": "row", "label": "Trên không", "text": "%s / %s / %s / %s" % [moves.air_neutral.display_name, moves.air_forward.display_name, moves.air_up.display_name, moves.air_down.display_name]})
	basics.append({"kind": "head", "text": "CƠ BẢN"})
	basics.append({"kind": "row", "label": "%s + %s" % [guard, attack], "text": "Ném khi sát đối thủ: %s (hồi 2s)" % moves.throw_move.display_name})
	basics.append({"kind": "row", "label": guard, "text": "Đỡ đòn (nhận 20% sát thương). Bấm ngay trước khi trúng đòn = PARRY."})
	basics.append({"kind": "row", "label": "2× hướng", "text": "Lướt (+ %s = đòn lướt)" % attack})
	basics.append({"kind": "row", "label": "Hủy đòn", "text": "Đòn trúng xong bấm %s trong 12 frame = hủy sang skill tầm xa/áp sát. %s giữa đòn = Gauge Cancel (40)." % [special, charge]})
	basics.append({"kind": "head", "text": "BIẾN HÌNH & ULTIMATE"})
	var ultimate := character.ultimate.display_name if character.ultimate != null else "-"
	basics.append({"kind": "row", "label": charge, "text": "Biến hình: %s (khi đầy Gauge)" % character.transform_title})
	basics.append({"kind": "row", "label": "Ultimate", "text": "%s (đang biến hình + đủ Reiatsu, bấm %s)" % [ultimate, charge]})
	return [skills, basics, _bankai_page(character, player_id)]


## The skills of the transformed form: the same slots, stronger, some changed.
static func _bankai_page(character: CharacterData, player_id: int) -> Array:
	var special := _key(player_id, &"special")
	var kit := character.bankai_specials
	var page: Array = [{"kind": "title", "text": "%s · %s" % [character.display_name.to_upper(), character.transform_title]}]
	if kit == null:
		page.append({"kind": "note", "text": "Dạng này dùng lại bộ skill thường."})
		return page
	page.append_array(_slot_entries(special, kit.neutral))
	page.append_array(_slot_entries("%s + Tiến" % special, kit.forward))
	page.append_array(_slot_entries("%s + Lên" % special, kit.up))
	page.append_array(_slot_entries("%s + Xuống" % special, kit.down))
	return page


## Every text of a character's list, one per line; the first is the name. Used by tests and logs.
static func lines_for(character: CharacterData, player_id: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for page: Array in pages_for(character, player_id):
		for entry: Dictionary in page:
			match entry["kind"]:
				"skill":
					lines.append("%s  %s  %s  %s" % [entry["key"], entry["name"], entry["tag"], entry["text"]])
				"row":
					lines.append("%s  %s" % [entry["label"], entry["text"]])
				_:
					lines.append(entry["text"])
	return lines
