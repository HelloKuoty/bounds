shader_type canvas_item;
// Procedural aged-parchment backdrop: a warm base mottled with stains and a fine
// directional fibre grain. No texture assets — ships in the web build. The world
// stops reading as a flat fill and starts reading as old paper. (顾屿, iter-16)
//
// Visual result needs a real GPU to judge (headless can't render); the shader is
// deliberately plain GLSL so it compiles on the GL Compatibility renderer.

uniform vec3 base_color : source_color = vec3(0.115, 0.088, 0.052);
uniform vec3 high_color : source_color = vec3(0.180, 0.140, 0.085);
uniform float fibre_strength = 0.6;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float stain = fbm(uv * 4.0);                      // low-freq aging / blotches
	float fibre = fbm(uv * vec2(240.0, 46.0));        // stretched → paper grain runs lengthwise
	float t = mix(stain, fibre, 0.35) * fibre_strength;
	vec3 col = mix(base_color, high_color, clamp(t, 0.0, 1.0));
	col *= 0.9 + 0.1 * fbm(uv * 9.0 + 11.0);          // faint darker patches
	COLOR = vec4(col, 1.0);
}
