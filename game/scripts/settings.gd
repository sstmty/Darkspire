extends Node
## Player settings: window mode, graphics, sound, mouse and key bindings. Saved to user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

## [action, label, default bindings (keyboard "k:<physical keycode>" or mouse "m:<button>"), gamepad button or -1]
const ACTIONS := [
	["up", "Вперёд", ["k:%d" % KEY_W, "k:%d" % KEY_UP], JOY_BUTTON_DPAD_UP],
	["down", "Назад", ["k:%d" % KEY_S, "k:%d" % KEY_DOWN], JOY_BUTTON_DPAD_DOWN],
	["left", "Влево", ["k:%d" % KEY_A, "k:%d" % KEY_LEFT], JOY_BUTTON_DPAD_LEFT],
	["right", "Вправо", ["k:%d" % KEY_D, "k:%d" % KEY_RIGHT], JOY_BUTTON_DPAD_RIGHT],
	["sprint", "Бег", ["k:%d" % KEY_SHIFT, ""], JOY_BUTTON_LEFT_STICK],
	["jump", "Прыжок", ["k:%d" % KEY_SPACE, ""], JOY_BUTTON_A],
	["roll", "Перекат", ["k:%d" % KEY_CTRL, "m:%d" % MOUSE_BUTTON_RIGHT], JOY_BUTTON_B],
	["attack", "Удар", ["m:%d" % MOUSE_BUTTON_LEFT, "k:%d" % KEY_J], JOY_BUTTON_X],
	["heal", "Настойка", ["k:%d" % KEY_R, "k:%d" % KEY_F], JOY_BUTTON_Y],
	["interact", "Действие, лошадь", ["k:%d" % KEY_E, ""], JOY_BUTTON_RIGHT_SHOULDER],
	["lock", "Захват цели", ["k:%d" % KEY_Q, "m:%d" % MOUSE_BUTTON_MIDDLE], JOY_BUTTON_RIGHT_STICK],
	["camera", "Вид камеры", ["k:%d" % KEY_V, ""], JOY_BUTTON_LEFT_SHOULDER],
	["memory", "Память", ["k:%d" % KEY_TAB, ""], JOY_BUTTON_BACK],
	["pause", "Пауза", ["k:%d" % KEY_ESCAPE, ""], JOY_BUTTON_START],
]
const WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const CAMERAS := ["top", "third", "first"]

var window_mode := "windowed"
var vsync := true
var pixel := 1  # 1 = smooth 3D, 2..4 = render the world that many times smaller for a pixel look
var fov := 70.0
var shadows := true
var sens := 1.0
var invert_y := false
var camera := "third"
var master := 0.8
var music := 0.6
var sfx := 0.9
var bindings := {}  # action -> [String, String]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		bindings[a[0]] = a[2].duplicate()
	load_settings()
	_build_input()
	apply()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	window_mode = cf.get_value("display", "window_mode", window_mode)
	vsync = cf.get_value("display", "vsync", vsync)
	pixel = int(cf.get_value("display", "pixel", pixel))
	fov = float(cf.get_value("display", "fov", fov))
	shadows = cf.get_value("display", "shadows", shadows)
	sens = float(cf.get_value("controls", "sens", sens))
	invert_y = cf.get_value("controls", "invert_y", invert_y)
	camera = cf.get_value("controls", "camera", camera)
	master = float(cf.get_value("audio", "master", master))
	music = float(cf.get_value("audio", "music", music))
	sfx = float(cf.get_value("audio", "sfx", sfx))
	for a in ACTIONS:
		var b = cf.get_value("bindings", a[0], null)
		if typeof(b) == TYPE_ARRAY and b.size() == 2:
			bindings[a[0]] = [str(b[0]), str(b[1])]


func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("display", "window_mode", window_mode)
	cf.set_value("display", "vsync", vsync)
	cf.set_value("display", "pixel", pixel)
	cf.set_value("display", "fov", fov)
	cf.set_value("display", "shadows", shadows)
	cf.set_value("controls", "sens", sens)
	cf.set_value("controls", "invert_y", invert_y)
	cf.set_value("controls", "camera", camera)
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	for a in bindings:
		cf.set_value("bindings", a, bindings[a])
	cf.save(PATH)


## Applies everything and tells the running level (camera, pixel size, shadows) to refresh.
func apply() -> void:
	if DisplayServer.get_name() != "headless":
		match window_mode:
			"fullscreen":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			"borderless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_:
				if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Sfx.set_volumes(master * sfx, master * music)
	changed.emit()


func toggle_fullscreen() -> void:
	window_mode = "windowed" if window_mode != "windowed" else "fullscreen"
	apply()
	save_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11 or (event.physical_keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- input

func _event_for(code: String) -> InputEvent:
	if code.begins_with("k:"):
		var e := InputEventKey.new()
		e.physical_keycode = int(code.substr(2))
		return e
	if code.begins_with("m:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(code.substr(2))
		return m
	return null


func _build_input() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		InputMap.action_erase_events(action)
		for code in bindings[action]:
			var e := _event_for(code)
			if e != null:
				InputMap.action_add_event(action, e)
		if a[3] >= 0:
			var j := InputEventJoypadButton.new()
			j.button_index = a[3]
			InputMap.action_add_event(action, j)
	for pair in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


## Turns a key or mouse press into a binding code, or "" if it can't be bound.
func code_for(event: InputEvent) -> String:
	if event is InputEventKey and event.physical_keycode != 0:
		return "k:%d" % event.physical_keycode
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		return "m:%d" % event.button_index
	return ""


func rebind(action: String, slot: int, code: String) -> void:
	# a key does one thing: take it away from any other action first
	if code != "":
		for a in bindings:
			for i in 2:
				if bindings[a][i] == code:
					bindings[a][i] = ""
	bindings[action][slot] = code
	_build_input()
	save_settings()


func reset_bindings() -> void:
	for a in ACTIONS:
		bindings[a[0]] = a[2].duplicate()
	_build_input()
	save_settings()


func code_name(code: String) -> String:
	if code.begins_with("k:"):
		return OS.get_keycode_string(int(code.substr(2)))
	if code.begins_with("m:"):
		match int(code.substr(2)):
			MOUSE_BUTTON_LEFT:
				return "ЛКМ"
			MOUSE_BUTTON_RIGHT:
				return "ПКМ"
			MOUSE_BUTTON_MIDDLE:
				return "СКМ"
			MOUSE_BUTTON_XBUTTON1:
				return "Мышь 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Мышь 5"
	return "—"


## Short name of the first binding of an action, for on-screen hints.
func key_of(action: String) -> String:
	for code in bindings.get(action, []):
		if code != "":
			return code_name(code)
	return "—"
