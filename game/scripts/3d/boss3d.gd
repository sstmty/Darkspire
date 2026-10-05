extends "res://scripts/3d/enemy3d.gd"
## Bosses in 3D. Пастырь Мор: staff slams, ash waves and his flock; the first meeting cannot be won.
## Сир Дрейвен: sweeps and lunges; in the second phase every hit leaves rust.

const WAVE := preload("res://scripts/3d/wave3d.gd")

var phase := 1
var scripted := false
var doom := false
var fight_t := 0.0
var cast_cd := 3.0
var thrust_cd := 4.0
var summoned: Array = []


func intro() -> void:
	spotted = true
	level.say(stats["name"], Data.BOSS_LINES[kind][0], 3.5)


func think(dt: float) -> void:
	fight_t += dt
	cast_cd = maxf(0.0, cast_cd - dt)
	thrust_cd = maxf(0.0, thrust_cd - dt)
	var p: Node = level.player
	var dist := flat_dist(p.global_position)
	if scripted and not doom and state != "attack" and (fight_t > 22.0 or hp < max_hp * 0.72):
		doom = true
		level.say(stats["name"], Data.BOSS_LINES[kind][1], 4.0)
		start_attack(["cast", 1.6, 0.6, 1.0])
		return
	if phase == 1 and not scripted and hp < max_hp * 0.5:
		phase = 2
		speed *= 1.3
		level.say(stats["name"], Data.BOSS_LINES[kind][1 if kind == "draven" else 2], 3.5)
		level.shake(0.4)
		Sfx.play("thud", 0.6)
		if kind == "draven":
			level.burst(center(), Color(0.9, 0.4, 0.15), 40)
	match state:
		"move":
			if not p.alive():
				velocity.x = 0.0
				velocity.z = 0.0
				return
			turn_toward(yaw_to(global_position, p.global_position), 4.0, dt)
			if dist <= reach and cooldown <= 0.0:
				choose_attack(dist)
			elif kind == "shepherd" and cast_cd <= 0.0 and dist > 5.0:
				start_attack(["cast", 1.3, 0.5, 1.0])
			elif kind == "draven" and thrust_cd <= 0.0 and cooldown <= 0.0 and dist > 4.5 and dist < 11.0:
				start_attack(["thrust", 1.1, 0.55, 0.85])
				thrust_cd = randf_range(3.0, 5.0)
			elif dist > reach * 0.75 and root_t <= 0.0:
				var f := forward()
				velocity.x = f.x * speed
				velocity.z = f.z * speed
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		"attack":
			_boss_attack(dt)


func _boss_attack(dt: float) -> void:
	var t := state_t / attack_dur
	var f := forward()
	if attack == "thrust" and t > 0.3 and t < attack_hit:
		velocity.x = f.x * 11.0
		velocity.z = f.z * 11.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * dt)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * dt)
		if t < attack_hit - 0.15:
			turn_toward(yaw_to(global_position, level.player.global_position), 2.5 * (1.4 if phase == 2 else 1.0), dt)
	if not hit_done and t >= attack_hit:
		hit_done = true
		match attack:
			"cast":
				if doom:
					_doom_blast()
				else:
					_cast()
			_:
				Sfx.play("swing", 0.6)
				level.shake(0.3)
				level.burst(rig.blade_tip(), Color(0.5, 0.45, 0.45), 14)
				strike(reach + 0.5, dmg * attack_mul)
	if t >= 1.0:
		set_state("move")
		cooldown = randf_range(0.6, 1.3) / (1.35 if phase == 2 else 1.0)
		if attack == "cast":
			cast_cd = 4.5 if phase == 1 else 3.2


func _cast() -> void:
	Sfx.play("bow", 0.6)
	summoned = summoned.filter(func(e): return is_instance_valid(e) and e.alive())
	if phase == 2 and summoned.size() < 2 and randf() < 0.5:
		var e: Node = level.spawn_enemy("ashghoul", global_position + forward() * 2.5 + Vector3(0, 0.5, 0))
		e.spotted = true
		summoned.append(e)
		level.burst(e.center(), Color(0.3, 0.28, 0.3), 24)
		return
	for k in ([-0.35, 0.0, 0.35] if phase == 2 else [0.0]):
		var w := WAVE.new()
		w.level = level
		w.dir = forward().rotated(Vector3.UP, k)
		w.position = global_position + w.dir * 1.5
		level.world.add_child(w)


## The first meeting: a wave of ash nobody walks out of.
func _doom_blast() -> void:
	Sfx.play("thud", 0.5)
	level.flash(Color(1.0, 0.55, 0.25))
	level.shake(0.8)
	level.burst(level.player.center(), Color(0.25, 0.22, 0.24), 60)
	level.player.take_damage(999.0, self, true)


func on_hit_player() -> void:
	if kind == "draven" and phase == 2:
		level.player.rust = 6.0


func take_hit(d: float, from: Node3D) -> void:
	if scripted:
		d = minf(d, hp - max_hp * 0.55)
		if d <= 0.0:
			Sfx.play("clang", 0.7)
			return
	super.take_hit(d, from)


func die() -> void:
	super.die()
	if kind == "draven":
		level.say(stats["name"], Data.BOSS_LINES[kind][2], 5.0)
	for e in summoned:
		if is_instance_valid(e) and e.alive():
			e.die()
	level.on_boss_dead()
