shader_type spatial;
render_mode cull_front, unshaded;

// The ink outline, as ink_body.gdshaderinc draws it, with the move_hold uniform
// (effects.gdshaderinc, MOVE_HELD): for the copies of its materials a building wears while it holds
// its folded moving parts (MaterialKit.moving, BuildingView), the hold set on each copy.

#define MOVE_HELD
#include "res://src/game/ink_body.gdshaderinc"
