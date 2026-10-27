shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// The hologram surface of a kit mesh, as holo_body.gdshaderinc draws it, with the move_hold uniform
// (effects.gdshaderinc, MOVE_HELD): for the copies of its materials a building wears while it holds
// its folded moving parts (MaterialKit.moving, BuildingView), the hold set on each copy.

#define MOVE_HELD
#include "res://src/game/holo_body.gdshaderinc"
