extends "res://scripts/3d/actor.gd"
## A creature of the Rust in 3D: waits, notices the hunter, chases, winds up and strikes.

const KINDS := {
	"ashghoul": {"speed": 3.4, "aggro": 13.0, "reach": 1.7, "attacks": [["claw", 0.9, 0.55, 1.0]], "r": 0.35, "h": 1.5},
	"rustguard": {"speed": 2.0, "aggro": 15.0, "reach": 2.4, "attacks": [["attack2", 1.4, 0.58, 1.0], ["attack1", 1.0, 0.5, 0.8]], "r": 0.5, "h": 2.0},
	"shepherd": {"speed": 1.7, "aggro": 99.0, "reach": 3.4, "attacks": [["attack2", 1.5, 0.58, 1.0]], "r": 0.7, "h": 2.6},
	"draven": {"speed": 2.5, "aggro": 99.0, "reach": 3.6, "attacks": [["heavy", 1.4, 0.62, 1.0], ["attack2", 1.3, 0.58, 1.1]], "r": 0.7, "h": 2.5},
}

var stats: Dictionary
var spec: Dictionary
var dmg := 10.0
var speed := 2.0
var reach := 2.0
var attack := ""
var attack_dur := 1.0
var attack_hit := 0.5
var attack_mul := 1.0
var hit_done := false
var cooldown := 0.0
var poise := 0
var root_t := 0.0
var spotted := false
var home := Vector3.ZERO


func setup(k: String, lvl: Node) -> void:
	kind = k
	level = lvl
	stats = Data.ENEMIES[k]
	spec = KINDS[k]
	max_hp = float(stats["hp"])
	hp = max_hp
	dmg = float(stats["dmg"])
	speed = spec["speed"]
	reach = spec["reach"]


func _ready() -> void:
	make_body(spec["r"], spec["h"])
	collision_layer = 4
	collision_mask = 1 | 2
	build_rig(kind)
	home = global_position
	yaw = randf() * TAU


func is_striking() -> bool:
	return state == "attack" and not hit_done


func _physics_process(dt: float) -> void:
	state_t += dt
	cooldown = maxf(0.0, cooldown - dt)
	root_t = maxf(0.0, root_t - dt)
	apply_gravity(dt)
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * dt)
	elif level.busy:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		think(dt)
		if root_t > 0.0 and state != "attack":
			velocity.x = 0.0
			velocity.z = 0.0
	move_and_slide()
	if global_position.y < level.death_y and state != "dead":
		die()
	_animate(dt)


func _animate(dt: float) -> void:
	rig.rotation.y = yaw
	var p := {"state": "move", "speed": Vector2(velocity.x, velocity.z).length(), "run": maxf(3.0, speed)}
	match state:
		"attack":
			p = {"state": attack, "t": state_t / attack_dur}
		"hurt":
			p = {"state": "hurt", "t": state_t / 0.45}
		"dead":
			p = {"state": "death", "t": state_t / 1.3}
	rig.animate(dt, p)


func think(dt: float) -> void:
	var p: Node = level.player
	var dist := flat_dist(p.global_position)
	match state:
		"move":
			if not spotted:
				velocity.x = 0.0
				velocity.z = 0.0
				if p.alive() and dist < float(spec["aggro"]) and absf(p.global_position.y - global_position.y) < 4.0:
					spotted = true
					if randf() < 0.5:
						level.say(stats["name"], Data.BARKS[kind].pick_random())
				return
			if not p.alive() or dist > float(spec["aggro"]) * 2.2:
				spotted = false
				return
			turn_toward(yaw_to(global_position, p.global_position), 6.0, dt)
			if dist <= reach and cooldown <= 0.0 and root_t <= 0.0:
				choose_attack(dist)
			elif dist > reach * 0.75:
				var f := forward()
				velocity.x = f.x * speed
				velocity.z = f.z * speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		"attack":
			attack_step(dt)
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 12.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 12.0 * dt)
			if state_t >= 0.45:
				set_state("move")


func choose_attack(_dist: float) -> void:
	var list: Array = spec["attacks"]
	start_attack(list[randi() % list.size()])


func start_attack(a: Array) -> void:
	attack = a[0]
	attack_dur = a[1]
	attack_hit = a[2]
	attack_mul = a[3]
	hit_done = false
	set_state("attack")
	velocity.x = 0.0
	velocity.z = 0.0


func attack_step(dt: float) -> void:
	var t := state_t / attack_dur
	var lunge := 0.0
	if kind == "ashghoul" and t > attack_hit - 0.15 and t < attack_hit:
		lunge = 5.0
	var f := forward()
	velocity.x = move_toward(velocity.x, f.x * lunge, 30.0 * dt)
	velocity.z = move_toward(velocity.z, f.z * lunge, 30.0 * dt)
	if t < attack_hit - 0.1:
		turn_toward(yaw_to(global_position, level.player.global_position), 3.0, dt)
	if not hit_done and t >= attack_hit:
		hit_done = true
		Sfx.play("bite" if kind == "ashghoul" else "swing", 0.75)
		strike(reach + 0.3, dmg * attack_mul)
	if t >= 1.0:
		set_state("move")
		cooldown = randf_range(0.5, 1.2)


func strike(r: float, d: float) -> void:
	var p: Node = level.player
	if in_reach(p, r, 65.0) and p.take_damage(d, self):
		on_hit_player()
	if level.nayra != null and in_reach(level.nayra, r, 65.0):
		level.nayra.take_damage(d, self)


func on_hit_player() -> void:
	pass


func take_hit(d: float, from: Node3D) -> void:
	if state == "dead":
		return
	hp -= d
	var metal := kind in ["rustguard", "draven"]
	Sfx.play("clang" if metal else "hit", randf_range(0.9, 1.1))
	level.burst(center(), Color(0.95, 0.6, 0.25) if metal else Color(0.3, 0.26, 0.26), 12)
	if hp <= 0.0:
		die()
		return
	spotted = true
	poise += 1
	if poise > int(stats.get("poise", 0)) and not stats.get("boss", false):
		poise = 0
		set_state("hurt")
		var away := global_position - from.global_position
		away.y = 0
		velocity = away.normalized() * 3.0


func root(t: float) -> void:
	root_t = t
	level.burst(center(), Color(0.4, 0.75, 1.0), 16)


func die() -> void:
	set_state("dead")
	collision_layer = 0
	Game.stats["kills"] = int(Game.stats.get("kills", 0)) + 1
	Sfx.play("thud")
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(rig, "position:y", -1.2, 2.0)
	tw.tween_callback(func(): visible = false)
