extends "res://scripts/3d/rig.gd"
## A low-poly warhorse with a saddle and caparison, animated procedurally: idle, walk, trot and gallop.
## Faces -Z like the humanoid; the rider sits on the "saddle" node.

var saddle: Node3D
var legs := []  # [hip node, knee node, phase offset, is_front]


func build_horse(coat: Color, mane: Color, cloth: Color) -> void:
	look = {}
	var m_coat := mat(coat, 0.75)
	var m_dark := mat(coat.darkened(0.3), 0.8)
	var m_mane := mat(mane, 0.95)
	var m_hoof := mat(Color("1a1614"), 0.6)
	var m_leather := mat(Color("4a2e1c"), 0.6)
	var m_cloth := mat(cloth, 0.9)
	var m_trim := mat(Color("a88a4a"), 0.35, 0.8)
	var body := _joint("body", self, Vector3(0, 1.28, 0))
	box(body, Vector3(0.52, 0.56, 1.5), Vector3.ZERO, m_coat)
	ball(body, 0.33, Vector3(0, 0.02, 0.62), m_coat, Vector3(0.85, 0.9, 0.8))  # rump
	ball(body, 0.32, Vector3(0, 0.05, -0.62), m_coat, Vector3(0.85, 0.95, 0.75))  # chest
	box(body, Vector3(0.5, 0.2, 1.3), Vector3(0, -0.28, 0), m_dark)  # belly shade
	# caparison and saddle
	box(body, Vector3(0.6, 0.42, 0.9), Vector3(0, -0.05, 0.05), m_cloth)
	box(body, Vector3(0.61, 0.05, 0.91), Vector3(0, -0.27, 0.05), m_trim)
	saddle = Node3D.new()
	saddle.position = Vector3(0, 0.33, -0.05)
	body.add_child(saddle)
	box(body, Vector3(0.44, 0.12, 0.55), Vector3(0, 0.3, -0.05), m_leather)
	box(body, Vector3(0.4, 0.14, 0.08), Vector3(0, 0.38, -0.3), m_leather)
	box(body, Vector3(0.4, 0.1, 0.08), Vector3(0, 0.36, 0.2), m_leather)
	for side in [-1, 1]:
		box(body, Vector3(0.02, 0.45, 0.04), Vector3(side * 0.31, 0.05, -0.05), m_leather)
		box(body, Vector3(0.06, 0.03, 0.1), Vector3(side * 0.32, -0.18, -0.05), m_trim)
	# neck and head
	var neck := _joint("neck", body, Vector3(0, 0.2, -0.7))
	var nk := box(neck, Vector3(0.3, 0.75, 0.38), Vector3(0, 0.3, -0.12), m_coat, Vector3(-0.55, 0, 0))
	nk.position = Vector3(0, 0.28, -0.14)
	box(neck, Vector3(0.08, 0.8, 0.14), Vector3(0, 0.4, 0.04), m_mane, Vector3(-0.55, 0, 0))
	var head := _joint("head", neck, Vector3(0, 0.62, -0.4))
	box(head, Vector3(0.24, 0.26, 0.36), Vector3(0, 0, -0.05), m_coat)
	box(head, Vector3(0.18, 0.2, 0.32), Vector3(0, -0.06, -0.33), m_coat, Vector3(0.25, 0, 0))
	box(head, Vector3(0.17, 0.12, 0.08), Vector3(0, -0.12, -0.5), m_dark)
	for side in [-1, 1]:
		box(head, Vector3(0.05, 0.14, 0.04), Vector3(side * 0.07, 0.19, 0.05), m_coat, Vector3(0, 0, side * -0.2))
		box(head, Vector3(0.03, 0.04, 0.04), Vector3(side * 0.125, 0.04, -0.12), mat(Color("0c0a0a"), 0.2))
		box(head, Vector3(0.02, 0.04, 0.3), Vector3(side * 0.1, -0.06, -0.3), m_leather, Vector3(0.25, 0, 0))
	box(head, Vector3(0.07, 0.08, 0.2), Vector3(0, 0.15, -0.05), m_mane)
	# tail
	var tail := _joint("cloak", body, Vector3(0, 0.18, 0.78))
	box(tail, Vector3(0.1, 0.7, 0.12), Vector3(0, -0.33, 0.06), m_mane, Vector3(-0.2, 0, 0))
	# legs: front pair under the chest, hind pair under the rump
	for spec in [[-1, -0.55, 0.0, true], [1, -0.55, PI, true], [-1, 0.58, PI, false], [1, 0.58, 0.0, false]]:
		var hp := Node3D.new()
		hp.position = Vector3(spec[0] * 0.17, -0.12, spec[1])
		body.add_child(hp)
		box(hp, Vector3(0.14, 0.5, 0.2 if spec[3] else 0.26), Vector3(0, -0.22, 0.0), m_coat)
		var kn := Node3D.new()
		kn.position = Vector3(0, -0.46, 0)
		hp.add_child(kn)
		box(kn, Vector3(0.09, 0.48, 0.1), Vector3(0, -0.22, 0), m_coat)
		box(kn, Vector3(0.12, 0.08, 0.14), Vector3(0, -0.5, -0.01), m_hoof)
		box(kn, Vector3(0.11, 0.1, 0.12), Vector3(0, -0.41, 0.01), m_mane)  # feathering
		legs.append([hp, kn, spec[2], spec[3]])


func animate_horse(dt: float, speed: float) -> void:
	var gallop := speed > 7.0
	cycle += dt * (1.5 + speed * (0.9 if gallop else 1.3))
	var amt := clampf(speed / 6.0, 0.0, 1.0)
	for leg in legs:
		var hp: Node3D = leg[0]
		var kn: Node3D = leg[1]
		var ph: float = cycle + leg[2] + ((0.5 if leg[3] else 0.0) if gallop else 0.0)
		var swing := sin(ph) * (0.6 if gallop else 0.45) * amt
		hp.rotation.x = lerpf(hp.rotation.x, swing, 1.0 - exp(-14.0 * dt))
		var bend := maxf(0.0, cos(ph)) * (1.2 if gallop else 0.8) * amt
		kn.rotation.x = lerpf(kn.rotation.x, bend * (-1.0 if leg[3] else 1.0) * (1.0 if leg[3] else -1.0), 1.0 - exp(-14.0 * dt))
	var body: Node3D = j["body"]
	var bob := (absf(sin(cycle)) * 0.08 if gallop else absf(sin(cycle)) * 0.04) * amt
	body.position.y = lerpf(body.position.y, 1.28 + bob, 1.0 - exp(-12.0 * dt))
	body.rotation.x = lerpf(body.rotation.x, (sin(cycle) * 0.06 if gallop else 0.0), 1.0 - exp(-8.0 * dt))
	j["neck"].rotation.x = lerpf(j["neck"].rotation.x, -0.15 * amt + sin(cycle) * 0.08 * amt + (sin(cycle * 0.3) * 0.05 if amt < 0.05 else 0.0), 1.0 - exp(-8.0 * dt))
	j["cloak"].rotation.x = lerpf(j["cloak"].rotation.x, -0.2 - 0.9 * amt + sin(cycle * 2.0) * 0.1, 1.0 - exp(-6.0 * dt))
