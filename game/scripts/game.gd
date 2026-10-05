extends Node
## Global state: the hunter's progress, saving, sprites, input map and the shared UI theme.

const SAVE_PATH := "user://darkspire_save.json"
const FLASKS := 3

var theme: Theme
var font: FontFile  # Press Start 2P: body text, crisp at 8 / 16 / 32
var small_font: FontFile  # Tiny5: compact labels, crisp at 8 / 16
var main: Node  # set by main.gd

var level := "hollowd"
var checkpoint := -1  # index of the Угль Памяти last rested at in this level, -1 = level start
var flasks := FLASKS
var flask_max := FLASKS
var lost: Array = []  # indices into Data.MEMORIES the Spire has taken
var flags := {}
var stats := {"kills": 0, "deaths": 0}
var autotest := false  # developer self-play mode, see main.gd

var _frames_cache := {}
var _chars := {}

func _ready() -> void:
	_chars = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chars/chars.json"))
	_build_theme()
	get_tree().root.theme = theme


# ---------------------------------------------------------------- theme

func _build_theme() -> void:
	font = _pixel_font("res://assets/fonts/PressStart2P.ttf")
	small_font = _pixel_font("res://assets/fonts/Tiny5.ttf")
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 8
	var panel := _box(Color("1b1620"), Color("8a6b3a"), 2)
	panel.shadow_color = Color(0, 0, 0, 0.5)
	panel.shadow_size = 0
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	var normal := _box(Color("2b2230"), Color("8a6b3a"), 1)
	var hover := _box(Color("3d3044"), Color("e0b55a"), 1)
	var pressed := _box(Color("15111a"), Color("e0b55a"), 1)
	var disabled := _box(Color("1e1a22"), Color("4a4048"), 1)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", _box(Color(0, 0, 0, 0), Color("e0b55a"), 1)]]:
		theme.set_stylebox(pair[0], "Button", pair[1])
	theme.set_color("font_color", "Button", Color("e8dcc0"))
	theme.set_color("font_hover_color", "Button", Color("fff2c8"))
	theme.set_color("font_disabled_color", "Button", Color("6a6068"))
	theme.set_color("font_color", "Label", Color("e8dcc0"))
	theme.set_color("font_outline_color", "Label", Color("0c0a0e"))
	theme.set_color("default_color", "RichTextLabel", Color("e8dcc0"))
	theme.set_constant("outline_size", "Label", 0)


func _pixel_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.force_autohinter = false
	return f


## Maps a requested text size onto the closest pixel-perfect font and size.
func font_for(size: int) -> Array:
	if size <= 9:
		return [small_font, 8]
	if size <= 14:
		return [font, 8]
	if size <= 18:
		return [small_font, 16]
	if size <= 27:
		return [font, 16]
	return [font, 32]


func _box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(w)
	s.set_content_margin_all(4)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.anti_aliasing = false
	return s


func label(text: String, size: int = 10, color: Color = Color("e8dcc0"), outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	var fs := font_for(size)
	ls.font = fs[0]
	ls.font_size = fs[1]
	if fs[0] == font:
		ls.line_spacing = 4.0 if fs[1] == 8 else 6.0
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color("0c0a0e")
	l.label_settings = ls
	return l


func button(text: String, cb: Callable, size: int = 10) -> Button:
	var b := Button.new()
	b.text = text
	var fs := font_for(size)
	b.add_theme_font_override("font", fs[0])
	b.add_theme_font_size_override("font_size", fs[1])
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	b.focus_mode = Control.FOCUS_NONE
	return b


# ---------------------------------------------------------------- sprites

func char_meta(id: String) -> Dictionary:
	return _chars[id]


func frames(id: String) -> SpriteFrames:
	if _frames_cache.has(id):
		return _frames_cache[id]
	var tex: Texture2D = load("res://assets/chars/%s.png" % id)
	var meta: Dictionary = _chars[id]
	var fw := int(meta["w"])
	var fh := int(meta["h"])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in meta["anims"]:
		var a: Dictionary = meta["anims"][anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a["fps"]))
		sf.set_animation_loop(anim, bool(a["loop"]))
		for f in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * fw, int(a["row"]) * fh, fw, fh)
			sf.add_frame(anim, at)
	_frames_cache[id] = sf
	return sf


## Seconds an animation takes to play once.
func anim_len(id: String, anim: String) -> float:
	var a: Dictionary = _chars[id]["anims"][anim]
	return float(a["frames"]) / float(a["fps"])


func hit_frame(id: String, anim: String) -> int:
	return int(_chars[id]["anims"][anim]["hit"])


# ---------------------------------------------------------------- state

func new_game() -> void:
	level = "hollowd"
	checkpoint = -1
	flask_max = FLASKS
	flasks = FLASKS
	lost = []
	flags = {}
	stats = {"kills": 0, "deaths": 0}


## The Spire takes a memory. index -1 takes the next one still remembered.
## Returns its text, or "" when nothing is left to forget.
func forget(index: int = -1) -> String:
	if index < 0:
		for i in range(1, Data.MEMORIES.size()):
			if not lost.has(i):
				index = i
				break
	if index < 0 or lost.has(index):
		return ""
	lost.append(index)
	return Data.MEMORIES[index]


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var d := {
		"version": 2, "level": level, "checkpoint": checkpoint, "flasks": flasks, "flask_max": flask_max,
		"lost": lost, "flags": flags, "stats": stats,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != 2:
		return false
	level = d["level"]
	checkpoint = int(d["checkpoint"])
	flasks = int(d["flasks"])
	flask_max = int(d["flask_max"])
	lost = []
	for i in d["lost"]:
		lost.append(int(i))
	flags = d["flags"]
	stats = {}
	for k in d["stats"]:
		stats[k] = int(d["stats"][k])
	return true


# ---------------------------------------------------------------- screens

func goto(screen: String, params: Dictionary = {}) -> void:
	main.change_screen(screen, params)
