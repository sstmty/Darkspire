extends Node2D
## Turn-based tactical battle on a 12x7 grid, in the spirit of classic hero strategies.

signal player_done

const COLS := 12
const ROWS := 7
const CW := 44
const CH := 30
const OX := 56
const OY := 114
const UnitScript := preload("res://scripts/battle_unit.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
const PLACES := {1: [3], 2: [2, 4], 3: [1, 3, 5], 4: [0, 2, 4, 6], 5: [0, 1, 3, 5, 6], 6: [0, 1, 2, 4, 5, 6], 7: [0, 1, 2, 3, 4, 5, 6]}

var battle_id := ""
var bdef := {}
var stage: Node2D
var units_layer: Node2D
var fx_layer: Node2D
var stacks: Array = []
var obstacles := {}
var queue: Array = []
var active = null
var round_no := 0
var state := "busy"
var reach := {}
var parents := {}
var hover_cell := Vector2i(-1, -1)
var hover_target = null
var hover_from := Vector2i(-1, -1)
var auto := false
var cry_used := false
var enemy_bonus := 0
var army_snapshot: Array = []
var xp_gain := 0
var killed_total := 0

var ui: CanvasLayer
var info_label: Label
var hint_label: Label
var log_label: Label
var round_label: Label
var queue_box: HBoxContainer
var btn_cry: Button
var btn_def: Button
var btn_wait: Button
var btn_auto: Button


func setup(params: Dictionary) -> void:
	battle_id = params.get("battle", "village")
	auto = params.get("auto", false) or Game.autotest
	bdef = Data.BATTLES[battle_id]
	enemy_bonus = int(bdef.get("enemy_bonus", 0))
	army_snapshot = Game.army.duplicate(true)
	Sfx.music("battle")
	stage = Node2D.new()
	add_child(stage)
	var bg := Sprite2D.new()
	bg.texture = load("res://assets/battle/bg_%s.png" % bdef["bg"])
	bg.centered = false
	stage.add_child(bg)
	var grid := Node2D.new()
	grid.draw.connect(_draw_grid.bind(grid))
	grid.name = "Grid"
	stage.add_child(grid)
	units_layer = Node2D.new()
	units_layer.y_sort_enabled = true
	stage.add_child(units_layer)
	fx_layer = Node2D.new()
	fx_layer.z_index = 10
	stage.add_child(fx_layer)
	_place_obstacles()
	_place_side(Game.army, 0)
	var enemy := []
	for s in bdef["army"]:
		enemy.append({"id": s[0], "count": s[1]})
	_place_side(enemy, 1)
	_build_ui()
	_banner(bdef["title"])
	await get_tree().create_timer(1.0).timeout
	_run()


# ---------------------------------------------------------------- layout

func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(OX + c.x * CW, OY + c.y * CH, CW, CH)


func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(OX + c.x * CW + CW / 2.0, OY + c.y * CH + CH - 7)


func pos_cell(p: Vector2) -> Vector2i:
	var c := Vector2i(floori((p.x - OX) / CW), floori((p.y - OY) / CH))
	if c.x < 0 or c.y < 0 or c.x >= COLS or c.y >= ROWS:
		return Vector2i(-1, -1)
	return c


func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func _place_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(battle_id)
	var names := ["rock_0", "rock_1", "rock_2", "stump", "deadtree"]
	var n := rng.randi_range(3, 5)
	while obstacles.size() < n:
		var c := Vector2i(rng.randi_range(3, 8), rng.randi_range(0, ROWS - 1))
		if obstacles.has(c):
			continue
		obstacles[c] = true
		var s := Sprite2D.new()
		s.texture = load("res://assets/battle/%s.png" % names[rng.randi() % names.size()])
		s.centered = false
		s.position = cell_pos(c) - Vector2(s.texture.get_width() / 2.0, s.texture.get_height() - 3)
		var holder := Node2D.new()
		holder.position = cell_pos(c)
		s.position -= holder.position
		holder.add_child(s)
		units_layer.add_child(holder)


func _place_side(list: Array, side: int) -> void:
	var rows: Array = PLACES[clampi(list.size(), 1, 7)]
	for i in list.size():
		var u = UnitScript.new()
		u.setup(list[i]["id"], int(list[i]["count"]), side)
		if side == 0:
			u.slot = i
		var col := 0 if side == 0 else COLS - 1
		var c := Vector2i(col, rows[i])
		if side == 0 and Data.UNITS[list[i]["id"]]["shots"] == 0 and list[i]["id"] != "vale_knight":
			c.x = 1
		if side == 1 and Data.UNITS[list[i]["id"]]["shots"] == 0:
			c.x = COLS - 2
		u.cell = c
		u.position = cell_pos(c)
		units_layer.add_child(u)
		stacks.append(u)


# ---------------------------------------------------------------- drawing

func _draw_grid(g: Node2D) -> void:
	var line := Color(0, 0, 0, 0.22)
	for y in ROWS:
		for x in COLS:
			var r := cell_rect(Vector2i(x, y))
			g.draw_rect(r.grow(-1), Color(1, 1, 1, 0.025), true)
			g.draw_rect(r, line, false, 1.0)
	if state == "player" and active:
		for c in reach:
			if c != active.cell:
				g.draw_rect(cell_rect(c).grow(-2), Color(0.95, 0.85, 0.5, 0.16), true)
		g.draw_rect(cell_rect(active.cell).grow(-1), Color("e0b55a"), false, 1.0)
		if hover_target and hover_from != Vector2i(-1, -1) and hover_from != active.cell:
			g.draw_rect(cell_rect(hover_from).grow(-2), Color(0.9, 0.9, 0.5, 0.35), true)
		if hover_target:
			g.draw_rect(cell_rect(hover_target.cell).grow(-1), Color("d04a3a"), false, 1.0)
		elif reach.has(hover_cell) and not _occupied(hover_cell):
			var c: Vector2i = hover_cell
			while c != active.cell and parents.has(c):
				g.draw_rect(Rect2(cell_pos(c) - Vector2(2, 4), Vector2(4, 4)), Color(1, 0.9, 0.5, 0.8), true)
				c = parents[c]
	elif active:
		g.draw_rect(cell_rect(active.cell).grow(-1), Color(0.8, 0.3, 0.3, 0.8) if active.side == 1 else Color("e0b55a"), false, 1.0)


func _redraw() -> void:
	stage.get_node("Grid").queue_redraw()


# ---------------------------------------------------------------- ui

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var top := ColorRect.new()
	top.color = Color(0.05, 0.04, 0.06, 0.75)
	top.size = Vector2(640, 34)
	ui.add_child(top)
	queue_box = HBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 2)
	queue_box.position = Vector2(150, 2)
	ui.add_child(queue_box)
	round_label = Game.label("", 10, Color("e0b55a"))
	round_label.position = Vector2(8, 4)
	ui.add_child(round_label)
	var hero_lbl := Game.label("%s · ур. %d\nАтака +%d  Защита +%d" % [Game.hero.get("name", "Кайрен"), Game.hero.get("level", 1), Game.hero.get("atk", 1), Game.hero.get("def", 1)], 8, Color("b8aac0"))
	hero_lbl.position = Vector2(8, 15)
	ui.add_child(hero_lbl)
	log_label = Game.label("", 8, Color("d8c8a8"), 2)
	log_label.position = Vector2(8, 36)
	log_label.size = Vector2(624, 12)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(log_label)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(0, 328)
	bottom.size = Vector2(640, 32)
	ui.add_child(bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bottom.add_child(row)
	info_label = Game.label("", 8)
	info_label.custom_minimum_size = Vector2(250, 22)
	row.add_child(info_label)
	hint_label = Game.label("", 8, Color("e0b55a"))
	hint_label.custom_minimum_size = Vector2(150, 22)
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint_label)
	btn_cry = Game.button("Клич", _on_cry, 8)
	btn_cry.tooltip_text = "Клич Сокола: +3 к атаке всем вашим отрядам до конца боя. Один раз за бой."
	btn_def = Game.button("Защита", _on_defend, 8)
	btn_wait = Game.button("Ждать", _on_wait, 8)
	btn_auto = Game.button("Авто", _on_auto, 8)
	for b in [btn_cry, btn_def, btn_wait, btn_auto]:
		b.custom_minimum_size = Vector2(44, 20)
		row.add_child(b)
	_update_buttons()


func _update_buttons() -> void:
	var mine: bool = state == "player"
	btn_cry.disabled = not mine or cry_used
	btn_def.disabled = not mine
	btn_wait.disabled = not mine or (active != null and active.waited)
	btn_auto.text = "Стоп" if auto else "Авто"


func _update_queue() -> void:
	for c in queue_box.get_children():
		c.queue_free()
	var list: Array = []
	if active:
		list.append(active)
	for u in queue:
		if not u.dead:
			list.append(u)
	var nxt := _round_order()
	for u in nxt:
		if list.size() >= 11:
			break
		list.append(u)
	for i in mini(list.size(), 11):
		var u = list[i]
		var box := Panel.new()
		box.custom_minimum_size = Vector2(28, 30)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2a1e33") if u.side == 0 else Color("3a1518")
		sb.border_color = Color("e0b55a") if i == 0 else (Color("6a5a80") if u.side == 0 else Color("8a3a32"))
		sb.set_border_width_all(1)
		box.add_theme_stylebox_override("panel", sb)
		var tex := AtlasTexture.new()
		tex.atlas = load("res://assets/units/%s_mini.png" % u.id)
		tex.region = Rect2(2, 2, 28, 28)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.position = Vector2(0, -2)
		tr.flip_h = u.side == 1
		box.add_child(tr)
		var l := Game.label(str(u.count), 8, Color("fff2c8"), 2)
		l.position = Vector2(2, 19)
		box.add_child(l)
		queue_box.add_child(box)
	round_label.text = "Раунд %d" % round_no


func _unit_info(u) -> String:
	var d: Dictionary = u.def
	var atk: int = int(d["atk"]) + _side_atk(u)
	var df: int = int(d["def"]) + _side_def(u)
	var s := "%s: %d   Атака %d  Защита %d  Урон %d–%d" % [d["name"], u.count, atk, df, d["dmg"][0], d["dmg"][1]]
	s += "\nЗдоровье %d/%d   Скорость %d" % [u.top_hp, d["hp"], d["speed"]]
	if u.is_ranged():
		s += "   Выстрелы %d" % u.shots
	if u.defending:
		s += "   (защита)"
	return s


func _log(t: String) -> void:
	log_label.text = t


func _banner(text: String) -> void:
	var l := Game.label(text, 20, Color("f0d890"), 3)
	l.size = Vector2(640, 30)
	l.position = Vector2(0, 150)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


# ---------------------------------------------------------------- turn loop

func _side_atk(u) -> int:
	return (int(Game.hero.get("atk", 0)) if u.side == 0 else enemy_bonus) + u.atk_bonus


func _side_def(u) -> int:
	return int(Game.hero.get("def", 0)) if u.side == 0 else enemy_bonus


func _alive(side: int) -> Array:
	return stacks.filter(func(u): return not u.dead and u.side == side)


func _round_order() -> Array:
	var list := stacks.filter(func(u): return not u.dead)
	list.sort_custom(func(a, b):
		if a.def["speed"] != b.def["speed"]:
			return a.def["speed"] > b.def["speed"]
		return a.side < b.side)
	return list


func _new_round() -> void:
	round_no += 1
	queue = _round_order()
	for u in stacks:
		u.retaliated = false
		u.waited = false


func _run() -> void:
	while true:
		if _alive(0).is_empty() or _alive(1).is_empty():
			break
		if queue.is_empty():
			_new_round()
		var u = queue.pop_front()
		if u.dead:
			continue
		active = u
		u.defending = false
		_update_queue()
		info_label.text = _unit_info(u)
		if u.side == 0 and not auto:
			_compute_reach(u)
			state = "player"
			hint_label.text = "Ваш ход: %s" % u.def["name"]
			_update_buttons()
			_redraw()
			_on_hover(get_global_mouse_position())
			await player_done
		else:
			state = "busy"
			_update_buttons()
			_compute_reach(u)
			_redraw()
			await get_tree().create_timer(0.25).timeout
			await _ai_turn(u)
		state = "busy"
		_update_buttons()
		active = null
		_redraw()
		await get_tree().create_timer(0.12).timeout
	_finish(not _alive(0).is_empty())


# ---------------------------------------------------------------- movement

func _occupied(c: Vector2i) -> bool:
	if obstacles.has(c):
		return true
	for u in stacks:
		if not u.dead and u.cell == c:
			return true
	return false


func _unit_at(c: Vector2i):
	for u in stacks:
		if not u.dead and u.cell == c:
			return u
	return null


func _compute_reach(u) -> void:
	reach = {u.cell: 0}
	parents = {}
	var frontier := [u.cell]
	var speed := int(u.def["speed"])
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_front()
		if reach[c] >= speed:
			continue
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_grid(n) or reach.has(n) or _occupied(n):
				continue
			reach[n] = reach[c] + 1
			parents[n] = c
			frontier.append(n)


func _path_to(c: Vector2i) -> Array:
	var path := []
	while parents.has(c):
		path.push_front(c)
		c = parents[c]
	return path


func _move(u, target: Vector2i) -> void:
	var path := _path_to(target)
	if path.is_empty():
		return
	u.sprite.play("walk")
	for c in path:
		var to := cell_pos(c)
		u.face(to.x - u.position.x)
		var tw := create_tween()
		tw.tween_property(u, "position", to, 0.16)
		Sfx.play("step", 0.8 if u.def["speed"] >= 6 else 1.2)
		await tw.finished
		u.cell = c
	u.play_idle()


static func cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _adjacent_enemy(u) -> bool:
	for e in stacks:
		if not e.dead and e.side != u.side and cheb(e.cell, u.cell) == 1:
			return true
	return false


func _can_shoot(u) -> bool:
	return u.is_ranged() and u.shots > 0 and not _adjacent_enemy(u)


# ---------------------------------------------------------------- combat

func _dmg_mod(a, d, ranged: bool) -> float:
	var atk := float(int(a.def["atk"]) + _side_atk(a))
	var df := float(int(d.def["def"]) + _side_def(d))
	if d.defending:
		df *= 1.3
	var m := 1.0
	if atk > df:
		m = minf(3.0, 1.0 + 0.05 * (atk - df))
	else:
		m = maxf(0.3, 1.0 - 0.025 * (df - atk))
	if ranged and cheb(a.cell, d.cell) > 6:
		m *= 0.5
	if not ranged and a.is_ranged():
		m *= 0.5
	return m


func _dmg_range(a, d, ranged: bool) -> Vector2i:
	var m := _dmg_mod(a, d, ranged)
	return Vector2i(maxi(1, roundi(a.count * int(a.def["dmg"][0]) * m)), maxi(1, roundi(a.count * int(a.def["dmg"][1]) * m)))


func _roll_dmg(a, d, ranged: bool) -> int:
	var lo := int(a.def["dmg"][0])
	var hi := int(a.def["dmg"][1])
	var base := 0.0
	if a.count <= 10:
		for i in a.count:
			base += randi_range(lo, hi)
	else:
		base = a.count * randf_range(lo, hi) * 0.6 + a.count * (lo + hi) * 0.5 * 0.4
	return maxi(1, roundi(base * _dmg_mod(a, d, ranged)))


func _strike(a, d, ranged: bool) -> void:
	a.face(d.position.x - a.position.x)
	if not ranged:
		d.face(a.position.x - d.position.x)
	await a.attack_anim()
	if ranged:
		Sfx.play("bow", 1.3 if a.id == "karr_crossbow" else 1.0)
		a.shots -= 1
		await _missile(a, d)
	else:
		Sfx.play("bite" if a.id in ["karr_hound", "wolf"] else "swing")
	var dmg := _roll_dmg(a, d, ranged)
	var killed: int = d.take_damage(dmg)
	_hit_fx(d, dmg, killed)
	if a.side == 0:
		killed_total += killed
		xp_gain += killed * int(d.def.get("xp", 3))
	var name_d: String = d.def["name"]
	var line := "%s: %d урона по отряду «%s»." % [a.def["name"], dmg, name_d]
	if killed > 0:
		line += " Погибло: %d." % killed
	_log(line)
	if d.count <= 0:
		Sfx.play("thud")
		d.die()
	else:
		d.hurt()
	await a.finish_anim()
	if not d.dead:
		await get_tree().create_timer(0.15).timeout


func _missile(a, d) -> void:
	var arrow := Sprite2D.new()
	arrow.texture = load("res://assets/battle/arrow.png")
	fx_layer.add_child(arrow)
	var from: Vector2 = a.position + Vector2(10 if not a.sprite.flip_h else -10, -24)
	var to: Vector2 = d.position + Vector2(0, -18)
	var dist := from.distance_to(to)
	var dur := clampf(dist / 380.0, 0.18, 0.6)
	var arc := dist * 0.18
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var p := from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
		var p2 := from.lerp(to, minf(1.0, t + 0.02)) + Vector2(0, -arc * 4.0 * minf(1.0, t + 0.02) * (1.0 - minf(1.0, t + 0.02)))
		arrow.position = p
		arrow.rotation = (p2 - p).angle(), 0.0, 1.0, dur)
	await tw.finished
	arrow.queue_free()


func _hit_fx(d, dmg: int, killed: int) -> void:
	var armored: bool = d.id in ["vale_knight", "karr_rider", "karr_lord", "vale_spearman", "karr_crossbow"]
	Sfx.play("clang" if armored else "hit")
	var p := CPUParticles2D.new()
	p.position = d.position + Vector2(0, -18)
	p.amount = 14
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 70
	p.initial_velocity_min = 40
	p.initial_velocity_max = 90
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color("f0e0a0") if armored else Color("a02020")
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	var l := Game.label("-%d" % dmg, 10, Color("ff6050"), 2)
	l.position = d.position + Vector2(-14, -52)
	l.size = Vector2(28, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_layer.add_child(l)
	if killed > 0:
		var k := Game.label("убито %d" % killed, 8, Color("f0f0f0"), 2)
		k.position = Vector2(-16, 10)
		k.size = Vector2(60, 10)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_child(k)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 16, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)
	if dmg >= 40 or d.count <= 0:
		_shake(3.0 if dmg < 120 else 5.0)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for i in 5:
		tw.tween_property(stage, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	tw.tween_property(stage, "position", Vector2.ZERO, 0.04)


## Full attack: optional move, strike, retaliation.
func _attack(a, d, from: Vector2i, ranged: bool) -> void:
	if not ranged and from != a.cell:
		await _move(a, from)
	await _strike(a, d, ranged)
	if not ranged and not d.dead and not a.dead and not d.retaliated:
		d.retaliated = true
		await _strike(d, a, false)
	a.face_default()
	if not d.dead:
		d.face_default()


# ---------------------------------------------------------------- player input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_on_hover(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_hover(get_global_mouse_position())
		_on_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_D:
				_on_defend()
			KEY_W:
				_on_wait()
			KEY_A:
				_on_auto()


func _on_hover(mp: Vector2) -> void:
	var c := pos_cell(mp)
	var u = _unit_at(c) if c != Vector2i(-1, -1) else null
	if u:
		info_label.text = _unit_info(u)
	elif active:
		info_label.text = _unit_info(active)
	if state != "player" or active == null:
		return
	hover_cell = c
	hover_target = null
	hover_from = Vector2i(-1, -1)
	if c == Vector2i(-1, -1):
		hint_label.text = ""
	elif u and u.side != active.side:
		if _can_shoot(active):
			hover_target = u
			hover_from = active.cell
			var r := _dmg_range(active, u, true)
			hint_label.text = "Выстрел: урон %d–%d%s" % [r.x, r.y, _kill_hint(r, u)]
		else:
			var best := _best_from(u, mp)
			if best != Vector2i(-1, -1):
				hover_target = u
				hover_from = best
				var r2 := _dmg_range(active, u, false)
				hint_label.text = "Атака: урон %d–%d%s" % [r2.x, r2.y, _kill_hint(r2, u)]
			else:
				hint_label.text = "Не дотянуться"
	elif u == active:
		hint_label.text = "Ваш ход: %s" % active.def["name"]
	elif u:
		hint_label.text = u.def["name"]
	elif reach.has(c):
		hint_label.text = "Идти сюда"
	else:
		hint_label.text = "Слишком далеко"
	_redraw()


func _kill_hint(r: Vector2i, u) -> String:
	var hp := int(u.def["hp"])
	var lo := 0
	var hi := 0
	if r.x >= u.total_hp():
		return " (уничтожит отряд)"
	lo = maxi(0, u.count - int(ceil(float(u.total_hp() - r.x) / hp)))
	hi = mini(u.count, u.count - int(ceil(float(maxi(1, u.total_hp() - r.y)) / hp)))
	if hi <= 0:
		return ""
	return " (убьёт %d–%d)" % [lo, hi] if lo != hi else " (убьёт %d)" % hi


func _best_from(target, mp: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := INF
	for d in DIRS:
		var n: Vector2i = target.cell + d
		if not in_grid(n):
			continue
		if n != active.cell and not (reach.has(n) and not _occupied(n)):
			continue
		var dist := mp.distance_to(cell_pos(n) - Vector2(0, 10))
		if dist < bd:
			bd = dist
			best = n
	return best


func _on_click() -> void:
	if state != "player" or active == null:
		return
	var c := hover_cell
	if c == Vector2i(-1, -1):
		return
	if hover_target:
		var ranged := _can_shoot(active)
		_act(func(): await _attack(active, hover_target, hover_from, ranged))
	elif reach.has(c) and not _occupied(c):
		_act(func(): await _move(active, c))


func _act(fn: Callable) -> void:
	state = "busy"
	hint_label.text = ""
	_update_buttons()
	_redraw()
	await fn.call()
	player_done.emit()


func _on_defend() -> void:
	if state != "player":
		return
	active.defending = true
	_log("%s занимают оборону." % active.def["name"])
	_act(func(): await get_tree().create_timer(0.2).timeout)


func _on_wait() -> void:
	if state != "player" or active.waited:
		return
	active.waited = true
	queue.push_back(active)
	_log("%s ждут." % active.def["name"])
	_act(func(): await get_tree().process_frame)


func _on_cry() -> void:
	if state != "player" or cry_used:
		return
	cry_used = true
	Sfx.play("buff")
	_log("Клич Сокола! Все ваши отряды получают +3 к атаке.")
	for u in _alive(0):
		u.atk_bonus += 3
		var tw := create_tween()
		u.sprite.modulate = Color(2.0, 1.8, 0.8)
		tw.tween_property(u.sprite, "modulate", Color(1, 1, 1), 0.8)
	_update_buttons()
	info_label.text = _unit_info(active)


func _on_auto() -> void:
	auto = not auto
	_update_buttons()
	if auto and state == "player":
		_act(func(): await _ai_turn(active))


# ---------------------------------------------------------------- AI

func _target_value(a, e, ranged: bool) -> float:
	var r := _dmg_range(a, e, ranged)
	var avg := (r.x + r.y) * 0.5
	var removed := minf(avg, float(e.total_hp()))
	var threat := float(int(e.def["dmg"][0]) + int(e.def["dmg"][1])) * 0.5 + (4.0 if e.is_ranged() else 0.0)
	var v: float = removed / float(e.def["hp"]) * threat
	if removed >= e.total_hp():
		v *= 1.5
	return v


func _ai_turn(u) -> void:
	var enemies := _alive(1 - u.side)
	if enemies.is_empty():
		return
	if _can_shoot(u):
		var best = null
		var bv := -1.0
		for e in enemies:
			var v := _target_value(u, e, true)
			if v > bv:
				bv = v
				best = e
		await _attack(u, best, u.cell, true)
		return
	var best_t = null
	var best_c := Vector2i(-1, -1)
	var best_v := -1.0
	for e in enemies:
		for d in DIRS:
			var n: Vector2i = e.cell + d
			if n != u.cell and not (reach.has(n) and not _occupied(n)):
				continue
			var v: float = _target_value(u, e, false) - (0.0 if n == u.cell else reach.get(n, 0) * 0.01)
			if v > best_v:
				best_v = v
				best_t = e
				best_c = n
	if best_t:
		await _attack(u, best_t, best_c, false)
		return
	# advance toward the closest enemy
	var goal := Vector2i(-1, -1)
	var gd := 999
	for c in reach:
		if _occupied(c) and c != u.cell:
			continue
		for e in enemies:
			var dd := cheb(c, e.cell)
			if dd < gd:
				gd = dd
				goal = c
	if goal != Vector2i(-1, -1) and goal != u.cell:
		await _move(u, goal)
	else:
		u.defending = true


# ---------------------------------------------------------------- end of battle

func _finish(win: bool) -> void:
	state = "over"
	active = null
	_redraw()
	_update_buttons()
	await get_tree().create_timer(0.8).timeout
	var lost := []
	var new_army := []
	for u in stacks:
		if u.side != 0:
			continue
		var gone: int = u.start_count - u.count
		if gone > 0:
			lost.append("%s: %d" % [u.def["name"], gone])
		Game.stats["lost"] = int(Game.stats.get("lost", 0)) + gone
		if u.count > 0:
			new_army.append({"id": u.id, "count": u.count})
	Game.stats["killed"] = int(Game.stats.get("killed", 0)) + killed_total
	Game.stats["battles"] = int(Game.stats.get("battles", 0)) + 1
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Game.label("Победа!" if win else "Поражение", 20, Color("f0d890") if win else Color("e05a4a"), 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if win:
		Sfx.play("victory")
		Game.army = new_army
		var msgs := Game.add_xp(xp_gain)
		var text := "Опыт героя: +%d\nПотери: %s" % [xp_gain, ", ".join(lost) if not lost.is_empty() else "нет"]
		for m in msgs:
			text += "\n" + m
		var l := Game.label(text, 10)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(280, 0)
		box.add_child(l)
		box.add_child(Game.button("Продолжить", func(): Game.goto("world", {"result": "win"})))
	else:
		Sfx.play("defeat")
		var l2 := Game.label("Ваше войско разбито. Кайрена уносят с поля боя.", 10)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size = Vector2(280, 0)
		box.add_child(l2)
		box.add_child(Game.button("Переиграть бой", func():
			Game.army = army_snapshot.duplicate(true)
			Game.goto("battle", {"battle": battle_id})))
		box.add_child(Game.button("Вернуться на карту", func():
			Game.army = army_snapshot.duplicate(true)
			Game.goto("world", {"result": "retreat"})))
	ui.add_child(panel)
	await get_tree().process_frame
	panel.position = (Vector2(640, 360) - panel.size) / 2.0
	if Game.autotest:
		print("BATTLE ", battle_id, " win=", win, " army=", Game.army, " xp=", xp_gain)
		await get_tree().create_timer(0.5).timeout
		if win:
			Game.goto("world", {"result": "win"})
		else:
			Game.army = army_snapshot.duplicate(true)
			Game.goto("world", {"result": "retreat"})
