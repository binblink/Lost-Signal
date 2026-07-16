shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float alpha = step(length(uv), 0.5);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= alpha;
}
