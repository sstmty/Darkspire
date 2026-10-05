extends Node3D
## The Shepherd's ash wave: rolls along the ground. Jump over it or roll through it.

var level: Node
var dir := Vector3.FORWARD
var speed := 7.0
var life := 3.0
var dmg := 16.0


func _ready() -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	q.material = level.world.part_mat(Color.WHITE, false)
	p.mesh = q
	p.amount = 60
	p.lifetime = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.6, 0.3, 0.6)
	p.position = Vector3(0, 0.4, 0)
	p.direction = Vector3.UP
	p.spread = 25
	p.gravity = Vector3(0, 2.0, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.2, 1.0))
	g.set_color(1, Color(0.15, 0.13, 0.14, 0.0))
	p.color_ramp = g
	add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color("ff7a2a")
	l.omni_range = 4.0
	l.position = Vector3(0, 0.6, 0)
	add_child(l)


func _physics_process(dt: float) -> void:
	position += dir * speed * dt
	position.y = level.world.height(position.x, position.z) if not level.world.in_chasm(level.world.project(Vector2(position.x, position.z)).x) else position.y
	life -= dt
	if life <= 0.0:
		queue_free()
		return
	var pl: Node = level.player
	var d: Vector3 = pl.global_position - global_position
	if Vector2(d.x, d.z).length() < 0.9 and d.y < 0.9 and pl.take_damage(dmg, self):
		queue_free()
	elif level.nayra != null and level.nayra.global_position.distance_to(global_position) < 0.9:
		level.nayra.take_damage(dmg, self)
