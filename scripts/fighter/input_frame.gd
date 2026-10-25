class_name InputFrame
extends RefCounted
## One tick of intent from a player or an AI. Fighters only ever read this,
## so keyboard, CPU and test scripts are interchangeable.

var move: Vector2 = Vector2.ZERO
var up_just_pressed: bool = false
var down_just_pressed: bool = false
var down_held: bool = false
var attack_just_pressed: bool = false
var special_just_pressed: bool = false
var guard_just_pressed: bool = false
var guard_held: bool = false
var charge_held: bool = false
