// Scanline overlay — drifting horizontal light bands for the end screen glitch effect.
// Applied to a full-screen ColorRect (blend_add, low alpha — does not obscure text).
//
// [END SCREEN] — delete this file to remove the end screen feature.

shader_type canvas_item;
render_mode blend_add;

void fragment() {
	float t = TIME;
	float y = UV.y;

	// Three bands at different speeds and widths
	float b1 = smoothstep(0.015, 0.0, abs(fract(y * 2.0  + t * 0.28) - 0.5));
	float b2 = smoothstep(0.007, 0.0, abs(fract(y * 5.5  - t * 0.19) - 0.5));
	float b3 = smoothstep(0.022, 0.0, abs(fract(y * 1.0  + t * 0.06) - 0.5));

	float alpha = b1 * 0.10 + b2 * 0.06 + b3 * 0.07;
	COLOR = vec4(0.7, 0.9, 1.0, alpha);
}
