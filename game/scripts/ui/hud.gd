extends CanvasLayer
## Health, stamina and flasks, the boss bar, subtitles, banners, the death screen
## and the Memory and pause menus.

var level: Node
var bars: Control
var boss: Node
var boss_name: Label
var sub: Label
var banner: Label
var prompt: Label
var flash_rect: ColorRect
var death_shade: ColorRect
var death_title: Label
var death_text: Label
var memory_panel: PanelContainer
var memory_list: VBoxContainer
var pause_panel: PanelContainer
var _sub_t := 0.0
var _banner_tw: Tween


func setup(lvl: Node) -> void:
	level = lvl
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	bars = Control.new()
	bars.size = Vector2(640, 360)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.draw.connect(_draw_bars)
	add_child(bars)
	boss_name = _centered("", 10, Color("e8dcc0"), Vector2(0, 318), 1)
	boss_name.visible = false
	sub = _centered("", 10, Color("e8dcc0"), Vector2(0, 46), 2)
	sub.size = Vector2(560, 24)
	sub.position.x = 40
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner = _centered("", 16, Color("f0d890"), Vector2(0, 110), 3)
	banner.modulate.a = 0.0
	prompt = _centered("", 9, Color("d8c8a8"), Vector2(0, 250), 1)
	flash_rect = _shade(Color(1, 1, 1, 0))
	death_shade = _shade(Color(0, 0, 0, 0))
	death_title = _centered("", 32, Color("a82a22"), Vector2(0, 140), 4)
	death_text = _centered("", 16, Color("c8b8b0"), Vector2(0, 188), 2)
	_build_memory()
	_build_pause()


func _centered(text: String, size: int, color: Color, pos: Vector2, outline: int) -> Label:
	var l := Game.label(text, size, color, outline)
	l.size = Vector2(640, 16)
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _shade(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.size = Vector2(640, 360)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


func _process(delta: float) -> void:
	bars.queue_redraw()
	sub.visible = not level.busy
	boss_name.visible = boss != null and is_instance_valid(boss) and boss.alive() and not level.busy
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			sub.text = ""


func _bar(pos: Vector2, w: float, h: float, ratio: float, fill: Color, back: Color) -> void:
	bars.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color("0c0a0e"))
	bars.draw_rect(Rect2(pos, Vector2(w, h)), back)
	bars.draw_rect(Rect2(pos, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), h)), fill)
	bars.draw_rect(Rect2(pos, Vector2(roundf(w * clampf(ratio, 0.0, 1.0)), 1)), fill.lightened(0.3))


func _draw_bars() -> void:
	var p: Node = level.player
	if p == null or level.busy:
		return
	_bar(Vector2(12, 12), 120, 6, p.hp / p.MAX_HP, Color("b3302a"), Color("3a1414"))
	_bar(Vector2(12, 22), 96, 3, p.stamina / p.MAX_ST, Color("b8742a") if p.rust > 0.0 else Color("78a046"), Color("1c2614"))
	for i in Game.flask_max:
		var x := 12.0 + i * 10.0
		var full := i < Game.flasks
		bars.draw_rect(Rect2(x + 2, 30, 3, 2), Color("8a7a6a"))
		bars.draw_rect(Rect2(x, 32, 7, 7), Color("0c0a0e"))
		bars.draw_rect(Rect2(x + 1, 33, 5, 5), Color("e08a30") if full else Color("3a3236"))
		if full:
			bars.draw_rect(Rect2(x + 1, 33, 2, 2), Color("ffd27a"))
	if boss != null and is_instance_valid(boss) and boss.alive():
		_bar(Vector2(120, 332), 400, 5, boss.hp / boss.max_hp, Color("a82a22"), Color("2a1214"))


func set_boss(b: Node) -> void:
	boss = b
	boss_name.visible = b != null
	if b != null:
		boss_name.text = b.stats["name"]


func say(who: String, text: String, dur: float = 3.0) -> void:
	sub.text = "%s: «%s»" % [who, text] if who != "" else text
	_sub_t = dur


func show_banner(text: String, hold: float = 2.0) -> void:
	if _banner_tw:
		_banner_tw.kill()
	banner.text = text
	banner.modulate.a = 0.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner, "modulate:a", 1.0, 0.6)
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(banner, "modulate:a", 0.0, 0.8)


func show_prompt(text: String) -> void:
	prompt.text = text


func flash(c: Color) -> void:
	flash_rect.color = Color(c.r, c.g, c.b, 0.85)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.6)


## Soulslike death card: the memory the Spire just took.
func show_death(memory: String) -> void:
	death_title.text = "ВЫ ЗАБЫЛИ" if memory != "" else "ВЫ ПАЛИ"
	death_text.text = memory if memory != "" else "Вам больше нечего забыть"
	death_title.modulate.a = 0.0
	death_text.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(death_shade, "color:a", 0.75, 0.8)
	tw.tween_property(death_title, "modulate:a", 1.0, 0.8)
	tw.tween_property(death_text, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.8)
	tw.tween_property(death_shade, "color:a", 1.0, 0.6)
	await tw.finished


# ---------------------------------------------------------------- menus

func _panel(pos: Vector2, w: float) -> Array:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(w, 0)
	panel.visible = false
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	return [panel, box]


func _build_memory() -> void:
	var pb := _panel(Vector2(170, 40), 300)
	memory_panel = pb[0]
	var box: VBoxContainer = pb[1]
	var t := Game.label("Память", 16, Color("f0d890"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var hint := Game.label("Каждая смерть у Шпиля стоит одного воспоминания.", 8, Color("8a7a80"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	memory_list = VBoxContainer.new()
	memory_list.add_theme_constant_override("separation", 2)
	box.add_child(memory_list)
	var close := Game.label("Tab: закрыть", 8, Color("8a6b3a"))
	close.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(close)


func _fill_memory() -> void:
	for c in memory_list.get_children():
		c.queue_free()
	for i in Data.MEMORIES.size():
		var gone: bool = Game.lost.has(i)
		var l := Game.label("· забыто ·" if gone else Data.MEMORIES[i], 9, Color("5a4e56") if gone else Color("e8dcc0"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		memory_list.add_child(l)
	var d := Game.label("Смертей: %d" % int(Game.stats.get("deaths", 0)), 9, Color("a82a22"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	memory_list.add_child(d)


const SETTINGS_PANEL := preload("res://scripts/ui/settings_panel.gd")
var settings: PanelContainer


func _build_pause() -> void:
	settings = SETTINGS_PANEL.new()
	settings.visible = false
	settings.closed.connect(func(): pause_panel.visible = true)
	add_child(settings)
	var pb := _panel(Vector2(200, 70), 240)
	pause_panel = pb[0]
	var box: VBoxContainer = pb[1]
	var t := Game.label("Пауза", 16, Color("f0d890"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var keys := Game.label("Клавиши можно поменять в настройках.\nF11: полный экран.", 9, Color("c8b8a0"))
	box.add_child(keys)
	box.add_child(Game.button("Настройки", func():
		pause_panel.visible = false
		settings.visible = true, 12))
	box.add_child(Game.button("Продолжить", func(): _toggle(pause_panel), 12))
	box.add_child(Game.button("В главное меню", func():
		get_tree().paused = false
		Game.goto("menu"), 12))


func _toggle(panel: PanelContainer) -> void:
	var open := not panel.visible
	memory_panel.visible = false
	pause_panel.visible = false
	panel.visible = open
	if open and panel == memory_panel:
		_fill_memory()
	get_tree().paused = open
	if open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		settings.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if level.busy or level.player == null or not level.player.alive():
		return
	if event.is_action_pressed("memory"):
		_toggle(memory_panel)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if settings.visible:
			return
		_toggle(pause_panel if not memory_panel.visible else memory_panel)
		get_viewport().set_input_as_handled()
