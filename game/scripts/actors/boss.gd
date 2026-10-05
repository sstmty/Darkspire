extends "res://scripts/actors/enemy.gd"
## Bosses. Пастырь Мор: staff swings, ash waves and his flock; the first meeting cannot be won.
## Сир Дрейвен: sweeps and lunges, and in the second phase every hit leaves rust.

const WAVE := preload("res://scripts/actors/wave.gd")

var phase := 1
var scripted := false
var doom := false
var fight_t := 0.0
var cast_cd := 2.5
var summoned: Array = []


func intro() -> void:
	_set_state("chase")
	spotted = true
	level.say(stats["name"], Data.BOSS_LINES[kind][0], 3.5)


func _tint() -> Color:
	if kind == "draven" and phase == 2:
		return Color(1.15, 0.8, 0.65)
	return Color.WHITE


func _think(delta: float) -> void:
	fight_t += delta
	cast_cd = maxf(0.0, cast_cd - delta)
	var p: Node = level.player
	var dx: float = p.position.x - position.x
	var dist := absf(dx)
	if scripted and not doom and state != "attack" and (fight_t > 22.0 or hp < max_hp * 0.72):
		_doom()
		return
	if phase == 1 and not scripted and hp < max_hp * 0.5:
		phase = 2
		speed *= 1.3
		level.say(stats["name"], Data.BOSS_LINES[kind][1 if kind == "draven" else 2], 3.5)
		level.shake(4.0)
		Sfx.play("thud", 0.6)
	match state:
		"idle", "chase":
			if not p.alive():
				velocity.x = 0.0
				_play("idle")
				return
			facing = 1 if dx > 0.0 else -1
			if dist <= reach and cooldown <= 0.0:
				_start_attack("attack")
			elif kind == "shepherd" and cast_cd <= 0.0 and dist > 70.0:
				_start_attack("cast")
			elif kind == "draven" and cooldown <= 0.0 and dist > 100.0 and dist < 200.0 and randf() < 0.03:
				_start_attack("thrust")
			elif dist > reach * 0.75 and root_t <= 0.0:
				velocity.x = facing * speed
				_play("walk")
			else:
				velocity.x = 0.0
				_play("idle")
		"attack":
			_boss_attack(delta)
		"hurt":
			if state_t >= 0.3:
				_set_state("chase")


func _boss_attack(delta: float) -> void:
	var hf := Game.hit_frame(kind, attack)
	if attack == "thrust" and sprite.frame >= 1 and sprite.frame <= hf:
		velocity.x = facing * 250.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	if not hit_done and sprite.frame >= hf:
		hit_done = true
		match attack:
			"attack":
				Sfx.play("swing", 0.6)
				level.shake(2.0)
				_strike(reach + 10.0, dmg)
			"thrust":
				Sfx.play("swing", 0.75)
				_strike(reach, dmg * 0.85)
			"cast":
				if doom:
					_doom_blast()
				else:
					_cast()
	if state_t >= Game.anim_len(kind, attack):
		_set_state("chase")
		cooldown = randf_range(0.7, 1.3) / (1.35 if phase == 2 else 1.0)
		if attack == "cast":
			cast_cd = 4.5 if phase == 1 else 3.0


func _cast() -> void:
	Sfx.play("bow", 0.6)
	summoned = summoned.filter(func(e): return is_instance_valid(e) and e.alive())
	if phase == 2 and summoned.size() < 2 and randf() < 0.5:
		var e: Node = level.spawn_enemy("ashghoul", position + Vector2(facing * 50.0, -8.0))
		e.spotted = true
		e._set_state("chase")
		summoned.append(e)
		level.burst(e.position + Vector2(0, -16), Color(0.3, 0.28, 0.3), 16)
		return
	var w := WAVE.new()
	w.level = level
	w.dir = facing
	w.position = position + Vector2(facing * 34.0, 0)
	level.world.add_child(w)


## The first meeting: a wave of ash nobody walks out of.
func _doom() -> void:
	doom = true
	level.say(stats["name"], Data.BOSS_LINES[kind][1], 4.0)
	_start_attack("cast")


func _doom_blast() -> void:
	Sfx.play("thud", 0.5)
	level.flash(Color(1.0, 0.55, 0.25))
	level.shake(8.0)
	level.burst(level.player.position + Vector2(0, -16), Color(0.25, 0.22, 0.24), 40)
	level.player.take_damage(999.0, facing, true)


func _on_hit_player() -> void:
	if kind == "draven" and phase == 2:
		level.player.rust = 6.0


func take_hit(d: float, dir: int) -> void:
	if scripted:
		d = minf(d, hp - max_hp * 0.55)
		if d <= 0.0:
			flash_t = 0.08
			Sfx.play("clang", 0.7)
			return
	super.take_hit(d, dir)


func die() -> void:
	super.die()
	if kind == "draven":
		level.say(stats["name"], Data.BOSS_LINES[kind][2], 5.0)
	for e in summoned:
		if is_instance_valid(e) and e.alive():
			e.die()
	level.on_boss_dead()
