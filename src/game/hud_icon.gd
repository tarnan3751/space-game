class_name HudIcon
extends Control
## A HUD badge drawn in code, vector, from no asset file: the icon at the left end of each
## meter, the drone on the drone meter's coin (`DroneRing`), the unit glyphs of the queue
## strip and the abilities' glyphs (docs/reference/hud.md, **Top bar**, **Unit glyphs**, **Ability
## glyphs**). Each part of a silhouette is a flat fill in the
## icon's colour, with a lighter highlight facet and a 2.5 px ink outline, over a 2 px ink
## offset shadow under the whole icon. The shapes are laid out in a 40-unit box, scaled to
## the rect they are painted into. A control draws only when it is built or resized, and the
## whole icon is one triangle array, so one draw call (`Pen`). Any icon can wear a coin under it
## (`coin`): a disc in the coin's colour with its light band and ink ring, the silhouette inset on it.

## The box the silhouettes are laid out in, in units.
const BOX := 40.0
const OUTLINE := 2.5
## Inner edges between the facets of one part.
const EDGE := 2.0
const SHADOW_OFFSET := Vector2(2, 2)
## The coin: its disc's radius, its ink ring, the most HSV value its fill keeps, how much lighter its
## band is, the share of its height the band covers from the top, and the share of the rect the
## silhouette is inset to.
const COIN_RADIUS := 18.5
const COIN_RING := 3.0
const COIN_VALUE := 0.55
const COIN_BAND_LIGHT := 0.15
const COIN_BAND := 0.4
const COIN_INSET := 0.7
## The metal ingot's own colour, whatever the icon's: deeper than the metal's text colour, so the
## ingot does not match the crystal's shards in value.
const STEEL := Color("7fa6cc")

## "metal", "crystal", "antimatter", "drones", "army" (the army's figure, on the training panel's
## housing line), or a unit's crew, "human", "piloted" or "autonomous", or an ability's effect,
## "swarm", "emp" or "strike", or a mark, "lock", "clock", "chevron", "star", "skull" or "cross"; anything
## else draws a plain gem.
var kind: String = ""
var color: Color = Color.WHITE
## A wing mark at the lower right: an air unit.
var winged: bool = false
## The coin under the icon, in this colour (at most COIN_VALUE in value); transparent for none.
var coin: Color = Color.TRANSPARENT


func _draw() -> void:
	var pen := Pen.new()
	paint(pen, kind, Rect2(Vector2.ZERO, size), color, winged, coin)
	pen.draw(self)


## Shows another icon; it redraws only when something changed.
func show_icon(new_kind: String, new_winged: bool) -> void:
	if new_kind == kind and new_winged == winged:
		return
	kind = new_kind
	winged = new_winged
	queue_redraw()


## Adds the `icon`, fitted to `rect`, to `pen`: every part's shadow, then the parts, the wing
## mark last when `wing`; on a coin of `coin_color` filling `rect`, the icon inset on it, unless
## `coin_color` is transparent.
static func paint(pen: Pen, icon: String, rect: Rect2, tint: Color, wing: bool = false,
		coin_color: Color = Color.TRANSPARENT) -> void:
	if coin_color.a > 0.0:
		pen.fit(rect)
		_coin(pen, coin_color)
		var side := minf(rect.size.x, rect.size.y) * COIN_INSET
		rect = Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
	pen.fit(rect)
	for shadow: bool in [true, false]:
		pen.shadow = shadow
		match icon:
			"metal":
				_ingot(pen, STEEL)
			"crystal":
				_shards(pen, tint)
			"antimatter":
				_orb(pen, tint)
			"drones":
				_drone(pen, tint)
			"army":
				_figure(pen, tint)
			"human":
				_helmet(pen, tint)
			"piloted":
				_tracked(pen, tint)
			"autonomous":
				_sensor_head(pen, tint)
			"swarm":
				_swarm(pen, tint)
			"emp":
				_burst(pen, tint)
			"strike":
				_strike(pen, tint)
			"lock":
				_padlock(pen, tint)
			"clock":
				_clock(pen, tint)
			"chevron":
				_chevron(pen, tint)
			"star":
				_star(pen, tint)
			"skull":
				_skull(pen, tint)
			"cross":
				_cross(pen, tint)
			_:
				_gem(pen, tint)
		if wing:
			_wing(pen)
	pen.shadow = false


## The coin: its shadow, a disc of `coin_color` at most COIN_VALUE in value, a lighter cel band
## across its upper COIN_BAND, and its ink ring.
static func _coin(pen: Pen, coin_color: Color) -> void:
	var centre := Vector2(BOX, BOX) * 0.5
	var disc := _ellipse(centre, Vector2(COIN_RADIUS, COIN_RADIUS), 0.0, TAU, 32)
	var fill := Color.from_hsv(coin_color.h, coin_color.s, minf(coin_color.v, COIN_VALUE))
	pen.shadow = true
	pen.shape(disc, fill)
	pen.shadow = false
	pen.shape(disc, fill)
	pen.facet(_cap(centre, COIN_RADIUS, COIN_RADIUS * (1.0 - 2.0 * COIN_BAND), true, 16),
		fill.lightened(COIN_BAND_LIGHT))
	pen.outline(disc, COIN_RING)


## A bar seen from the front and a little above: a trapezoid front, a lighter top face and a
## darker end.
static func _ingot(pen: Pen, tint: Color) -> void:
	var front_left := Vector2(4, 32)
	var front_right := Vector2(27, 32)
	var top_left := Vector2(8, 20)
	var top_right := Vector2(23, 20)
	var depth := Vector2(8, -8)
	var outline := PackedVector2Array([front_left, front_right, front_right + depth,
		top_right + depth, top_left + depth, top_left])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([top_left, top_right, top_right + depth, top_left + depth]), tint.lightened(0.45))
	pen.facet(PackedVector2Array([front_right, top_right, top_right + depth, front_right + depth]), tint.darkened(0.25))
	pen.edge(PackedVector2Array([top_left, top_right, front_right]))
	pen.edge(PackedVector2Array([top_right, top_right + depth]))
	pen.outline(outline)


## A tall kite with a smaller one leaning on it, each with a lighter left face.
static func _shards(pen: Pen, tint: Color) -> void:
	_kite(pen, tint, Vector2(9, 11), Vector2(16, 20), Vector2(13, 36), Vector2(3, 24))
	_kite(pen, tint, Vector2(24, 3), Vector2(34, 16), Vector2(23, 37), Vector2(15, 17))


static func _kite(pen: Pen, tint: Color, top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var outline := PackedVector2Array([top, right, bottom, left])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([top, bottom, left]), tint.lightened(0.45))
	pen.edge(PackedVector2Array([top, bottom]))
	pen.outline(outline)


## An orb with an orbit ring tilted across it: the ring's far half behind the orb, its near
## half in front; a lighter cel band over the orb's upper half and a white highlight, so it is no
## dark blob when small.
static func _orb(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 20)
	var ring_radii := Vector2(18, 6.5)
	var tilt := -0.38
	var ring_color := tint.lightened(0.35)
	pen.band(_ellipse(centre, ring_radii, PI, TAU, 12, tilt), ring_color)
	var orb := _ellipse(centre, Vector2(11, 11), 0.0, TAU, 24)
	pen.shape(orb, tint)
	pen.facet(_cap(centre, 11.0, 1.0, true, 12), tint.lightened(0.3))
	pen.facet(_ellipse(Vector2(15.5, 14.5), Vector2(4.5, 3), 0.0, TAU, 12, -0.6), Color.WHITE)
	pen.outline(orb)
	pen.band(_ellipse(centre, ring_radii, 0.0, PI, 12, tilt), ring_color)


## The construction drone from the front and a little above, as it flies over a site: a domed
## hull in the icon's colour, a light rim inside its ink round the dome and its belly a little
## darker, with a highlight lobe at the top left and a dark visor band across its front holding a
## white eye; a rotor arm out from each of its upper flanks, over the hull, to a light rotor disc
## seen at an angle; the tool's nozzle under its belly, a light lens at its end.
static func _drone(pen: Pen, tint: Color) -> void:
	var nozzle := PackedVector2Array([Vector2(15.5, 25), Vector2(24.5, 25), Vector2(22.5, 33), Vector2(17.5, 33)])
	pen.shape(nozzle, tint.darkened(0.15))
	pen.facet(_ellipse(Vector2(20, 31.2), Vector2(2.2, 1.1), 0.0, TAU, 10), tint.lightened(0.7))
	pen.outline(nozzle)
	var centre := Vector2(20, 23)
	var hull := _ellipse(centre, Vector2(12, 11), PI, TAU, 16)
	hull.append_array(_ellipse(centre, Vector2(12, 5), 0.0, PI, 12).slice(1, 12))
	pen.shape(hull, tint)
	pen.facet(_ellipse(centre, Vector2(12, 5), 0.0, PI, 12), tint.darkened(0.18))
	if not pen.shadow:
		pen.add_stroke(pen.place(_ellipse(centre, Vector2(10.3, 9.3), PI * 1.06, PI * 1.94, 12)), 1.5,
			tint.lightened(0.55), false)
	pen.facet(_ellipse(Vector2(15, 14.8), Vector2(3.2, 1.6), 0.0, TAU, 12, -0.5), tint.lightened(0.7))
	# A visor band round the dome's middle, dipping towards the eye at its front.
	var visor := _ellipse(Vector2(20, 11), Vector2(11, 7.5), PI * 0.2, PI * 0.8, 8)
	visor.append_array(_ellipse(Vector2(20, 12), Vector2(11.5, 10.5), PI * 0.8, PI * 0.2, 8))
	pen.facet(visor, Hud.INK)
	pen.facet(_ellipse(Vector2(20, 20.5), Vector2(3.8, 1.6), 0.0, TAU, 12), Color.WHITE)
	pen.outline(hull)
	for side: float in [-1.0, 1.0]:
		pen.band(PackedVector2Array([Vector2(20 + side * 8.0, 17.5), Vector2(20 + side * 14.0, 13)]), tint.darkened(0.25))
	for side: float in [-1.0, 1.0]:
		var hub := Vector2(20 + side * 14.0, 11.5)
		var disc := _ellipse(hub, Vector2(6.0, 2.6), 0.0, TAU, 16)
		pen.shape(disc, tint.lightened(0.55))
		pen.facet(_ellipse(hub + Vector2(-1.8, -0.8), Vector2(2.6, 0.9), 0.0, TAU, 10), Color(1, 1, 1, 0.85))
		pen.outline(disc)


## The army's figure: a head over a pair of rounded shoulders, each with a lighter facet.
static func _figure(pen: Pen, tint: Color) -> void:
	var shoulders := _ellipse(Vector2(20, 30), Vector2(13, 9), PI, TAU, 12)
	shoulders.append_array(PackedVector2Array([Vector2(33, 37), Vector2(7, 37)]))
	pen.shape(shoulders, tint)
	pen.facet(_ellipse(Vector2(13, 27), Vector2(3.5, 2), 0.0, TAU, 10, -0.7), tint.lightened(0.5))
	pen.outline(shoulders)
	var head := _ellipse(Vector2(20, 12), Vector2(7, 7), 0.0, TAU, 16)
	pen.shape(head, tint)
	pen.facet(_ellipse(Vector2(17, 9), Vector2(2.6, 1.8), 0.0, TAU, 10, -0.6), tint.lightened(0.55))
	pen.outline(head)


## A human unit: a space helmet from the front, a dome over two cheek guards, with a cyan visor
## across it and a glint on the dome and the visor.
static func _helmet(pen: Pen, tint: Color) -> void:
	var helmet := _ellipse(Vector2(20, 21), Vector2(14, 14), PI, TAU, 16)
	helmet.append_array(PackedVector2Array([Vector2(33, 30), Vector2(28, 34), Vector2(12, 34), Vector2(7, 30)]))
	pen.shape(helmet, tint)
	pen.facet(_ellipse(Vector2(14, 12), Vector2(4, 2.4), 0.0, TAU, 10, -0.6), tint.lightened(0.55))
	pen.outline(helmet)
	var visor := PackedVector2Array([Vector2(9, 18), Vector2(31, 18), Vector2(29, 27), Vector2(11, 27)])
	pen.facet(visor, Hud.ACCENT)
	pen.facet(PackedVector2Array([Vector2(12, 19.5), Vector2(17, 19.5), Vector2(15, 25), Vector2(13, 25)]),
		Color(1, 1, 1, 0.7))
	pen.outline(visor)


## A piloted unit: a cyan cockpit canopy on a hull over a track with three wheels.
static func _tracked(pen: Pen, tint: Color) -> void:
	var track := _ellipse(Vector2(9, 32), Vector2(5, 5), PI / 2.0, PI * 1.5, 6)
	track.append_array(_ellipse(Vector2(31, 32), Vector2(5, 5), -PI / 2.0, PI / 2.0, 6))
	pen.shape(track, tint.darkened(0.35))
	for x: float in [10.0, 20.0, 30.0]:
		pen.facet(_ellipse(Vector2(x, 32), Vector2(3, 3), 0.0, TAU, 10), tint.lightened(0.25))
		pen.facet(_ellipse(Vector2(x, 32), Vector2(1.2, 1.2), 0.0, TAU, 8), Hud.INK)
	pen.outline(track)
	var hull := PackedVector2Array([Vector2(6, 27), Vector2(34, 27), Vector2(30, 19), Vector2(10, 19)])
	pen.shape(hull, tint)
	pen.facet(PackedVector2Array([Vector2(10, 19), Vector2(14, 19), Vector2(11, 27), Vector2(6, 27)]),
		tint.lightened(0.45))
	pen.outline(hull)
	var canopy := _ellipse(Vector2(20, 19), Vector2(8, 9), PI, TAU, 12)
	pen.shape(canopy, Hud.ACCENT)
	pen.facet(_ellipse(Vector2(17, 14), Vector2(2.4, 1.5), 0.0, TAU, 10, -0.7), Color(1, 1, 1, 0.8))
	pen.outline(canopy)


## An autonomous unit: a block head with a sensor slit and a cyan eye, an antenna on top, on a
## neck and a shoulder bar.
static func _sensor_head(pen: Pen, tint: Color) -> void:
	var shoulders := PackedVector2Array([Vector2(7, 38), Vector2(33, 38), Vector2(30, 32), Vector2(10, 32)])
	pen.shape(shoulders, tint.darkened(0.3))
	pen.outline(shoulders)
	pen.band(PackedVector2Array([Vector2(20, 8), Vector2(20, 3.5)]), tint.lightened(0.3))
	var bulb := _ellipse(Vector2(20, 3.5), Vector2(2.4, 2.4), 0.0, TAU, 10)
	pen.shape(bulb, Hud.ACCENT)
	pen.outline(bulb)
	var head := _rounded_square(Vector2(20, 19), 12.0, 4.0)
	pen.shape(head, tint)
	pen.facet(_ellipse(Vector2(13, 11), Vector2(3, 1.8), 0.0, TAU, 10, -0.6), tint.lightened(0.55))
	pen.outline(head)
	var slit := PackedVector2Array([Vector2(11, 16), Vector2(29, 16), Vector2(29, 22), Vector2(11, 22)])
	pen.facet(slit, Hud.INK)
	pen.facet(_ellipse(Vector2(20, 19), Vector2(3.6, 2.2), 0.0, TAU, 12), Hud.ACCENT)
	pen.facet(_ellipse(Vector2(19, 18.3), Vector2(1.2, 0.8), 0.0, TAU, 8), Color.WHITE)


## The air mark: a swept wing, white with its ink outline, at the box's lower right.
static func _wing(pen: Pen) -> void:
	var wing := PackedVector2Array([Vector2(24, 31), Vector2(39, 24), Vector2(36, 31), Vector2(28, 38)])
	pen.shape(wing, Hud.TEXT)
	pen.outline(wing)


## A square `half` across each way of `centre`, its corners rounded to `radius`.
static func _rounded_square(centre: Vector2, half: float, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inset := half - radius
	for corner: int in 4:
		var angle := -PI / 2.0 + corner * PI / 2.0
		var at := centre + Vector2(signf(cos(angle + PI / 4.0)), signf(sin(angle + PI / 4.0))) * inset
		points.append_array(_ellipse(at, Vector2(radius, radius), angle, angle + PI / 2.0, 4))
	return points


## The repair swarm: three fat nanites of three sizes overlapping, the largest in front with a
## white "+" on it in its ink outline.
static func _swarm(pen: Pen, tint: Color) -> void:
	_blob(pen, Vector2(24, 9.5), 6.5, tint)
	_blob(pen, Vector2(30, 22), 8.0, tint)
	_blob(pen, Vector2(15.5, 25), 12.5, tint)
	var cross := _plus(Vector2(15.5, 25.5), 8.0, 3.1)
	pen.shape(cross, Color.WHITE)
	pen.outline(cross)


## A round nanite: its fill, a darker band across its lower part, a white highlight at its upper
## left and its ink outline.
static func _blob(pen: Pen, centre: Vector2, radius: float, tint: Color) -> void:
	var disc := _ellipse(centre, Vector2(radius, radius), 0.0, TAU, 20)
	pen.shape(disc, tint)
	pen.facet(_cap(centre, radius, radius * 0.35, false, 10), tint.darkened(0.3))
	pen.facet(_ellipse(centre + Vector2(-0.38, -0.4) * radius, Vector2(0.3, 0.2) * radius, 0.0, TAU, 10, -0.7),
		Color.WHITE)
	pen.outline(disc)


## The EMP: three thick concentric arcs opening upward, each with a lighter inner edge, and a slim
## white zigzag bolt down through them, its jog below the innermost arc so all three show either
## side of it.
static func _burst(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 2)
	var half := deg_to_rad(38.0)
	for band: Vector2 in [Vector2(9, 15), Vector2(18, 24), Vector2(27, 33)]:
		var arc := _arc_band(centre, band.x, band.y, PI / 2.0 - half, PI / 2.0 + half, 10)
		pen.shape(arc, tint)
		pen.facet(_arc_band(centre, band.x, band.x + 2.5, PI / 2.0 - half, PI / 2.0 + half, 10),
			tint.lightened(0.55))
		pen.outline(arc)
	var bolt := PackedVector2Array([Vector2(21, 0), Vector2(26, 0), Vector2(22.5, 20), Vector2(27, 20),
		Vector2(16, 40), Vector2(18, 26), Vector2(14, 26)])
	pen.shape(bolt, Color.WHITE)
	pen.facet(PackedVector2Array([Vector2(22.5, 20), Vector2(27, 20), Vector2(16, 40), Vector2(20, 25)]),
		tint.lightened(0.7))
	pen.outline(bolt)


## The orbital strike: a thick white crosshair, a ring in four arcs between four bars round a dot
## of the colour, broken by a hazard-yellow bolt falling into it from the upper right, its corner
## kept inside a coin's ring.
static func _strike(pen: Pen, tint: Color) -> void:
	var centre := Vector2(19, 21)
	var gap := deg_to_rad(16.0)
	for quarter: int in 4:
		var from := quarter * PI / 2.0
		var arc := _arc_band(centre, 8.5, 14.0, from + gap, from + PI / 2.0 - gap, 6)
		pen.shape(arc, Color.WHITE)
		pen.outline(arc)
	for along: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var side := along.orthogonal() * 2.6
		var bar := PackedVector2Array([centre + along * 5.0 + side, centre + along * 18.5 + side,
			centre + along * 18.5 - side, centre + along * 5.0 - side])
		pen.shape(bar, Color.WHITE)
		pen.outline(bar)
	var dot := _ellipse(centre, Vector2(3, 3), 0.0, TAU, 12)
	pen.shape(dot, tint)
	pen.outline(dot)
	var bolt := PackedVector2Array([Vector2(28, 3), Vector2(37, 3), Vector2(31, 12), Vector2(36, 12),
		Vector2(19, 27), Vector2(23.5, 16), Vector2(19, 16)])
	pen.shape(bolt, MaterialKit.HAZARD)
	pen.facet(PackedVector2Array([Vector2(28, 3), Vector2(32, 3), Vector2(23.5, 16), Vector2(19, 16)]),
		MaterialKit.HAZARD.lightened(0.55))
	pen.outline(bolt)


## A "+" round `centre`, each arm `reach` from it and `half` either side of its axis.
static func _plus(centre: Vector2, reach: float, half: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(-half, -reach), Vector2(half, -reach), Vector2(half, -half),
			Vector2(reach, -half), Vector2(reach, half), Vector2(half, half), Vector2(half, reach),
			Vector2(-half, reach), Vector2(-half, half), Vector2(-reach, half), Vector2(-reach, -half),
			Vector2(-half, -half)]:
		points.append(centre + corner)
	return points


## A thick arc round `centre` between radii `inner` and `outer`, from angle `from` to `to`: the
## outer edge in `steps`, then the inner one back.
static func _arc_band(centre: Vector2, inner: float, outer: float, from: float, to: float,
		steps: int) -> PackedVector2Array:
	var points := _ellipse(centre, Vector2(outer, outer), from, to, steps)
	var back := _ellipse(centre, Vector2(inner, inner), from, to, steps)
	back.reverse()
	points.append_array(back)
	return points


## A padlock: a thick shackle arch over a chunky body with a lighter left face and an ink keyhole.
static func _padlock(pen: Pen, tint: Color) -> void:
	var shackle := _ellipse(Vector2(20, 18), Vector2(11.5, 11.5), PI, TAU, 12)
	shackle.append_array(PackedVector2Array([Vector2(31.5, 22), Vector2(26.5, 22)]))
	var inside := _ellipse(Vector2(20, 18), Vector2(6.5, 6.5), PI, TAU, 12)
	inside.reverse()
	shackle.append_array(inside)
	shackle.append_array(PackedVector2Array([Vector2(13.5, 22), Vector2(8.5, 22)]))
	pen.shape(shackle, tint.lightened(0.35))
	pen.outline(shackle)
	var body := _rounded_rect(Rect2(6, 19, 28, 19), 4.0)
	pen.shape(body, tint)
	pen.facet(PackedVector2Array([Vector2(9, 21), Vector2(15, 21), Vector2(15, 36), Vector2(9, 36)]),
		tint.lightened(0.4))
	pen.outline(body)
	pen.facet(PackedVector2Array([Vector2(18.2, 27), Vector2(21.8, 27), Vector2(22.5, 33), Vector2(17.5, 33)]),
		Hud.INK)
	pen.facet(_ellipse(Vector2(20, 26), Vector2(3, 3), 0.0, TAU, 10), Hud.INK)


## A clock: a disc with a lighter cel band across its top, four ink ticks, a long ink hand up, a
## short one to the right and an ink hub.
static func _clock(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 20)
	var face := _ellipse(centre, Vector2(17, 17), 0.0, TAU, 28)
	pen.shape(face, tint)
	pen.facet(_cap(centre, 17.0, 4.0, true, 14), tint.lightened(0.35))
	pen.outline(face)
	for along: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		pen.edge(PackedVector2Array([centre + along * 11.5, centre + along * 14.5]))
	pen.band(PackedVector2Array([centre, centre + Vector2(0, -11)]), Hud.INK)
	pen.band(PackedVector2Array([centre, centre + Vector2(8, 3.5)]), Hud.INK)
	pen.facet(_ellipse(centre, Vector2(3, 3), 0.0, TAU, 10), Hud.INK)


## A right-pointing chevron: two thick arms meeting at a point 12 units ahead of their notch, the
## upper arm lighter.
static func _chevron(pen: Pen, tint: Color) -> void:
	var outline := PackedVector2Array([Vector2(10, 5), Vector2(20, 5), Vector2(32, 20), Vector2(20, 35),
		Vector2(10, 35), Vector2(22, 20)])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([Vector2(10, 5), Vector2(20, 5), Vector2(32, 20), Vector2(22, 20)]),
		tint.lightened(0.4))
	pen.outline(outline)


## A five-point star: a lighter facet down one side of each point, and the ink outline.
static func _star(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 21.5)
	var points := PackedVector2Array()
	for k: int in 10:
		var radius := 19.0 if k % 2 == 0 else 8.0
		var angle := -PI / 2.0 + PI * k / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	pen.shape(points, tint)
	for k: int in 5:
		pen.facet(PackedVector2Array([points[k * 2], centre, points[(k * 2 + 9) % 10]]), tint.lightened(0.35))
	pen.outline(points)


## A comic skull: a round cranium over a narrower jaw, a lighter facet on the brow, ink eye
## sockets, nose and teeth.
static func _skull(pen: Pen, tint: Color) -> void:
	var outline := _ellipse(Vector2(20, 17), Vector2(15, 14), PI * 0.72, PI * 2.28, 20)
	outline.append_array(PackedVector2Array([Vector2(28, 30), Vector2(27, 37), Vector2(13, 37), Vector2(12, 30)]))
	pen.shape(outline, tint)
	pen.facet(_ellipse(Vector2(13, 9.5), Vector2(4.5, 2.6), 0.0, TAU, 10, -0.6), tint.lightened(0.6))
	pen.outline(outline)
	for x: float in [13.5, 26.5]:
		pen.facet(_ellipse(Vector2(x, 19.5), Vector2(4.6, 5), 0.0, TAU, 12), Hud.INK)
	pen.facet(PackedVector2Array([Vector2(20, 24.5), Vector2(22.5, 28.5), Vector2(17.5, 28.5)]), Hud.INK)
	for x: float in [16.5, 20.0, 23.5]:
		pen.edge(PackedVector2Array([Vector2(x, 31.5), Vector2(x, 37)]))


## An "x": two thick bars crossed at the box's centre, the upper left arm lighter.
static func _cross(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 20)
	var outline := PackedVector2Array()
	for point: Vector2 in _plus(centre, 17.0, 5.0):
		outline.append(centre + (point - centre).rotated(PI / 4.0))
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([outline[9], outline[10], outline[11], centre]), tint.lightened(0.4))
	pen.outline(outline)


## `rect` with its corners rounded to `radius`.
static func _rounded_rect(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners: Array[Vector2] = [rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius),
		Vector2(rect.position.x + radius, rect.end.y - radius)]
	for k: int in 4:
		var angle := PI + k * PI / 2.0
		points.append_array(_ellipse(corners[k], Vector2(radius, radius), angle, angle + PI / 2.0, 4))
	return points


## A cut gem, for a resource with no silhouette of its own.
static func _gem(pen: Pen, tint: Color) -> void:
	var outline := PackedVector2Array([Vector2(12, 8), Vector2(28, 8), Vector2(35, 17), Vector2(20, 35), Vector2(5, 17)])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([Vector2(12, 8), Vector2(20, 17), Vector2(5, 17)]), tint.lightened(0.45))
	pen.edge(PackedVector2Array([Vector2(5, 17), Vector2(35, 17)]))
	pen.outline(outline)


## The part of the circle round `centre`, `radius` across, beyond a chord `from_centre` from its
## centre, above it when `top`, else below it: the arc in `steps`, closed along the chord.
static func _cap(centre: Vector2, radius: float, from_centre: float, top: bool, steps: int) -> PackedVector2Array:
	var half := acos(clampf(from_centre / radius, -1.0, 1.0))
	var middle := -PI / 2.0 if top else PI / 2.0
	return _ellipse(centre, Vector2(radius, radius), middle - half, middle + half, steps)


## Points along an ellipse round `centre` from angle `from` to `to`, rotated by `tilt`; a whole
## turn does not repeat its first point.
static func _ellipse(centre: Vector2, radii: Vector2, from: float, to: float, steps: int,
		tilt: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := steps if is_equal_approx(to - from, TAU) else steps + 1
	for i: int in count:
		var angle := from + (to - from) * i / steps
		points.append(centre + (Vector2(cos(angle), sin(angle)) * radii).rotated(tilt))
	return points


## Builds an icon (or the drone meter's slots) as one triangle array, so it costs one draw call: the
## renderer draws every draw_polygon and draw_polyline on its own. Shapes are given in box
## units (fit() maps the box onto a rect); in the shadow pass only shadows are added. Strokes
## and shadows get a 1 px feather that fades to nothing, in place of the renderer's
## antialiasing; fills are left hard, since their outlines cover their edges.
class Pen:
	const FEATHER := 1.0

	var shadow: bool = false
	var _origin: Vector2 = Vector2.ZERO
	var _scale: float = 1.0
	## Lines thin with the icon below full size, so a small one is not all ink.
	var _thinning: float = 1.0
	var _points: PackedVector2Array = PackedVector2Array()
	var _colors: PackedColorArray = PackedColorArray()
	var _indices: PackedInt32Array = PackedInt32Array()

	## Maps the 40-unit box onto `rect`, centred, at the scale of its shorter side.
	func fit(rect: Rect2) -> void:
		_scale = minf(rect.size.x, rect.size.y) / HudIcon.BOX
		_origin = rect.position + (rect.size - Vector2.ONE * HudIcon.BOX * _scale) * 0.5
		_thinning = clampf(_scale, 0.6, 1.0)

	## A part's silhouette: its shadow in the shadow pass, else its flat fill.
	func shape(points: PackedVector2Array, fill: Color) -> void:
		if shadow:
			add_fill(place(points, HudIcon.SHADOW_OFFSET), Hud.SHADOW, true)
		else:
			add_fill(place(points), fill, false)

	func facet(points: PackedVector2Array, fill: Color) -> void:
		if not shadow:
			add_fill(place(points), fill, false)

	## An ink line between facets.
	func edge(points: PackedVector2Array) -> void:
		if not shadow:
			add_stroke(place(points), HudIcon.EDGE * _thinning, Hud.INK, false)

	func outline(points: PackedVector2Array, width: float = HudIcon.OUTLINE) -> void:
		if not shadow:
			add_stroke(place(points), width * _thinning, Hud.INK, true)

	## An open stroke with a shadow of its own: an ink band, and a core of `fill` unless the
	## band is ink itself.
	func band(points: PackedVector2Array, fill: Color) -> void:
		var width := 5.0 * _thinning
		if shadow:
			add_stroke(place(points, HudIcon.SHADOW_OFFSET), width, Hud.SHADOW, false)
			return
		add_stroke(place(points), width, Hud.INK, false)
		if fill != Hud.INK:
			add_stroke(place(points), width - 3.0 * _thinning, fill, false)

	func place(points: PackedVector2Array, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
		var placed := PackedVector2Array()
		for point: Vector2 in points:
			placed.append(_origin + point * _scale + offset)
		return placed

	## A filled simple polygon, in pixels; `feathered` fades its edge out over FEATHER.
	func add_fill(at: PackedVector2Array, color: Color, feathered: bool) -> void:
		var base := _points.size()
		for point: Vector2 in at:
			_points.append(point)
			_colors.append(color)
		for index: int in Geometry2D.triangulate_polygon(at):
			_indices.append(base + index)
		if not feathered:
			return
		var count := at.size()
		# The normals point out of one winding and into the other.
		var outward := -1.0 if Geometry2D.is_point_in_polygon(at[0] + _normal(at, 0, true) * 0.5, at) else 1.0
		var fringe := _points.size()
		for i: int in count:
			_points.append(at[i] + _normal(at, i, true) * _miter(at, i, true) * FEATHER * outward)
			_colors.append(Color(color, 0.0))
		for i: int in count:
			var j := (i + 1) % count
			_quad(base + i, base + j, fringe + j, fringe + i)

	## A stroke along `at`, in pixels, `width` wide, with a feather either side.
	func add_stroke(at: PackedVector2Array, width: float, color: Color, closed: bool) -> void:
		var count := at.size()
		var base := _points.size()
		var clear := Color(color, 0.0)
		for i: int in count:
			var normal := _normal(at, i, closed)
			var reach := _miter(at, i, closed)
			var half := width * 0.5 * reach
			var fade := (width * 0.5 + FEATHER) * reach
			for side: float in [fade, half, -half, -fade]:
				_points.append(at[i] + normal * side)
			_colors.append_array(PackedColorArray([clear, color, color, clear]))
		var segments := count if closed else count - 1
		for i: int in segments:
			var a := base + i * 4
			var b := base + ((i + 1) % count) * 4
			for lane: int in 3:
				_quad(a + lane, a + lane + 1, b + lane + 1, b + lane)

	## How many triangles have been added, for the harness.
	func triangle_count() -> int:
		return _indices.size() / 3

	## Submits everything added as one triangle array on `item`'s canvas item.
	func draw(item: CanvasItem) -> void:
		if not _indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), _indices, _points, _colors)

	func _quad(a: int, b: int, c: int, d: int) -> void:
		_indices.append_array(PackedInt32Array([a, b, c, a, c, d]))

	## The unit normal at point `i`: across the line there, or between its two segments at a
	## corner.
	func _normal(at: PackedVector2Array, i: int, closed: bool) -> Vector2:
		var count := at.size()
		var before := at[i] - at[(i - 1 + count) % count] if closed or i > 0 else Vector2.ZERO
		var after := at[(i + 1) % count] - at[i] if closed or i < count - 1 else Vector2.ZERO
		var sum := before.normalized().orthogonal() + after.normalized().orthogonal()
		return sum.normalized()

	## How much farther than on a straight line an edge sits from point `i` along its normal,
	## so a corner's sides keep their width; at most 3, for a very sharp corner.
	func _miter(at: PackedVector2Array, i: int, closed: bool) -> float:
		var count := at.size()
		if not closed and (i == 0 or i == count - 1):
			return 1.0
		var after := (at[(i + 1) % count] - at[i]).normalized().orthogonal()
		return 1.0 / maxf(_normal(at, i, closed).dot(after), 1.0 / 3.0)
