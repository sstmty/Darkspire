extends Node2D
## The Shepherd's ash wave: rolls along the ground. Jump over it or roll through it.

var level: Node
var dir := 1
var speed := 150.0
var life := 3.2
var dmg := 16.0
var _t := 0.0


func _ready() -> void:
	var p := CPUParticles2D.new()
	p.amount = 40
	p.lifetime = 0.6
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(7, 9)
	p.position = Vector2(0, -9)
	p.direction = Vector2(0, -1)
	p.spread = 30
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 10
	p.initial_velocity_max = 30
	p.scale_amount_min = 1.0
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.2, 1.0))
	g.set_color(1, Color(0.2, 0.18, 0.2, 0.0))
	p.color_ramp = g
	add_child(p)


func _process(delta: float) -> void:
	_t += delta
	position.x += dir * speed * delta
	life -= delta
	queue_redraw()
	if life <= 0.0 or level.solid_px(position.x + dir * 8.0, position.y - 6.0):
		queue_free()
		return
	var r := Rect2(position.x - 7, position.y - 18, 14, 18)
	if r.intersects(level.player.hurt_rect()) and level.player.take_damage(dmg, dir):
		queue_free()
	elif level.nayra != null and r.intersects(level.nayra.hurt_rect()):
		level.nayra.take_damage(dmg, dir)


func _draw() -> void:
	for i in 4:
		var h := 10.0 + 6.0 * sin(_t * 18.0 + i * 1.7)
		draw_rect(Rect2(-7 + i * 3.5, -h, 3, h), Color(0.18, 0.15, 0.17, 0.9))
	draw_rect(Rect2(-8, -3, 16, 3), Color(0.95, 0.45, 0.15, 0.8))
