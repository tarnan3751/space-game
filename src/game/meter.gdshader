shader_type canvas_item;

// A resource meter's stripes (Hud._build_meter; docs/reference/hud.md, **Top bar**): the stripe
// tile, tinted, drifting along the bar, cut to the pill's round ends, with a gloss across its top
// third; a glint sweeping across the filled part now and then; a flash of the whole fill when the
// amount changes; and, at the cap, a gold line inside the pill. Drawn on the stripes' TextureRect,
// which spans the whole track; the fill's clip cuts it to the amount, so nothing here reaches the
// trough's border, its shadow or the coin. Everything runs from anim_time
// (docs/reference/art-style.md, **Animation**, "One clock"); the HUD sets only fill_width,
// flash_time and full, and only on a refresh that changes them. Sizes are in the HUD's pixels
// (720p).

global uniform float anim_time;

// The fill's colour over the tile's grey, so the grey reads as the colour itself.
uniform vec4 tint = vec4(1.0);
// 0 to 1: where in the glint's period this meter is at time 0, so the meters glint in turn.
uniform float phase = 0.0;
// The track's size (its ends are round, a radius of half its height), and the filled part's width,
// which the glint sweeps across.
uniform float track_height = 38.0;
uniform float track_width = 210.0;
uniform float fill_width = 0.0;
// anim_time when the amount last changed; the flash runs from it.
uniform float flash_time = -100.0;
// The amount is at its cap: a line FULL_LINE px wide in full_color just inside the pill.
uniform bool full = false;
uniform vec4 full_color : source_color = vec4(1.0, 0.757, 0.231, 1.0);

// The stripe tile's side (Hud.STRIPE_TILE); the stripes drift one tile along the bar in DRIFT_SECONDS.
const float TILE = 16.0;
const float DRIFT_SECONDS = 4.0;
// White over the top third of the track.
const float GLOSS = 0.1;
// The glint: a band WIDTH wide, leaning SLANT px right per px up, near-white at GLINT_ALPHA with a
// CORE px core at CORE_ALPHA, each with a 1 px soft edge; it crosses the fill in SWEEP_SECONDS, once
// every PERIOD_SECONDS, which divides the clock's hour.
const float PERIOD_SECONDS = 8.0;
const float SWEEP_SECONDS = 0.6;
const float WIDTH = 26.0;
const float CORE = 6.0;
const float SLANT = 0.5;
const float GLINT_ALPHA = 0.35;
const float CORE_ALPHA = 0.5;
const vec3 GLINT = vec3(0.957, 0.949, 1.0);
// The flash: the fill brightens towards white by FLASH at once, then back over FLASH_SECONDS.
const float FLASH = 0.45;
const float FLASH_SECONDS = 0.25;
const float FULL_LINE = 2.0;

varying vec2 local;
// The vertex colour, the item's modulate in it; the fragment's COLOR has the texture at the item's
// own UV in it too, which the drifted stripes replace.
varying vec4 modulate;

void vertex() {
	local = VERTEX;
	modulate = COLOR;
}

void fragment() {
	vec2 at = local - vec2(anim_time * TILE / DRIFT_SECONDS, 0.0);
	vec3 color = texture(TEXTURE, at / TILE).rgb * tint.rgb;
	if (local.y < track_height / 3.0) {
		color = mix(color, vec3(1.0), GLOSS);
	}

	float since = mod(anim_time - phase * PERIOD_SECONDS, PERIOD_SECONDS);
	if (since < SWEEP_SECONDS) {
		// The band's centre line at mid-height runs from wholly left of the fill to wholly right.
		float reach = WIDTH * 0.5 + SLANT * track_height * 0.5;
		float centre = mix(-reach, fill_width + reach, since / SWEEP_SECONDS);
		float off = abs(local.x - centre + SLANT * (local.y - track_height * 0.5));
		float glint = max(GLINT_ALPHA * clamp(WIDTH * 0.5 + 0.5 - off, 0.0, 1.0),
				CORE_ALPHA * clamp(CORE * 0.5 + 0.5 - off, 0.0, 1.0));
		color = mix(color, GLINT, glint);
	}

	float flash = anim_time - flash_time;
	if (flash >= 0.0 && flash < FLASH_SECONDS) {
		color = mix(color, vec3(1.0), FLASH * (1.0 - flash / FLASH_SECONDS));
	}

	// How far inside the pill this pixel lies (negative outside): its round ends cut the fill.
	float radius = track_height * 0.5;
	vec2 spine = vec2(clamp(local.x, radius, track_width - radius), radius);
	float inside = radius - distance(local, spine);
	if (full) {
		color = mix(color, full_color.rgb, clamp(FULL_LINE + 0.5 - inside, 0.0, 1.0));
	}
	COLOR = modulate * vec4(color, clamp(inside + 0.5, 0.0, 1.0));
}
