class_name StageBackdrop
extends Node2D
## Parallax backdrop: sky, stars and moon, far hills, ruined towers and dark rock,
## each painted in code and shifted with the camera at its own depth.

const LAYERS := [
	[BackdropLayer.Kind.SKY, 0.0, 1],
	[BackdropLayer.Kind.STARS, 0.05, 7],
	[BackdropLayer.Kind.FAR, 0.25, 21],
	[BackdropLayer.Kind.MID, 0.5, 33],
	[BackdropLayer.Kind.NEAR, 0.8, 45],
]

var layers: Array[BackdropLayer] = []


func _ready() -> void:
	for spec: Array in LAYERS:
		var layer := BackdropLayer.new()
		layer.kind = spec[0]
		layer.depth = spec[1]
		layer.seed_value = spec[2]
		add_child(layer)
		layers.append(layer)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		follow(camera.get_screen_center_position())


## Moves every layer for a camera looking at this point: deeper layers trail further behind.
func follow(camera_position: Vector2) -> void:
	for layer in layers:
		layer.position = camera_position * (1.0 - layer.depth)
