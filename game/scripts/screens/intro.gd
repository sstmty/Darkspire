extends Node2D
## Opening cutscene: the burning castle and the story so far.

var text: Label
var idx := -1
var _tw: Tween


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var sky := ColorRect.new()
	sky.size = Vector2(640, 360)
	sky.color = Color("1a0d12")
	add_child(sky)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/battle/bg_ash.png")
	bg.centered = false
	bg.modulate = Color(0.8, 0.55, 0.5)
	add_child(bg)
	var castle := Sprite2D.new()
	castle.texture = load("res://assets/world/castle_vale.png")
	castle.position = Vector2(320, 150)
	castle.scale = Vector2(3, 3)
	add_child(castle)
	for i in 3:
		var fire := CPUParticles2D.new()
		fire.position = Vector2(250 + i * 70, 120 - (i % 2) * 30)
		fire.amount = 50
		fire.lifetime = 1.2
		fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fire.emission_rect_extents = Vector2(22, 4)
		fire.direction = Vector2(0, -1)
		fire.spread = 15
		fire.gravity = Vector2(0, -50)
		fire.initial_velocity_min = 20
		fire.initial_velocity_max = 50
		fire.scale_amount_min = 2.0
		fire.scale_amount_max = 5.0
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.9, 0.4, 1))
		g.set_color(1, Color(0.8, 0.1, 0.05, 0))
		fire.color_ramp = g
		add_child(fire)
	var embers := CPUParticles2D.new()
	embers.position = Vector2(320, 200)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(200, 30)
	embers.amount = 50
	embers.lifetime = 4.0
	embers.direction = Vector2(0.3, -1)
	embers.gravity = Vector2(6, -10)
	embers.initial_velocity_min = 10
	embers.initial_velocity_max = 30
	embers.color = Color(1, 0.6, 0.2, 0.9)
	add_child(embers)
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.7)
	band.position = Vector2(0, 268)
	band.size = Vector2(640, 92)
	add_child(band)
	text = Game.label("", 12, Color("e8dcc0"), 2)
	text.position = Vector2(60, 284)
	text.size = Vector2(520, 60)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(text)
	var skip := Game.label("Щелчок: дальше · Esc: пропустить", 8, Color("8a7a70"))
	skip.position = Vector2(470, 348)
	add_child(skip)
	_next()


func _next() -> void:
	if _tw and _tw.is_running():
		_tw.kill()
		text.visible_ratio = 1.0
		return
	idx += 1
	if idx >= Data.INTRO.size():
		Game.goto("world")
		return
	text.text = Data.INTRO[idx]
	text.visible_ratio = 0.0
	if idx == Data.INTRO.size() - 1:
		text.label_settings = text.label_settings.duplicate()
		text.label_settings.font_size = 20
		text.label_settings.font_color = Color("f0d890")
		Sfx.play("victory", 0.7)
	_tw = create_tween()
	_tw.tween_property(text, "visible_ratio", 1.0, text.text.length() * 0.03)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play("click")
		_next()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Game.goto("world")
		elif event.keycode in [KEY_SPACE, KEY_ENTER]:
			_next()
