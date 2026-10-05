extends Control
## Dialogue box with portrait, typewriter text and optional choices.

signal advanced
signal chosen(index: int)

var portrait: TextureRect
var name_label: Label
var text_label: Label
var hint: Label
var choice_box: VBoxContainer
var _typing := false
var _tw: Tween


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.size = Vector2(640, 360)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(40, 8)
	panel.size = Vector2(560, 80)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	portrait = TextureRect.new()
	portrait.position = Vector2(56, 24)
	portrait.size = Vector2(48, 48)
	add_child(portrait)
	name_label = Game.label("", 10, Color("e0b55a"))
	name_label.position = Vector2(114, 16)
	add_child(name_label)
	text_label = Game.label("", 10)
	text_label.position = Vector2(114, 30)
	text_label.size = Vector2(470, 50)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(text_label)
	hint = Game.label("▼", 8, Color("8a6b3a"))
	hint.position = Vector2(584, 74)
	add_child(hint)
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(200, 180)
	choice_box.custom_minimum_size = Vector2(240, 0)
	choice_box.add_theme_constant_override("separation", 4)
	add_child(choice_box)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_next()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_J]:
		_next()
		get_viewport().set_input_as_handled()


func _next() -> void:
	if choice_box.get_child_count() > 0:
		return
	if _typing:
		_tw.kill()
		text_label.visible_ratio = 1.0
		_typing = false
		return
	advanced.emit()


func _show_line(speaker: String, text: String) -> void:
	var sp: Dictionary = Data.SPEAKERS.get(speaker, Data.SPEAKERS["none"])
	name_label.text = sp["name"]
	if sp["portrait"] != "":
		portrait.texture = load("res://assets/portraits/%s.png" % sp["portrait"])
		portrait.visible = true
		name_label.position.x = 114
		text_label.position.x = 114
		text_label.size.x = 470
	else:
		portrait.visible = false
		name_label.position.x = 56
		text_label.position.x = 56
		text_label.size.x = 528
	text_label.text = text
	text_label.visible_ratio = 0.0
	_typing = true
	_tw = create_tween()
	_tw.tween_property(text_label, "visible_ratio", 1.0, text.length() * 0.018)
	_tw.tween_callback(func(): _typing = false)


## Plays a list of [speaker, text] lines; returns when the last one is dismissed.
func play(lines: Array) -> void:
	if Game.autotest:
		await get_tree().process_frame
		return
	for l in lines:
		_show_line(l[0], l[1])
		await advanced
		Sfx.play("click")


## Shows a question with buttons; returns the chosen index.
func ask(speaker: String, text: String, options: Array) -> int:
	if Game.autotest:
		await get_tree().process_frame
		return Game.autotest_choice(options)
	_show_line(speaker, text)
	_tw.kill()
	text_label.visible_ratio = 1.0
	_typing = false
	for i in options.size():
		var b := Game.button(options[i], func(): chosen.emit(i))
		choice_box.add_child(b)
	await get_tree().process_frame
	choice_box.position = Vector2((640 - choice_box.size.x) / 2.0, 100)
	var idx: int = await chosen
	for c in choice_box.get_children():
		c.queue_free()
	await get_tree().process_frame
	return idx


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_next()
		get_viewport().set_input_as_handled()
