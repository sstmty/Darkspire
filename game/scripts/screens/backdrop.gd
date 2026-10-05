extends Node2D
## Static scenery for the menu, intro and ending: a parallax background, a strip of ground and props.

const TILES := preload("res://assets/side/tiles.png")

var theme_name := "hollowd"
var ground_y := 296


func build(theme: String, gy: int = 296) -> void:
	theme_name = theme
	ground_y = gy
	for layer in ["sky", "far", "mid"]:
		var s := Sprite2D.new()
		s.texture = load("res://assets/side/bg_%s_%s.png" % [theme, layer])
		s.centered = false
		add_child(s)
	var g := Node2D.new()
	g.draw.connect(func():
		var tex: Texture2D = TILES
		var top := 7 if theme_name == "hollowd" else 2
		var fill := 1 if theme_name == "hollowd" else 3
		for c in 40:
			for r in range(0, 5):
				var idx := top if r == 0 else (fill if r < 3 else 9)
				g.draw_texture_rect_region(tex, Rect2(c * 16, ground_y + r * 16, 16, 16), Rect2(idx * 16, ((c * 7 + r) % 3) * 16, 16, 16)))
	add_child(g)


func prop(name: String, x: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/side/%s.png" % name)
	s.centered = false
	s.position = Vector2(roundf(x - s.texture.get_width() / 2.0), ground_y - s.texture.get_height())
	add_child(s)
	return s


func actor(id: String, x: float, anim: String, flip: bool = false, scale_by: int = 1) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = Game.frames(id)
	var meta := Game.char_meta(id)
	a.offset = Vector2(0, -(float(meta["h"]) / 2.0 - 4.0))
	a.position = Vector2(x, ground_y)
	a.scale = Vector2(scale_by, scale_by)
	a.flip_h = flip
	a.play(anim)
	add_child(a)
	return a


func fire(pos: Vector2, color: Color, w: float = 5.0, n: int = 24) -> CPUParticles2D:
	var f := CPUParticles2D.new()
	f.position = pos
	f.amount = n
	f.lifetime = 0.9
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(w, 2)
	f.direction = Vector2(0, -1)
	f.spread = 12
	f.gravity = Vector2(0, -30)
	f.initial_velocity_min = 8
	f.initial_velocity_max = 24
	f.scale_amount_min = 1.0
	f.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, color.lightened(0.5))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	f.color_ramp = g
	add_child(f)
	return f


func embers(color: Color) -> void:
	var e := CPUParticles2D.new()
	e.position = Vector2(320, 370)
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(330, 4)
	e.amount = 40
	e.lifetime = 6.0
	e.preprocess = 6.0
	e.direction = Vector2(0, -1)
	e.spread = 25
	e.gravity = Vector2(0, -4)
	e.initial_velocity_min = 15
	e.initial_velocity_max = 45
	e.scale_amount_max = 2.0
	e.color = color
	add_child(e)
