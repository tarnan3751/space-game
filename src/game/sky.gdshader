shader_type sky;

// The sky behind the terrain ring (main.gd's environment; docs/reference/art-style.md, **Light and
// shading**): deep space, one faint band of nebula haze in the terrain's violet, and a sparse
// field of small hard-edged stars in pale cyan and white, the largest drawn as four-pointed comic
// sparkles. Nothing moves. It shows only beyond the ring, on screens wider than the ring fills.
//
// The camera is orthographic, and for one the renderer hands the sky the direction
// view_basis * (x, y, -1) at a point x, y world units from the middle of the view (half the view's
// width and height at its edges). So the sky is drawn on the view's plane rather than on a sphere:
// it lies still behind the panning ground, like a sky at infinity, and scales with the zoom, at
// which it shows only near the widest. Its sizes are in world units of that plane: at the widest
// zoom (IsoCamera.MAX_ZOOM_SIZE, 44 units over 720 px) a unit is about 16 px.

// The camera's basis (IsoCamera's fixed angle): right, up, and back from the view.
uniform mat3 view_basis = mat3(1.0);
uniform vec4 space : source_color = vec4(0.051, 0.043, 0.102, 1.0);
uniform vec4 haze : source_color = vec4(0.337, 0.29, 0.773, 1.0);
uniform vec4 star_tint : source_color = vec4(0.345, 0.91, 1.0, 1.0);

// The stars' grid in units, the share of its cells that hold a star, and the stars' radii in
// units (small, medium, the sparkles), the medium and the sparkles' shares of the stars, and the
// share of the stars that are cyan.
const float STAR_CELL = 1.0;
const float STAR_SHARE = 0.22;
const vec3 STAR_RADIUS = vec3(0.07, 0.12, 0.3);
const float MEDIUM = 0.3;
const float SPARKLE = 0.08;
const float CYAN = 0.4;
// The pale cyan: the tint mixed this far towards white.
const float PALE = 0.55;
// The haze: its band's direction and offset across the view, half its width, the value noise
// that breaks it into clouds (its lattice in units), and how far it goes towards the haze colour.
const vec2 BAND_NORMAL = vec2(-0.243, 0.97);
const float BAND_OFFSET = -4.3;
const float BAND_HALF_WIDTH = 10.0;
const float HAZE_CELL = 6.0;
const float HAZE = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	// The point on the view's plane this pixel looks through, in units from the view's middle.
	vec3 back = view_basis[2];
	vec3 through = EYEDIR / max(dot(EYEDIR, -back), 0.0001) + back;
	vec2 at = vec2(dot(through, view_basis[0]), dot(through, view_basis[1]));
	float px = max(fwidth(at.x), 0.0001);

	vec3 color = space.rgb;
	float across = (dot(at, BAND_NORMAL) - BAND_OFFSET) / BAND_HALF_WIDTH;
	float clouds = value_noise(at / HAZE_CELL) * 0.6 + value_noise(at / (HAZE_CELL * 0.4) + 17.0) * 0.4;
	color = mix(color, haze.rgb, HAZE * clamp(1.0 - across * across, 0.0, 1.0) * clouds);

	vec2 cell = floor(at / STAR_CELL);
	float pick = hash(cell);
	if (pick < STAR_SHARE) {
		float kind = pick / STAR_SHARE;
		// Kept within the middle of the cell, so no star is cut by its edge.
		vec2 centre = (cell + 0.3 + 0.4 * vec2(hash(cell + 7.3), hash(cell + 3.1))) * STAR_CELL;
		vec2 d = abs(at - centre);
		float radius = kind < SPARKLE ? STAR_RADIUS.z : (kind < SPARKLE + MEDIUM ? STAR_RADIUS.y : STAR_RADIUS.x);
		// A disc, or for a sparkle four points: a star whose edge runs (sqrt |x| + sqrt |y|)^2.
		float shape = kind < SPARKLE ? pow(sqrt(d.x) + sqrt(d.y), 2.0) : length(d);
		float inside = clamp((radius - shape) / px + 0.5, 0.0, 1.0);
		vec3 star = hash(cell + 11.9) < CYAN ? mix(star_tint.rgb, vec3(1.0), PALE) : vec3(1.0);
		color = mix(color, star, inside);
	}
	COLOR = color;
}
