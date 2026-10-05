extends CharacterBody2D
## Нэйра, the oath-weaver: follows the hunter, binds enemies with her thread and shares his wounds.

const SPEED := 120.0
const GRAVITY := 900.0

var level: Node
var sprite: AnimatedSprite2D
var facing := 1
var state := "move"  # move, cast, hurt
var state_t := 0.0
var anim := ""
var cast_cd := 3.0
var target: Node
var hit_done := false
var invuln := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 28)
	shape.shape = r
	shape.position = Vector2(0, -14)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.frames("nayra")
	sprite.offset = Vector2(0, -20)
	add_child(sprite)
	_play("idle")


func hurt_rect() -> Rect2:
	return Rect2(position.x - 5, position.y - 28, 10, 28)


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
	cast_cd = maxf(0.0, cast_cd - delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 420.0)
	var p: Node = level.player
	if level.busy or not p.alive():
		velocity.x = 0.0
		if state == "move":
			_play("idle")
	elif state == "cast":
		velocity.x = 0.0
		if not hit_done and sprite.frame >= Game.hit_frame("nayra", "cast"):
			hit_done = true
			if is_instance_valid(target) and target.alive():
				target.root(2.5)
				target.take_hit(8.0, facing)
				level.bind_flash(self, target)
				Sfx.play("buff", 1.6)
		if state_t >= Game.anim_len("nayra", "cast"):
			_set_state("move")
	elif state == "hurt":
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		if state_t >= 0.3:
			_set_state("move")
	else:
		_follow(p)
	sprite.flip_h = facing < 0
	move_and_slide()
	if position.distance_to(p.position) > 240.0 or position.y > level.H * level.T:
		position = p.position + Vector2(-p.facing * 20.0, -4.0)
		velocity = Vector2.ZERO
		level.burst(position + Vector2(0, -14), Color(0.4, 0.75, 1.0), 10)


func _follow(p: Node) -> void:
	var tx: float = p.position.x - p.facing * 30.0
	var dx := tx - position.x
	if absf(dx) > 8.0:
		facing = 1 if dx > 0.0 else -1
		velocity.x = facing * SPEED * minf(1.0, absf(dx) / 40.0)
		_play("run" if is_on_floor() else "idle")
		if is_on_floor():
			var ahead := position.x + facing * 12.0
			if level.solid_px(ahead, position.y - 8.0) or not level.floor_px(ahead, position.y + 4.0) or p.position.y < position.y - 24.0:
				velocity.y = -285.0
	else:
		velocity.x = 0.0
		facing = p.facing
		_play("idle")
	if cast_cd <= 0.0:
		for e in level.targets():
			if not e.stats.get("boss", false) or not e.get("scripted"):
				if e.root_t <= 0.0 and position.distance_to(e.position) < 150.0:
					target = e
					facing = 1 if e.position.x > position.x else -1
					_set_state("cast")
					anim = ""
					_play("cast")
					cast_cd = 7.0
					return


## The oath-thread: a wound to Нэйра is felt by the hunter too.
func take_damage(d: float, dir: int) -> bool:
	if invuln > 0.0:
		return false
	invuln = 0.6
	sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	Sfx.play("hit", 1.4)
	_set_state("hurt")
	_play("hurt")
	velocity = Vector2(dir * 80.0, -80.0)
	level.bind_flash(self, level.player)
	level.player.take_damage(d * 0.5, dir)
	return true
