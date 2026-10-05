extends CharacterBody2D
## A creature of the Rust: waits, chases the hunter, winds up and strikes.

const GRAVITY := 900.0
const SIZES := {
	"ashghoul": Vector2(16, 30), "rustguard": Vector2(22, 40),
	"shepherd": Vector2(36, 72), "draven": Vector2(40, 70),
}

var kind := ""
var stats: Dictionary
var level: Node
var sprite: AnimatedSprite2D
var size := Vector2(16, 30)
var hp := 1.0
var max_hp := 1.0
var dmg := 10.0
var speed := 40.0
var reach := 30.0
var facing := -1
var state := "idle"  # idle, chase, attack, hurt, dead
var state_t := 0.0
var anim := ""
var attack := "attack"
var hit_done := false
var cooldown := 0.0
var poise := 0
var root_t := 0.0
var flash_t := 0.0
var spotted := false


func setup(k: String, lvl: Node) -> void:
	kind = k
	level = lvl
	stats = Data.ENEMIES[k]
	max_hp = float(stats["hp"])
	hp = max_hp
	dmg = float(stats["dmg"])
	speed = float(stats["speed"])
	reach = float(stats["reach"])
	size = SIZES[k]


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(minf(size.x, 20.0), size.y)
	shape.shape = r
	shape.position = Vector2(0, -size.y / 2.0)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.frames(kind)
	var meta := Game.char_meta(kind)
	sprite.offset = Vector2(0, -(float(meta["h"]) / 2.0 - 4.0))
	add_child(sprite)
	_play("idle")
	sprite.frame = randi() % 4


func alive() -> bool:
	return state != "dead"


func half_width() -> float:
	return size.x / 2.0


func hurt_rect() -> Rect2:
	return Rect2(position.x - size.x / 2.0, position.y - size.y, size.x, size.y)


func is_striking() -> bool:
	return state == "attack" and not hit_done


func _play(a: String) -> void:
	if anim != a:
		anim = a
		sprite.play(a)


func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	hit_done = false


func _physics_process(delta: float) -> void:
	state_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	root_t = maxf(0.0, root_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	if state == "dead":
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	elif level.busy:
		velocity.x = 0.0
	else:
		_think(delta)
		if root_t > 0.0 and state != "attack":
			velocity.x = 0.0
	sprite.flip_h = facing < 0
	if state == "dead":
		pass
	elif flash_t > 0.0:
		sprite.modulate = Color(2.5, 2.5, 2.5)
	elif root_t > 0.0:
		sprite.modulate = Color(0.55, 0.8, 1.4)
	else:
		sprite.modulate = _tint()
	move_and_slide()
	if position.y > level.H * level.T + 60 and state != "dead":
		die()


func _tint() -> Color:
	return Color.WHITE


func _think(delta: float) -> void:
	var p: Node = level.player
	var dx: float = p.position.x - position.x
	var dist := absf(dx)
	match state:
		"idle":
			velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
			_play("idle")
			if p.alive() and dist < float(stats["aggro"]) and absf(p.position.y - position.y) < 80.0:
				_set_state("chase")
				if not spotted:
					spotted = true
					if randf() < 0.5:
						level.say(stats["name"], Data.BARKS[kind].pick_random())
		"chase":
			if not p.alive() or dist > float(stats["aggro"]) * 2.0:
				_set_state("idle")
				return
			facing = 1 if dx > 0.0 else -1
			if dist <= reach and cooldown <= 0.0 and root_t <= 0.0:
				_start_attack("attack")
			elif dist > reach * 0.7 and level.floor_px(position.x + facing * (size.x / 2.0 + 4.0), position.y + 4.0):
				velocity.x = facing * speed
				_play("walk")
			else:
				velocity.x = 0.0
				_play("idle")
		"attack":
			_attack_step(delta)
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if state_t >= 0.35:
				_set_state("chase")


func _start_attack(a: String) -> void:
	attack = a
	_set_state("attack")
	anim = ""
	_play(a)
	velocity.x = 0.0


func _attack_step(delta: float) -> void:
	var hf := Game.hit_frame(kind, attack)
	if kind == "ashghoul" and sprite.frame >= hf - 1 and sprite.frame <= hf:
		velocity.x = facing * 90.0  # the lunge
	else:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	if not hit_done and sprite.frame >= hf:
		hit_done = true
		Sfx.play("bite" if kind == "ashghoul" else "swing", 0.8)
		_strike(reach + 4.0, dmg)
	if state_t >= Game.anim_len(kind, attack):
		_set_state("chase")
		cooldown = randf_range(0.5, 1.1) / float(stats.get("fps", 1.0))


func _strike(r: float, d: float) -> void:
	var rect := Rect2(position.x + (-4.0 if facing > 0 else -r + 4.0), position.y - size.y, r, size.y)
	var p: Node = level.player
	if rect.intersects(p.hurt_rect()):
		p.take_damage(d, facing)
		_on_hit_player()
	if level.nayra != null and rect.intersects(level.nayra.hurt_rect()):
		level.nayra.take_damage(d, facing)


func _on_hit_player() -> void:
	pass


func take_hit(d: float, dir: int) -> void:
	if state == "dead":
		return
	hp -= d
	flash_t = 0.08
	Sfx.play("clang" if kind in ["rustguard", "draven"] else "hit", randf_range(0.9, 1.1))
	level.burst(position + Vector2(0, -size.y * 0.6), Color(0.9, 0.5, 0.2) if kind in ["rustguard", "draven"] else Color(0.35, 0.3, 0.3), 6)
	if hp <= 0.0:
		die()
		return
	if not spotted or state == "idle":
		spotted = true
		facing = -dir
		_set_state("chase")
	poise += 1
	if poise > int(stats.get("poise", 0)) and not stats.get("boss", false):
		poise = 0
		_set_state("hurt")
		_play("hurt")
		velocity.x = dir * 70.0


func root(t: float) -> void:
	root_t = t


func die() -> void:
	_set_state("dead")
	_play("death")
	collision_layer = 0
	Game.stats["kills"] = int(Game.stats.get("kills", 0)) + 1
	Sfx.play("thud")
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func(): visible = false)
