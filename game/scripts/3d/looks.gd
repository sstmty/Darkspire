extends RefCounted
## How each character of the story bible looks in 3D (see rig.gd for the keys).

const LOOKS := {
	"said": {
		"skin": Color("c69a7a"), "torso": Color("3b2f2a"), "arm": Color("35302e"), "legs": Color("2b2826"),
		"boots": Color("1f1a18"), "cloak": Color("3d3f48"), "hood": Color("3a3c44"), "hair": Color("1e1a18"),
		"beard": Color("2a2220"), "ember": true, "weapon": "sword", "eye": Color("2a2420"),
	},
	"nayra": {
		"skin": Color("e2b89a"), "torso": Color("2f6f6a"), "arm": Color("2a5e5a"), "legs": Color("24403e"),
		"boots": Color("3a2a22"), "robe": Color("2f6f6a"), "hair": Color("b8432f"), "long_hair": true,
		"belt": Color("6a4a2a"), "weapon": "none", "thread": true, "eye": Color("3a6a5a"), "bulk": 0.88,
		"cloak": Color("23403e"), "cloak_len": 0.7, "pouch": false, "scale": 0.94,
	},
	"kassian": {
		"skin": Color("b88a6a"), "torso": Color("3a3a42"), "cloak": Color("55565e"), "hair": Color("a8a8a8"),
		"beard": Color("b0b0b0"), "weapon": "sword",
	},
	"ashghoul": {
		"skin": Color("4f4a48"), "torso": Color("2e2a28"), "arm": Color("4f4a48"), "legs": Color("3a3532"),
		"boots": Color("5a5550"), "ghoul": true, "bare_hands": true, "weapon": "none", "eye": Color("e8f0ff"),
		"eye_glow": Color("c8d8ff"), "hunch": 0.55, "bulk": 0.82, "pouch": false, "cloak": Color("2e2a28"), "cloak_len": 0.55,
	},
	"rustguard": {
		"skin": Color("8a7060"), "torso": Color("4a3a30"), "arm": Color("4a4c50"), "legs": Color("3a3634"),
		"boots": Color("2a2624"), "armor": Color("6b6d72"), "rust": true, "helm": Color("6b6d72"),
		"weapon": "axe", "eye": Color("ff8a3a"), "eye_glow": Color("ff7a2a"), "bulk": 1.25, "scale": 1.12, "hunch": 0.12,
	},
	"shepherd": {
		"skin": Color("d8d0c0"), "torso": Color("2b2e3a"), "arm": Color("2b2e3a"), "legs": Color("22242e"),
		"robe": Color("262834"), "hood": Color("1e2029"), "skull": true, "weapon": "staff", "eye": Color("9aff6a"),
		"eye_glow": Color("9aff6a"), "cloak": Color("1a1c24"), "cloak_len": 1.15, "scale": 1.45, "bulk": 1.1, "hunch": 0.2,
		"bare_hands": true,
	},
	"draven": {
		"skin": Color("8a7060"), "torso": Color("3a3030"), "arm": Color("44464c"), "legs": Color("2e2c2c"),
		"boots": Color("24201e"), "armor": Color("55585e"), "rust": true, "helm": Color("55585e"), "plume": Color("6a1f1a"),
		"weapon": "greatsword", "eye": Color("ff4a2a"), "eye_glow": Color("ff4a2a"), "cloak": Color("5a1c18"),
		"cloak_len": 1.1, "scale": 1.35, "bulk": 1.25,
	},
}
