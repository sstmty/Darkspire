extends Node2D
## End of chapter screen.


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/battle/bg_fort.png")
	bg.centered = false
	bg.modulate = Color(0.45, 0.4, 0.55)
	add_child(bg)
	var spire := Sprite2D.new()
	spire.texture = load("res://assets/world/spire.png")
	spire.position = Vector2(320, 120)
	spire.scale = Vector2(3, 3)
	add_child(spire)
	var glow := CPUParticles2D.new()
	glow.position = Vector2(320, 60)
	glow.amount = 40
	glow.lifetime = 3.0
	glow.direction = Vector2(0, -1)
	glow.spread = 180
	glow.gravity = Vector2.ZERO
	glow.initial_velocity_min = 5
	glow.initial_velocity_max = 25
	glow.scale_amount_max = 2.0
	glow.color = Color(0.75, 0.35, 0.95, 0.8)
	add_child(glow)
	var ui := CanvasLayer.new()
	add_child(ui)
	var t := Game.label("Конец главы I", 24, Color("f0d890"), 3)
	t.size = Vector2(640, 30)
	t.position = Vector2(0, 200)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(t)
	var s: Dictionary = Game.stats
	var info := Game.label("Битв выиграно: %d   Врагов повержено: %d\nСвоих потеряно: %d   Уровень героя: %d\n\nМордрек Карр идёт к Тёмному Шпилю.\nПродолжение следует в главе II." % [s.get("battles", 0), s.get("killed", 0), s.get("lost", 0), Game.hero.get("level", 1)], 10, Color("d8c8e0"), 2)
	info.size = Vector2(560, 60)
	info.position = Vector2(40, 234)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(info)
	var b := Game.button("В главное меню", func(): Game.goto("menu"), 12)
	b.position = Vector2(260, 312)
	b.custom_minimum_size = Vector2(120, 0)
	ui.add_child(b)
	Sfx.play("victory")
