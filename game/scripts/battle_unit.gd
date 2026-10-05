extends Node2D
## One stack of troops on the battlefield: sprite, shadow, count badge and state.

signal hit_frame

var id := ""
var def := {}
var side := 0  # 0 = player, 1 = enemy
var count := 0
var top_hp := 0
var cell := Vector2i.ZERO
var shots := 0
var retaliated := false
var defending := false
var waited := false
var atk_bonus := 0
var slot := -1  # index in Game.army for player stacks
var start_count := 0
var dead := false

var sprite: AnimatedSprite2D
var badge: Label
var badge_bg: ColorRect
var _hit_at := 99


func setup(unit_id: String, n: int, s: int) -> void:
	id = unit_id
	def = Data.UNITS[unit_id]
	side = s
	count = n
	start_count = n
	top_hp = int(def["hp"])
	shots = int(def["shots"])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Game.frames(unit_id)
	sprite.position = Vector2(0, -26)
	sprite.flip_h = side == 1
	add_child(sprite)
	sprite.play("idle")
	sprite.frame = randi() % 4
	sprite.speed_scale = randf_range(0.85, 1.1)
	_hit_at = int(Game.unit_meta(unit_id)["hit"])
	sprite.frame_changed.connect(_on_frame)
	badge_bg = ColorRect.new()
	badge_bg.color = Color("2a1e33") if side == 0 else Color("3a1518")
	badge_bg.size = Vector2(20, 9)
	badge_bg.position = Vector2(6 if side == 0 else -26, -4)
	add_child(badge_bg)
	var border := ReferenceRect.new()
	border.border_color = Color("e0b55a") if side == 0 else Color("c04a3a")
	border.border_width = 1
	border.editor_only = false
	border.size = badge_bg.size
	badge_bg.add_child(border)
	badge = Game.label("", 8, Color("fff2c8"))
	badge.position = Vector2(0, -2)
	badge.size = Vector2(20, 9)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_bg.add_child(badge)
	refresh_badge()


func refresh_badge() -> void:
	badge.text = str(count)
	badge_bg.visible = not dead


func _draw() -> void:
	if dead:
		return
	var big: bool = def.get("boss", false) or id.ends_with("knight") or id.ends_with("rider") or id.ends_with("lord")
	var rx := 16.0 if big else 10.0
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * rx, sin(a) * rx * 0.32 + 1))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.35))


func total_hp() -> int:
	return (count - 1) * int(def["hp"]) + top_hp


func is_ranged() -> bool:
	return int(def["shots"]) > 0


func face(dir_x: float) -> void:
	if dir_x > 0.5:
		sprite.flip_h = false
	elif dir_x < -0.5:
		sprite.flip_h = true


func face_default() -> void:
	sprite.flip_h = side == 1


func _on_frame() -> void:
	if sprite.animation == "attack" and sprite.frame == _hit_at:
		hit_frame.emit()


func play_idle() -> void:
	if not dead:
		sprite.play("idle")


## Plays the attack animation and returns when the blow lands (or missile flies).
func attack_anim() -> void:
	sprite.play("attack")
	await hit_frame


func finish_anim() -> void:
	if sprite.is_playing() and sprite.animation != "idle":
		await sprite.animation_finished
	play_idle()


func hurt() -> void:
	sprite.play("hurt")
	var tw := create_tween()
	sprite.modulate = Color(2.2, 0.7, 0.7)
	tw.tween_property(sprite, "modulate", Color(1, 1, 1), 0.3)
	await sprite.animation_finished
	play_idle()


func die() -> void:
	dead = true
	refresh_badge()
	queue_redraw()
	sprite.play("death")
	await sprite.animation_finished
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color(0.55, 0.5, 0.5, 0.85), 0.6)


## Returns number of creatures killed.
func take_damage(dmg: int) -> int:
	var before := count
	var t := total_hp() - dmg
	if t <= 0:
		count = 0
		top_hp = 0
	else:
		var hp := int(def["hp"])
		count = int(ceil(float(t) / hp))
		top_hp = t - (count - 1) * hp
	refresh_badge()
	return before - count
