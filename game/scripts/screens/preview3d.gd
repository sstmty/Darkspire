extends Node3D
## Developer screen: every character and the horse side by side (used for screenshots).

const RIG := preload("res://scripts/3d/rig.gd")
const HORSE := preload("res://scripts/3d/horse_rig.gd")
const LOOKS := preload("res://scripts/3d/looks.gd")
const ENV := preload("res://scripts/3d/env.gd")

var rigs := []
var horse: Node3D
var t := 0.0
var pose := "move"


func setup(params: Dictionary) -> void:
	pose = params.get("pose", "move")
	ENV.build(self, "hollowd", true)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("3a2e26")
	ground.material_override = gm
	add_child(ground)
	var x := -5.0
	for id in ["said", "nayra", "ashghoul", "rustguard", "shepherd", "draven"]:
		var r := RIG.new()
		add_child(r)
		r.build(LOOKS.LOOKS[id])
		r.position = Vector3(x, 0, 0)
		r.rotation.y = PI + 0.5
		rigs.append(r)
		x += 1.7
	horse = HORSE.new()
	add_child(horse)
	horse.build_horse(Color("4a3424"), Color("1a1412"), Color("4a4c56"))
	horse.position = Vector3(6.0, 0, 1.0)
	horse.rotation.y = PI * 0.5 + 0.3
	var cam := Camera3D.new()
	cam.position = Vector3(0.6, 2.4, 7.5)
	cam.rotation = Vector3(-0.18, 0, 0)
	cam.fov = 60
	add_child(cam)
	cam.current = true


func _process(delta: float) -> void:
	t += delta
	var i := 0
	for r in rigs:
		var st := pose
		var p := {"state": st, "t": fmod(t * 0.8, 1.0), "speed": 0.0}
		if pose == "move":
			p["speed"] = [0.0, 3.0, 6.0, 0.0, 2.0, 0.0][i]
		elif pose == "mixed":
			p = [{"state": "attack1", "t": 0.3}, {"state": "cast", "t": 0.45}, {"state": "claw", "t": 0.35}, {"state": "attack2", "t": 0.35}, {"state": "attack1", "t": 0.55}, {"state": "heavy", "t": 0.4}][i]
		r.animate(delta, p)
		i += 1
	horse.animate_horse(delta, 9.0 if pose == "move" else 0.0)
