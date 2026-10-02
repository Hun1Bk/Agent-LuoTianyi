shader_type canvas_item;
render_mode unshaded;
uniform vec2 rect_size = vec2(384.0, 48.0);
uniform float radius = 12.0;
void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius));
	float distance = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-0.8, 0.8, distance);
}
