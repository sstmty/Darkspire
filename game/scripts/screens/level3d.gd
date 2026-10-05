extends Node
## A 3D level: the world, the hunter, his horse, Нэйра, enemies, story triggers, Угли Памяти, the boss, death and rest.
## The world renders into a SubViewport so the optional pixel look can shrink it without touching the UI.

const WORLD := preload("res://scripts/3d/world_builder.gd")
const ENV := preload("res://scripts/3d/env.gd")
const PLAYER := preload("res://scripts/3d/player3d.gd")
const ENEMY := preload("res://scripts/3d/enemy3d.gd")
const BOSS := preload("res://scripts/3d/boss3d.gd")
const NAYRA := preload("res://scripts/3d/nayra3d.gd")
const HORSE := preload("res://scripts/3d/horse.gd")
const CAMERA := preload("res://scripts/3d/camera_rig.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const DIALOG := preload("res://scripts/ui/dialog.gd")
const WIN := {"shepherd": "shepherd_win", "draven": "draven_win"}

var id := ""
var info: Dictionary
var map: Dictionary
var sv: SubViewport
var view: TextureRect
var world: Node3D
var sun: DirectionalLight3D
var player: Node
var nayra: Node
var horse: Node
var boss: Node
var cam: Node3D
var enemies: Array = []
var hud: Node
var ui: CanvasLayer
var thread: MeshInstance3D
var ash: CPUParticles3D
var busy := false
var boss_active := false
var death_y := -12.0
var _done_triggers := {}
var _dying := false
var _leaving := false


func setup(params: Dictionary) -> void:
	id = params.get("level", Game.level)
	Game.level = id
	info = Data.LEVELS[id]
	if id == "border":
		Game.flags["nayra"] = true

	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	view = TextureRect.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(view)
	sv = SubViewport.new()
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_2X
	add_child(sv)
	view.texture = sv.get_texture()

	world = WORLD.new()
	sv.add_child(world)
	world.setup_map(id)
	map = world.map
	sun = ENV.build(world, map["theme"], Settings.shadows)
	world.build_world()

	player = PLAYER.new()
	player.level = self
	player.collision_mask = 1 | 4
	var spawn: Vector3
	if Game.checkpoint >= 0 and Game.checkpoint < map["coals"].size():
		var c: Array = map["coals"][Game.checkpoint]
		spawn = world.point_at(c[0] + 2.0, 0.0)
	else:
		spawn = world.point_at(map["start"][0], map["start"][1])
	player.position = spawn + Vector3(0, 0.3, 0)
	player.yaw = world.yaw_along(world.project(Vector2(spawn.x, spawn.z)).x)
	world.add_child(player)

	horse = HORSE.new()
	horse.level = self
	var hp_: Vector3 = world.point_at(map["horse"][0], map["horse"][1])
	if Game.checkpoint >= 0:
		hp_ = spawn + Vector3(2.5, 0, 0)
	horse.position = hp_ + Vector3(0, 0.3, 0)
	horse.yaw = player.yaw + 0.6
	world.add_child(horse)

	if Game.flags.get("nayra", false):
		nayra = NAYRA.new()
		nayra.level = self
		nayra.position = spawn - player.forward() * 1.5 + Vector3(0, 0.3, 0)
		nayra.yaw = player.yaw
		world.add_child(nayra)
		thread = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.008
		cm.bottom_radius = 0.008
		cm.height = 1.0
		cm.radial_segments = 4
		thread.mesh = cm
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.albedo_color = Color(0.45, 0.8, 1.0, 0.5)
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		thread.material_override = tm
		thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(thread)

	for e in map["enemies"]:
		spawn_enemy(e[0], world.point_at(float(e[1]), float(e[2])) + Vector3(0, 0.3, 0))

	cam = CAMERA.new()
	cam.target = player
	cam.yaw = player.yaw
	world.add_child(cam)
	cam.snap.call_deferred()
	_add_ash()

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	Settings.changed.connect(_apply_settings)
	get_viewport().size_changed.connect(_resize)
	_resize()
	Sfx.music("world")
	_begin()


func _exit_tree() -> void:
	if Settings.changed.is_connected(_apply_settings):
		Settings.changed.disconnect(_apply_settings)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _apply_settings() -> void:
	cam.apply_settings()
	sun.shadow_enabled = Settings.shadows
	_resize()


func _resize() -> void:
	var ws := Vector2(DisplayServer.window_get_size())
	if ws.x < 10.0:
		ws = Vector2(1280, 720)
	var px: int = maxi(1, Settings.pixel)
	sv.size = Vector2i(maxi(160, int(ws.x / px)), maxi(90, int(ws.y / px)))
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if px > 1 else CanvasItem.TEXTURE_FILTER_LINEAR


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


func _add_ash() -> void:
	ash = CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	q.material = world.part_mat(Color.WHITE, false)
	ash.mesh = q
	ash.amount = 300
	ash.lifetime = 6.0
	ash.preprocess = 6.0
	ash.local_coords = false
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(18, 1, 18)
	ash.direction = Vector3(0.3, -1, 0.1)
	ash.spread = 20
	ash.gravity = Vector3(0, -0.3, 0)
	ash.initial_velocity_min = 0.6
	ash.initial_velocity_max = 1.4
	ash.color = Color(0.75, 0.68, 0.65, 0.7) if map["theme"] == "hollowd" else Color(0.85, 0.88, 0.95, 0.7)
	world.add_child(ash)


# ---------------------------------------------------------------- actors

func spawn_enemy(kind: String, pos: Vector3) -> Node:
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
	return not map.has("boss") or Game.flags.get("boss_" + map["boss"], false)


func arena_center() -> Vector3:
	var c: Vector3 = world.point_at(map["arena"][0], 0.0)
	if world.in_chasm(map["arena"][0]):
		c.y = 0.0
	return c


# ---------------------------------------------------------------- per frame

func _process(_dt: float) -> void:
	if player == null:
		return
	var playing: bool = not busy and not get_tree().paused and player.alive() and not Game.autotest
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	ash.global_position = player.global_position + Vector3(0, 9, 0)
	if thread != null and nayra != null:
		var a: Vector3 = player.center()
		var b: Vector3 = nayra.center()
		var d := a.distance_to(b)
		thread.visible = d > 0.3 and d < 20.0
		if thread.visible:
			thread.global_position = (a + b) / 2.0
			thread.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
			thread.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			thread.scale = Vector3(1, d, 1)
	if busy or _leaving or not player.alive():
		hud.show_prompt("")
		return
	var s: float = world.project(Vector2(player.global_position.x, player.global_position.z)).x
	for t in map["triggers"]:
		var key: String = t[1]
		if s >= float(t[0]) and not _done_triggers.has(key):
			_done_triggers[key] = true
			if not Game.flags.get("seen_" + key, false):
				Game.flags["seen_" + key] = true
				talk(key)
				return
	var prompt := ""
	var near := -1
	for i in world.coal_nodes.size():
		if player.global_position.distance_to(world.coal_nodes[i].global_position) < 2.8:
			near = i
	if near >= 0 and not boss_active and player.riding == null:
		prompt = "%s: отдохнуть у Угля Памяти" % Settings.key_of("interact")
		if (player.bot and Game.checkpoint < near):
			rest(near)
			return
	elif player.riding != null:
		prompt = "%s: спешиться" % Settings.key_of("interact")
	elif horse != null and player.global_position.distance_to(horse.global_position) < 3.0 and not boss_active:
		prompt = "%s: сесть на лошадь" % Settings.key_of("interact")
	hud.show_prompt(prompt)
	if map.has("arena") and not boss_active and not boss_done():
		var c := arena_center()
		if Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length() < float(map["arena"][1]) - 2.5:
			start_boss()
	if s >= float(map["exit"]) and boss_done():
		leave()


func _unhandled_input(event: InputEvent) -> void:
	if busy or player == null or not player.alive() or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam.look(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom(1)
	if event.is_action_pressed("camera"):
		cam.cycle()
	elif event.is_action_pressed("lock"):
		_toggle_lock()
	elif event.is_action_pressed("interact"):
		_interact()


func _toggle_lock() -> void:
	if player.lock_target != null:
		player.lock_target = null
		cam.lock = null
		return
	var best: Node = null
	var bd := 22.0
	for e in targets():
		var d: float = player.global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	player.lock_target = best
	cam.lock = best


func _interact() -> void:
	for i in world.coal_nodes.size():
		if player.riding == null and not boss_active and player.global_position.distance_to(world.coal_nodes[i].global_position) < 2.8:
			rest(i)
			return
	if player.riding != null:
		player.dismount()
	elif horse != null and not boss_active and player.global_position.distance_to(horse.global_position) < 3.0 and player.state == "move":
		player.mount(horse)


func talk(key: String) -> void:
	busy = true
	var d := DIALOG.new()
	ui.add_child(d)
	var lines: Array = Data.DIALOGS[key].duplicate(true)
	for l in lines:
		if l[0] == "none" and str(l[1]).begins_with("A/D"):
			l[1] = controls_text()
	await d.play(lines)
	d.queue_free()
	busy = false
	player.input_lock = 0.2


func controls_text() -> String:
	var k := func(a): return Settings.key_of(a)
	return "%s%s%s%s: идти, %s: бег, %s: прыжок, %s: удар, %s: перекат, %s: настойка, %s: Угль и лошадь, %s: захват цели, %s и колесо мыши: камера, %s: Память, F11: полный экран." % [
		k.call("up"), k.call("left"), k.call("down"), k.call("right"), k.call("sprint"), k.call("jump"), k.call("attack"),
		k.call("roll"), k.call("heal"), k.call("interact"), k.call("lock"), k.call("camera"), k.call("memory")]


func rest(i: int) -> void:
	busy = true
	Sfx.play("buff", 0.8)
	burst(world.coal_nodes[i].global_position + Vector3(0, 1, 0), Color(0.5, 0.8, 1.0), 40)
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
	if player.riding != null:
		player.dismount()
	world.set_arena(true)
	boss = BOSS.new()
	boss.setup(map["boss"], self)
	boss.scripted = id == "hollowd" and not Game.flags.get("shepherd_met", false)
	var c := arena_center()
	var f := Vector3(c.x - player.global_position.x, 0, c.z - player.global_position.z).normalized()
	boss.position = c + f * float(map["arena"][1]) * 0.45 + Vector3(0, 0.5, 0)
	boss.yaw = atan2(f.x, f.z)
	world.add_child(boss)
	burst(boss.center(), Color(0.25, 0.22, 0.26), 50)
	boss.intro()
	hud.set_boss(boss)
	Sfx.music("battle")


func on_boss_dead() -> void:
	Game.flags["boss_" + boss.kind] = true
	world.set_arena(false)
	player.lock_target = null
	cam.lock = null
	Sfx.music("")
	Sfx.play("victory")
	await get_tree().create_timer(1.5).timeout
	hud.set_boss(null)
	hud.show_banner("Враг повержен")
	boss_active = false
	await get_tree().create_timer(2.5).timeout
	Game.checkpoint = map["coals"].size() - 1
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
	var s: float = world.project(Vector2(player.global_position.x, player.global_position.z)).x
	print("DEATH level=", id, " s=", int(s), " boss_hp=", int(boss.hp) if boss != null else -1, " scripted=", scripted, " forgot=", memory)
	Sfx.music("")
	Sfx.play("defeat")
	await get_tree().create_timer(1.6).timeout
	await hud.show_death(memory)
	Game.flasks = Game.flask_max
	if scripted:
		Game.flags["shepherd_met"] = true
		Game.flags["nayra"] = true
		Game.flags["pending_dialog"] = "shepherd_first_death"
		Game.checkpoint = map["coals"].size() - 1
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
	cam.shake = maxf(cam.shake, amount)


func flash(c: Color) -> void:
	hud.flash(c)


func burst(pos: Vector3, color: Color, n: int) -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	q.material = world.part_mat(Color.WHITE, false)
	p.mesh = q
	p.position = pos
	p.amount = n
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180
	p.gravity = Vector3(0, -9, 0)
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	world.add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## A flash of the oath-thread between two people (or Нэйра and her target).
func bind_flash(a: Node3D, b: Node3D) -> void:
	var from: Vector3 = a.center()
	var to: Vector3 = b.center()
	var n := 12
	for k in n:
		burst(from.lerp(to, float(k) / n), Color(0.5, 0.85, 1.0), 2)
