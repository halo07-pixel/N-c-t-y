class_name MatchFx
extends Node
## Screen effects of a match that are not the camera's: the burst at the edge of
## the screen when someone is knocked out and the slow motion on the final KO.
## It only listens to the Events bus. With GameSettings.screen_effects off it does nothing.

const SLOWMO_SCALE := 0.35
const SLOWMO_SECONDS := 0.9 # real time
const FINAL_KO_WINDOW_FRAMES := 3
const EDGE_MARGIN := 24.0

var _last_ko_frame: int = -100
var _slowmo_active: bool = false
var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12 # above the world and vignette, below the HUD
	add_child(_layer)
	Events.fighter_ko.connect(_on_fighter_ko)
	Events.match_ended.connect(_on_match_ended)


func _exit_tree() -> void:
	_end_slowmo()


## Screen position of the burst for a KO at `ko_position`: where that point is on the
## screen, pulled inside the edge like the flash of a platform fighter.
static func burst_screen_position(
	ko_position: Vector2, view_center: Vector2, zoom_level: float, screen_size: Vector2
) -> Vector2:
	var screen := (ko_position - view_center) * zoom_level + screen_size * 0.5
	var margin := EDGE_MARGIN * RenderScale.FACTOR
	return Vector2(
		clampf(screen.x, margin, screen_size.x - margin),
		clampf(screen.y, margin, screen_size.y - margin)
	)


## The final KO slows time more, and for longer, on higher effect levels.
static func slowmo_scale(level: int) -> float:
	return 0.5 if level <= GameSettings.EffectsLevel.LOW else (0.35 if level == GameSettings.EffectsLevel.NORMAL else 0.25)


static func slowmo_seconds(level: int) -> float:
	return 0.6 if level <= GameSettings.EffectsLevel.LOW else (SLOWMO_SECONDS if level == GameSettings.EffectsLevel.NORMAL else 1.2)


## True when the match ended on the same frame as a KO (not by the clock).
static func is_final_ko(frame: int, last_ko_frame: int) -> bool:
	return frame - last_ko_frame <= FINAL_KO_WINDOW_FRAMES


func _on_fighter_ko(player_id: int, ko_position: Vector2) -> void:
	_last_ko_frame = Engine.get_physics_frames()
	if not GameSettings.screen_effects:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var burst := EdgeBurst.new()
	burst.position = burst_screen_position(
		ko_position, camera.get_screen_center_position(), camera.zoom.x,
		get_viewport().get_visible_rect().size
	)
	burst.scale = RenderScale.ui()
	burst.color = MatchHud.PLAYER_COLORS.get(player_id, Color.WHITE).lerp(Color.WHITE, 0.4)
	burst.amount = GameSettings.effect_amount()
	var character := MatchConfig.character_for(player_id)
	if character != null and character.fx_profile != null:
		burst.color = character.fx_profile.primary
		burst.accent = character.fx_profile.accent
	_layer.add_child(burst)


func _on_match_ended(_winner_id: int) -> void:
	if not GameSettings.screen_effects or _slowmo_active:
		return
	if not is_final_ko(Engine.get_physics_frames(), _last_ko_frame):
		return
	_slowmo_active = true
	Engine.time_scale = slowmo_scale(GameSettings.effects_level)
	# process_always, process_in_physics, ignore_time_scale: the timer runs in real time.
	get_tree().create_timer(slowmo_seconds(GameSettings.effects_level), true, false, true).timeout.connect(_end_slowmo)


func _end_slowmo() -> void:
	if _slowmo_active:
		_slowmo_active = false
		Engine.time_scale = 1.0
