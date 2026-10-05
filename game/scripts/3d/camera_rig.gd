extends Node3D
## Follows the hunter in one of three views: "top" (high, Diablo-like), "third" (over the shoulder) and "first".
## Mouse or right stick turns it; V cycles the view; the wheel zooms through the views.

const MODES := ["top", "third", "first"]

var target: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.3
var mode := "third"
var dist := 4.5
var shake := 0.0
var lock: Node = null


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 1500.0
	cam.near = 0.08
	add_child(cam)
	cam.current = true
	mode = Settings.camera
	apply_settings()


func apply_settings() -> void:
	cam.fov = Settings.fov
	_apply_mode()


func set_mode(m: String) -> void:
	mode = m
	_apply_mode()


func cycle() -> void:
	set_mode(MODES[(MODES.find(mode) + 1) % MODES.size()])


func _apply_mode() -> void:
	if target != null and target.get("rig") != null:
		target.rig.set_first_person(mode == "first")
	if mode == "top":
		dist = 13.0
	elif mode == "third":
		dist = clampf(dist, 2.5, 7.0) if dist < 8.0 else 5.0


func look(rel: Vector2) -> void:
	var s: float = 0.0035 * Settings.sens
	yaw -= rel.x * s
	pitch -= rel.y * s * (-1.0 if Settings.invert_y else 1.0)
	pitch = clampf(pitch, -1.35, 1.2 if mode == "first" else 0.5)


func zoom(steps: int) -> void:
	match mode:
		"first":
			if steps > 0:
				set_mode("third")
				dist = 2.5
		"third":
			dist += steps * 0.6
			if dist < 2.2:
				set_mode("first")
			elif dist > 7.5:
				set_mode("top")
		"top":
			if steps < 0:
				set_mode("third")
				dist = 7.0


func snap() -> void:
	_update(1.0, true)


func _process(dt: float) -> void:
	_update(dt, false)


func _update(dt: float, instant: bool) -> void:
	if target == null:
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.2:
		look(stick * 600.0 * dt)
	if lock != null and is_instance_valid(lock) and lock.alive():
		var want := atan2(-(lock.global_position.x - target.global_position.x), -(lock.global_position.z - target.global_position.z))
		yaw = rotate_toward(yaw, want, 6.0 * dt)
		pitch = lerpf(pitch, -0.25, 1.0 - exp(-4.0 * dt))
	var sc: float = target.rig.scale.y if target.get("rig") != null else 1.0
	var head: Vector3 = target.global_position + Vector3(0, 1.62 * sc, 0)
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	var pos: Vector3
	match mode:
		"first":
			pos = head + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.18
			cam.global_transform = Transform3D(basis, pos)
		"top":
			var tb := Basis.from_euler(Vector3(-0.72, yaw, 0))
			pos = target.global_position + Vector3(0, 1.0, 0) + tb * Vector3(0, 0, dist)
			var k := 1.0 if instant else 1.0 - exp(-10.0 * dt)
			cam.global_transform = Transform3D(tb, cam.global_position.lerp(pos, k))
		_:
			var pivot := head + Vector3(0, 0.15, 0)
			var want := pivot + basis * Vector3(0.55, 0.0, dist)
			var space := get_world_3d().direct_space_state
			var q := PhysicsRayQueryParameters3D.create(pivot, want)
			q.collision_mask = 1
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				want = hit["position"] + (pivot - want).normalized() * 0.3
			var k2 := 1.0 if instant else 1.0 - exp(-18.0 * dt)
			cam.global_transform = Transform3D(basis, cam.global_position.lerp(want, k2))
	if shake > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.3
		shake = move_toward(shake, 0.0, 2.0 * dt)
