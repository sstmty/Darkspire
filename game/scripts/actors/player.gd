extends CharacterBody2D
## Said, the Grey Cloak hunter: run, jump, roll, a two-hit combo and the healing flask.

const SPEED := 112.0
const ACCEL := 1000.0
const GRAVITY := 900.0
const MAX_FALL := 420.0
const JUMP_V := -292.0
const ROLL_SPEED := 180.0
const ROLL_TIME := 0.42
const MAX_HP := 100.0
const MAX_ST := 100.0
const ATTACKS := {"attack1": {"dmg": 22.0, "st": 18.0, "reach": 34.0}, "attack2": {"dmg": 30.0, "st": 22.0, "reach": 38.0}}
const HEAL := 45.0

var level: Node
var sprite: AnimatedSprite2D
var facing := 1
var hp := MAX_HP
var stamina := MAX_ST
var state := "move"  # move, roll, attack, heal, hurt, dead
var state_t := 0.0
var anim := ""
var queued := false
var hit_done := false
var healed := false
var invuln := 0.0
var coyote := 0.0
var jump_buf := 0.0
var st_delay := 0.0
var rust := 0.0  # Draven's rust: slows stamina and eats health
var input_lock := 0.0
var bot := false
var _step_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 30)
	shape.shape = r
	shape.position = Vector2(0, -15)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.frames("said")
	sprite.offset = Vector2(0, -20)
	add_child(sprite)
	_play("idle")
	bot = Game.autotest


func alive() -> bool:
	return state != "dead"


func hurt_rect() -> Rect2:
	return Rect2(position.x - 6, position.y - 30, 12, 30)


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
	invuln = maxf(0.0, invuln - delta)
	input_lock = maxf(0.0, input_lock - delta)
	jump_buf = maxf(0.0, jump_buf - delta)
	st_delay = maxf(0.0, st_delay - delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		coyote = maxf(0.0, coyote - delta)
	else:
		coyote = 0.1
	if st_delay <= 0.0 and state != "roll" and state != "attack":
		stamina = minf(MAX_ST, stamina + (18.0 if rust > 0.0 else 48.0) * delta)
	if rust > 0.0:
		rust -= delta
		if state != "dead":
			hp = maxf(1.0, hp - 2.0 * delta)
	sprite.modulate = Color(1.0, 0.72, 0.5) if rust > 0.0 else Color.WHITE
	if invuln > 0.0 and state != "roll" and int(invuln * 20) % 2 == 0:
		sprite.modulate.a = 0.5

	var inp := {"x": 0.0, "jump": false, "jump_held": false, "attack": false, "roll": false, "heal": false}
	if state != "dead" and not level.busy and input_lock <= 0.0:
		inp = _bot_input() if bot else _read_input()
	if inp["jump"]:
		jump_buf = 0.12

	match state:
		"move":
			velocity.x = move_toward(velocity.x, inp["x"] * SPEED, ACCEL * delta)
			if inp["x"] != 0.0:
				facing = 1 if inp["x"] > 0.0 else -1
			if jump_buf > 0.0 and coyote > 0.0:
				velocity.y = JUMP_V
				jump_buf = 0.0
				coyote = 0.0
				Sfx.play("step", 1.3)
			if velocity.y < -100.0 and not inp["jump_held"]:
				velocity.y = -100.0
			if inp["attack"] and stamina > 0.0:
				_start_attack("attack1")
			elif inp["roll"] and stamina > 0.0 and is_on_floor():
				_set_state("roll")
				_spend(25.0)
				_play("roll")
				Sfx.play("swing", 0.6)
			elif inp["heal"] and Game.flasks > 0 and is_on_floor():
				_set_state("heal")
				healed = false
				_play("heal")
			else:
				_move_anim(delta)
		"roll":
			velocity.x = facing * ROLL_SPEED * (1.0 - 0.35 * state_t / ROLL_TIME)
			if state_t >= ROLL_TIME:
				_set_state("move")
		"attack":
			velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if inp["attack"]:
				queued = true
			if not hit_done and sprite.frame >= Game.hit_frame("said", anim):
				hit_done = true
				_strike(ATTACKS[anim])
			if state_t >= Game.anim_len("said", anim):
				if queued and anim == "attack1" and stamina > 0.0:
					_start_attack("attack2")
				else:
					_set_state("move")
		"heal":
			velocity.x = 0.0
			if not healed and state_t >= 0.45:
				healed = true
				Game.flasks -= 1
				hp = minf(MAX_HP, hp + HEAL)
				rust = 0.0
				Sfx.play("buff", 1.2)
				level.burst(position + Vector2(0, -20), Color(1.0, 0.7, 0.3), 14)
			if state_t >= Game.anim_len("said", "heal"):
				_set_state("move")
		"hurt":
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if state_t >= 0.3:
				_set_state("move")
		"dead":
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	sprite.flip_h = facing < 0
	move_and_slide()
	if position.y > level.H * level.T + 40 and state != "dead":
		die()


func _move_anim(delta: float) -> void:
	if is_on_floor():
		if absf(velocity.x) > 10.0:
			_play("run")
			_step_t += delta
			if _step_t > 0.28:
				_step_t = 0.0
				Sfx.play("step", randf_range(0.9, 1.1))
		else:
			_play("idle")
	else:
		_play("jump" if velocity.y < 0.0 else "fall")


func _spend(st: float) -> void:
	stamina -= st
	st_delay = 0.55


func _start_attack(a: String) -> void:
	_set_state("attack")
	queued = false
	_spend(ATTACKS[a]["st"])
	anim = ""
	_play(a)
	velocity.x = facing * 60.0
	Sfx.play("swing", 1.0 if a == "attack1" else 0.85)


func _strike(a: Dictionary) -> void:
	var reach: float = a["reach"]
	var r := Rect2(position.x + (2.0 if facing > 0 else -reach - 2.0), position.y - 34, reach, 32)
	for e in level.targets():
		if r.intersects(e.hurt_rect()):
			e.take_hit(a["dmg"], facing)


func take_damage(dmg: float, dir: int, unavoidable: bool = false) -> bool:
	if state == "dead":
		return false
	if not unavoidable and (invuln > 0.0 or state == "roll"):
		return false
	if Game.autotest and not unavoidable:
		dmg *= 0.3
	hp -= dmg
	Sfx.play("hit", 0.9)
	level.shake(3.0)
	level.burst(position + Vector2(0, -18), Color(0.8, 0.1, 0.1), 8)
	if hp <= 0.0:
		hp = 0.0
		die()
		return true
	_set_state("hurt")
	_play("hurt")
	velocity = Vector2(dir * 110.0, -110.0)
	invuln = 0.6
	return true


func die() -> void:
	if state == "dead":
		return
	_set_state("dead")
	_play("death")
	level.on_player_death()


func _read_input() -> Dictionary:
	return {
		"x": Input.get_axis("left", "right"),
		"jump": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"attack": Input.is_action_just_pressed("attack"),
		"roll": Input.is_action_just_pressed("roll"),
		"heal": Input.is_action_just_pressed("heal"),
	}


## Self-play for the automated test: walk right, fight what is close, jump gaps and walls.
func _bot_input() -> Dictionary:
	var d := {"x": 1.0, "jump": false, "jump_held": true, "attack": false, "roll": false, "heal": false}
	var near: Node = null
	var nd := 1e9
	for e in level.targets():
		var dx: float = e.position.x - position.x
		if absf(dx) < nd and absf(e.position.y - position.y) < 64.0:
			nd = absf(dx)
			near = e
	if near != null and nd < 220.0:
		var dx: float = near.position.x - position.x
		var reach: float = 26.0 + near.half_width()
		facing = 1 if dx > 0.0 else -1
		if nd < reach:
			d["x"] = 0.0
			d["attack"] = stamina > 25.0 and state == "move"
			if near.is_striking() and stamina > 30.0 and randf() < 0.08:
				d["roll"] = true
				facing = -facing
		else:
			d["x"] = float(facing)
	if hp < 50.0 and Game.flasks > 0:
		if near == null or nd > 70.0 or float(near.cooldown) > 0.5:
			d["heal"] = true
			d["attack"] = false
		elif stamina > 25.0 and state == "move":
			d["roll"] = true
			facing = -facing
	if is_on_floor() and d["x"] != 0.0:
		var ahead := position.x + float(facing) * 14.0
		var wall: bool = level.solid_px(ahead, position.y - 8.0) or level.solid_px(ahead, position.y - 24.0)
		var gap: bool = not level.floor_px(ahead, position.y + 4.0)
		if wall or gap:
			d["jump"] = true
	return d
