class_name InputSource
extends Node
## Base class for anything that can steer a fighter.
## The fighter asks for a frame once per physics tick.


func get_frame() -> InputFrame:
	return InputFrame.new()
