class_name FighterBody
extends Node2D
## What a fighter looks like. The fighter tells its body what is happening and
## the body decides how to show it. PlaceholderBody draws it with rectangles,
## SpriteBody plays real sprite animations; BodyFactory picks between them.


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
