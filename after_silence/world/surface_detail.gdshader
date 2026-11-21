shader_type canvas_item;

uniform int material_kind = 0;
uniform float variation = 0.0;

void fragment() {
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec4 source = texture(TEXTURE, UV);
	float lightness = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float fleck = mod(texel.x * 11.0 + texel.y * 7.0 + variation, 23.0);
	float detail = 0.0;
	if (material_kind == 3) {
		if (lightness > 0.09 && lightness < 0.38 && source.b > source.r * 0.75) {
			detail = mod(texel.x + texel.y, 3.0) < 1.0 ? 0.012 : -0.007;
		}
	} else if (material_kind == 0 && source.g > source.r * 1.12 && source.g > source.b) {
		detail = fleck < 2.0 ? 0.020 : (fleck > 19.0 ? -0.012 : 0.0);
	} else if (material_kind == 1 && source.r > source.b * 1.10) {
		float grain = mod(texel.y * 3.0 + floor(texel.x / 9.0), 17.0);
		detail = grain < 2.0 ? -0.022 : (grain > 14.0 ? 0.010 : 0.0);
	} else if (material_kind == 2) {
		detail = fleck < 3.0 ? 0.018 : (fleck > 18.0 ? -0.012 : 0.0);
	}
	COLOR.rgb = clamp(COLOR.rgb + vec3(detail) * step(0.5, source.a), vec3(0.0), vec3(1.0));
}
