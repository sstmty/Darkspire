extends RefCounted
## Layouts of the 3D levels. Everything is placed by distance along the road ("s", metres)
## and sideways offset from it ("x", metres, + is the right-hand side when walking the road).

const MAPS := {
	"hollowd": {
		"theme": "hollowd",
		"road": [Vector2(0, 10), Vector2(0, -30), Vector2(12, -70), Vector2(8, -110), Vector2(-10, -150), Vector2(-4, -190), Vector2(0, -222)],
		"width": 9.0,
		"start": [4.0, 0.0],
		"horse": [9.0, 4.0],
		"coals": [[70.0, 4.5], [168.0, -4.5]],
		"enemies": [
			["ashghoul", 38, 2], ["ashghoul", 46, -3], ["ashghoul", 58, 4],
			["ashghoul", 92, -2], ["ashghoul", 98, 3], ["ashghoul", 112, 0], ["ashghoul", 126, -4],
			["ashghoul", 140, 2], ["ashghoul", 150, -2], ["ashghoul", 156, 4],
		],
		"triggers": [[30.0, "hollowd_ghouls"], [64.0, "hollowd_coal"], [175.0, "hollowd_arena"]],
		"arena": [205.0, 15.0],
		"exit": 228.0,
		"boss": "shepherd",
		"props": [
			["house_burnt", 16, -9], ["house", 20, 10], ["fence", 26, 6], ["tree", 30, -7], ["house_burnt", 44, 10],
			["house_burnt", 52, -10], ["cart", 60, -5], ["grave", 66, 7], ["house", 82, -10], ["house_burnt", 88, 10],
			["tree", 96, -8], ["fence", 104, 6], ["house_burnt", 118, -9], ["well", 122, 5], ["house_burnt", 132, 10],
			["tree", 138, -7], ["fence", 146, -6], ["house_burnt", 158, 9], ["tree", 162, -8], ["banner", 180, 4],
			["banner", 180, -4], ["grave", 196, 9], ["grave", 199, -10], ["grave", 212, 11], ["grave", 214, -9], ["tree", 220, 12],
		],
		"scatter": ["tree", "rock", "grave", "stump"],
	},
	"border": {
		"theme": "border",
		"road": [Vector2(0, 10), Vector2(0, -40), Vector2(-14, -80), Vector2(-6, -120), Vector2(8, -150), Vector2(8, -175), Vector2(8, -245), Vector2(8, -270)],
		"width": 8.0,
		"start": [4.0, 0.0],
		"horse": [10.0, 4.0],
		"coals": [[78.0, 4.5], [150.0, -4.5]],
		"enemies": [
			["rustguard", 34, 0], ["ashghoul", 50, -3], ["ashghoul", 56, 3],
			["rustguard", 96, 2], ["ashghoul", 104, -3], ["ashghoul", 110, 3], ["rustguard", 128, -1],
			["rustguard", 170, 0],
		],
		"triggers": [[22.0, "border_guards"], [66.0, "border_ring"], [156.0, "border_bridge"]],
		"chasm": [162.0, 232.0],
		"arena": [205.0, 9.0],
		"exit": 262.0,
		"boss": "draven",
		"props": [
			["tower", 18, -10], ["tree", 26, 8], ["rock", 30, -7], ["banner", 44, 5], ["tree", 62, -8], ["rock", 70, 8],
			["tower", 88, 11], ["cart", 92, -5], ["tree", 118, 8], ["banner", 136, -5], ["rock", 142, 7], ["banner", 158, 5],
			["banner", 158, -5], ["banner", 240, 5], ["banner", 240, -5], ["tower", 250, -10],
		],
		"scatter": ["tree", "rock", "rock", "stump"],
	},
}
