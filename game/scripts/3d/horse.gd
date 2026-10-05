extends CharacterBody3D
## A rideable horse. Without a rider it stands and grazes; with one it trots, gallops on sprint and turns smoothly.

const HORSE_RIG := preload("res://scripts/3d/horse_rig.gd")
const TROT := 7.5
const GALLOP := 13.5

var level: Node
var rig: Node3D
var rider: Node = null
var yaw := 0.0
var speed := 0.0
var radius := 0.6


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.8, 1.4, 2.2)
	cs.shape = b
	cs.position = Vector3(0, 1.1, 0)
	add_child(cs)
	collision_layer = 2
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(45)
	rig = HORSE_RIG.new()
	add_child(rig)
	rig.build_horse(Color("4a3424"), Color("161210"), Color("4a4c56"))


func seat() -> Vector3:
	return rig.saddle.global_position - Vector3(0, 0.95, 0)


func drive(wish: Vector3, sprint: bool, dt: float) -> void:
	var target := 0.0
	if wish.length() > 0.15:
		var want := atan2(-wish.x, -wish.z)
		yaw = rotate_toward(yaw, want, (2.4 if speed > 9.0 else 3.6) * dt)
		target = (GALLOP if sprint else TROT) * minf(1.0, wish.length())
	speed = move_toward(speed, target, (9.0 if target > speed else 14.0) * dt)


func _physics_process(dt: float) -> void:
	if rider == null:
		speed = move_toward(speed, 0.0, 12.0 * dt)
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	velocity.x = f.x * speed
	velocity.z = f.z * speed
	move_and_slide()
	if get_slide_collision_count() > 0 and speed > 3.0 and Vector2(velocity.x, velocity.z).length() < speed * 0.3:
		speed *= 0.5  # ran into a wall
	rig.rotation.y = yaw
	rig.animate_horse(dt, Vector2(velocity.x, velocity.z).length())
	if speed > 2.0 and Engine.get_physics_frames() % (12 if speed > 9.0 else 20) == 0:
		Sfx.play("thud", randf_range(1.6, 1.9))
