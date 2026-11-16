shader_type canvas_item;
uniform int material_kind = 0;
uniform float variation = 0.0;
void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec4 source = texture(TEXTURE, UV);
	float grain = fract(sin(dot(pixel + variation, vec2(12.9898,78.233))) * 43758.5453);
	float detail = 0.0;
	if (material_kind == 3) {
		// Fine fabric weave only on dark cloth; skin and facial highlights stay crisp.
		float lightness = dot(source.rgb, vec3(0.299,0.587,0.114));
		if (lightness > 0.09 && lightness < 0.38 && source.b > source.r * 0.75) {
			detail = mod(pixel.x + pixel.y, 3.0) < 1.0 ? 0.012 : -0.006;
		}
	} else if (material_kind == 0 && source.g > source.r * 1.12 && source.g > source.b) {
		detail = (grain - 0.5) * 0.045;
	} else if (material_kind == 1 && source.r > source.b * 1.10) {
		float seam = mod(pixel.y, 7.0);
		detail = seam < 1.0 ? -0.025 : (grain - 0.5) * 0.025;
	} else if (material_kind == 2) {
		detail = (grain - 0.5) * 0.035;
	}
	COLOR.rgb = clamp(COLOR.rgb + vec3(detail) * step(0.5, source.a), vec3(0.0), vec3(1.0));
}
