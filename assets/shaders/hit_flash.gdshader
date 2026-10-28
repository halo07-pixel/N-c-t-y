shader_type canvas_item;
// Blends whatever is drawn toward white; used for the flash when a fighter is hit.
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), amount);
}
