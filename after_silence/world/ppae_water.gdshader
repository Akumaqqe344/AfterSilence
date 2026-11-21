shader_type canvas_item;

uniform sampler2D waves : filter_nearest, repeat_disable;
uniform vec2 field_origin;
uniform vec2 field_size;
uniform float water_age;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

vec3 wave(vec2 cell, float frame, float row) {
	vec2 texel = vec2(frame * 16.0, row * 16.0) + mod(cell, 16.0) + vec2(0.5);
	return texture(waves, texel / vec2(128.0, 32.0)).rgb;
}

void fragment() {
	vec4 tint = vertex_tint;
	vec4 field = texture(TEXTURE, UV);
	vec2 address = floor((field_origin + UV * field_size) / vec2(3.0, 2.0));
	float depth = field.r;
	float phase = mod(water_age * 5.0, 8.0);
	float step0 = floor(phase);
	float step1 = mod(step0 + 1.0, 8.0);
	float band = smoothstep(0.04, 0.46, depth);
	vec3 near_water = mix(wave(address, step0, 0.0), wave(address, step1, 0.0), fract(phase));
	vec3 far_water = mix(wave(address / vec2(2.0, 1.0), step0, 1.0), wave(address / vec2(2.0, 1.0), step1, 1.0), fract(phase));
	float curl = floor(mod((address.x + address.y * 2.0) / 7.0 + step0 * 0.5, 5.0));
	float foam = (1.0 - smoothstep(0.0, 0.075, depth)) * (curl < 2.0 ? 0.48 : 0.18);
	vec3 water = mix(mix(near_water, far_water, band), vec3(0.72, 0.74, 0.59), foam);
	COLOR = vec4(water * tint.rgb, field.a * tint.a);
}
