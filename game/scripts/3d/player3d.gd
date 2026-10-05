extends "res://scripts/3d/actor.gd"
## Said in 3D: run, sprint, jump, roll, a two-hit combo, the healing flask, target lock and riding a horse.

const RUN := 5.4
const SPRINT := 8.4
const ACCEL := 32.0
const JUMP_V := 6.4
const ROLL_SPEED := 8.0
const ROLL_TIME := 0.6
const MAX_HP := 100.0
const MAX_ST := 100.0
const HEAL := 45.0
const ATTACKS := {
	"attack1": {"dur": 0.62, "hit": 0.48, "dmg": 22.0, "st": 18.0, "reach": 2.3},
	"attack2": {"dur": 0.8, "hit": 0.56, "dmg": 32.0, "st": 24.0, "reach": 2.5},
}

var stamina := MAX_ST
var rust := 0.0
var invuln := 0.0
var input_lock := 0.0
var coyote := 0.0
var st_delay := 0.0
var bot := false
var riding: Node = null
var lock_target: Node = null
var attack := "attack1"
var queued := false
var hit_done := false
var healed := false
var roll_dir := Vector3.FORWARD
var _step_t := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO


func _ready() -> void:
	make_body(0.35, 1.8)
	build_rig("said")
	bot = Game.autotest
	max_hp = MAX_HP
	hp = MAX_HP


func hurt_rect() -> Vector3:
	return center()


# ---------------------------------------------------------------- frame

func _physics_process(dt: float) -> void:
	state_t += dt
	invuln = maxf(0.0, invuln - dt)
	input_lock = maxf(0.0, input_lock - dt)
	st_delay = maxf(0.0, st_delay - dt)
	if st_delay <= 0.0 and state in ["move", "ride", "heal", "hurt"]:
		stamina = minf(MAX_ST, stamina + (18.0 if rust > 0.0 else 42.0) * dt)
	if rust > 0.0:
		rust -= dt
		if state != "dead":
			hp = maxf(1.0, hp - 2.0 * dt)
	if lock_target != null and (not is_instance_valid(lock_target) or not lock_target.alive() or flat_dist(lock_target.global_position) > 24.0):
		lock_target = null

	var inp := {"move": Vector2.ZERO, "sprint": false, "jump": false, "roll": false, "attack": false, "heal": false}
	if state != "dead" and not level.busy and input_lock <= 0.0:
		inp = _bot_input() if bot else _read_input()
	var cam_yaw: float = level.cam.yaw
	var wish := Vector3(inp["move"].x, 0, inp["move"].y).rotated(Vector3.UP, cam_yaw)
	if wish.length() > 1.0:
		wish = wish.normalized()

	if riding != null:
		_ride(dt, inp, wish)
		return
	apply_gravity(dt)
	if is_on_floor():
		coyote = 0.12
	else:
		coyote = maxf(0.0, coyote - dt)

	match state:
		"move":
			var sprinting: bool = inp["sprint"] and stamina > 1.0 and wish.length() > 0.2 and lock_target == null
			var speed := SPRINT if sprinting else RUN
			if sprinting:
				stamina -= 16.0 * dt
				st_delay = 0.3
			var hv := Vector3(velocity.x, 0, velocity.z).move_toward(wish * speed, ACCEL * dt)
			velocity.x = hv.x
			velocity.z = hv.z
			_face(wish, cam_yaw, dt)
			if inp["jump"] and coyote > 0.0:
				velocity.y = JUMP_V
				coyote = 0.0
				Sfx.play("step", 1.3)
			if inp["attack"] and stamina > 0.0:
				_start_attack("attack1", wish)
			elif inp["roll"] and stamina > 0.0 and is_on_floor():
				roll_dir = wish.normalized() if wish.length() > 0.2 else forward()
				yaw = atan2(-roll_dir.x, -roll_dir.z)
				set_state("roll")
				_spend(24.0)
				Sfx.play("swing", 0.55)
			elif inp["heal"] and Game.flasks > 0 and is_on_floor():
				set_state("heal")
				healed = false
			if is_on_floor() and hv.length() > 1.0:
				_step_t += dt * hv.length()
				if _step_t > 2.2:
					_step_t = 0.0
					Sfx.play("step", randf_range(0.85, 1.1))
		"roll":
			var k := state_t / ROLL_TIME
			var v := roll_dir * ROLL_SPEED * (1.0 - 0.45 * k)
			velocity.x = v.x
			velocity.z = v.z
			if state_t >= ROLL_TIME:
				set_state("move")
		"attack":
			var a: Dictionary = ATTACKS[attack]
			var t: float = state_t / a["dur"]
			var push := 2.4 if t < 0.5 else 0.0
			velocity.x = move_toward(velocity.x, forward().x * push, 30.0 * dt)
			velocity.z = move_toward(velocity.z, forward().z * push, 30.0 * dt)
			if lock_target != null:
				turn_toward(yaw_to(global_position, lock_target.global_position), 10.0, dt)
			elif t < 0.3 and wish.length() > 0.2:
				turn_toward(atan2(-wish.x, -wish.z), 8.0, dt)
			if inp["attack"] and t > 0.2:
				queued = true
			if not hit_done and t >= a["hit"]:
				hit_done = true
				_strike(a)
			if t >= 1.0:
				if queued and attack == "attack1" and stamina > 0.0:
					_start_attack("attack2", wish)
				else:
					set_state("move")
		"heal":
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
			if not healed and state_t >= 0.6:
				healed = true
				Game.flasks -= 1
				hp = minf(MAX_HP, hp + HEAL)
				rust = 0.0
				Sfx.play("buff", 1.2)
				level.burst(center(), Color(1.0, 0.7, 0.3), 20)
			if state_t >= 1.1:
				set_state("move")
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * dt)
			if state_t >= 0.4:
				set_state("move")
		"dead":
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
	move_and_slide()
	if global_position.y < level.death_y and state != "dead":
		die()
	_animate(dt)


func _face(wish: Vector3, cam_yaw: float, dt: float) -> void:
	if lock_target != null:
		turn_toward(yaw_to(global_position, lock_target.global_position), 12.0, dt)
	elif level.cam.mode == "first":
		yaw = cam_yaw
	elif wish.length() > 0.1:
		turn_toward(atan2(-wish.x, -wish.z), 12.0, dt)


func _animate(dt: float) -> void:
	rig.rotation.y = yaw
	var hv := Vector2(velocity.x, velocity.z).length()
	var p := {"state": "move", "speed": hv, "run": RUN}
	match state:
		"move":
			if not is_on_floor() and absf(velocity.y) > 1.5:
				p["state"] = "air"
		"roll":
			p = {"state": "roll", "t": state_t / ROLL_TIME}
		"attack":
			p = {"state": attack, "t": state_t / ATTACKS[attack]["dur"]}
		"heal":
			p = {"state": "heal", "t": state_t / 1.1}
		"hurt":
			p = {"state": "hurt", "t": state_t / 0.4}
		"dead":
			p = {"state": "death", "t": state_t / 1.2}
		"ride":
			p = {"state": "ride", "speed": riding.speed if riding != null else 0.0}
	rig.animate(dt, p)


# ---------------------------------------------------------------- combat

func _spend(st: float) -> void:
	stamina -= st
	st_delay = 0.6


func _start_attack(a: String, wish: Vector3) -> void:
	attack = a
	queued = false
	hit_done = false
	set_state("attack")
	_spend(ATTACKS[a]["st"])
	if lock_target == null and wish.length() > 0.2:
		yaw = atan2(-wish.x, -wish.z)
	Sfx.play("swing", 1.0 if a == "attack1" else 0.85)


func _strike(a: Dictionary) -> void:
	var landed := false
	for e in level.targets():
		if in_reach(e, a["reach"] + (0.8 if riding != null else 0.0), 75.0):
			e.take_hit(a["dmg"], self)
			landed = true
	if landed:
		level.shake(0.12)
		level.burst(rig.blade_tip(), Color(0.9, 0.85, 0.7), 10)


func take_damage(dmg: float, from: Node3D, unavoidable: bool = false) -> bool:
	if state == "dead":
		return false
	if not unavoidable and (invuln > 0.0 or (state == "roll" and state_t > 0.05 and state_t < 0.45)):
		return false
	if Game.autotest and not unavoidable:
		dmg *= 0.3
	hp -= dmg
	Sfx.play("hit", 0.9)
	level.shake(0.25)
	level.burst(center(), Color(0.7, 0.08, 0.06), 14)
	if hp <= 0.0:
		hp = 0.0
		die()
		return true
	invuln = 0.5
	if riding == null:
		set_state("hurt")
		if from != null:
			var away := (global_position - from.global_position)
			away.y = 0
			velocity = away.normalized() * 5.0 + Vector3(0, 2.5, 0)
	return true


func die() -> void:
	if state == "dead":
		return
	if riding != null:
		dismount()
	set_state("dead")
	level.on_player_death()


# ---------------------------------------------------------------- horse

func mount(h: Node) -> void:
	riding = h
	h.rider = self
	shape.disabled = true
	set_state("ride")
	Sfx.play("step", 0.6)


func dismount() -> void:
	if riding == null:
		return
	var h: Node = riding
	riding = null
	h.rider = null
	shape.disabled = false
	var side: Vector3 = Vector3(cos(h.yaw), 0, -sin(h.yaw)) * 1.4
	global_position = h.global_position + side + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO
	if state != "dead":
		set_state("move")


func _ride(dt: float, inp: Dictionary, wish: Vector3) -> void:
	riding.drive(wish, inp["sprint"], dt)
	yaw = riding.yaw
	global_position = riding.seat()
	velocity = riding.velocity
	if state == "attack":
		var a: Dictionary = ATTACKS[attack]
		var t: float = state_t / a["dur"]
		if not hit_done and t >= a["hit"]:
			hit_done = true
			_strike(a)
		if t >= 1.0:
			set_state("ride")
	elif inp["attack"] and stamina > 0.0:
		_start_attack("attack1", Vector3.ZERO)
	if state == "attack":
		rig.rotation.y = yaw
		rig.animate(dt, {"state": attack, "t": state_t / ATTACKS[attack]["dur"]})
	else:
		state = "ride"
		_animate(dt)


# ---------------------------------------------------------------- input

func _read_input() -> Dictionary:
	return {
		"move": Input.get_vector("left", "right", "up", "down"),
		"sprint": Input.is_action_pressed("sprint"),
		"jump": Input.is_action_just_pressed("jump"),
		"roll": Input.is_action_just_pressed("roll"),
		"attack": Input.is_action_just_pressed("attack"),
		"heal": Input.is_action_just_pressed("heal"),
	}


## Self-play for the automated test: follow the road, fight whatever is close, heal when low.
func _bot_input() -> Dictionary:
	var d := {"move": Vector2.ZERO, "sprint": false, "jump": false, "roll": false, "attack": false, "heal": false}
	var near: Node = null
	var nd := 1e9
	for e in level.targets():
		var dist := flat_dist(e.global_position)
		if dist < nd and absf(e.global_position.y - global_position.y) < 3.0:
			nd = dist
			near = e
	var goal: Vector3
	if near != null and nd < 14.0:
		goal = near.global_position
		var reach: float = 1.8 + near.radius
		if nd < reach:
			yaw = yaw_to(global_position, near.global_position)
			d["attack"] = stamina > 25.0 and state == "move"
			if near.is_striking() and stamina > 30.0 and randf() < 0.06:
				d["roll"] = true
			goal = global_position
	else:
		var s: float = level.world.project(Vector2(global_position.x, global_position.z)).x
		goal = level.world.point_at(s + 6.0, 0.0)
	if hp < 50.0 and Game.flasks > 0 and (near == null or nd > 5.0 or float(near.cooldown) > 0.5):
		d["heal"] = true
		d["attack"] = false
	var to := goal - global_position
	to.y = 0
	if to.length() > 0.3:
		# the bot moves in world space: undo the camera rotation applied to input
		var local := to.normalized().rotated(Vector3.UP, -level.cam.yaw)
		d["move"] = Vector2(local.x, local.z)
	if global_position.distance_to(_last_pos) < 0.02 and d["move"] != Vector2.ZERO and state == "move":
		_stuck_t += get_physics_process_delta_time()
		if _stuck_t > 0.6:
			d["jump"] = true
			_stuck_t = 0.0
	else:
		_stuck_t = 0.0
	_last_pos = global_position
	return d
