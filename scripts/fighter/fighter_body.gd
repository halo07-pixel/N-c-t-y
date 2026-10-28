class_name FighterBody
extends Node2D
## What a fighter looks like. The fighter tells its body what is happening and
## the body decides how to show it. PlaceholderBody draws it with rectangles,
## SpriteBody plays real sprite animations; BodyFactory picks between them.

const FLASH_SHADER: Shader = preload("res://assets/shaders/hit_flash.gdshader")
const FLASH_FRAMES := 5
const FLASH_AMOUNT := 0.85

var _flash_left: int = 0
var _flash_material: ShaderMaterial


func setup(_character: CharacterData, _player_id: int) -> void:
	pass


## The state machine entered a new state.
func set_pose(_pose: StringName) -> void:
	pass


## Called every physics frame with the current state, facing (1 or -1) and velocity.
func sync_to(_pose: StringName, _facing: int, _velocity: Vector2) -> void:
	pass


## While attacking: direction of the move ("neutral", "forward", "up", "down"),
## its phase ("startup", "active", "recovery") and whether it is an aerial or a
## special. Empty strings mean no attack.
func set_attack_visual(_kind: StringName, _phase: StringName, _aerial: bool = false, _special: bool = false) -> void:
	pass


func set_bankai(_active: bool) -> void:
	pass


## Art for a projectile (an effect sprite), or null to draw the plain shape.
func effect_texture(_effect_name: StringName) -> Texture2D:
	return null


## The fighter was just hit: show the body white for a few frames (a screen effect).
func flash_hit() -> void:
	if not GameSettings.screen_effects:
		return
	_flash_left = FLASH_FRAMES
	_apply_flash()


func is_flashing() -> bool:
	return _flash_left > 0


## The canvas item the white flash is applied to.
func _flash_target() -> CanvasItem:
	return self


func _physics_process(_delta: float) -> void:
	if _flash_left > 0:
		_flash_left -= 1
		_apply_flash()


func _apply_flash() -> void:
	var target := _flash_target()
	if target == null:
		return
	if _flash_left <= 0:
		target.material = null
		return
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = FLASH_SHADER
	_flash_material.set_shader_parameter("amount", FLASH_AMOUNT)
	target.material = _flash_material
