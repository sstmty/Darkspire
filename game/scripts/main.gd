extends Node
## Root node: swaps screens with a fade.

const SCREENS := {
	"menu": preload("res://scripts/screens/menu.gd"),
	"intro": preload("res://scripts/screens/intro.gd"),
	"world": preload("res://scripts/screens/world.gd"),
	"battle": preload("res://scripts/screens/battle.gd"),
	"ending": preload("res://scripts/screens/ending.gd"),
}

var current: Node
var fade: ColorRect
var _busy := false


func _ready() -> void:
	Game.main = self
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	fade = ColorRect.new()
	fade.color = Color(0.03, 0.02, 0.04, 1)
	fade.size = Vector2(640, 360)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "--autotest":
		_autotest()
		return
	if args.size() >= 1 and args[0] == "--shot":
		# Developer mode used for automated screenshots: --shot <screen> <file>
		_screenshot_mode(args)
		return
	change_screen("menu")


func change_screen(name: String, params: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	await tw.finished
	if current:
		current.queue_free()
		await get_tree().process_frame
	current = SCREENS[name].new()
	add_child(current)
	if current.has_method("setup"):
		current.setup(params)
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.35)
	await tw2.finished
	_busy = false


func _screenshot_mode(args: PackedStringArray) -> void:
	var screen := args[1]
	var file := args[2]
	Game.new_game()
	var params := {}
	if screen == "battle":
		params = {"battle": args[3] if args.size() > 3 else "village", "auto": true}
	elif screen == "world" and args.size() > 3:
		Game.hero_pos = Vector2i(int(args[3]), int(args[4]))
		Game.flags["start_done"] = true
	fade.color.a = 0.0
	current = SCREENS[screen].new()
	add_child(current)
	if current.has_method("setup"):
		current.setup(params)
	var wait := float(args[5]) if args.size() > 5 else 2.0
	if screen == "battle" and args.size() > 4:
		wait = float(args[4])
	await get_tree().create_timer(wait).timeout
	if screen == "world" and args.size() > 6:
		current._dialog(Data.DIALOGS[args[6]])
		await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(file)
	get_tree().quit()


## Self-play: walks the hero through every event of chapter I and logs the outcome.
func _autotest() -> void:
	Game.autotest = true
	Engine.time_scale = 6.0
	Game.new_game()
	change_screen("world")
	var order := ["g", "1", "g", "2", "R", "g", "g", "3", "c", "5", "c", "S", "4", "6", "g", "c", "g", "g", "c", "R", "7"]
	var steps := 0
	while steps < 600:
		steps += 1
		await get_tree().create_timer(0.5).timeout
		if _busy or current == null or not current.has_method("_go") or current.busy:
			continue
		if Game.flags.get("chapter1_done", false):
			break
		var target := Vector2i(-1, -1)
		while not order.is_empty():
			target = _next_target(current, order[0])
			if target != Vector2i(-1, -1):
				break
			order.pop_front()
		if order.is_empty():
			continue
		var key: String = order.pop_front()
		print("GO ", key, " ", target, " gold=", Game.gold, " lvl=", Game.hero["level"])
		await current._go(target)
	print("AUTOTEST DONE chapter_done=", Game.flags.get("chapter1_done", false), " stats=", Game.stats, " army=", Game.army)
	get_tree().quit()


func _next_target(w, key: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for y in w.H:
		for x in w.W:
			var p := Vector2i(x, y)
			if w.ch(p) != key:
				continue
			if key != "R" and key != "S" and Game.is_cleared(p):
				continue
			var d := (p - Game.hero_pos).length_squared()
			if d < bd:
				bd = d
				best = p
	return best
