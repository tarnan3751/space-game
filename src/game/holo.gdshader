shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// The hologram surface of a kit mesh, as holo_body.gdshaderinc draws it, for every instance that does not
// hold its moving parts (MaterialKit.holo() and its variants): no hold, so it is
// shared by every instance. holo_move.gdshader is the same with the hold
// (effects.gdshaderinc, MOVE_HELD).

#include "res://src/game/holo_body.gdshaderinc"
