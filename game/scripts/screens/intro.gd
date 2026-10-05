extends Node2D
## Opening cutscene: Ashmark, the Spire and the hunter who cannot die.

const BACKDROP := preload("res://scripts/screens/backdrop.gd")

var text: Label
var idx := -1
var _tw: Tween


func setup(_params: Dictionary) -> void:
	Sfx.music("menu")
	var bd := BACKDROP.new()
	add_child(bd)
	bd.build("hollowd", 300)
	bd.modulate = Color(1.0, 0.75, 0.7)
	for pair in [["house_burnt", 150], ["house_burnt2", 330], ["house_burnt", 500]]:
		bd.prop(pair[0], pair[1])
		bd.fire(Vector2(pair[1], 262), Color(1.0, 0.45, 0.1), 22, 40)
	bd.prop("dead_tree", 250)
	bd.prop("fence", 420)
	bd.embers(Color(1, 0.6, 0.2, 0.9))
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
		Game.goto("level")
		return
	text.text = Data.INTRO[idx]
	text.visible_ratio = 0.0
	if idx == Data.INTRO.size() - 1:
		text.label_settings = text.label_settings.duplicate()
		text.label_settings.font_size = 20
		text.label_settings.font_color = Color("f0d890")
		Sfx.play("thud", 0.6)
	_tw = create_tween()
	_tw.tween_property(text, "visible_ratio", 1.0, text.text.length() * 0.03)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Sfx.play("click")
		_next()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Game.goto("level")
		elif event.keycode in [KEY_SPACE, KEY_ENTER]:
			_next()
