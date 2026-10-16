class_name WallMesh
extends Node3D
## Every finished wall of the base drawn as one merged mesh: each wall is the piece of its
## level and neighbour mask (models/walls.gd), so a painted line reads as one barrier and
## corners, T-junctions and crossings join. Two walls connect when they share a cell edge,
## whatever their levels; diagonal walls do not. Where a neighbour's solid segment stands lower
## (WallModels.solid_top), the piece's segment towards it ends in an inked step (its lower
## mask). A wall under upgrade keeps its finished level's piece.
##
## BaseView owns one and rebuilds it only when the set of walls it draws changes, once a frame
## at most. A rebuild copies each piece's arrays into the merged ones with the engine's bulk
## packed-array calls (a transform of a whole vertex array, append_array), nothing per vertex in
## script. The wall views stay (the footprint tile, the timer label, the lift) with their models
## hidden (BuildingView.set_merged), except the dragged wall's: it leaves the mesh while it is
## in the air, and its own post follows the finger.
##
## Two instances, as every model has: the body, and its ink outline, which casts no shadow.

const WallModels := preload("res://src/game/models/walls.gd")

var body: MeshInstance3D
var outline: MeshInstance3D

var _base_view: BaseView
## The level of each wall drawn, by cell.
var _levels: Dictionary[Vector2i, int] = {}


## Call once, before adding to the tree. Pieces are placed with `base_view`'s cell mapping.
func setup(base_view: BaseView) -> void:
	_base_view = base_view
	body = MeshInstance3D.new()
	add_child(body)
	outline = MeshInstance3D.new()
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)


## Whether the merged mesh draws `building`: a wall (PlacementController.PAINT_TYPE, 1x1),
## once finished.
static func draws(building: BuildingState) -> bool:
	return building.level >= 1 and building.type == PlacementController.PAINT_TYPE


## Rebuilds the mesh from every wall of `state` that draws() accepts, except `skip_id`.
func rebuild(state: BaseState, skip_id: int) -> void:
	_levels.clear()
	for id: int in state.buildings:
		var building: BuildingState = state.buildings[id]
		if id != skip_id and draws(building):
			_levels[building.cell] = building.level
	if _levels.is_empty():
		body.mesh = null
		outline.mesh = null
		return
	var bodies := Merged.new()
	var outlines := Merged.new()
	for cell: Vector2i in _levels:
		var level := _levels[cell]
		var tier := BuildingModels.tier_of(state.catalog, PlacementController.PAINT_TYPE, level)
		var piece := WallModels.piece(level, tier, mask_at(cell), _lower_mask_at(cell))
		var at := Transform3D(Basis(), _base_view.cell_to_world(cell, 1))
		bodies.append(piece.body, at)
		outlines.append(piece.outline, at)
	body.mesh = bodies.to_mesh(MaterialKit.toon())
	outline.mesh = outlines.to_mesh(MaterialKit.ink())


## The neighbour mask (WallModels' bits) of the wall drawn on `cell`, -1 when none is.
func mask_at(cell: Vector2i) -> int:
	if not _levels.has(cell):
		return -1
	var mask := 0
	for bit: int in WallModels.NEIGHBOURS.size():
		if _levels.has(cell + WallModels.NEIGHBOURS[bit]):
			mask |= 1 << bit
	return mask


## The bits of the walls beside `cell` whose solid segment stands lower than its own
## (WallModels.solid_top: by height, not level, since level 5's is a low slab).
func _lower_mask_at(cell: Vector2i) -> int:
	var own := WallModels.solid_top(_levels[cell])
	var mask := 0
	for bit: int in WallModels.NEIGHBOURS.size():
		var neighbour := cell + WallModels.NEIGHBOURS[bit]
		if _levels.has(neighbour) and WallModels.solid_top(_levels[neighbour]) < own:
			mask |= 1 << bit
	return mask


## One merged surface: the channels of every piece appended in turn, the vertices moved to
## their cell. Normals are unchanged, since pieces are only moved. A channel no piece has
## stays empty and is left out.
class Merged:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()

	func append(arrays: Array, at: Transform3D) -> void:
		var piece_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var piece_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		vertices.append_array(at * piece_vertices)
		normals.append_array(piece_normals)
		if typeof(arrays[Mesh.ARRAY_TEX_UV]) == TYPE_PACKED_VECTOR2_ARRAY:
			var piece_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var piece_uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var piece_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			uvs.append_array(piece_uvs)
			uv2s.append_array(piece_uv2s)
			colors.append_array(piece_colors)

	func to_mesh(material: Material) -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		if not uvs.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_TEX_UV2] = uv2s
			arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, material)
		return mesh
