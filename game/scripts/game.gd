extends Node
## Global state: hero, army, map progress, saving, screens and shared UI theme.

const SAVE_PATH := "user://darkspire_save.json"
const MAX_SLOTS := 7

var theme: Theme
var font: FontFile  # Press Start 2P: body text, crisp at 8 / 16 / 32
var small_font: FontFile  # Tiny5: compact labels, crisp at 8 / 16
var main: Node  # set by main.gd

var hero := {}
var army: Array = []  # [{"id": String, "count": int}]
var gold := 0
var cleared := {}  # "x,y" -> true
var explored := PackedByteArray()
var hero_pos := Vector2i.ZERO
var flags := {}
var recruit_pool := {}
var stats := {"battles": 0, "killed": 0, "lost": 0}

var pending := {}
var autotest := false  # developer self-play mode, see main.gd  # battle in progress: {"event": key, "pos": Vector2i, "battle": id}

var _frames_cache := {}
var _unit_meta := {}


func _ready() -> void:
	_unit_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/units.json"))
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

func unit_meta(id: String) -> Dictionary:
	return _unit_meta[id]


func frames(id: String, mini: bool = false) -> SpriteFrames:
	var key := id + ("_mini" if mini else "")
	if _frames_cache.has(key):
		return _frames_cache[key]
	var tex: Texture2D = load("res://assets/units/%s.png" % key)
	var meta: Dictionary = _unit_meta[id]
	var fw := 32 if mini else int(meta["fw"])
	var fh := 32 if mini else int(meta["fh"])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in meta["anims"]:
		var a: Dictionary = meta["anims"][anim]
		if mini and int(a["row"]) > 1:
			continue
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(a["fps"]))
		sf.set_animation_loop(anim, anim in ["idle", "walk"])
		for f in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * fw, int(a["row"]) * fh, fw, fh)
			sf.add_frame(anim, at)
	_frames_cache[key] = sf
	return sf


func icon(name: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % name)


# ---------------------------------------------------------------- state

func new_game() -> void:
	hero = {"name": "Кайрен Вейл", "level": 1, "xp": 0, "atk": 1, "def": 1}
	army = []
	for s in Data.START_ARMY:
		army.append({"id": s[0], "count": s[1]})
	gold = 250
	cleared = {}
	explored = PackedByteArray()
	hero_pos = Vector2i(-1, -1)
	flags = {}
	recruit_pool = Data.RECRUIT_POOL.duplicate()
	stats = {"battles": 0, "killed": 0, "lost": 0}
	pending = {}


func xp_for(level: int) -> int:
	return 60 * level * (level + 1) / 2


## Adds XP and returns the list of level-up messages.
func add_xp(amount: int) -> Array:
	var msgs := []
	hero["xp"] += amount
	while hero["xp"] >= xp_for(hero["level"]):
		hero["level"] += 1
		if hero["level"] % 2 == 0:
			hero["atk"] += 1
			msgs.append("Уровень %d! Атака героя +1." % hero["level"])
		else:
			hero["def"] += 1
			msgs.append("Уровень %d! Защита героя +1." % hero["level"])
	return msgs


func add_units(id: String, n: int) -> bool:
	for s in army:
		if s["id"] == id:
			s["count"] += n
			return true
	if army.size() >= MAX_SLOTS:
		return false
	army.append({"id": id, "count": n})
	return true


func army_power() -> int:
	var p := 0
	for s in army:
		var d: Dictionary = Data.UNITS[s["id"]]
		p += int(s["count"]) * int(d["hp"])
	return p


func is_cleared(p: Vector2i) -> bool:
	return cleared.has("%d,%d" % [p.x, p.y])


func set_cleared(p: Vector2i) -> void:
	cleared["%d,%d" % [p.x, p.y]] = true


# ---------------------------------------------------------------- save / load

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var d := {
		"version": 1, "hero": hero, "army": army, "gold": gold, "cleared": cleared,
		"explored": Marshalls.raw_to_base64(explored), "hero_pos": [hero_pos.x, hero_pos.y],
		"flags": flags, "recruit_pool": recruit_pool, "stats": stats,
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
	if typeof(d) != TYPE_DICTIONARY:
		return false
	hero = d["hero"]
	for k in ["level", "xp", "atk", "def"]:
		hero[k] = int(hero[k])
	army = []
	for s in d["army"]:
		army.append({"id": s["id"], "count": int(s["count"])})
	gold = int(d["gold"])
	cleared = d["cleared"]
	explored = Marshalls.base64_to_raw(d["explored"])
	hero_pos = Vector2i(int(d["hero_pos"][0]), int(d["hero_pos"][1]))
	flags = d["flags"]
	recruit_pool = {}
	for k in d["recruit_pool"]:
		recruit_pool[k] = int(d["recruit_pool"][k])
	stats = {}
	for k in d["stats"]:
		stats[k] = int(d["stats"][k])
	pending = {}
	return true


func autotest_choice(options: Array) -> int:
	# recruit menu: buy the first offer, then leave; chests: take gold
	if options.size() > 1 and str(options[0]).contains("нанять"):
		return 0
	return options.size() - 1 if str(options[-1]) == "Уйти" and gold < 30 else 0


# ---------------------------------------------------------------- screens

func goto(screen: String, params: Dictionary = {}) -> void:
	main.change_screen(screen, params)
