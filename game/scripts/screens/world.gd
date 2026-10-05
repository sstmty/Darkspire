extends Node2D
## Adventure map: the hero travels, fights armies, loots and talks.

const T := 16
const DialogScript := preload("res://scripts/ui/dialog.gd")
const TILE_INDEX := {"grass": 0, "grass2": 1, "flowers": 2, "road": 3, "water0": 4, "water1": 5, "bridge_h": 6,
	"bridge_v": 7, "burnt": 8, "sand": 9, "stone": 10, "field": 11, "snow": 12, "mud": 13}
const TERRAIN := {".": "grass", ",": "grass2", ";": "flowers", "=": "road", "~": "water0", "H": "bridge_h",
	"b": "burnt", "f": "field", ":": "mud", "s": "stone"}
const DECOR := {"T": ["tree", "tree2"], "P": ["pine"], "D": ["dead_tree"], "M": ["mountain", "mountain2"], "r": ["rock"],
	"h": ["house"], "x": ["house_burnt"], "t": ["tent_karr"], "C": ["castle_vale"], "F": ["fort_karr"], "W": ["spire"]}
const BLOCKING := "TPDMrXChxtWF~k"
const EVENT_KEYS := "1234567RSBgc"

var grid: Array = []  # rows of single-char strings
var W := 0
var H := 0
var astar := AStarGrid2D.new()
var ground: Node2D
var objects: Node2D
var fog: Node2D
var hero: AnimatedSprite2D
var cam: Camera2D
var tiles_tex: Texture2D
var water_frame := 0
var event_nodes := {}  # Vector2i -> Node2D
var busy := false
var hover := Vector2i(-1, -1)

var ui: CanvasLayer
var gold_label: Label
var hero_label: Label
var army_box: HBoxContainer
var tip_label: Label
var toast: Label
var cursor_box: Node2D


func setup(params: Dictionary) -> void:
	Sfx.music("world")
	tiles_tex = load("res://assets/world/tiles.png")
	_load_map()
	ground = Node2D.new()
	ground.draw.connect(_draw_ground)
	add_child(ground)
	cursor_box = Node2D.new()
	cursor_box.draw.connect(_draw_cursor)
	add_child(cursor_box)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	fog = Node2D.new()
	fog.z_index = 20
	fog.draw.connect(_draw_fog)
	add_child(fog)
	_spawn_objects()
	hero = AnimatedSprite2D.new()
	hero.sprite_frames = Game.frames("vale_hero", true)
	hero.offset = Vector2(0, -13)
	hero.play("idle")
	var hero_holder := Node2D.new()
	objects.add_child(hero_holder)
	hero_holder.name = "Hero"
	hero.position = Vector2.ZERO
	hero_holder.add_child(hero)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = -24
	cam.limit_right = W * T
	cam.limit_bottom = H * T
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(2, 2)
	hero_holder.add_child(cam)
	if Game.explored.size() != W * H:
		Game.explored = PackedByteArray()
		Game.explored.resize(W * H)
	if Game.hero_pos == Vector2i(-1, -1):
		Game.hero_pos = _find("@")
	_place_hero(Game.hero_pos)
	cam.reset_smoothing()
	_reveal()
	_ambient()
	_build_ui()
	var t := Timer.new()
	t.wait_time = 0.45
	t.autostart = true
	t.timeout.connect(func():
		water_frame = 1 - water_frame
		ground.queue_redraw())
	add_child(t)
	await get_tree().process_frame
	cam.reset_smoothing()
	if params.get("result", "") != "":
		await _after_battle(params["result"])
	elif not Game.flags.get("start_done", false):
		Game.flags["start_done"] = true
		await get_tree().create_timer(0.5).timeout
		await _dialog(Data.DIALOGS["start"])


# ---------------------------------------------------------------- map data

func _load_map() -> void:
	var text := FileAccess.get_file_as_string("res://data/chapter1.txt")
	for line in text.split("\n"):
		if line.strip_edges() == "":
			continue
		var row := []
		for ch in line:
			row.append(ch)
		grid.append(row)
	H = grid.size()
	W = grid[0].size()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in H:
		for x in W:
			_update_solid(Vector2i(x, y))


func ch(p: Vector2i) -> String:
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return "P"
	return grid[p.y][p.x]


func _find(c: String) -> Vector2i:
	for y in H:
		for x in W:
			if grid[y][x] == c:
				return Vector2i(x, y)
	return Vector2i(1, 1)


func _is_event(p: Vector2i) -> bool:
	return EVENT_KEYS.contains(ch(p)) and not Game.is_cleared(p)


func _update_solid(p: Vector2i) -> void:
	var c := ch(p)
	var solid := BLOCKING.contains(c) or _is_event(p)
	if c == "R" or c == "S":
		solid = true
	astar.set_point_solid(p, solid)


func _base_tile(p: Vector2i) -> String:
	var c := ch(p)
	if TERRAIN.has(c):
		if c == "~":
			return "water1" if water_frame == 1 else "water0"
		return TERRAIN[c]
	if c == "4":
		return "bridge_h"
	# objects stand on the most common terrain around them
	var counts := {}
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := ch(p + d)
		if TERRAIN.has(n) and n != "~" and n != "H":
			counts[n] = counts.get(n, 0) + 1
	var best := "."
	var bc := 0
	for k in counts:
		if counts[k] > bc:
			bc = counts[k]
			best = k
	if best == "=" and c in "TPDMr":
		best = "."
	return TERRAIN[best]


func tile_center(p: Vector2i) -> Vector2:
	return Vector2(p.x * T + T / 2.0, p.y * T + T / 2.0)


func tile_feet(p: Vector2i) -> Vector2:
	return Vector2(p.x * T + T / 2.0, p.y * T + T - 2)


# ---------------------------------------------------------------- drawing

func _draw_ground() -> void:
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			var name := _base_tile(p)
			var v := (x * 7 + y * 13) % 4
			if name.begins_with("water") or name.begins_with("bridge"):
				v = 0
			ground.draw_texture_rect_region(tiles_tex, Rect2(x * T, y * T, T, T), Rect2(TILE_INDEX[name] * T, v * T, T, T))


func _draw_cursor() -> void:
	if hover == Vector2i(-1, -1) or busy:
		return
	var col := Color(1, 0.9, 0.5, 0.7)
	if _is_event(hover) and ch(hover) in "1234567":
		col = Color(1, 0.35, 0.3, 0.9)
	cursor_box.draw_rect(Rect2(hover.x * T, hover.y * T, T, T), col, false, 1.0)


func _draw_fog() -> void:
	for y in H:
		for x in W:
			if Game.explored[y * W + x] == 0:
				var edge := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + d
					if n.x >= 0 and n.y >= 0 and n.x < W and n.y < H and Game.explored[n.y * W + n.x] == 1:
						edge = true
				fog.draw_rect(Rect2(x * T, y * T, T, T), Color(0.03, 0.02, 0.04, 0.72 if edge else 1.0))


func _reveal() -> void:
	var r := 6
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := Game.hero_pos + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < W and p.y < H and dx * dx + dy * dy <= r * r + 2:
				Game.explored[p.y * W + p.x] = 1
	fog.queue_redraw()


# ---------------------------------------------------------------- objects

func _sprite(tex_name: String, p: Vector2i, offset: Vector2 = Vector2.ZERO) -> Node2D:
	var holder := Node2D.new()
	holder.position = tile_feet(p) + offset
	var s := Sprite2D.new()
	s.texture = load("res://assets/world/%s.png" % tex_name)
	s.centered = false
	s.position = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height() + 2)
	holder.add_child(s)
	objects.add_child(holder)
	return holder


func _anim_sprite(frames: Array, p: Vector2i, fps: float) -> Node2D:
	var holder := Node2D.new()
	holder.position = tile_feet(p)
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	for f in frames:
		sf.add_frame("default", load("res://assets/world/%s.png" % f))
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.offset = Vector2(0, -sf.get_frame_texture("default", 0).get_height() / 2.0 + 2)
	a.play()
	holder.add_child(a)
	objects.add_child(holder)
	return holder


func _spawn_objects() -> void:
	for y in H:
		for x in W:
			var p := Vector2i(x, y)
			var c := ch(p)
			if DECOR.has(c):
				var names: Array = DECOR[c]
				var n: String = names[(x * 3 + y * 5) % names.size()]
				var off := Vector2.ZERO
				if c in "TP":
					off = Vector2(((x * 13 + y * 7) % 5) - 2, 0)
				if c == "W":
					var s := _sprite(n, p)
					s.modulate = Color(1, 1, 1, 0.9)
					continue
				_sprite(n, p, off)
			elif c == "k":
				_anim_sprite(["campfire_0", "campfire_1", "campfire_2"], p, 8)
			elif EVENT_KEYS.contains(c) and not Game.is_cleared(p):
				_spawn_event(p, c)
	# flags on the fort and village
	var fort := _find("F")
	_anim_sprite(["flag_karr_0", "flag_karr_1", "flag_karr_2", "flag_karr_3"], fort + Vector2i(2, 0), 6)
	if Game.flags.get("village_free", false):
		_anim_sprite(["flag_vale_0", "flag_vale_1", "flag_vale_2", "flag_vale_3"], _find("R") + Vector2i(0, -1), 6)


func _spawn_event(p: Vector2i, c: String) -> void:
	var node: Node2D
	if c in "1234567":
		var ev: Dictionary = Data.EVENTS[c]
		node = Node2D.new()
		node.position = tile_feet(p)
		var a := AnimatedSprite2D.new()
		a.sprite_frames = Game.frames(ev["sprite"], true)
		a.offset = Vector2(0, -13)
		a.flip_h = true
		a.play("idle")
		a.frame = (p.x + p.y) % 4
		node.add_child(a)
		objects.add_child(node)
	elif c == "g":
		node = _sprite("gold", p, Vector2(0, -2))
	elif c == "c":
		node = _sprite("chest", p, Vector2(0, -2))
	elif c == "R":
		node = _sprite("house", p)
	elif c == "S":
		node = Node2D.new()
		node.position = tile_feet(p)
		var a2 := AnimatedSprite2D.new()
		a2.sprite_frames = Game.frames("vale_archer", true)
		a2.offset = Vector2(0, -13)
		a2.flip_h = true
		a2.play("idle")
		node.add_child(a2)
		objects.add_child(node)
	elif c == "B":
		node = _sprite("cage", p)
	if node:
		event_nodes[p] = node


func _ambient() -> void:
	# ash falling over the land
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var ash := CPUParticles2D.new()
	ash.position = Vector2(320, -10)
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(340, 4)
	ash.amount = 60
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.direction = Vector2(0.3, 1)
	ash.spread = 20
	ash.gravity = Vector2(0, 0)
	ash.initial_velocity_min = 18
	ash.initial_velocity_max = 40
	ash.scale_amount_min = 1.0
	ash.scale_amount_max = 1.5
	ash.color = Color(0.75, 0.72, 0.72, 0.6)
	layer.add_child(ash)
	# fire and smoke over the burning castle
	var castle := tile_feet(_find("C"))
	for i in 2:
		var fire := CPUParticles2D.new()
		fire.position = castle + Vector2(-14 + i * 26, -26 - i * 8)
		fire.z_index = 5
		fire.amount = 26
		fire.lifetime = 0.9
		fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		fire.emission_rect_extents = Vector2(8, 2)
		fire.direction = Vector2(0, -1)
		fire.spread = 15
		fire.gravity = Vector2(0, -30)
		fire.initial_velocity_min = 8
		fire.initial_velocity_max = 22
		fire.scale_amount_min = 1.0
		fire.scale_amount_max = 2.5
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.9, 0.4, 1))
		g.set_color(1, Color(0.8, 0.15, 0.05, 0))
		fire.color_ramp = g
		add_child(fire)
		var smoke := CPUParticles2D.new()
		smoke.position = fire.position + Vector2(0, -10)
		smoke.z_index = 5
		smoke.amount = 16
		smoke.lifetime = 3.0
		smoke.direction = Vector2(0.4, -1)
		smoke.spread = 20
		smoke.gravity = Vector2(4, -6)
		smoke.initial_velocity_min = 6
		smoke.initial_velocity_max = 14
		smoke.scale_amount_min = 2.0
		smoke.scale_amount_max = 4.0
		var g2 := Gradient.new()
		g2.set_color(0, Color(0.25, 0.22, 0.22, 0.6))
		g2.set_color(1, Color(0.2, 0.2, 0.2, 0))
		smoke.color_ramp = g2
		add_child(smoke)


# ---------------------------------------------------------------- ui

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var bar := PanelContainer.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(640, 26)
	ui.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	var gi := TextureRect.new()
	gi.texture = Game.icon("gold")
	gi.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(gi)
	gold_label = Game.label("", 10, Color("f0d890"))
	gold_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(gold_label)
	hero_label = Game.label("", 8, Color("c8bcd0"))
	hero_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(hero_label)
	army_box = HBoxContainer.new()
	army_box.add_theme_constant_override("separation", 1)
	army_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(army_box)
	row.add_child(Game.button("Сохранить", _on_save, 8))
	row.add_child(Game.button("Меню", func(): Game.goto("menu"), 8))
	tip_label = Game.label("", 8, Color("f0e0b0"), 2)
	tip_label.position = Vector2(0, 0)
	tip_label.size = Vector2(160, 12)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(tip_label)
	toast = Game.label("", 10, Color("f0d890"), 2)
	toast.position = Vector2(0, 300)
	toast.size = Vector2(640, 14)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(toast)
	_refresh_ui()


func _refresh_ui() -> void:
	gold_label.text = str(Game.gold)
	var h: Dictionary = Game.hero
	hero_label.text = "%s, ур. %d\nОпыт %d/%d  Атк +%d Защ +%d" % [h["name"], h["level"], h["xp"], Game.xp_for(h["level"]), h["atk"], h["def"]]
	for c in army_box.get_children():
		c.queue_free()
	for s in Game.army:
		var box := Control.new()
		box.custom_minimum_size = Vector2(26, 24)
		var tex := AtlasTexture.new()
		tex.atlas = load("res://assets/units/%s_mini.png" % s["id"])
		tex.region = Rect2(3, 4, 26, 26)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.position = Vector2(0, -4)
		box.add_child(tr)
		var l := Game.label(str(s["count"]), 8, Color("fff2c8"), 2)
		l.position = Vector2(2, 12)
		box.add_child(l)
		box.tooltip_text = "%s: %d" % [Data.UNITS[s["id"]]["name"], s["count"]]
		army_box.add_child(box)


func _toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.6)


func _on_save() -> void:
	if busy:
		return
	_toast("Игра сохранена." if Game.save_game() else "Не удалось сохранить игру.")


func _dialog(lines: Array) -> void:
	busy = true
	var d = DialogScript.new()
	ui.add_child(d)
	await d.play(lines)
	d.queue_free()
	busy = false


func _ask(speaker: String, text: String, options: Array) -> int:
	busy = true
	var d = DialogScript.new()
	ui.add_child(d)
	var i: int = await d.ask(speaker, text, options)
	d.queue_free()
	busy = false
	return i


# ---------------------------------------------------------------- input + movement

func _mouse_tile() -> Vector2i:
	var m := get_global_mouse_position()
	var p := Vector2i(floori(m.x / T), floori(m.y / T))
	if p.x < 0 or p.y < 0 or p.x >= W or p.y >= H:
		return Vector2i(-1, -1)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if busy:
			return
		if get_viewport().get_mouse_position().y < 26:
			return
		var p := _mouse_tile()
		if p != Vector2i(-1, -1):
			_go(p)
	elif event is InputEventKey and event.pressed and not event.echo and not busy:
		var d := Vector2i.ZERO
		match event.keycode:
			KEY_LEFT, KEY_A: d = Vector2i(-1, 0)
			KEY_RIGHT, KEY_D: d = Vector2i(1, 0)
			KEY_UP, KEY_W: d = Vector2i(0, -1)
			KEY_DOWN, KEY_S: d = Vector2i(0, 1)
			KEY_F5:
				_on_save()
		if d != Vector2i.ZERO:
			_go(Game.hero_pos + d)


func _update_hover() -> void:
	var p := _mouse_tile()
	hover = p
	cursor_box.queue_redraw()
	tip_label.text = ""
	if p == Vector2i(-1, -1) or Game.explored[p.y * W + p.x] == 0:
		return
	var c := ch(p)
	var text := ""
	if _is_event(p):
		match c:
			"1", "2", "3", "4", "5", "6", "7":
				text = _army_desc(Data.EVENTS[c]["battle"])
			"g":
				text = "Золото"
			"c":
				text = "Сундук"
			"R":
				text = "Дом старосты (найм)" if Game.flags.get("village_free", false) else "Дом старосты"
			"S":
				text = "Разведчица"
			"B":
				text = "Клетка с пленницей"
	else:
		match c:
			"C": text = "Соколиный Утёс (горит)"
			"F": text = "Крепость Чёрный Брод"
			"W": text = "Тёмный Шпиль"
			"R": text = "Дом старосты (найм)"
	if text != "":
		var sp := get_viewport().get_canvas_transform() * Vector2(p.x * T + T / 2.0, p.y * T)
		tip_label.text = text
		tip_label.size = Vector2(220, 12)
		tip_label.position = Vector2(clampf(sp.x - 110, 0, 420), maxf(28, sp.y - 16))


func _army_desc(battle: String) -> String:
	var total := 0
	var power := 0
	for s in Data.BATTLES[battle]["army"]:
		total += int(s[1])
		power += int(s[1]) * int(Data.UNITS[s[0]]["hp"]) * (int(Data.UNITS[s[0]]["dmg"][0]) + int(Data.UNITS[s[0]]["dmg"][1]))
	var mine := 0
	for s in Game.army:
		var d: Dictionary = Data.UNITS[s["id"]]
		mine += int(s["count"]) * int(d["hp"]) * (int(d["dmg"][0]) + int(d["dmg"][1]))
	var size_word := "Немного"
	if total >= 50:
		size_word = "Полчище"
	elif total >= 20:
		size_word = "Орда"
	elif total >= 10:
		size_word = "Много"
	var ratio := float(power) / maxf(1.0, float(mine))
	var threat := "угроза низкая"
	if ratio > 1.3:
		threat = "угроза смертельная"
	elif ratio > 0.8:
		threat = "угроза высокая"
	elif ratio > 0.45:
		threat = "угроза средняя"
	return "%s: %s, %s" % [Data.BATTLES[battle]["title"], size_word.to_lower(), threat]


func _place_hero(p: Vector2i) -> void:
	Game.hero_pos = p
	objects.get_node("Hero").position = tile_feet(p)


func _go(target: Vector2i) -> void:
	if busy or target == Game.hero_pos:
		return
	var interact := _is_event(target) or ch(target) == "R"
	var dest := target
	if interact:
		if maxi(absi(target.x - Game.hero_pos.x), absi(target.y - Game.hero_pos.y)) == 1:
			await _interact(target)
			return
		dest = _nearest_free_neighbor(target)
		if dest == Vector2i(-1, -1):
			return
	elif astar.is_point_solid(target):
		return
	var path := astar.get_id_path(Game.hero_pos, dest)
	if path.size() < 2:
		return
	busy = true
	cursor_box.queue_redraw()
	hero.play("walk")
	for i in range(1, path.size()):
		var p: Vector2i = path[i]
		var from := Game.hero_pos
		hero.flip_h = p.x < from.x if p.x != from.x else hero.flip_h
		var tw := create_tween()
		tw.tween_property(objects.get_node("Hero"), "position", tile_feet(p), 0.13)
		if i % 2 == 0:
			Sfx.play("step", 1.4)
		await tw.finished
		Game.hero_pos = p
		_reveal()
	hero.play("idle")
	busy = false
	if interact:
		await _interact(target)


func _nearest_free_neighbor(t: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bl := 99999
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var n: Vector2i = t + d
		if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H or astar.is_point_solid(n):
			continue
		var path := astar.get_id_path(Game.hero_pos, n)
		if n == Game.hero_pos:
			return n
		if path.size() > 0 and path.size() < bl:
			bl = path.size()
			best = n
	return best


# ---------------------------------------------------------------- events

func _clear_event(p: Vector2i) -> void:
	Game.set_cleared(p)
	if event_nodes.has(p):
		var n: Node2D = event_nodes[p]
		var tw := create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.4)
		tw.tween_callback(n.queue_free)
		event_nodes.erase(p)
	_update_solid(p)


func _interact(p: Vector2i) -> void:
	var c := ch(p)
	hero.flip_h = p.x < Game.hero_pos.x if p.x != Game.hero_pos.x else hero.flip_h
	if c == "R":
		await _recruit()
		return
	if not _is_event(p):
		return
	var ev: Dictionary = Data.EVENTS[c]
	match ev["type"]:
		"battle":
			if ev.has("before"):
				await _dialog(Data.DIALOGS[ev["before"]])
			Game.pending = {"event": c, "pos": [p.x, p.y], "battle": ev["battle"]}
			Game.goto("battle", {"battle": ev["battle"]})
		"gold":
			var amount := 150 + ((p.x * 37 + p.y * 11) % 4) * 50
			Game.gold += amount
			Sfx.play("coin")
			_toast("Найдено золото: +%d" % amount)
			_clear_event(p)
			_refresh_ui()
		"chest":
			var g := 500 + ((p.x * 7 + p.y) % 3) * 100
			var xp := g / 2 + 50
			Sfx.play("coin")
			var i := await _ask("none", "Вы нашли сундук, спрятанный людьми Карра.", ["Забрать %d золота" % g, "Раздать бедным: +%d опыта" % xp])
			if i == 0:
				Game.gold += g
				_toast("+%d золота" % g)
			else:
				var msgs := Game.add_xp(xp)
				_toast("+%d опыта" % xp if msgs.is_empty() else msgs[-1])
			_clear_event(p)
			_refresh_ui()
		"talk":
			await _dialog(Data.DIALOGS[ev["dialog"]])
			if c == "S":
				Game.flags["met_scout"] = true


func _after_battle(result: String) -> void:
	var pend: Dictionary = Game.pending
	Game.pending = {}
	_refresh_ui()
	if result != "win" or pend.is_empty():
		if result == "retreat":
			_toast("Отряд отступил.")
		return
	var p := Vector2i(int(pend["pos"][0]), int(pend["pos"][1]))
	var c: String = pend["event"]
	var ev: Dictionary = Data.EVENTS[c]
	_clear_event(p)
	await get_tree().create_timer(0.4).timeout
	if ev.has("after"):
		await _dialog(Data.DIALOGS[ev["after"]])
	match c:
		"2":
			Game.flags["village_free"] = true
			_anim_sprite(["flag_vale_0", "flag_vale_1", "flag_vale_2", "flag_vale_3"], _find("R") + Vector2i(0, -1), 6)
		"3":
			_clear_event(_find("B"))
			Game.add_units("vale_knight", 4)
			Game.hero["def"] += 1
			Game.flags["brenna"] = true
			Game.recruit_pool["vale_knight"] = int(Game.recruit_pool.get("vale_knight", 0)) + 6
			_refresh_ui()
		"7":
			Game.flags["chapter1_done"] = true
			Game.save_game()
			Game.goto("ending")
			return
	Game.save_game()


func _recruit() -> void:
	if not Game.flags.get("village_free", false):
		await _dialog(Data.DIALOGS["recruit_locked"])
		return
	while true:
		var opts := []
		var ids := []
		for id in Game.recruit_pool:
			var left: int = Game.recruit_pool[id]
			var cost: int = Data.UNITS[id]["cost"]
			var can := mini(left, Game.gold / cost)
			if can > 0:
				opts.append("%s: нанять %d за %d золота (осталось %d)" % [Data.UNITS[id]["name"], can, can * cost, left])
				ids.append(id)
		opts.append("Уйти")
		var i := await _ask("elder", "Кого возьмёте, милорд? У вас %d золота." % Game.gold, opts)
		if i >= ids.size():
			return
		var id: String = ids[i]
		var cost2: int = Data.UNITS[id]["cost"]
		var n := mini(Game.recruit_pool[id], Game.gold / cost2)
		if Game.add_units(id, n):
			Game.gold -= n * cost2
			Game.recruit_pool[id] -= n
			Sfx.play("coin")
			_toast("%s: +%d" % [Data.UNITS[id]["name"], n])
		else:
			_toast("В армии нет свободных мест.")
		_refresh_ui()
