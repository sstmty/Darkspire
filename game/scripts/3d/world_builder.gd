extends "res://scripts/3d/rig.gd"
## Builds a 3D level from maps.gd: terrain along the road, the village, ruins, the bridge, Coals of Memory,
## the boss arena and the Spire on the horizon. Also answers road geometry questions for the game logic.

const MAPS := preload("res://scripts/3d/maps.gd")
const CELL := 2.0

var map: Dictionary
var theme_name := ""
var pts: Array[Vector2] = []
var cum: Array[float] = []
var length := 0.0
var width := 9.0
var noise := FastNoiseLite.new()
var fires: Array[OmniLight3D] = []
var coal_nodes: Array[Node3D] = []
var arena_walls: Array[CollisionShape3D] = []
var arena_fog: CPUParticles3D
var rng := RandomNumberGenerator.new()
var _t := 0.0
var _occupied: Array[Vector3] = []


func setup_map(id: String) -> void:
	map = MAPS.MAPS[id]
	theme_name = map["theme"]
	width = map["width"]
	for p in map["road"]:
		pts.append(p)
	cum = [0.0]
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	length = cum[-1]
	noise.seed = 7 if id == "hollowd" else 11
	noise.frequency = 0.03
	rng.seed = hash(id)


# ---------------------------------------------------------------- road geometry

## Road distance s and signed sideways offset (+ = right) of a world point.
func project(p: Vector2) -> Vector2:
	var best := 1e20
	var out := Vector2.ZERO
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var c := a + ab * t
		var dd := p.distance_squared_to(c)
		if dd < best:
			best = dd
			var f := ab.normalized()
			var right := Vector2(-f.y, f.x)
			out = Vector2(cum[i] + ab.length() * t, (p - c).dot(right))
	return out


func dir_at(s: float) -> Vector2:
	for i in range(pts.size() - 1):
		if s <= cum[i + 1] or i == pts.size() - 2:
			return (pts[i + 1] - pts[i]).normalized()
	return Vector2(0, -1)


func flat_at(s: float, x: float) -> Vector2:
	s = clampf(s, 0.0, length)
	for i in range(pts.size() - 1):
		if s <= cum[i + 1] or i == pts.size() - 2:
			var f := (pts[i + 1] - pts[i]).normalized()
			var c := pts[i] + f * (s - cum[i])
			return c + Vector2(-f.y, f.x) * x
	return pts[-1]


func point_at(s: float, x: float) -> Vector3:
	var f := flat_at(s, x)
	return Vector3(f.x, height(f.x, f.y), f.y)


## Yaw that makes a -Z-facing node look along the road (or back toward the road with face_road).
func yaw_along(s: float) -> float:
	var f := dir_at(s)
	return atan2(-f.x, -f.y)


func in_chasm(s: float) -> bool:
	return map.has("chasm") and s > map["chasm"][0] and s < map["chasm"][1]


func height(x: float, z: float) -> float:
	var pr := project(Vector2(x, z))
	var s := pr.x
	var d := absf(pr.y)
	var n := noise.get_noise_2d(x, z)
	if map.has("chasm"):  # the bridge ends sit flush with a level road
		n *= 1.0 - _smooth(map["chasm"][0] - 14.0, map["chasm"][0] - 8.0, s) * (1.0 - _smooth(map["chasm"][1] + 8.0, map["chasm"][1] + 14.0, s))
	var h := n * 0.4
	var edge := _smooth(width, width + 9.0, d)
	h += edge * (6.0 + noise.get_noise_2d(x * 2.0, z * 2.0) * 4.0)
	if map.has("arena"):
		var ac := flat_at(map["arena"][0], 0.0)
		var da := Vector2(x, z).distance_to(ac)
		var r: float = map["arena"][1]
		h = lerpf(n * 0.2, h, _smooth(r + 1.0, r + 6.0, da))
	if map.has("chasm"):
		var s0: float = map["chasm"][0]
		var s1: float = map["chasm"][1]
		var k := _smooth(s0 - 1.0, s0 + 3.0, s) * (1.0 - _smooth(s1 - 3.0, s1 + 1.0, s))
		h = lerpf(h, -45.0, k)
	return h


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- terrain

func build_world() -> void:
	_build_terrain()
	if map.has("chasm"):
		_build_bridge()
	for p in map["props"]:
		_prop(p[0], float(p[1]), float(p[2]), true)
	_scatter()
	for c in map["coals"]:
		coal_nodes.append(_coal(point_at(c[0], c[1])))
	_build_arena()
	_build_spire()
	_exit_marker(point_at(map["exit"], 0.0))


func _build_terrain() -> void:
	var minx := 1e9
	var maxx := -1e9
	var minz := 1e9
	var maxz := -1e9
	for p in pts:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
		minz = minf(minz, p.y)
		maxz = maxf(maxz, p.y)
	var margin := width + 40.0
	minx -= margin
	maxx += margin
	minz -= margin
	maxz += margin
	var nx := int((maxx - minx) / CELL) + 1
	var nz := int((maxz - minz) / CELL) + 1
	var hs := PackedFloat32Array()
	hs.resize(nx * nz)
	var cols := PackedColorArray()
	cols.resize(nx * nz)
	var hollowd := theme_name == "hollowd"
	var c_ground := Color("3a2f28") if hollowd else Color("4a4d52")
	var c_ground2 := Color("2a2220") if hollowd else Color("5a5e64")
	var c_road := Color("5c4634") if hollowd else Color("5e574c")
	var c_rock := Color("40363a") if hollowd else Color("3a3c42")
	for iz in nz:
		for ix in nx:
			var x := minx + ix * CELL
			var z := minz + iz * CELL
			var h := height(x, z)
			hs[iz * nx + ix] = h
			var pr := project(Vector2(x, z))
			var n := noise.get_noise_2d(x * 3.0, z * 3.0)
			var c := c_ground.lerp(c_ground2, clampf(n * 1.5 + 0.5, 0.0, 1.0))
			var road := 1.0 - _smooth(2.2, 3.6, absf(pr.y))
			if not in_chasm(pr.x) and pr.x > -2.0 and pr.x < length + 2.0:
				c = c.lerp(c_road, road * 0.9)
			c = c.lerp(c_rock, _smooth(1.5, 5.0, h))
			if h < -3.0:
				c = c_rock.darkened(clampf(-h / 40.0, 0.0, 0.8))
			cols[iz * nx + ix] = c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz - 1:
		for ix in nx - 1:
			var i00 := iz * nx + ix
			var quad := [
				[Vector3(minx + ix * CELL, hs[i00], minz + iz * CELL), cols[i00]],
				[Vector3(minx + (ix + 1) * CELL, hs[i00 + 1], minz + iz * CELL), cols[i00 + 1]],
				[Vector3(minx + ix * CELL, hs[i00 + nx], minz + (iz + 1) * CELL), cols[i00 + nx]],
				[Vector3(minx + (ix + 1) * CELL, hs[i00 + nx + 1], minz + (iz + 1) * CELL), cols[i00 + nx + 1]],
			]
			# flat-shaded low-poly: every triangle gets its own colour
			for tri in [[0, 1, 2], [1, 3, 2]]:
				var col: Color = (quad[tri[0]][1] + quad[tri[1]][1] + quad[tri[2]][1]) / 3.0
				for k in tri:
					st.set_color(col)
					st.add_vertex(quad[k][0])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	mi.material_override = m
	add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


# ---------------------------------------------------------------- props

func _place(node: Node3D, s: float, x: float, face_road: bool) -> void:
	var p := point_at(s, x)
	node.position = p
	var yaw := yaw_along(s)
	if face_road:
		yaw += PI / 2.0 if x > 0.0 else -PI / 2.0
	node.rotation.y = yaw + rng.randf_range(-0.12, 0.12)
	_occupied.append(p)


func _solid(node: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)
	node.add_child(body)


func _prop(kind: String, s: float, x: float, solid: bool) -> void:
	var n := Node3D.new()
	add_child(n)
	_place(n, s, x, kind in ["house", "house_burnt", "tower", "cart", "fence"])
	match kind:
		"house":
			_house(n, false, solid)
		"house_burnt":
			_house(n, true, solid)
		"tree":
			_tree(n, solid)
		"stump":
			cyl(n, 0.25, 0.32, 0.5, Vector3(0, 0.25, 0), mat(Color("3a2a20")))
		"rock":
			var sc := rng.randf_range(0.6, 1.8)
			ball(n, 0.8 * sc, Vector3(0, 0.3 * sc, 0), mat(Color("4a4448") if theme_name == "hollowd" else Color("54585e"), 0.95), Vector3(1.3, 0.8, 1.0), 6)
			if solid:
				_solid(n, Vector3(1.6, 1.2, 1.2) * sc, Vector3(0, 0.5 * sc, 0))
		"grave":
			var m_stone := mat(Color("5a5658"), 0.9)
			if rng.randf() < 0.5:
				box(n, Vector3(0.5, 0.8, 0.15), Vector3(0, 0.4, 0), m_stone, Vector3(rng.randf_range(-0.2, 0.2), 0, 0))
			else:
				box(n, Vector3(0.12, 1.0, 0.12), Vector3(0, 0.5, 0), m_stone)
				box(n, Vector3(0.5, 0.12, 0.12), Vector3(0, 0.72, 0), m_stone)
			box(n, Vector3(0.6, 0.12, 1.2), Vector3(0, 0.05, 0.5), mat(Color("3a2e28")))
		"fence":
			var wood := mat(Color("4a3626"))
			for k in 6:
				box(n, Vector3(0.12, 1.1, 0.12), Vector3(-3.0 + k * 1.2, 0.55, 0), wood, Vector3(0, 0, rng.randf_range(-0.12, 0.12)))
			for yy in [0.45, 0.85]:
				box(n, Vector3(6.2, 0.08, 0.06), Vector3(0, yy, 0), wood, Vector3(0, 0, rng.randf_range(-0.04, 0.04)))
			if solid:
				_solid(n, Vector3(6.2, 1.1, 0.3), Vector3(0, 0.55, 0))
		"cart":
			var wood := mat(Color("5a3e28"))
			box(n, Vector3(1.6, 0.15, 2.6), Vector3(0, 0.8, 0), wood)
			for side in [-1, 1]:
				box(n, Vector3(0.08, 0.5, 2.6), Vector3(side * 0.78, 1.05, 0), wood)
				cyl(n, 0.55, 0.55, 0.1, Vector3(side * 0.9, 0.55, 0.3), mat(Color("3a2a1c")), Vector3(0, 0, PI / 2.0), 10)
			box(n, Vector3(0.08, 0.08, 2.0), Vector3(-0.3, 0.6, -2.1), wood, Vector3(0.3, 0, 0))
			box(n, Vector3(0.08, 0.08, 2.0), Vector3(0.3, 0.6, -2.1), wood, Vector3(0.3, 0, 0))
			for k in 3:
				box(n, Vector3(0.5, 0.4, 0.5), Vector3(rng.randf_range(-0.4, 0.4), 1.1, -0.8 + k * 0.7), mat(Color("6a5a40")))
			if solid:
				_solid(n, Vector3(1.8, 1.4, 2.8), Vector3(0, 0.7, 0))
		"well":
			var stone := mat(Color("5a5450"), 0.9)
			cyl(n, 1.0, 1.1, 0.9, Vector3(0, 0.45, 0), stone, Vector3.ZERO, 10)
			cyl(n, 0.8, 0.8, 0.05, Vector3(0, 0.88, 0), mat(Color("0a0a10")), Vector3.ZERO, 10)
			for side in [-1, 1]:
				box(n, Vector3(0.12, 1.6, 0.12), Vector3(side * 0.9, 1.4, 0), mat(Color("4a3626")))
			box(n, Vector3(2.2, 0.5, 1.2), Vector3(0, 2.3, 0), mat(Color("3a2a22")), Vector3(0, 0, 0))
			if solid:
				_solid(n, Vector3(2.2, 1.0, 2.2), Vector3(0, 0.5, 0))
		"banner":
			cyl(n, 0.06, 0.08, 4.0, Vector3(0, 2.0, 0), mat(Color("3a2a20")))
			box(n, Vector3(0.9, 0.06, 0.06), Vector3(0.4, 3.9, 0), mat(Color("3a2a20")))
			var cloth := box(n, Vector3(0.8, 1.8, 0.03), Vector3(0.45, 2.95, 0), mat(Color("6a1f1a") if theme_name == "hollowd" else Color("3a4458")))
			cloth.set_meta("sway", true)
			box(n, Vector3(0.3, 0.3, 0.035), Vector3(0.45, 3.1, 0), mat(Color("1a1414")))
			_torch(n, Vector3(0, 0, 0.4))
		"tower":
			var stone := mat(Color("5a5a5e"), 0.95)
			for k in 5:
				var w := 4.0 - k * 0.15
				box(n, Vector3(w, 1.6, w), Vector3(rng.randf_range(-0.1, 0.1), 0.8 + k * 1.6, 0), stone)
			for k in 4:
				box(n, Vector3(0.9, 1.2, 0.9), Vector3(-1.4 + (k % 2) * 2.8, 8.6, -1.4 + (k / 2) * 2.8), stone)
			box(n, Vector3(0.6, 1.8, 0.2), Vector3(0, 1.0, -2.0), mat(Color("0a0808")))
			if solid:
				_solid(n, Vector3(4.0, 9.0, 4.0), Vector3(0, 4.5, 0))


func _house(n: Node3D, burnt: bool, solid: bool) -> void:
	var w := rng.randf_range(4.0, 5.5)
	var d := rng.randf_range(5.0, 6.5)
	var h := rng.randf_range(2.6, 3.2)
	var wall := mat(Color("2a2220") if burnt else Color("8a7a62"), 0.95)
	var beam := mat(Color("140e0c") if burnt else Color("3a2618"), 0.9)
	var roof := mat(Color("1a1412") if burnt else Color("5a3a26"), 0.95)
	var stone := mat(Color("3a3434") if burnt else Color("5a5450"), 0.95)
	box(n, Vector3(w + 0.3, 0.5, d + 0.3), Vector3(0, 0.25, 0), stone)
	box(n, Vector3(w, h, d), Vector3(0, 0.5 + h / 2.0, 0), wall)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			box(n, Vector3(0.22, h, 0.22), Vector3(cx * w / 2.0, 0.5 + h / 2.0, cz * d / 2.0), beam)
	box(n, Vector3(w + 0.1, 0.18, 0.2), Vector3(0, 0.5 + h * 0.55, -d / 2.0), beam)
	box(n, Vector3(0.18, h, 0.2), Vector3(0, 0.5 + h / 2.0, -d / 2.0), beam, Vector3(0, 0, 0.6))
	box(n, Vector3(1.0, 1.9, 0.12), Vector3(w * 0.25, 1.45, -d / 2.0 - 0.02), mat(Color("0c0808") if burnt else Color("3a2414")))
	for wx in [-w * 0.25]:
		box(n, Vector3(0.7, 0.6, 0.12), Vector3(wx, 0.5 + h * 0.6, -d / 2.0 - 0.02), mat(Color("ff9a4a"), 0.5, 0.0, 2.0) if not burnt else mat(Color("0a0606")))
	var rh := w * 0.42
	for side in [-1, 1]:
		if burnt and side > 0 and rng.randf() < 0.7:
			# fallen slope: a few charred rafters left
			for k in 3:
				box(n, Vector3(0.15, 0.15, d + 0.4), Vector3(side * w * 0.25, 0.5 + h + rh * 0.5 - k * 0.1, -d * 0.3 + k * d * 0.3), beam, Vector3(0, 0, side * -0.75))
			continue
		box(n, Vector3(w * 0.68, 0.18, d + 0.6), Vector3(side * w * 0.25, 0.5 + h + rh * 0.5, 0), roof, Vector3(0, 0, side * -0.72))
	var gable := PrismMesh.new()
	gable.size = Vector3(w, rh, 0.1)
	_add(n, gable, Vector3(0, 0.5 + h + rh / 2.0, -d / 2.0), wall)
	_add(n, gable, Vector3(0, 0.5 + h + rh / 2.0, d / 2.0), wall)
	box(n, Vector3(0.6, 1.8, 0.6), Vector3(-w * 0.3, 0.5 + h + rh * 0.6, d * 0.2), stone)
	if burnt:
		var l := OmniLight3D.new()
		l.light_color = Color("ff7a2a")
		l.light_energy = 1.6
		l.omni_range = 9.0
		l.position = Vector3(0, 2.0, 0)
		n.add_child(l)
		fires.append(l)
		var f := _particles(n, Vector3(0, 1.5, 0), Vector3(w * 0.35, 0.6, d * 0.35), Color(1.0, 0.5, 0.15), 40, 1.0, 2.5, true)
		f.scale_amount_max = 3.0
		_particles(n, Vector3(0, h + 1.5, 0), Vector3(w * 0.3, 0.3, d * 0.3), Color(0.12, 0.1, 0.1, 0.6), 20, 4.0, 1.5, false)
		for k in 4:
			box(n, Vector3(rng.randf_range(0.4, 1.0), 0.25, rng.randf_range(0.3, 0.8)), Vector3(rng.randf_range(-w, w) * 0.6, 0.12, -d / 2.0 - rng.randf_range(0.5, 1.6)), beam, Vector3(0, rng.randf() * 3.0, 0))
	if solid:
		_solid(n, Vector3(w + 0.3, h + 1.0, d + 0.3), Vector3(0, (h + 1.0) / 2.0, 0))


func _tree(n: Node3D, solid: bool) -> void:
	var h := rng.randf_range(3.5, 6.5)
	var bark := mat(Color("2a201a") if theme_name == "hollowd" else Color("3a3632"), 0.95)
	cyl(n, 0.12, 0.3, h, Vector3(0, h / 2.0, 0), bark, Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1)), 6)
	for k in rng.randi_range(3, 5):
		var y := h * rng.randf_range(0.45, 0.9)
		var ln := rng.randf_range(1.0, 2.2)
		var a := rng.randf() * TAU
		var tilt := rng.randf_range(0.6, 1.1)
		var b := cyl(n, 0.03, 0.09, ln, Vector3.ZERO, bark, Vector3.ZERO, 5)
		var dir := Vector3(sin(a) * sin(tilt), cos(tilt), cos(a) * sin(tilt))
		b.position = Vector3(0, y, 0) + dir * ln / 2.0
		var side := dir.cross(Vector3.UP).normalized()
		b.basis = Basis(side, dir, side.cross(dir).normalized())
	if solid:
		_solid(n, Vector3(0.6, h, 0.6), Vector3(0, h / 2.0, 0))


func _scatter() -> void:
	var s := 0.0
	var kinds: Array = map["scatter"]
	while s < length:
		for side in [-1.0, 1.0]:
			var x: float = side * rng.randf_range(width + 1.5, width + 16.0)
			var p := point_at(s, x)
			var crowded := false
			for o in _occupied:
				if o.distance_to(p) < 6.0:
					crowded = true
					break
			if crowded or in_chasm(s):
				continue
			if map.has("arena") and p.distance_to(point_at(map["arena"][0], 0)) < float(map["arena"][1]) + 4.0:
				continue
			_prop(kinds[rng.randi() % kinds.size()], s, x, absf(x) < width + 4.0)
		s += rng.randf_range(5.0, 9.0)


func _torch(n: Node3D, pos: Vector3) -> void:
	box(n, Vector3(0.08, 0.5, 0.08), pos + Vector3(0, 1.6, 0), mat(Color("3a2a20")))
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a4a")
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.position = pos + Vector3(0, 2.0, 0)
	n.add_child(l)
	fires.append(l)
	_particles(n, pos + Vector3(0, 1.95, 0), Vector3(0.06, 0.05, 0.06), Color(1.0, 0.6, 0.2), 14, 0.5, 1.2, true)


func part_mat(c: Color, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color.WHITE
	return m


func _particles(n: Node3D, pos: Vector3, extents: Vector3, c: Color, amount: int, life: float, up: float, add: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = part_mat(c, add)
	p.mesh = q
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 15
	p.gravity = Vector3(0, up, 0)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, c.a))
	g.set_color(1, Color(c.r * 0.5, c.g * 0.3, c.b * 0.3, 0.0))
	p.color_ramp = g
	n.add_child(p)
	return p


func _coal(p: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	var stone := mat(Color("4a4648"), 0.9)
	cyl(n, 0.7, 0.8, 0.45, Vector3(0, 0.22, 0), stone, Vector3.ZERO, 8)
	cyl(n, 0.55, 0.55, 0.05, Vector3(0, 0.46, 0), mat(Color("141418")), Vector3.ZERO, 8)
	for k in 5:
		box(n, Vector3(0.25, 0.18, 0.22), Vector3(cos(k * 1.3) * 0.25, 0.52, sin(k * 1.3) * 0.25), mat(Color("1a1a24"), 0.6), Vector3(0, k, 0.3))
	for k in 6:
		var a := k * TAU / 6.0
		box(n, Vector3(0.3, rng.randf_range(0.6, 1.2), 0.3), Vector3(cos(a) * 1.6, 0.4, sin(a) * 1.6), stone, Vector3(0, a, rng.randf_range(-0.15, 0.15)))
	var fire := _particles(n, Vector3(0, 0.6, 0), Vector3(0.25, 0.05, 0.25), Color(0.5, 0.8, 1.0), 40, 1.0, 1.8, true)
	fire.name = "Fire"
	var l := OmniLight3D.new()
	l.light_color = Color("6aa8ff")
	l.light_energy = 2.0
	l.omni_range = 8.0
	l.position = Vector3(0, 1.2, 0)
	n.add_child(l)
	_occupied.append(p)
	return n


func _build_arena() -> void:
	if not map.has("arena"):
		return
	var c := point_at(map["arena"][0], 0.0)
	if in_chasm(map["arena"][0]):
		c.y = 0.0
	var r: float = map["arena"][1]
	var body := StaticBody3D.new()
	body.position = c
	add_child(body)
	for k in 28:
		var a := k * TAU / 28.0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(r * TAU / 28.0 + 0.6, 6.0, 0.6)
		cs.shape = bs
		cs.position = Vector3(cos(a) * r, 3.0, sin(a) * r)
		cs.rotation.y = -a + PI / 2.0
		cs.disabled = true
		body.add_child(cs)
		arena_walls.append(cs)
	arena_fog = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	q.material = part_mat(Color(0.6, 0.6, 0.7), false)
	arena_fog.mesh = q
	arena_fog.position = c
	arena_fog.amount = 200
	arena_fog.lifetime = 2.0
	arena_fog.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	arena_fog.emission_ring_axis = Vector3.UP
	arena_fog.emission_ring_radius = r
	arena_fog.emission_ring_inner_radius = r - 0.3
	arena_fog.emission_ring_height = 0.5
	arena_fog.direction = Vector3.UP
	arena_fog.initial_velocity_min = 0.5
	arena_fog.initial_velocity_max = 1.5
	arena_fog.gravity = Vector3(0, 0.5, 0)
	arena_fog.scale_amount_min = 2.0
	arena_fog.scale_amount_max = 4.0
	var g := Gradient.new()
	g.set_color(0, Color(0.7, 0.7, 0.8, 0.35))
	g.set_color(1, Color(0.4, 0.4, 0.5, 0.0))
	arena_fog.color_ramp = g
	arena_fog.emitting = false
	add_child(arena_fog)
	if theme_name == "hollowd":
		for k in 6:
			var a := k * TAU / 6.0 + 0.3
			var t := Node3D.new()
			t.position = c + Vector3(cos(a) * (r + 1.5), 0, sin(a) * (r + 1.5))
			t.position.y = height(t.position.x, t.position.z)
			add_child(t)
			cyl(t, 0.08, 0.1, 2.0, Vector3(0, 1.0, 0), mat(Color("2a1e18")))
			_torch(t, Vector3(0, 0.3, 0))


func set_arena(on: bool) -> void:
	for w in arena_walls:
		w.set_deferred("disabled", not on)
	if arena_fog != null:
		arena_fog.emitting = on


func _build_bridge() -> void:
	var s0: float = map["chasm"][0] - 3.0
	var s1: float = map["chasm"][1] + 3.0
	var wood := mat(Color("4a3424"), 0.9)
	var wood2 := mat(Color("3a281c"), 0.9)
	var iron := mat(Color("6a4a34"), 0.7, 0.5)
	var root := Node3D.new()
	add_child(root)
	var a := point_at(s0, 0)
	a.y = 0.0
	var f := dir_at((s0 + s1) / 2.0)
	root.position = a
	root.rotation.y = atan2(-f.x, -f.y)
	var len := s1 - s0
	var w := 7.0
	for k in int(len):
		var pl := box(root, Vector3(w, 0.25, 0.95), Vector3(0, -0.12, -k - 0.5), wood if k % 2 == 0 else wood2)
		pl.rotation.z = rng.randf_range(-0.01, 0.01)
	for side in [-1, 1]:
		box(root, Vector3(0.4, 0.8, len), Vector3(side * w / 2.0, -0.6, -len / 2.0), iron)
		for k in range(0, int(len), 3):
			box(root, Vector3(0.15, 1.2, 0.15), Vector3(side * (w / 2.0 - 0.1), 0.6, -k - 0.5), wood2)
		box(root, Vector3(0.12, 0.12, len), Vector3(side * (w / 2.0 - 0.1), 1.15, -len / 2.0), wood)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.3, 2.0, len)
		cs.shape = bs
		cs.position = Vector3(side * (w / 2.0 - 0.1), 1.0, -len / 2.0)
		body.add_child(cs)
		root.add_child(body)
	for k in range(10, int(len) - 5, 20):
		box(root, Vector3(1.2, 40.0, 1.2), Vector3(0, -20.5, -k), mat(Color("4a4a4e"), 0.95))
		box(root, Vector3(w + 1.0, 0.6, 0.6), Vector3(0, -1.2, -k), iron)
	var deck := StaticBody3D.new()
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = Vector3(w, 0.3, len)
	dcs.shape = dbs
	dcs.position = Vector3(0, -0.15, -len / 2.0)
	deck.add_child(dcs)
	root.add_child(deck)
	if map.has("arena") and in_chasm(map["arena"][0]):
		var r: float = map["arena"][1]
		var ac := point_at(map["arena"][0], 0)
		var plat := Node3D.new()
		plat.position = Vector3(ac.x, 0, ac.z)
		plat.rotation.y = root.rotation.y
		add_child(plat)
		var disc := cyl(plat, r + 0.5, r + 0.5, 0.3, Vector3(0, -0.15, 0), mat(Color("4a4a4e"), 0.95), Vector3.ZERO, 16)
		disc.name = "Platform"
		cyl(plat, r + 0.7, r - 0.5, 1.6, Vector3(0, -1.1, 0), iron, Vector3.ZERO, 16)
		var pb := StaticBody3D.new()
		var pcs := CollisionShape3D.new()
		var cy := CylinderShape3D.new()
		cy.radius = r + 0.5
		cy.height = 0.3
		pcs.shape = cy
		pcs.position = Vector3(0, -0.15, 0)
		pb.add_child(pcs)
		plat.add_child(pb)
		for k in 8:
			var ang := k * TAU / 8.0
			box(plat, Vector3(0.3, 1.3, 0.3), Vector3(cos(ang) * (r + 0.2), 0.65, sin(ang) * (r + 0.2)), iron)


func _build_spire() -> void:
	var end := pts[-1]
	var f := (pts[-1] - pts[0]).normalized()
	var at := end + f * 340.0 + Vector2(-f.y, f.x) * 60.0
	var n := Node3D.new()
	n.position = Vector3(at.x, -20, at.y)
	add_child(n)
	var dark := mat(Color("08060a"), 0.3, 0.2)
	dark.set("disable_fog", true)
	var c := cyl(n, 0.0, 26.0, 420.0, Vector3(0, 210, 0), dark, Vector3.ZERO, 6)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 3:
		var side := cyl(n, 0.0, 12.0, 180.0 + k * 40.0, Vector3((k - 1) * 22.0, 90.0 + k * 20.0, 10.0 * (k % 2)), dark, Vector3.ZERO, 5)
		side.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var vein := mat(Color("ff3a1a"), 0.5, 0.0, 3.0)
	vein.set("disable_fog", true)
	for k in 9:
		var v := box(n, Vector3(0.8, 18.0, 0.8), Vector3(rng.randf_range(-6, 6), 60.0 + k * 34.0, -12.0 + k * 0.6), vein)
		v.rotation.z = rng.randf_range(-0.3, 0.3)
		v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _exit_marker(p: Vector3) -> void:
	var n := Node3D.new()
	n.position = p
	add_child(n)
	_particles(n, Vector3(0, 1.5, 0), Vector3(1.5, 1.5, 0.3), Color(1.0, 0.85, 0.5, 0.8), 40, 2.0, 0.3, true)
	var l := OmniLight3D.new()
	l.light_color = Color("ffd88a")
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position = Vector3(0, 2, 0)
	n.add_child(l)


func _process(delta: float) -> void:
	_t += delta
	var i := 0
	for l in fires:
		l.light_energy = 1.3 + sin(_t * 9.0 + i * 1.7) * 0.25 + sin(_t * 23.0 + i) * 0.15
		i += 1
