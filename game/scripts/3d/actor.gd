extends CharacterBody3D
## Shared body of every fighter in 3D: a procedural rig, health, gravity, facing and reach checks.

const RIG := preload("res://scripts/3d/rig.gd")
const LOOKS := preload("res://scripts/3d/looks.gd")
const GRAVITY := 18.0

var level: Node
var rig: Node3D
var kind := ""
var hp := 100.0
var max_hp := 100.0
var yaw := 0.0
var state := "move"
var state_t := 0.0
var radius := 0.4
var tall := 1.8
var shape: CollisionShape3D


func make_body(r: float, h: float) -> void:
	radius = r
	tall = h
	shape = CollisionShape3D.new()
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = h
	shape.shape = c
	shape.position = Vector3(0, h / 2.0, 0)
	add_child(shape)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)


func build_rig(look_id: String) -> void:
	rig = RIG.new()
	add_child(rig)
	rig.build(LOOKS.LOOKS[look_id])


func alive() -> bool:
	return state != "dead"


func set_state(s: String) -> void:
	state = s
	state_t = 0.0


func forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func center() -> Vector3:
	return global_position + Vector3(0, tall * 0.55, 0)


func flat_dist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))


func turn_toward(target_yaw: float, rate: float, dt: float) -> void:
	yaw = rotate_toward(yaw, target_yaw, rate * dt)


## True if `other` stands within reach in front of us (a cone of +-cone_deg).
func in_reach(other: Node3D, reach: float, cone_deg: float = 70.0) -> bool:
	var d := other.global_position - global_position
	if absf(d.y) > 2.5:
		return false
	var flat := Vector2(d.x, d.z)
	var r: float = other.get("radius") if other.get("radius") != null else 0.4
	if flat.length() > reach + r:
		return false
	if flat.length() < 0.6:
		return true
	var f := Vector2(-sin(yaw), -cos(yaw))
	return f.dot(flat.normalized()) >= cos(deg_to_rad(cone_deg))


func apply_gravity(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * dt
	elif velocity.y < 0.0:
		velocity.y = -0.5
