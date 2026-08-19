shader_type canvas_item;
render_mode blend_mix;

// A dusk sky built for contrast rather than harmony.
//
// The first version derived every colour from the city palette, which kept the
// destinations consistent but flattened each frame into a single hue. This one
// keeps a fixed cool-to-warm structure — deep indigo overhead, a blazing warm
// band at the horizon — and lets the city tint only the warm half. Identity
// still reads (Tokyo is pink-gold, London green-grey, Rome amber) while the
// complementary contrast that makes the look work survives.

uniform vec4 warm : source_color = vec4(1.00, 0.72, 0.42, 1.0);   // horizon, city-tinted
uniform vec4 mid : source_color = vec4(0.62, 0.40, 0.55, 1.0);    // transition band
uniform vec4 cool : source_color = vec4(0.09, 0.12, 0.30, 1.0);   // zenith

uniform vec2 sun = vec2(0.70, 0.58);
uniform float bloom : hint_range(0.0, 1.0) = 1.0;
uniform float drift = 0.0;
uniform float stars : hint_range(0.0, 1.0) = 0.7;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// A cloud field with an actual edge, plus how strongly that edge faces the sun.
// Returns (density, rimlight).
vec2 clouds(vec2 uv, float scale, float t, float sharpness) {
	vec2 p = vec2(uv.x * scale + t, uv.y * scale * 2.1);
	float d = fbm(p);
	// Sample slightly towards the sun: where density falls off in that
	// direction we are on the lit edge of the cloud.
	float d_sun = fbm(p + normalize(sun - uv) * 0.16);
	float body = smoothstep(0.52 - sharpness, 0.52 + sharpness, d);
	float lit = clamp((d_sun - d) * 6.0, 0.0, 1.0) * body;
	return vec2(body, lit);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.008 + drift;

	// Vertical ramp. The warm band is deliberately narrow and low, which is what
	// makes the sky read as late dusk instead of a generic gradient.
	vec3 col = mix(cool.rgb, mid.rgb, smoothstep(0.05, 0.62, uv.y));
	col = mix(col, warm.rgb, smoothstep(0.58, 0.94, uv.y));

	// Stars in the upper band, fading out as the horizon brightens.
	float star_field = hash(floor(uv * 420.0));
	float twinkle = 0.5 + 0.5 * sin(TIME * 1.7 + star_field * 40.0);
	float star_mask = smoothstep(0.62, 0.10, uv.y) * step(0.9975, star_field);
	col += vec3(1.0, 0.97, 0.92) * star_mask * twinkle * stars * bloom;

	// Horizon glow line — a thin blaze where the sun sits just above the edge.
	float band = exp(-pow((uv.y - 0.86) * 9.0, 2.0));
	col += warm.rgb * band * 0.35 * bloom;

	// Sun: small hot core, tight halo. Squashed on Y so it reads atmospheric.
	float d = distance(uv * vec2(1.0, 0.62), sun * vec2(1.0, 0.62));
	col += warm.rgb * exp(-d * 11.0) * 0.55 * bloom;
	col += vec3(1.0, 0.95, 0.86) * exp(-d * 60.0) * 0.85 * bloom;

	// Two cloud layers, the far one slower and softer.
	vec2 far = clouds(uv, 1.7, t * 0.5, 0.20);
	vec3 far_body = mix(cool.rgb, mid.rgb, 0.55);
	col = mix(col, far_body, far.x * 0.35 * smoothstep(0.08, 0.55, uv.y));
	col += warm.rgb * far.y * 0.30 * bloom;

	vec2 near = clouds(uv, 3.1, t, 0.13);
	vec3 near_body = mix(cool.rgb, mid.rgb, 0.25);
	float near_mask = near.x * smoothstep(0.18, 0.52, uv.y) * smoothstep(0.98, 0.72, uv.y);
	col = mix(col, near_body, near_mask * 0.55);
	col += vec3(1.0, 0.90, 0.76) * near.y * near_mask * 0.9 * bloom;

	// Volumetric shafts, anchored to the sun and only in the lower half.
	vec2 dir = uv - sun;
	float ang = atan(dir.y, dir.x);
	float shaft = fbm(vec2(ang * 4.0, TIME * 0.03 + drift));
	shaft = smoothstep(0.58, 1.0, shaft) * exp(-length(dir) * 2.2);
	col += vec3(1.0, 0.93, 0.80) * shaft * 0.40 * bloom;

	// Scrim so the destination name always has something to sit on.
	col *= mix(1.0, 0.62, smoothstep(0.74, 1.0, uv.y));

	float vig = smoothstep(1.30, 0.30, distance(uv, vec2(0.5)));
	col *= mix(1.0, vig, 0.45);

	// Filmic roll-off: keeps colour in the highlights instead of clipping to
	// white, which is what blew out the first attempt.
	col = col / (col + vec3(0.72)) * 1.72;

	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
