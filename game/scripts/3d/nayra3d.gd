extends "res://scripts/3d/actor.gd"
## Нэйра in 3D: follows the hunter, binds enemies with her thread and shares his wounds.

const SPEED := 6.0

var cast_cd := 3.0
var target: Node
var hit_done := false
var invuln := 0.0


func _ready() -> void:
	make_body(0.3, 1.7)
	collision_layer = 8
	collision_mask = 1
	build_rig("nayra")


func _physics_process(dt: float) -> void:
	state_t += dt
	invuln = maxf(0.0, invuln - dt)
	cast_cd = maxf(0.0, cast_cd - dt)
	apply_gravity(dt)
	var p: Node = level.player
	var follow: Vector3 = p.global_position - p.forward() * 0.5 + Vector3(cos(p.yaw), 0, -sin(p.yaw)) * -1.7
	if level.busy or not p.alive():
		velocity.x = 0.0
		velocity.z = 0.0
	elif state == "cast":
		velocity.x = 0.0
		velocity.z = 0.0
		if is_instance_valid(target):
			turn_toward(yaw_to(global_position, target.global_position), 8.0, dt)
		if not hit_done and state_t >= 0.6:
			hit_done = true
			if is_instance_valid(target) and target.alive():
				target.root(2.5)
				target.take_hit(8.0, self)
				level.bind_flash(self, target)
				Sfx.play("buff", 1.6)
		if state_t >= 1.2:
			set_state("move")
	elif state == "hurt":
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
		if state_t >= 0.4:
			set_state("move")
	else:
		var to := follow - global_position
		to.y = 0
		var spd := SPEED * clampf(to.length() / 3.0, 0.0, 1.0) * (1.6 if p.riding != null else 1.0)
		if to.length() > 0.5:
			var f := to.normalized()
			velocity.x = f.x * spd
			velocity.z = f.z * spd
			turn_toward(atan2(-f.x, -f.z), 8.0, dt)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			turn_toward(p.yaw, 3.0, dt)
		if is_on_floor() and get_slide_collision_count() > 0 and to.length() > 2.0:
			velocity.y = 6.0
		if cast_cd <= 0.0 and p.riding == null:
			for e in level.targets():
				if e.get("scripted") == true or e.root_t > 0.0:
					continue
				if global_position.distance_to(e.global_position) < 10.0:
					target = e
					set_state("cast")
					hit_done = false
					cast_cd = 7.0
					break
	move_and_slide()
	if global_position.distance_to(p.global_position) > 26.0 or global_position.y < level.death_y:
		global_position = p.global_position - p.forward() * 0.5 + Vector3(cos(p.yaw), 0, -sin(p.yaw)) * -1.7 + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
		level.burst(center(), Color(0.4, 0.75, 1.0), 16)
	rig.rotation.y = yaw
	var anim := {"state": "move", "speed": Vector2(velocity.x, velocity.z).length(), "run": SPEED}
	if state == "cast":
		anim = {"state": "cast", "t": state_t / 1.2}
	elif state == "hurt":
		anim = {"state": "hurt", "t": state_t / 0.4}
	rig.animate(dt, anim)


## The oath-thread: a wound to Нэйра is felt by the hunter too.
func take_damage(d: float, from: Node3D) -> bool:
	if invuln > 0.0:
		return false
	invuln = 0.6
	Sfx.play("hit", 1.4)
	set_state("hurt")
	level.bind_flash(self, level.player)
	level.player.take_damage(d * 0.5, from)
	return true
