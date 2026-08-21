shader_type canvas_item;
render_mode blend_mix;

// "The puzzle becomes the place."
//
// Samples the postcard art through an animated mosaic. At blocks == the
// puzzle's grid size the image reads at exactly the resolution the player just
// solved; as progress climbs it refines into the full illustration.
//
// The refinement is depth-ordered rather than uniform: the bottom of the frame
// sharpens first and the horizon last, which is the order your eye focuses a
// landscape and makes a flat image read as having layers.

uniform sampler2D art : filter_linear, source_color;
uniform float grid = 15.0;                          // starting mosaic cells
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float depth : hint_range(0.0, 1.0) = 0.42;  // 0 = uniform, 1 = strong
uniform float warmth : hint_range(0.0, 1.0) = 0.0;
uniform vec2 cover = vec2(1.0, 1.0);
uniform float shimmer : hint_range(0.0, 1.0) = 0.0; // living light, post-resolve
uniform vec2 sun = vec2(0.72, 0.34);
// Cells finer than one screen pixel alias against the texture and produce
// moire streaks, so the mosaic stops once it reaches the render resolution.
uniform float max_blocks = 2048.0;
// Soft wash under the caption. Full-bleed artwork has no quiet band of its own,
// so the type needs one made for it or it fights the texture underneath.
uniform float caption_scrim : hint_range(0.0, 1.0) = 0.0;
// +1 lifts the band for dark type, -1 sinks it for light type. A Caravaggio
// lightened to suit dark lettering would stop being a Caravaggio.
uniform float scrim_dir = 1.0;
// Slow push in and out, the Ken Burns move the reference video does. Driven by
// a sine so it is seamless by construction rather than by editing.
uniform float breathe : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float zoom = 1.0 - breathe * 0.040 * (0.5 + 0.5 * sin(TIME * 0.16));
	vec2 uv = (UV - 0.5) * cover * zoom + 0.5;

	// One mosaic grid for the whole frame. Letting the cell size vary per row
	// (the obvious way to do depth ordering) makes neighbouring rows snap to
	// different grids and tears the image into horizontal streaks.
	float b = clamp(grid * pow(90.0, progress), 1.0, max_blocks);
	vec2 q = (floor(uv * b) + 0.5) / b;
	vec4 coarse = texture(art, clamp(q, vec2(0.0), vec2(1.0)));
	vec4 sharp = texture(art, clamp(uv, vec2(0.0), vec2(1.0)));

	// Depth ordering instead rides on *when* each part swaps to the sharp
	// sample: the foreground crosses over first, the horizon last.
	float lead = (uv.y - 0.5) * depth;
	float m = clamp(progress * (1.0 + depth) + lead - depth * 0.5, 0.0, 1.0);
	vec4 c = mix(coarse, sharp, smoothstep(0.45, 0.98, m));

	// Extra light while still coarse, so resolving feels like the picture
	// lighting up rather than merely sharpening.
	c.rgb += vec3(1.0, 0.92, 0.80) * warmth * 0.16;

	// There used to be a slow breath of light along the sun's rays here, meant
	// to keep the card from freezing into a screenshot. On a painted sunset it
	// read as weather; on a grey ink drawing it was a starburst across the
	// whole picture, and it was the brightest thing on the card.

	if (caption_scrim > 0.0) {
		float band = smoothstep(0.62, 0.94, UV.y);
		// Lift and flatten rather than darken: the type is dark, so it reads
		// best against a calm bright ground.
		vec3 washed = mix(c.rgb, vec3(dot(c.rgb, vec3(0.33))), 0.30);
		washed = mix(washed, vec3(step(0.0, scrim_dir)), 0.28);
		c.rgb = mix(c.rgb, washed, band * caption_scrim);
	}

	COLOR = vec4(clamp(c.rgb, vec3(0.0), vec3(1.0)), c.a);
}
