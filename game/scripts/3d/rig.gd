extends Node3D
## A low-poly humanoid built from primitives and animated procedurally, so the game ships without model files.
## The model faces -Z, its right hand is +X. Joints are Node3D pivots and limbs hang along -Y from them.
## Rotation conventions: +X on a shoulder or hip swings the limb forward, +X on an elbow curls the forearm
## forward, -X on a knee bends the shin back, +Z on the right shoulder lifts the arm outward.

const JOINTS := ["body", "hips", "spine", "neck", "head", "shL", "elL", "shR", "elR", "hipL", "knL", "hipR", "knR", "cloak", "wpn"]
const FIRST_PERSON_HIDDEN := 2  # render layer for the head, hidden by the first-person camera

var look: Dictionary
var j := {}  # joint name -> Node3D
var rest := {}  # joint name -> rest position
var cur := {}  # joint name -> current euler
var weapon: Node3D
var flask: Node3D
var glow: OmniLight3D
var cycle := 0.0
var _mats := {}
var _layer := 1


# ---------------------------------------------------------------- building

func mat(c: Color, rough: float = 0.85, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%.2f" % [c.to_html(), rough, metal, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = sc
	mi.layers = _layer
	parent.add_child(mi)
	return mi


func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _add(parent, b, pos, m, rot)


func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, seg: int = 8) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _add(parent, c, pos, m, rot)


func ball(parent: Node3D, r: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE, seg: int = 10) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	return _add(parent, s, pos, m, Vector3.ZERO, sc)


func cap(parent: Node3D, r: float, h: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 8
	c.rings = 2
	return _add(parent, c, pos, m)


func _joint(name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	j[name] = n
	rest[name] = pos
	cur[name] = Vector3.ZERO
	return n


## look keys: skin, torso, arm, legs, boots, cloak, hood, hair, long_hair, helm, skull, ghoul, armor, rust,
## robe, belt, weapon (sword/greatsword/staff/axe/none), eye, eye_glow, scale, bulk, hunch, beard, plume
func build(lk: Dictionary) -> void:
	look = lk
	var bulk: float = lk.get("bulk", 1.0)
	var skin: Color = lk.get("skin", Color("c69a7a"))
	var torso_c: Color = lk.get("torso", Color("3b2f2a"))
	var arm_c: Color = lk.get("arm", torso_c)
	var legs_c: Color = lk.get("legs", Color("2e2a2a"))
	var boots_c: Color = lk.get("boots", Color("1f1a18"))
	var m_skin := mat(skin, 0.7)
	var m_torso := mat(torso_c)
	var m_arm := mat(arm_c)
	var m_legs := mat(legs_c)
	var m_boots := mat(boots_c, 0.6)
	var m_belt := mat(lk.get("belt", Color("4a3322")), 0.6)
	var m_buckle := mat(Color("b89a5a"), 0.35, 0.8)
	var armor = lk.get("armor", null)
	var m_armor: StandardMaterial3D = mat(armor, 0.45, 0.75) if armor != null else null
	var m_rust := mat(Color("8a4b2a"), 0.9, 0.2)
	scale = Vector3.ONE * float(lk.get("scale", 1.0))

	var body := _joint("body", self, Vector3(0, 0.5, 0))
	var hips := _joint("hips", body, Vector3(0, 0.45, 0))
	box(hips, Vector3(0.34 * bulk, 0.18, 0.21), Vector3.ZERO, m_legs)
	box(hips, Vector3(0.36 * bulk, 0.07, 0.23), Vector3(0, 0.07, 0), m_belt)
	box(hips, Vector3(0.07, 0.06, 0.02), Vector3(0, 0.07, -0.12), m_buckle)
	if lk.get("pouch", true):
		box(hips, Vector3(0.09, 0.1, 0.06), Vector3(-0.17 * bulk, 0.0, -0.06), m_belt)
	var robe = lk.get("robe", null)
	if robe != null:
		cyl(hips, 0.2 * bulk, 0.34 * bulk, 0.78, Vector3(0, -0.36, 0), mat(robe))
	if m_armor != null:
		for side in [-1, 1]:  # tassets
			box(hips, Vector3(0.15 * bulk, 0.2, 0.05), Vector3(side * 0.09 * bulk, -0.15, -0.11), m_armor, Vector3(-0.15, 0, 0))

	var spine := _joint("spine", hips, Vector3(0, 0.08, 0))
	box(spine, Vector3(0.31 * bulk, 0.22, 0.2), Vector3(0, 0.12, 0), m_torso)
	box(spine, Vector3(0.42 * bulk, 0.26, 0.24), Vector3(0, 0.34, 0), m_torso)
	if m_armor != null:
		box(spine, Vector3(0.44 * bulk, 0.3, 0.07), Vector3(0, 0.33, -0.11), m_armor)
		box(spine, Vector3(0.34 * bulk, 0.18, 0.06), Vector3(0, 0.12, -0.1), m_armor)
		box(spine, Vector3(0.44 * bulk, 0.32, 0.05), Vector3(0, 0.32, 0.12), m_armor)
		if lk.get("rust", false):
			for p in [Vector3(0.1, 0.4, -0.15), Vector3(-0.12, 0.25, -0.15), Vector3(0.05, 0.1, -0.135)]:
				box(spine, Vector3(0.09, 0.07, 0.01), p, m_rust)
	else:
		# leather jerkin details: collar, lacing, strap for the scabbard
		box(spine, Vector3(0.3 * bulk, 0.05, 0.25), Vector3(0, 0.47, 0), mat(torso_c.darkened(0.25)))
		box(spine, Vector3(0.03, 0.3, 0.01), Vector3(0, 0.3, -0.125), mat(torso_c.lightened(0.15)))
		box(spine, Vector3(0.05, 0.62, 0.02), Vector3(0.02, 0.25, -0.125), m_belt, Vector3(0, 0, 0.7))

	var neck := _joint("neck", spine, Vector3(0, 0.48, 0))
	_layer = FIRST_PERSON_HIDDEN
	cyl(neck, 0.05, 0.06, 0.1, Vector3(0, 0.04, 0), m_skin)
	var head := _joint("head", neck, Vector3(0, 0.09, 0))
	_build_head(head, lk, m_skin)
	_layer = 1

	if lk.get("cloak", null) != null:
		var cl := _joint("cloak", spine, Vector3(0, 0.47, 0.13))
		var m_cloak := mat(lk["cloak"])
		box(cl, Vector3(0.46 * bulk, 0.08, 0.06), Vector3(0, 0.0, -0.02), m_cloak)
		var cloak_len: float = lk.get("cloak_len", 0.95)
		# Three panels angled like folds, widening toward the hem, with a darker worn hem.
		var m_fold := mat(Color(lk["cloak"]).darkened(0.25))
		var m_hem := mat(Color(lk["cloak"]).darkened(0.45))
		for f in 3:
			var fx := (f - 1) * 0.17 * bulk
			var fm: Material = m_fold if f != 1 else m_cloak
			var panel := box(cl, Vector3(0.19 * bulk, cloak_len, 0.03), Vector3(fx * 1.12, -cloak_len / 2.0, 0.02 + absf(f - 1) * 0.015), fm,
				Vector3(0, (1 - f) * 0.35, (f - 1) * 0.06))
			panel.position.x = fx * 1.12
			box(cl, Vector3(0.2 * bulk, 0.06, 0.04), Vector3(fx * 1.25, -cloak_len + 0.03, 0.025 + absf(f - 1) * 0.015), m_hem, Vector3(0, (1 - f) * 0.35, 0))
		box(cl, Vector3(0.12, 0.12, 0.03), Vector3(-0.17, -cloak_len + 0.02, 0.02), m_cloak, Vector3(0, 0, 0.5))
		box(cl, Vector3(0.1, 0.1, 0.03), Vector3(0.15, -cloak_len + 0.04, 0.02), m_cloak, Vector3(0, 0, -0.4))
		box(cl, Vector3(0.06, 0.06, 0.03), Vector3(0, -0.02, -0.06), m_buckle)
	else:
		j["cloak"] = Node3D.new()
		spine.add_child(j["cloak"])
		cur["cloak"] = Vector3.ZERO

	for side in [-1, 1]:
		var sn := "shL" if side < 0 else "shR"
		var en := "elL" if side < 0 else "elR"
		var sh := _joint(sn, spine, Vector3(side * 0.25 * bulk, 0.43, 0))
		cap(sh, 0.065 * bulk, 0.34, Vector3(0, -0.15, 0), m_arm)
		if m_armor != null:
			ball(sh, 0.11 * bulk, Vector3(side * 0.02, 0.0, 0), m_armor, Vector3(1.1, 0.8, 1.0))
		else:
			ball(sh, 0.075 * bulk, Vector3(0, -0.01, 0), m_arm)
		var el := _joint(en, sh, Vector3(0, -0.3, 0))
		var long_arm: float = 1.3 if lk.get("ghoul", false) else 1.0
		cap(el, 0.055 * bulk, 0.3 * long_arm, Vector3(0, -0.13 * long_arm, 0), m_arm)
		box(el, Vector3(0.12 * bulk, 0.12, 0.12 * bulk), Vector3(0, -0.18 * long_arm, 0), m_armor if m_armor != null else m_boots)
		var hand := Node3D.new()
		hand.position = Vector3(0, -0.28 * long_arm, 0)
		el.add_child(hand)
		box(hand, Vector3(0.08, 0.1, 0.09), Vector3(0, -0.04, 0), m_skin if lk.get("bare_hands", false) else m_boots)
		if lk.get("ghoul", false):
			for k in 3:
				box(hand, Vector3(0.015, 0.12, 0.015), Vector3(-0.025 + k * 0.025, -0.13, -0.02), mat(Color("d8d0c0"), 0.5), Vector3(0.3, 0, 0))
		if side > 0:
			j["wpn"] = Node3D.new()
			j["wpn"].position = Vector3(0, -0.05, 0)
			hand.add_child(j["wpn"])
			rest["wpn"] = j["wpn"].position
			cur["wpn"] = Vector3.ZERO
			weapon = _build_weapon(j["wpn"], lk.get("weapon", "sword"))
		else:
			flask = Node3D.new()
			flask.position = Vector3(0, -0.08, -0.03)
			hand.add_child(flask)
			cyl(flask, 0.03, 0.045, 0.09, Vector3(0, 0.0, 0), mat(Color("e08a30"), 0.2, 0.0, 1.5))
			cyl(flask, 0.015, 0.015, 0.05, Vector3(0, 0.06, 0), mat(Color("8a7a6a")))
			flask.visible = false
			if lk.get("thread", false):
				ball(hand, 0.03, Vector3(0, -0.1, 0), mat(Color("66ccff"), 0.2, 0.0, 3.0))

	for side in [-1, 1]:
		var hn := "hipL" if side < 0 else "hipR"
		var kn := "knL" if side < 0 else "knR"
		var hp := _joint(hn, hips, Vector3(side * 0.1 * bulk, -0.05, 0))
		cap(hp, 0.08 * bulk, 0.46, Vector3(0, -0.21, 0), m_legs)
		var kn_n := _joint(kn, hp, Vector3(0, -0.43, 0))
		cap(kn_n, 0.065 * bulk, 0.44, Vector3(0, -0.21, 0), m_boots if robe == null else m_legs)
		box(kn_n, Vector3(0.12 * bulk, 0.18, 0.13), Vector3(0, -0.3, 0), m_boots)
		box(kn_n, Vector3(0.11 * bulk, 0.08, 0.26), Vector3(0, -0.46, -0.05), m_boots)
		if m_armor != null:
			box(kn_n, Vector3(0.1, 0.1, 0.05), Vector3(0, 0.0, -0.07), m_armor)

	if lk.has("eye_glow"):
		glow = OmniLight3D.new()
		glow.light_color = lk["eye_glow"]
		glow.light_energy = 0.25
		glow.omni_range = 1.2
		glow.position = Vector3(0, 0.1, -0.2)
		head.add_child(glow)
	var hunch: float = lk.get("hunch", 0.0)
	cur["spine"] = Vector3(hunch, 0, 0)


func _build_head(head: Node3D, lk: Dictionary, m_skin: Material) -> void:
	var eye_c: Color = lk.get("eye", Color("1a1414"))
	var m_eye := mat(eye_c, 0.3, 0.0, 2.5 if lk.has("eye_glow") else 0.0)
	if lk.get("skull", false):
		var m_bone := mat(Color("d8d0c0"), 0.6)
		ball(head, 0.12, Vector3(0, 0.1, 0), m_bone, Vector3(0.95, 1.1, 1.0))
		box(head, Vector3(0.12, 0.06, 0.1), Vector3(0, -0.0, -0.06), m_bone)
		for side in [-1, 1]:
			ball(head, 0.032, Vector3(side * 0.045, 0.11, -0.095), mat(Color("0c0a0a")))
			ball(head, 0.012, Vector3(side * 0.045, 0.11, -0.115), m_eye)
	elif lk.get("ghoul", false):
		ball(head, 0.11, Vector3(0, 0.1, 0), m_skin, Vector3(0.9, 1.15, 1.05))
		box(head, Vector3(0.12, 0.08, 0.13), Vector3(0, 0.0, -0.05), m_skin)
		box(head, Vector3(0.1, 0.015, 0.02), Vector3(0, -0.01, -0.115), mat(Color("1a0c0c")))
		for side in [-1, 1]:
			ball(head, 0.022, Vector3(side * 0.045, 0.12, -0.095), m_eye)
	else:
		ball(head, 0.11, Vector3(0, 0.1, 0), m_skin, Vector3(0.95, 1.12, 1.0))
		box(head, Vector3(0.025, 0.045, 0.03), Vector3(0, 0.09, -0.11), m_skin)  # nose
		for side in [-1, 1]:
			box(head, Vector3(0.035, 0.02, 0.01), Vector3(side * 0.042, 0.12, -0.103), mat(Color("f0e8e0"), 0.4))
			box(head, Vector3(0.018, 0.018, 0.012), Vector3(side * 0.042, 0.12, -0.108), m_eye)
			box(head, Vector3(0.045, 0.012, 0.012), Vector3(side * 0.042, 0.147, -0.103), mat(lk.get("hair", Color("2a2220")).darkened(0.2)))
		box(head, Vector3(0.05, 0.012, 0.01), Vector3(0, 0.045, -0.105), mat(Color("7a4a40")))  # mouth
		if lk.get("beard", null) != null:
			box(head, Vector3(0.17, 0.08, 0.06), Vector3(0, 0.03, -0.075), mat(lk["beard"], 0.95))
		if lk.get("ember", false):  # Said's burnt eye, a spark of the Spire
			box(head, Vector3(0.02, 0.02, 0.014), Vector3(-0.042, 0.12, -0.11), mat(Color("ff7a1a"), 0.3, 0.0, 4.0))
			box(head, Vector3(0.012, 0.07, 0.01), Vector3(-0.06, 0.12, -0.104), mat(Color("8a5a48")))  # scar
	if lk.get("hair", null) != null and lk.get("hood", null) == null and lk.get("helm", null) == null:
		var m_hair := mat(lk["hair"], 0.9)
		ball(head, 0.118, Vector3(0, 0.14, 0.012), m_hair, Vector3(1.0, 0.85, 1.02))
		box(head, Vector3(0.2, 0.05, 0.05), Vector3(0, 0.2, -0.085), m_hair, Vector3(0.3, 0, 0))
		if lk.get("long_hair", false):
			box(head, Vector3(0.22, 0.42, 0.08), Vector3(0, -0.06, 0.08), m_hair)
			for side in [-1, 1]:
				box(head, Vector3(0.05, 0.3, 0.06), Vector3(side * 0.1, 0.0, -0.03), m_hair)
	if lk.get("hood", null) != null:
		var m_hood := mat(lk["hood"])
		var m_in := mat(Color(lk["hood"]).darkened(0.55))
		box(head, Vector3(0.29, 0.07, 0.3), Vector3(0, 0.24, 0.0), m_hood, Vector3(-0.1, 0, 0))
		box(head, Vector3(0.29, 0.34, 0.07), Vector3(0, 0.08, 0.12), m_hood)
		for side in [-1, 1]:
			box(head, Vector3(0.05, 0.3, 0.27), Vector3(side * 0.135, 0.09, -0.005), m_hood)
		box(head, Vector3(0.21, 0.05, 0.02), Vector3(0, 0.2, -0.13), m_in)
		box(head, Vector3(0.18, 0.28, 0.12), Vector3(0, 0.15, 0.17), m_hood, Vector3(-0.5, 0, 0))  # peak
		box(head, Vector3(0.36, 0.08, 0.26), Vector3(0, -0.07, 0.04), m_hood)  # mantle
	if lk.get("helm", null) != null:
		var m_helm := mat(lk["helm"], 0.45, 0.75)
		box(head, Vector3(0.25, 0.27, 0.27), Vector3(0, 0.11, 0), m_helm)
		box(head, Vector3(0.27, 0.06, 0.29), Vector3(0, 0.03, 0), m_helm)
		box(head, Vector3(0.18, 0.025, 0.02), Vector3(0, 0.13, -0.137), mat(Color("0a0808"), 0.3, 0.0, 0.0))
		box(head, Vector3(0.025, 0.12, 0.02), Vector3(0, 0.07, -0.14), m_helm)
		if lk.get("rust", false):
			box(head, Vector3(0.08, 0.06, 0.01), Vector3(0.07, 0.19, -0.137), mat(Color("8a4b2a"), 0.9))
		if lk.get("plume", null) != null:
			box(head, Vector3(0.04, 0.12, 0.3), Vector3(0, 0.3, 0.05), mat(lk["plume"], 0.9))


func _build_weapon(w: Node3D, kind: String) -> Node3D:
	var root := Node3D.new()
	w.add_child(root)
	var steel := mat(Color("b8c0c8"), 0.25, 0.9)
	var dark := mat(Color("2a2020"), 0.7)
	var gold := mat(Color("a88a4a"), 0.35, 0.8)
	var wood := mat(Color("5a3c24"), 0.85)
	# Grip runs through the fist; the blade points along the hand's -Z, forward of the knuckles,
	# so with a relaxed arm the sword rests forward and down like a real one-handed hold.
	root.rotation.x = -PI / 2.0 - 0.15
	match kind:
		"sword":
			ball(root, 0.03, Vector3(0, -0.11, 0), gold)
			cyl(root, 0.018, 0.018, 0.18, Vector3(0, -0.02, 0), dark)
			box(root, Vector3(0.22, 0.03, 0.04), Vector3(0, 0.08, 0), gold)
			box(root, Vector3(0.055, 0.8, 0.012), Vector3(0, 0.49, 0), steel)
			box(root, Vector3(0.012, 0.76, 0.016), Vector3(0, 0.48, 0), mat(Color("8a929a"), 0.3, 0.9))
			var tip := PrismMesh.new()
			tip.size = Vector3(0.055, 0.08, 0.012)
			_add(root, tip, Vector3(0, 0.93, 0), steel)
		"greatsword":
			ball(root, 0.04, Vector3(0, -0.24, 0), mat(Color("6a3a20"), 0.6, 0.6))
			cyl(root, 0.022, 0.022, 0.36, Vector3(0, -0.05, 0), dark)
			box(root, Vector3(0.38, 0.05, 0.06), Vector3(0, 0.15, 0), mat(Color("6a6d72"), 0.5, 0.7))
			box(root, Vector3(0.09, 1.35, 0.02), Vector3(0, 0.84, 0), mat(Color("7a7c80"), 0.55, 0.7))
			for k in 4:
				box(root, Vector3(0.05, 0.08, 0.022), Vector3(0.02 * (k % 2), 0.4 + k * 0.28, 0), mat(Color("8a4b2a"), 0.9))
			var gtip := PrismMesh.new()
			gtip.size = Vector3(0.09, 0.14, 0.02)
			_add(root, gtip, Vector3(0, 1.58, 0), mat(Color("7a7c80"), 0.55, 0.7))
		"axe":
			cyl(root, 0.025, 0.025, 1.2, Vector3(0, 0.3, 0), wood)
			box(root, Vector3(0.24, 0.2, 0.025), Vector3(0.1, 0.8, 0), mat(Color("6a6d72"), 0.6, 0.6))
			box(root, Vector3(0.06, 0.06, 0.03), Vector3(0.18, 0.84, 0), mat(Color("8a4b2a"), 0.9))
			box(root, Vector3(0.04, 0.25, 0.04), Vector3(0, 0.95, 0), mat(Color("6a6d72"), 0.6, 0.6))
		"staff":
			root.rotation.x = -0.2
			cyl(root, 0.025, 0.03, 1.9, Vector3(0, 0.35, 0), wood)
			box(root, Vector3(0.3, 0.04, 0.04), Vector3(0.0, 1.25, 0), wood, Vector3(0, 0, 0.3))
			cyl(root, 0.005, 0.005, 0.25, Vector3(0.12, 1.1, 0), dark)
			ball(root, 0.07, Vector3(0.12, 0.95, 0), mat(Color("3a3a2a"), 0.5, 0.6))
			ball(root, 0.04, Vector3(0.12, 0.95, 0), mat(Color("9aff6a"), 0.2, 0.0, 3.0))
		_:
			pass
	return root


# ---------------------------------------------------------------- animation

static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


## Keyframes: [[time 0..1, {joint: Vector3}], ...]; joints missing from a key keep their base pose.
static func keys(frames: Array, t: float, base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	for i in range(frames.size() - 1):
		var a: Array = frames[i]
		var b: Array = frames[i + 1]
		if t >= a[0] and t <= b[0]:
			var k := _ease((t - a[0]) / maxf(0.0001, b[0] - a[0]))
			var names := {}
			for n in a[1]:
				names[n] = true
			for n in b[1]:
				names[n] = true
			for n in names:
				var va: Vector3 = a[1].get(n, base.get(n, Vector3.ZERO))
				var vb: Vector3 = b[1].get(n, base.get(n, Vector3.ZERO))
				out[n] = va.lerp(vb, k)
			return out
	return out


const ATTACKS := {
	"attack1": [  # rising diagonal cut from the right shoulder down to the left hip
		[0.0, {}],
		[0.3, {"spine": Vector3(0.05, -0.7, 0.05), "shR": Vector3(2.3, -0.3, 1.0), "elR": Vector3(0.9, 0, 0), "wpn": Vector3(0.2, 0, 0), "shL": Vector3(0.6, 0, -0.5), "hipL": Vector3(0.4, 0, 0), "hipR": Vector3(-0.3, 0, 0), "knL": Vector3(-0.4, 0, 0)}],
		[0.55, {"spine": Vector3(0.25, 0.6, -0.05), "shR": Vector3(1.0, 0.6, -0.6), "elR": Vector3(0.05, 0, 0), "wpn": Vector3(-0.4, 0, 0), "shL": Vector3(-0.3, 0, -0.6), "hipL": Vector3(0.6, 0, 0), "hipR": Vector3(-0.4, 0, 0), "knL": Vector3(-0.5, 0, 0), "hips_y": Vector3(0, -0.08, 0)}],
		[1.0, {}],
	],
	"attack2": [  # overhead strike
		[0.0, {}],
		[0.35, {"spine": Vector3(-0.3, -0.15, 0), "shR": Vector3(3.0, 0, 0.25), "elR": Vector3(1.2, 0, 0), "shL": Vector3(2.4, 0, 0.3), "elL": Vector3(1.4, 0, 0), "head": Vector3(0.2, 0, 0)}],
		[0.58, {"spine": Vector3(0.45, 0, 0), "shR": Vector3(0.7, 0, 0.05), "elR": Vector3(0.1, 0, 0), "wpn": Vector3(-0.3, 0, 0), "shL": Vector3(0.6, 0, -0.2), "elL": Vector3(0.2, 0, 0), "hipL": Vector3(0.8, 0, 0), "knL": Vector3(-0.7, 0, 0), "hipR": Vector3(-0.5, 0, 0), "hips_y": Vector3(0, -0.15, 0)}],
		[1.0, {}],
	],
	"heavy": [  # two-handed greatsword sweep
		[0.0, {}],
		[0.4, {"spine": Vector3(0.0, -1.1, 0), "shR": Vector3(2.0, 0, 1.3), "elR": Vector3(0.7, 0, 0), "shL": Vector3(2.2, 0, 0.6), "elL": Vector3(1.0, 0, 0), "hipR": Vector3(-0.3, 0, 0)}],
		[0.62, {"spine": Vector3(0.2, 1.0, 0), "shR": Vector3(1.3, 0.5, -0.8), "elR": Vector3(0.1, 0, 0), "shL": Vector3(1.4, 0, -0.9), "elL": Vector3(0.3, 0, 0), "hipL": Vector3(0.6, 0, 0), "knL": Vector3(-0.5, 0, 0), "hips_y": Vector3(0, -0.12, 0)}],
		[1.0, {}],
	],
	"thrust": [  # lunge
		[0.0, {}],
		[0.35, {"spine": Vector3(-0.1, -0.5, 0), "shR": Vector3(0.6, 0, 0.3), "elR": Vector3(2.0, 0, 0), "wpn": Vector3(0.9, 0, 0), "hipR": Vector3(-0.4, 0, 0), "hipL": Vector3(0.3, 0, 0), "knL": Vector3(-0.4, 0, 0)}],
		[0.55, {"spine": Vector3(0.35, 0.2, 0), "shR": Vector3(1.6, 0, 0.05), "elR": Vector3(0.05, 0, 0), "wpn": Vector3(1.2, 0, 0), "hipL": Vector3(1.0, 0, 0), "knL": Vector3(-0.4, 0, 0), "hipR": Vector3(-0.7, 0, 0), "hips_y": Vector3(0, -0.2, 0)}],
		[1.0, {}],
	],
	"claw": [  # the ghouls' double swipe
		[0.0, {}],
		[0.35, {"spine": Vector3(-0.1, -0.4, 0), "shR": Vector3(2.4, 0, 0.6), "elR": Vector3(0.5, 0, 0), "shL": Vector3(2.4, 0, -0.6), "elL": Vector3(0.5, 0, 0)}],
		[0.6, {"spine": Vector3(0.6, 0.3, 0), "shR": Vector3(0.5, 0, -0.3), "shL": Vector3(0.6, 0, 0.3), "hipL": Vector3(0.7, 0, 0), "knL": Vector3(-0.6, 0, 0), "hips_y": Vector3(0, -0.12, 0)}],
		[1.0, {}],
	],
	"cast": [
		[0.0, {}],
		[0.4, {"spine": Vector3(-0.2, 0, 0), "shL": Vector3(2.6, 0, -0.3), "elL": Vector3(0.6, 0, 0), "head": Vector3(0.25, 0, 0), "shR": Vector3(0.8, 0, 0.4)}],
		[0.6, {"spine": Vector3(0.2, 0, 0), "shL": Vector3(1.5, 0, -0.1), "elL": Vector3(0.0, 0, 0), "shR": Vector3(0.9, 0, 0.3)}],
		[1.0, {}],
	],
}


## Called every frame by the actor. p keys: state (move/air/roll/attack1/.../heal/hurt/death/cast/ride),
## t (0..1 progress of a timed action), speed (m/s on the ground), run (top speed for the full run cycle).
func animate(dt: float, p: Dictionary) -> void:
	var st: String = p.get("state", "move")
	var t: float = p.get("t", 0.0)
	var speed: float = p.get("speed", 0.0)
	var hunch: float = look.get("hunch", 0.0)
	var two_hand: bool = look.get("weapon", "sword") in ["greatsword", "axe"]
	var pose := {}
	var amt := clampf(speed / float(p.get("run", 6.0)), 0.0, 1.4)
	cycle += dt * (2.0 + speed * 1.7)
	var c := cycle
	# base: a guarded stance; the sword arm holds the blade forward, the free arm loose
	var guard_r := Vector3(0.35, 0.0, 0.12) if not two_hand else Vector3(0.7, 0.0, 0.25)
	var guard_l := Vector3(0.1, 0.0, -0.1) if not two_hand else Vector3(0.9, 0.0, 0.35)
	pose["body"] = Vector3.ZERO
	pose["hips"] = Vector3.ZERO
	pose["spine"] = Vector3(hunch + 0.04 + amt * 0.18, sin(c) * 0.08 * amt, 0)
	pose["neck"] = Vector3(-hunch * 0.6 - amt * 0.1, 0, 0)
	pose["head"] = Vector3.ZERO
	pose["shR"] = guard_r + Vector3(sin(c) * 0.15 * amt, 0, 0)
	pose["elR"] = Vector3(0.3 + amt * 0.3, 0, 0)
	pose["shL"] = guard_l + Vector3(-sin(c) * 0.7 * amt, 0, 0)
	pose["elL"] = Vector3(0.25 + amt * 0.6, 0, 0) if not two_hand else Vector3(1.0, 0, 0)
	pose["wpn"] = Vector3.ZERO
	var stride := 0.35 + 0.45 * minf(amt, 1.0)
	pose["hipL"] = Vector3(sin(c) * stride * minf(amt * 2.0, 1.0), 0, 0)
	pose["hipR"] = Vector3(-sin(c) * stride * minf(amt * 2.0, 1.0), 0, 0)
	pose["knL"] = Vector3(-(0.05 + maxf(0.0, cos(c)) * (0.5 + amt) * minf(amt * 2.0, 1.0)), 0, 0)
	pose["knR"] = Vector3(-(0.05 + maxf(0.0, -cos(c)) * (0.5 + amt) * minf(amt * 2.0, 1.0)), 0, 0)
	pose["cloak"] = Vector3(-0.08 - amt * 0.55 - sin(c * 2.0) * 0.05 * amt, 0, sin(c) * 0.04 * amt)
	pose["hips_y"] = Vector3(0, -absf(sin(c)) * 0.05 * minf(amt, 1.0) + (sin(cycle * 0.5) * 0.008 if amt < 0.05 else 0.0), 0)
	if amt < 0.05:
		# idle breathing and a slight weight shift
		var b := sin(cycle * 0.9)
		pose["spine"] += Vector3(b * 0.02, 0, 0)
		pose["shL"] += Vector3(0, 0, -b * 0.03)
		pose["knL"] = Vector3(-0.12, 0, 0)
		pose["knR"] = Vector3(-0.08, 0, 0)
		pose["hipL"] = Vector3(0.12, 0, 0)
		pose["hipR"] = Vector3(-0.05, 0, 0)

	match st:
		"air":
			pose["hipL"] = Vector3(0.7, 0, 0)
			pose["knL"] = Vector3(-1.1, 0, 0)
			pose["hipR"] = Vector3(-0.1, 0, 0)
			pose["knR"] = Vector3(-0.5, 0, 0)
			pose["shL"] = Vector3(1.2, 0, -0.5)
			pose["cloak"] = Vector3(-0.9, 0, 0)
		"roll":
			var r := _ease(clampf(t, 0.0, 1.0))
			pose["body"] = Vector3(-TAU * r, 0, 0)
			pose["hips_y"] = Vector3(0, -0.35 * sin(PI * t), 0)
			pose["hipL"] = Vector3(1.9, 0, 0)
			pose["hipR"] = Vector3(1.7, 0, 0)
			pose["knL"] = Vector3(-2.2, 0, 0)
			pose["knR"] = Vector3(-2.2, 0, 0)
			pose["spine"] = Vector3(0.9, 0, 0)
			pose["neck"] = Vector3(0.5, 0, 0)
			pose["shL"] = Vector3(1.2, 0, -0.2)
			pose["shR"] = Vector3(1.0, 0, 0.2)
			pose["elR"] = Vector3(1.5, 0, 0)
			pose["cloak"] = Vector3(-0.3, 0, 0)
		"heal":
			var k := sin(PI * clampf(t, 0.0, 1.0))
			pose["shL"] = Vector3(2.2 * k + 0.1, 0, -0.35 * k)
			pose["elL"] = Vector3(0.3 + 1.6 * k, 0, 0)
			pose["head"] = Vector3(0.35 * k, 0, 0)
			pose["knL"] = Vector3(-0.15, 0, 0)
		"hurt":
			var k := sin(PI * clampf(t, 0.0, 1.0))
			pose["spine"] = Vector3(-0.45 * k, 0.2 * k, 0)
			pose["head"] = Vector3(0.4 * k, 0, 0)
			pose["shL"] = Vector3(0.8 * k, 0, -0.8 * k)
			pose["shR"] = guard_r + Vector3(0.3 * k, 0, 0.5 * k)
			pose["knL"] = Vector3(-0.4 * k, 0, 0)
			pose["knR"] = Vector3(-0.4 * k, 0, 0)
			pose["hips_y"] = Vector3(0, -0.08 * k, 0)
		"death":
			var k := _ease(clampf(t, 0.0, 1.0))
			pose["body"] = Vector3(1.45 * k, 0, 0.15 * k)
			pose["hips_y"] = Vector3(0, -0.35 * k, 0)
			pose["spine"] = Vector3(-0.2 * k, 0, 0)
			pose["head"] = Vector3(0.5 * k, 0.4 * k, 0)
			pose["shL"] = Vector3(-0.3 * k, 0, -1.2 * k)
			pose["shR"] = Vector3(-0.2 * k, 0, 1.3 * k)
			pose["elR"] = Vector3(0.2, 0, 0)
			pose["hipL"] = Vector3(0.6 * k, 0, 0)
			pose["knL"] = Vector3(-1.2 * k, 0, 0)
			pose["hipR"] = Vector3(0.2 * k, 0, 0)
			pose["knR"] = Vector3(-0.3 * k, 0, 0)
			pose["cloak"] = Vector3(-1.4 * k, 0, 0)
		"ride":
			var bob := sin(cycle * 1.4) * 0.04 * minf(amt, 1.0)
			pose["hips_y"] = Vector3(0, bob, 0)
			pose["hipL"] = Vector3(1.25, 0, -0.45)
			pose["hipR"] = Vector3(1.25, 0, 0.45)
			pose["knL"] = Vector3(-1.4, 0, 0)
			pose["knR"] = Vector3(-1.4, 0, 0)
			pose["spine"] = Vector3(0.12 + amt * 0.2, 0, 0)
			pose["shL"] = Vector3(0.9, 0, -0.1)
			pose["elL"] = Vector3(0.9, 0, 0)
			pose["shR"] = Vector3(0.6, 0, 0.2)
			pose["elR"] = Vector3(0.7, 0, 0)
			pose["cloak"] = Vector3(-0.3 - amt * 0.6, 0, 0)
		_:
			if ATTACKS.has(st):
				var k: Dictionary = keys(ATTACKS[st], clampf(t, 0.0, 1.0), pose)
				pose = k
	_apply(pose, dt, 0.0 if st in ["death"] else 16.0)
	if flask != null:
		flask.visible = st == "heal"


func _apply(pose: Dictionary, dt: float, sharp: float) -> void:
	var k := 1.0 - exp(-(sharp if sharp > 0.0 else 9.0) * dt)
	for n in pose:
		if n == "hips_y":
			var hy: Vector3 = pose[n]
			var hn: Node3D = j["hips"]
			hn.position = hn.position.lerp(rest["hips"] + hy, k)
			continue
		if not j.has(n):
			continue
		var target: Vector3 = pose[n]
		var now: Vector3 = cur.get(n, Vector3.ZERO)
		now = now.lerp(target, k)
		cur[n] = now
		j[n].rotation = now


## World position of the blade tip, for hit traces and trails.
func blade_tip() -> Vector3:
	if weapon == null:
		return global_position + Vector3(0, 1.0, 0)
	return weapon.to_global(Vector3(0, 0.9, 0))


func set_first_person(on: bool) -> void:
	for n in [j.get("head"), j.get("neck")]:
		if n != null:
			n.visible = not on
