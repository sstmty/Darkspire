extends Node
## Root node: swaps screens with a fade.

const SCREENS := {
	"menu": preload("res://scripts/screens/menu.gd"),
	"intro": preload("res://scripts/screens/intro.gd"),
	"level": preload("res://scripts/screens/level3d.gd"),
	"ending": preload("res://scripts/screens/ending.gd"),
	"preview3d": preload("res://scripts/screens/preview3d.gd"),
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
	while _busy:
		await get_tree().process_frame
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


## Developer screenshots: --shot <screen> <file> [level] [column] [wait] [extra]
## extra: "nayra" (she has joined), "boss" (walk into the arena), or a dialog key.
func _screenshot_mode(args: PackedStringArray) -> void:
	var screen := args[1]
	var file := args[2]
	Game.new_game()
	var extra := args[6] if args.size() > 6 else ""
	var params := {}
	if screen == "preview3d":
		params["pose"] = args[3]
	if screen == "level":
		params["level"] = args[3]
		for k in Data.DIALOGS:
			Game.flags["seen_" + k] = true
		if extra != "" and extra != "solo":
			Game.flags["nayra"] = true
			Game.flags["shepherd_met"] = extra == "boss"
	fade.color.a = 0.0
	current = SCREENS[screen].new()
	add_child(current)
	if current.has_method("setup"):
		current.setup(params)
	if screen == "level" and args.size() > 4:
		var w: Node = current.world
		var sd := float(args[4])
		current.player.global_position = w.point_at(sd, 0.0) + Vector3(0, 0.2, 0)
		current.player.yaw = w.yaw_along(sd)
		current.cam.yaw = current.player.yaw
		if current.nayra:
			current.nayra.global_position = w.point_at(sd - 1.5, -1.0) + Vector3(0, 0.2, 0)
		current.horse.global_position = w.point_at(sd + 1.0, 2.5) + Vector3(0, 0.2, 0)
		current.horse.yaw = current.player.yaw
		if extra in ["top", "first"]:
			current.cam.set_mode(extra)
		if extra == "ride":
			current.player.mount(current.horse)
		current.cam.snap()
	var wait := float(args[5]) if args.size() > 5 else 2.0
	await get_tree().create_timer(wait).timeout
	if screen == "level" and Data.DIALOGS.has(extra):
		current.talk(extra)
		await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(file)
	get_tree().quit()


## Self-play: the bot walks through the prologue and chapter 1 and logs what happens.
func _autotest() -> void:
	Game.autotest = true
	Game.new_game()
	change_screen("level")
	var t := 0
	while t < 1800:
		await get_tree().create_timer(1.0).timeout
		t += 1
		if Game.flags.get("chapter1_done", false):
			break
		if t % 15 == 0 and current != null and current.get("player") != null:
			var p: Node = current.player
			print("T%d %s x=%d hp=%d flasks=%d boss=%s" % [t, Game.level, int(p.position.x), int(p.hp), Game.flasks, current.boss_active])
	print("AUTOTEST DONE chapter1_done=", Game.flags.get("chapter1_done", false), " t=", t, " stats=", Game.stats, " lost=", Game.lost)
	get_tree().quit()
