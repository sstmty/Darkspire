extends Node2D
## Title screen.

const BACKDROP := preload("res://scripts/screens/backdrop.gd")
const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")

var settings: PanelContainer

var help_panel: PanelContainer


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var bd := BACKDROP.new()
	add_child(bd)
	bd.build("hollowd")
	bd.prop("house_burnt", 90)
	bd.prop("dead_tree", 520)
	bd.prop("grave", 470)
	bd.prop("coal", 320)
	bd.fire(Vector2(320, 282), Color(0.4, 0.7, 1.0))
	bd.actor("said", 282, "idle")
	bd.actor("nayra", 358, "idle", true)
	bd.embers(Color(1, 0.6, 0.25, 0.8))

	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Game.label("DARKSPIRE", 40, Color("f0d890"), 4)
	title.size = Vector2(640, 50)
	title.position = Vector2(0, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(title)
	var sub := Game.label("Пролог и Глава 1: Пепельное Пограничье", 12, Color("c8b8d8"), 2)
	sub.size = Vector2(640, 16)
	sub.position = Vector2(0, 80)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(sub)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.position = Vector2(250, 120)
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
	box.add_child(Game.button("Настройки", func(): settings.visible = true, 12))
	box.add_child(Game.button("Как играть", func(): help_panel.visible = not help_panel.visible, 12))
	box.add_child(Game.button("Выход", func(): get_tree().quit(), 12))
	var ver := Game.label("v%s" % ProjectSettings.get_setting("application/config/version"), 8, Color("6a6070"))
	ver.position = Vector2(6, 346)
	ui.add_child(ver)

	settings = SETTINGS_PANEL.new()
	settings.visible = false
	ui.add_child(settings)
	help_panel = PanelContainer.new()
	help_panel.position = Vector2(150, 110)
	help_panel.custom_minimum_size = Vector2(340, 0)
	help_panel.visible = false
	var help := Game.label("""WASD: идти, Shift: бег, Пробел: прыжок.
ЛКМ: удар, нажмите дважды для серии. ПКМ или Ctrl: перекат.
R: целебная настойка. E: Угль Памяти и лошадь. Q: захват цели.
V или колесо мыши: камера сверху, сзади или от первого лица.
Tab: Память. Esc: пауза. F11: полный экран.

Said не умирает окончательно. Каждая смерть отнимает одно воспоминание.
Все клавиши можно поменять в настройках. Геймпад тоже работает.""", 10)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(320, 0)
	var hb := VBoxContainer.new()
	hb.add_child(help)
	hb.add_child(Game.button("Понятно", func(): help_panel.visible = false))
	help_panel.add_child(hb)
	ui.add_child(help_panel)
