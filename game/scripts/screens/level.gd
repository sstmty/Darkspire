extends Node2D
## One side-scrolling level: tiles, parallax, actors, story triggers, Угли Памяти, the boss, death and rest.
## Maps live in res://data/<level>.txt; the legend is in tools/gen_levels.py.

const T := 16
const PLAYER := preload("res://scripts/actors/player.gd")
const ENEMY := preload("res://scripts/actors/enemy.gd")
const BOSS := preload("res://scripts/actors/boss.gd")
const NAYRA := preload("res://scripts/actors/nayra.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const DIALOG := preload("res://scripts/ui/dialog.gd")
const PROPS := {
	"h": "house", "b": "house_burnt", "c": "house_burnt2", "t": "dead_tree", "T": "dead_tree2",
	"f": "fence", "k": "cart", "r": "rail", "n": "banner", "x": "grave",
}
const TRIGGERS := {
	"2": "hollowd_ghouls", "3": "hollowd_coal", "4": "hollowd_arena",
	"5": "border_guards", "6": "border_ring", "7": "border_bridge",
}
const BOSSES := {"hollowd": "shepherd", "border": "draven"}
const WIN := {"shepherd": "shepherd_win", "draven": "draven_win"}
const TILES := preload("res://assets/side/tiles.png")
const ASH := {"hollowd": Color(0.55, 0.5, 0.5, 0.6), "border": Color(0.7, 0.72, 0.8, 0.5)}

var id := ""
var info: Dictionary
var rows: Array[String] = []
var W := 0
var H := 0
var world: Node2D
var player: Node
var nayra: Node
var boss: Node
var enemies: Array = []
var coals: Array[Vector2] = []
var triggers: Array = []
var start_pos := Vector2.ZERO
var exit_x := -1.0
var arena := Vector2(-1, -1)
var boss_pos := Vector2.ZERO
var walls: Array[CollisionShape2D] = []
var hud: Node
var camera: Camera2D
var thread: Line2D
var ui: CanvasLayer
var busy := false
var boss_active := false
var _dying := false
var _leaving := false
var _shake := 0.0


func setup(params: Dictionary) -> void:
	id = params.get("level", Game.level)
	Game.level = id
	info = Data.LEVELS[id]
	if id == "border":
		Game.flags["nayra"] = true
	_load_map()
	_build_parallax()
	world = Node2D.new()
	add_child(world)
	var tiles := Node2D.new()
	tiles.z_index = -2
	tiles.draw.connect(_draw_tiles.bind(tiles))
	world.add_child(tiles)
	_build_colliders()
	_spawn_entities()

	player = PLAYER.new()
	player.level = self
	player.position = start_pos if Game.checkpoint < 0 or Game.checkpoint >= coals.size() else coals[Game.checkpoint] + Vector2(18, 0)
	world.add_child(player)
	if Game.flags.get("nayra", false):
		thread = Line2D.new()
		thread.width = 1.0
		thread.default_color = Color(0.45, 0.75, 1.0, 0.45)
		world.add_child(thread)
		nayra = NAYRA.new()
		nayra.level = self
		nayra.position = player.position - Vector2(22, 0)
		world.add_child(nayra)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = W * T
	camera.limit_bottom = H * T
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = player.position + Vector2(0, -48)
	add_child(camera)
	camera.reset_smoothing.call_deferred()
	_add_ash()

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	Sfx.music("world")
	_begin()


func _begin() -> void:
	await get_tree().create_timer(0.5).timeout
	hud.show_banner(info["title"])
	var intro: String = id + "_start"
	if Data.DIALOGS.has(intro) and not Game.flags.get("seen_" + intro, false):
		Game.flags["seen_" + intro] = true
		await get_tree().create_timer(1.0).timeout
		await talk(intro)
	var pend: String = Game.flags.get("pending_dialog", "")
	if pend != "":
		Game.flags.erase("pending_dialog")
		await talk(pend)


# ---------------------------------------------------------------- map

func _load_map() -> void:
	var txt := FileAccess.get_file_as_string("res://data/%s.txt" % id)
	for line in txt.split("\n"):
		if line.length() > 0:
			rows.append(line)
			W = maxi(W, line.length())
	H = rows.size()
	for i in H:
		rows[i] = rows[i].rpad(W)


func ch(c: int, r: int) -> String:
	if r < 0 or r >= H:
		return " "
	if c < 0 or c >= W:
		return "#"
	return rows[r][c]


func solid(c: int, r: int) -> bool:
	return ch(c, r) in ["#", "="]


func solid_px(x: float, y: float) -> bool:
	return solid(floori(x / T), floori(y / T))


## True when something stands under (x, y), one tile of drop allowed.
func floor_px(x: float, y: float) -> bool:
	var c := floori(x / T)
	var r := floori(y / T)
	for rr in [r, r + 1]:
		if ch(c, rr) in ["#", "=", "-"]:
			return true
	return false


func _ground_tile(c: int, r: int) -> int:
	if not solid(c, r - 1):
		if id == "hollowd":
			return 0 if (c * 31 + r) % 5 == 0 else 7
		return 8 if (c * 17 + r) % 4 == 0 else 2
	var depth := 1
	while depth < 3 and solid(c, r - depth - 1):
		depth += 1
	if depth >= 3 and solid(c, r - 3):
		return 9
	return 1 if id == "hollowd" else 3


func _draw_tiles(n: Node2D) -> void:
	var tex: Texture2D = TILES
	for r in H:
		for c in W:
			var k := rows[r][c]
			var idx := -1
			match k:
				"#":
					idx = _ground_tile(c, r)
				"=":
					idx = 4
				"-":
					idx = 6
				"|":
					idx = 5
			if idx < 0:
				continue
			var v := (c * 7 + r * 13) % 3
			n.draw_texture_rect_region(tex, Rect2(c * T, r * T, T, T), Rect2(idx * T, v * T, T, T))


func _build_colliders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	world.add_child(body)
	for r in H:
		var c := 0
		while c < W:
			var k := ch(c, r)
			if k in ["#", "=", "-"]:
				var start := c
				while c < W and ch(c, r) == k:
					c += 1
				var plank := k == "-"
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2((c - start) * T, 5 if plank else T)
				shape.shape = rect
				shape.position = Vector2(start * T + rect.size.x / 2.0, r * T + rect.size.y / 2.0)
				shape.one_way_collision = plank
				body.add_child(shape)
			else:
				c += 1


func _spawn_entities() -> void:
	var foes := []
	for r in H:
		for c in W:
			var k := rows[r][c]
			var pos := Vector2(c * T + T / 2.0, (r + 1) * T)
			match k:
				"p":
					start_pos = pos
				"U":
					coals.append(pos)
					_make_coal(pos)
				"g":
					foes.append(["ashghoul", pos])
				"G":
					foes.append(["rustguard", pos])
				"B":
					boss_pos = pos
				"[":
					arena.x = c * T
				"]":
					arena.y = (c + 1) * T
				"E":
					exit_x = pos.x
					_make_exit(pos)
				_:
					if PROPS.has(k):
						_make_prop(PROPS[k], pos)
					elif k >= "1" and k <= "9":
						triggers.append({"x": pos.x, "key": TRIGGERS.get(k, ""), "done": false})
	triggers.sort_custom(func(a, b): return a["x"] < b["x"])
	for f in foes:
		spawn_enemy(f[0], f[1])
	if arena.x >= 0.0 and not boss_done():
		var body := StaticBody2D.new()
		world.add_child(body)
		for x in [arena.x - 4.0, arena.y + 4.0]:
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(8, H * T)
			shape.shape = rect
			shape.position = Vector2(x, H * T / 2.0)
			shape.disabled = true
			body.add_child(shape)
			walls.append(shape)


func _make_prop(name: String, pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = load("res://assets/side/%s.png" % name)
	s.centered = false
	s.position = pos - Vector2(roundf(s.texture.get_width() / 2.0), s.texture.get_height())
	s.z_index = -1
	world.add_child(s)


func _make_coal(pos: Vector2) -> void:
	_make_prop("coal", pos)
	var fire := CPUParticles2D.new()
	fire.position = pos + Vector2(0, -14)
	fire.amount = 24
	fire.lifetime = 0.9
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fire.emission_rect_extents = Vector2(5, 2)
	fire.direction = Vector2(0, -1)
	fire.spread = 12
	fire.gravity = Vector2(0, -30)
	fire.initial_velocity_min = 8
	fire.initial_velocity_max = 20
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.95, 1.0, 1.0))
	g.set_color(1, Color(0.2, 0.4, 1.0, 0.0))
	fire.color_ramp = g
	fire.z_index = -1
	world.add_child(fire)


func _make_exit(pos: Vector2) -> void:
	var glow := CPUParticles2D.new()
	glow.position = pos + Vector2(0, -24)
	glow.amount = 16
	glow.lifetime = 2.0
	glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	glow.emission_rect_extents = Vector2(6, 24)
	glow.direction = Vector2(1, -0.3)
	glow.gravity = Vector2.ZERO
	glow.initial_velocity_min = 4
	glow.initial_velocity_max = 12
	glow.color = Color(1.0, 0.85, 0.5, 0.5)
	world.add_child(glow)


func _build_parallax() -> void:
	var theme: String = info["theme"]
	for pair in [["sky", 0.0], ["far", 0.15], ["mid", 0.4]]:
		var px := Parallax2D.new()
		px.z_index = -10
		px.scroll_scale = Vector2(pair[1], 0.0)
		px.repeat_size = Vector2(640, 0)
		px.repeat_times = 3
		var s := Sprite2D.new()
		s.texture = load("res://assets/side/bg_%s_%s.png" % [theme, pair[0]])
		s.centered = false
		px.add_child(s)
		add_child(px)


func _add_ash() -> void:
	var ash := CPUParticles2D.new()
	ash.position = Vector2(0, -200)
	ash.amount = 60
	ash.lifetime = 7.0
	ash.preprocess = 7.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ash.emission_rect_extents = Vector2(380, 4)
	ash.direction = Vector2(-0.3, 1)
	ash.spread = 20
	ash.gravity = Vector2(0, 6)
	ash.initial_velocity_min = 10
	ash.initial_velocity_max = 25
	ash.color = ASH[info["theme"]]
	camera.add_child(ash)


# ---------------------------------------------------------------- actors

func spawn_enemy(kind: String, pos: Vector2) -> Node:
	var e := ENEMY.new()
	e.setup(kind, self)
	e.position = pos
	world.add_child(e)
	enemies.append(e)
	return e


## Everything the hunter's blade can hit.
func targets() -> Array:
	var out := enemies.filter(func(e): return is_instance_valid(e) and e.alive())
	if boss != null and boss.alive():
		out.append(boss)
	return out


func boss_done() -> bool:
	return not BOSSES.has(id) or Game.flags.get("boss_" + BOSSES[id], false)


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if player == null:
		return
	camera.position = player.position + Vector2(player.facing * 36.0, -56.0)
	camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	_shake = move_toward(_shake, 0.0, 24.0 * delta)
	if thread != null and nayra != null:
		var a: Vector2 = player.position + Vector2(0, -16)
		var b: Vector2 = nayra.position + Vector2(0, -16)
		var mid := (a + b) / 2.0 + Vector2(0, 6.0 + 2.0 * sin(Time.get_ticks_msec() / 400.0))
		thread.points = PackedVector2Array([a, mid, b])
	if busy or _leaving or not player.alive():
		hud.show_prompt("")
		return
	for t in triggers:
		if not t["done"] and player.position.x >= t["x"]:
			t["done"] = true
			var key: String = t["key"]
			if key != "" and not Game.flags.get("seen_" + key, false):
				Game.flags["seen_" + key] = true
				talk(key)
				return
	var near := -1
	for i in coals.size():
		if absf(player.position.x - coals[i].x) < 22.0 and absf(player.position.y - coals[i].y) < 24.0:
			near = i
	hud.show_prompt("E: отдохнуть у Угля Памяти" if near >= 0 and not boss_active else "")
	if near >= 0 and not boss_active:
		if Input.is_action_just_pressed("interact") or (player.bot and Game.checkpoint < near):
			rest(near)
			return
	if arena.x >= 0.0 and not boss_active and not boss_done() and player.position.x > arena.x + 40.0:
		start_boss()
	if exit_x >= 0.0 and player.position.x >= exit_x - 4.0 and boss_done():
		leave()


func talk(key: String) -> void:
	busy = true
	var d := DIALOG.new()
	ui.add_child(d)
	await d.play(Data.DIALOGS[key])
	d.queue_free()
	busy = false
	player.input_lock = 0.2


func rest(i: int) -> void:
	busy = true
	Sfx.play("buff", 0.8)
	burst(coals[i] + Vector2(0, -12), Color(0.5, 0.8, 1.0), 24)
	Game.checkpoint = i
	Game.flasks = Game.flask_max
	if not Game.flags.get("seen_rest", false):
		Game.flags["seen_rest"] = true
		Game.save_game()
		await talk("rest")
		busy = true
	Game.save_game()
	hud.show_banner("Угль Памяти", 0.6)
	await get_tree().create_timer(1.0).timeout
	Game.goto("level", {"level": id})


func start_boss() -> void:
	boss_active = true
	for w in walls:
		w.set_deferred("disabled", false)
	boss = BOSS.new()
	boss.setup(BOSSES[id], self)
	boss.scripted = id == "hollowd" and not Game.flags.get("shepherd_met", false)
	boss.position = boss_pos
	world.add_child(boss)
	burst(boss_pos + Vector2(0, -30), Color(0.25, 0.22, 0.26), 30)
	boss.intro()
	hud.set_boss(boss)
	Sfx.music("battle")


func on_boss_dead() -> void:
	Game.flags["boss_" + boss.kind] = true
	for w in walls:
		w.set_deferred("disabled", true)
	Sfx.music("")
	Sfx.play("victory")
	await get_tree().create_timer(1.5).timeout
	hud.set_boss(null)
	hud.show_banner("Враг повержен")
	boss_active = false
	await get_tree().create_timer(2.5).timeout
	Game.checkpoint = coals.size() - 1
	Game.save_game()
	Sfx.music("world")
	if player.alive():
		await talk(WIN[boss.kind])


func on_player_death() -> void:
	if _dying:
		return
	_dying = true
	Game.stats["deaths"] = int(Game.stats.get("deaths", 0)) + 1
	var scripted: bool = boss != null and boss.scripted
	var memory := Game.forget(0 if scripted else -1)
	print("DEATH level=", id, " x=", int(player.position.x), " boss_hp=", int(boss.hp) if boss != null else -1, " scripted=", scripted, " forgot=", memory)
	Sfx.music("")
	Sfx.play("defeat")
	await get_tree().create_timer(1.2).timeout
	await hud.show_death(memory)
	Game.flasks = Game.flask_max
	if scripted:
		Game.flags["shepherd_met"] = true
		Game.flags["nayra"] = true
		Game.flags["pending_dialog"] = "shepherd_first_death"
		Game.checkpoint = coals.size() - 1
	Game.save_game()
	Game.goto("level", {"level": id})


func leave() -> void:
	_leaving = true
	busy = true
	var nxt: String = info["next"]
	print("LEVEL DONE ", id, " deaths=", Game.stats["deaths"])
	Game.flasks = Game.flask_max
	if nxt == "":
		Game.flags["chapter1_done"] = true
		Game.save_game()
		Game.goto("ending")
		return
	Game.level = nxt
	Game.checkpoint = -1
	Game.save_game()
	Game.goto("level", {"level": nxt})


# ---------------------------------------------------------------- effects

func say(who: String, text: String, dur: float = 3.0) -> void:
	hud.say(who, text, dur)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func flash(c: Color) -> void:
	hud.flash(c)


func burst(pos: Vector2, color: Color, n: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = n
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180
	p.gravity = Vector2(0, 200)
	p.initial_velocity_min = 40
	p.initial_velocity_max = 110
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	world.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## A flash of the oath-thread between two people (or Нэйра and her target).
func bind_flash(a: Node2D, b: Node2D) -> void:
	var l := Line2D.new()
	l.width = 1.5
	l.default_color = Color(0.6, 0.9, 1.0, 0.9)
	l.points = PackedVector2Array([a.position + Vector2(0, -16), b.position + Vector2(0, -16)])
	world.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
