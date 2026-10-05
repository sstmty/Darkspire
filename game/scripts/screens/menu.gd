extends Node2D
## Title screen.

var help_panel: PanelContainer


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/battle/bg_fort.png")
	bg.centered = false
	bg.modulate = Color(0.75, 0.7, 0.8)
	add_child(bg)
	var spire := Sprite2D.new()
	spire.texture = load("res://assets/world/spire.png")
	spire.position = Vector2(320, 70)
	spire.scale = Vector2(2, 2)
	spire.modulate = Color(0.6, 0.55, 0.7)
	add_child(spire)
	# two champions facing each other
	for pair in [["vale_knight", Vector2(220, 300), false], ["karr_lord", Vector2(420, 300), true]]:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Game.frames(pair[0])
		a.position = pair[1]
		a.scale = Vector2(2, 2)
		a.flip_h = pair[2]
		a.play("idle")
		add_child(a)
	var embers := CPUParticles2D.new()
	embers.position = Vector2(320, 370)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(330, 4)
	embers.amount = 40
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.direction = Vector2(0, -1)
	embers.spread = 25
	embers.gravity = Vector2(0, -4)
	embers.initial_velocity_min = 20
	embers.initial_velocity_max = 50
	embers.scale_amount_max = 2.0
	embers.color = Color(1, 0.6, 0.25, 0.8)
	add_child(embers)

	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Game.label("DARKSPIRE", 40, Color("f0d890"), 4)
	title.size = Vector2(640, 50)
	title.position = Vector2(0, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(title)
	var sub := Game.label("Тёмный Шпиль · Глава I: Пепел Сокола", 12, Color("c8b8d8"), 2)
	sub.size = Vector2(640, 16)
	sub.position = Vector2(0, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(sub)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.position = Vector2(250, 140)
	box.custom_minimum_size = Vector2(140, 0)
	ui.add_child(box)
	box.add_child(Game.button("Новая игра", func():
		Game.new_game()
		Game.goto("intro"), 12))
	var cont := Game.button("Продолжить", func():
		if Game.load_game():
			Game.goto("world"), 12)
	cont.disabled = not Game.has_save()
	box.add_child(cont)
	box.add_child(Game.button("Как играть", func(): help_panel.visible = not help_panel.visible, 12))
	box.add_child(Game.button("Выход", func(): get_tree().quit(), 12))
	var ver := Game.label("v%s" % ProjectSettings.get_setting("application/config/version"), 8, Color("6a6070"))
	ver.position = Vector2(6, 346)
	ui.add_child(ver)

	help_panel = PanelContainer.new()
	help_panel.position = Vector2(150, 110)
	help_panel.custom_minimum_size = Vector2(340, 0)
	help_panel.visible = false
	var help := Game.label("""Карта: щёлкните по земле, чтобы идти. Щёлкните по войску, сундуку или дому, чтобы взаимодействовать. Стрелки или WASD тоже двигают героя. F5 сохраняет игру.

Бой: отряды ходят по очереди. Щёлкните по клетке, чтобы идти, по врагу, чтобы атаковать. Стрелки стреляют издалека, если рядом нет врага. Каждый отряд один раз за раунд отвечает на удар.

Кнопки боя: Защита (D), Ждать (W), Авто (A) и Клич Сокола.""", 10)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(320, 0)
	var hb := VBoxContainer.new()
	hb.add_child(help)
	hb.add_child(Game.button("Понятно", func(): help_panel.visible = false))
	help_panel.add_child(hb)
	ui.add_child(help_panel)
