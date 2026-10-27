shader_type spatial;
render_mode cull_front, unshaded;

// The ink outline, as ink_body.gdshaderinc draws it, for every instance that does not
// hold its moving parts (MaterialKit.ink() and its variants): no hold, so it is
// shared by every instance. ink_move.gdshader is the same with the hold
// (effects.gdshaderinc, MOVE_HELD).

#include "res://src/game/ink_body.gdshaderinc"
