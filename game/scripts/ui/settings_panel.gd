extends PanelContainer
## Settings window shared by the main menu and the pause menu: screen, sound and controls with key rebinding.

signal closed

var tabs: TabContainer
var _waiting: Array = []  # [action, slot, button] while waiting for a key
var _rows := {}  # action -> [Button, Button]


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = Vector2(70, 22)
	custom_minimum_size = Vector2(500, 316)
	size = custom_minimum_size
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Game.label("Настройки", 16, Color("f0d890"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	tabs = TabContainer.new()
	tabs.custom_minimum_size = Vector2(480, 252)
	tabs.add_theme_font_override("font", Game.font)
	tabs.add_theme_font_size_override("font_size", 8)
	box.add_child(tabs)
	tabs.add_child(_screen_tab())
	tabs.add_child(_sound_tab())
	tabs.add_child(_controls_tab())
	tabs.set_tab_title(0, "Экран")
	tabs.set_tab_title(1, "Звук")
	tabs.set_tab_title(2, "Управление")
	var close := Game.button("Готово", func():
		Settings.save_settings()
		visible = false
		closed.emit(), 10)
	box.add_child(close)


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	return g


func _row(g: GridContainer, text: String, ctl: Control) -> void:
	var l := Game.label(text, 10)
	l.custom_minimum_size = Vector2(200, 0)
	g.add_child(l)
	ctl.custom_minimum_size.x = maxf(ctl.custom_minimum_size.x, 200)
	g.add_child(ctl)


## A button that cycles through options; get_text(value) names the current one.
func _cycler(values: Array, get_value: Callable, set_value: Callable, names: Callable) -> Button:
	var b := Game.button("", func(): pass, 10)
	var refresh := func(): b.text = names.call(get_value.call())
	b.pressed.connect(func():
		var i := values.find(get_value.call())
		set_value.call(values[(i + 1) % values.size()])
		Settings.apply()
		refresh.call())
	refresh.call()
	return b


func _stepper(get_value: Callable, set_value: Callable, lo: float, hi: float, step: float, fmt: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var val := Game.label("", 10)
	val.custom_minimum_size = Vector2(110, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func(): val.text = fmt.call(get_value.call())
	var minus := Game.button("-", func():
		set_value.call(clampf(get_value.call() - step, lo, hi))
		Settings.apply()
		refresh.call(), 10)
	var plus := Game.button("+", func():
		set_value.call(clampf(get_value.call() + step, lo, hi))
		Settings.apply()
		refresh.call(), 10)
	minus.custom_minimum_size = Vector2(40, 0)
	plus.custom_minimum_size = Vector2(40, 0)
	h.add_child(minus)
	h.add_child(val)
	h.add_child(plus)
	refresh.call()
	return h


func _screen_tab() -> Control:
	var g := _grid()
	g.name = "Screen"
	_row(g, "Режим окна", _cycler(Settings.WINDOW_MODES, func(): return Settings.window_mode, func(v): Settings.window_mode = v,
		func(v): return {"windowed": "Окно", "fullscreen": "Полный экран", "borderless": "Окно без рамки"}[v]))
	_row(g, "Вертикальная синхронизация", _cycler([true, false], func(): return Settings.vsync, func(v): Settings.vsync = v,
		func(v): return "Вкл" if v else "Выкл"))
	_row(g, "Тени", _cycler([true, false], func(): return Settings.shadows, func(v): Settings.shadows = v,
		func(v): return "Вкл" if v else "Выкл"))
	_row(g, "Пиксельный стиль", _cycler([1, 2, 3, 4], func(): return Settings.pixel, func(v): Settings.pixel = v,
		func(v): return "Выкл" if v == 1 else "x%d" % v))
	_row(g, "Поле зрения", _stepper(func(): return Settings.fov, func(v): Settings.fov = v, 50.0, 110.0, 5.0,
		func(v): return "%d°" % int(v)))
	_row(g, "Камера при старте", _cycler(Settings.CAMERAS, func(): return Settings.camera, func(v): Settings.camera = v,
		func(v): return {"top": "Сверху", "third": "Сзади", "first": "От первого лица"}[v]))
	var hint := Game.label("F11 или Alt+Enter: полный экран в любой момент.", 8, Color("8a7a80"))
	g.add_child(hint)
	return g


func _sound_tab() -> Control:
	var g := _grid()
	g.name = "Sound"
	var pct := func(v): return "%d%%" % int(roundf(v * 100.0))
	_row(g, "Общая громкость", _stepper(func(): return Settings.master, func(v): Settings.master = v, 0.0, 1.0, 0.1, pct))
	_row(g, "Музыка", _stepper(func(): return Settings.music, func(v): Settings.music = v, 0.0, 1.0, 0.1, pct))
	_row(g, "Эффекты", _stepper(func(): return Settings.sfx, func(v): Settings.sfx = v, 0.0, 1.0, 0.1, pct))
	return g


func _controls_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Controls"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(460, 0)
	scroll.add_child(box)
	var g := _grid()
	_row(g, "Чувствительность мыши", _stepper(func(): return Settings.sens, func(v): Settings.sens = v, 0.2, 3.0, 0.1,
		func(v): return "%.1f" % v))
	_row(g, "Инвертировать мышь по Y", _cycler([false, true], func(): return Settings.invert_y, func(v): Settings.invert_y = v,
		func(v): return "Да" if v else "Нет"))
	box.add_child(g)
	var hint := Game.label("Нажмите на клавишу, затем новую кнопку. Esc отменяет.", 8, Color("8a7a80"))
	box.add_child(hint)
	var kg := GridContainer.new()
	kg.columns = 3
	kg.add_theme_constant_override("h_separation", 6)
	kg.add_theme_constant_override("v_separation", 3)
	for a in Settings.ACTIONS:
		var l := Game.label(a[1], 10)
		l.custom_minimum_size = Vector2(170, 0)
		kg.add_child(l)
		var pair := []
		for slot in 2:
			var b := Game.button("", func(): pass, 10)
			b.custom_minimum_size = Vector2(130, 0)
			var action: String = a[0]
			b.pressed.connect(func(): _start_rebind(action, slot, b))
			kg.add_child(b)
			pair.append(b)
		_rows[a[0]] = pair
	box.add_child(kg)
	box.add_child(Game.button("Сбросить управление", func():
		Settings.reset_bindings()
		_refresh_keys(), 10))
	_refresh_keys()
	return scroll


func _refresh_keys() -> void:
	for action in _rows:
		for slot in 2:
			_rows[action][slot].text = Settings.code_name(Settings.bindings[action][slot])


func _start_rebind(action: String, slot: int, b: Button) -> void:
	_waiting = [action, slot, b]
	b.text = "Нажмите..."


func _input(event: InputEvent) -> void:
	if _waiting.is_empty() or not visible:
		return
	if not (event.is_pressed() and (event is InputEventKey or event is InputEventMouseButton)):
		return
	if event is InputEventKey and event.echo:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_waiting = []
		_refresh_keys()
		return
	var code := Settings.code_for(event)
	if code == "":
		return
	Settings.rebind(_waiting[0], _waiting[1], code)
	_waiting = []
	_refresh_keys()
