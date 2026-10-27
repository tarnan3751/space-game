shader_type canvas_item;

// A locked build card's picture (Hud._refresh_entries; docs/reference/hud.md, **Cards**): drawn at
// full alpha, its colour half way to its own grey, the grey leaning a little towards the panels'
// violet, so the building still reads but plainly is not on offer yet.

const float DESATURATE = 0.5;
const vec3 VIOLET = vec3(0.84, 0.82, 1.0);

void fragment() {
	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, grey * VIOLET, DESATURATE);
}
