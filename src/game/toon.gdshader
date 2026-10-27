shader_type spatial;
render_mode ambient_light_disabled;

// The body of every kit mesh, as toon_body.gdshaderinc draws it, for every instance that does not
// hold its moving parts (MaterialKit.toon() and its variants): no hold, so it is
// shared by every instance. toon_move.gdshader is the same with the hold
// (effects.gdshaderinc, MOVE_HELD).

#include "res://src/game/toon_body.gdshaderinc"
