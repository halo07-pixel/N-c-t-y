class_name FxProfile
extends Resource
## How a character's effects look: palette and feel. Pure data, one per character; the
## effect scripts read it so nothing about a character is hard-coded in them.

@export var primary: Color = Color(1.0, 1.0, 1.0)
@export var accent: Color = Color(1.0, 0.9, 0.6)
## The dark tone used for contrast rims and shadows.
@export var shadow: Color = Color(0.1, 0.05, 0.15)
## How the hit burst is drawn: slash, shards, petals or ink.
@export var impact_style: StringName = &"slash"
## 0.5..1.5, a heavier character gets bigger bursts.
@export var spark_scale: float = 1.0
## The screen motif of the transformation and ultimate presentation: frame, glyph, petal_ring or shadow.
@export var motif: StringName = &"frame"
