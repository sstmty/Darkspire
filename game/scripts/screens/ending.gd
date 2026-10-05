extends Node2D
## End of chapter 1: past the Rust Bridge, on the road to the Rotten Marshes.

const BACKDROP := preload("res://scripts/screens/backdrop.gd")


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var bd := BACKDROP.new()
	add_child(bd)
	bd.build("border")
	bd.prop("banner", 120)
	bd.prop("dead_tree2", 560)
	var said := bd.actor("said", 200, "run")
	var nayra := bd.actor("nayra", 168, "run")
	for a in [said, nayra]:
		var tw := create_tween()
		tw.tween_property(a, "position:x", a.position.x + 240.0, 6.0)
		tw.tween_callback(a.play.bind("idle"))
	bd.embers(Color(0.75, 0.8, 0.9, 0.6))
	var ui := CanvasLayer.new()
	add_child(ui)
	var t := Game.label("Конец главы 1", 24, Color("f0d890"), 3)
	t.size = Vector2(640, 30)
	t.position = Vector2(0, 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(t)
	var s: Dictionary = Game.stats
	var info := Game.label("Ржавый мост пройден. Сир Дрейвен назвал тебя капитаном, и ты не знаешь почему.\nНить Нэйры тянется на юг, в Гнилые Топи, откуда она бежала.\n\nСмертей: %d   Повержено врагов: %d   Забыто воспоминаний: %d из %d\n\nПродолжение: Глава 2. Гнилые Топи." % [s.get("deaths", 0), s.get("kills", 0), Game.lost.size(), Data.MEMORIES.size()], 10, Color("d8d0e0"), 2)
	info.size = Vector2(560, 80)
	info.position = Vector2(40, 84)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.add_child(info)
	var b := Game.button("В главное меню", func(): Game.goto("menu"), 12)
	b.position = Vector2(260, 200)
	b.custom_minimum_size = Vector2(120, 0)
	ui.add_child(b)
	Sfx.play("victory")
