extends RefCounted
## Sky, fog and light for the two regions of the prologue and chapter 1.

const THEMES := {
	"hollowd": {
		"sky_top": Color("1a0c10"), "sky_horizon": Color("6e3a30"), "ground": Color("241a18"),
		"fog": Color("2e2226"), "fog_density": 0.006, "sun": Color("f0c8b0"), "sun_energy": 1.2,
		"sun_rot": Vector3(-0.55, 0.6, 0), "ambient": Color("50485a"), "ambient_energy": 0.55,
	},
	"border": {
		"sky_top": Color("10141c"), "sky_horizon": Color("5a6474"), "ground": Color("1a1c20"),
		"fog": Color("3a4250"), "fog_density": 0.008, "sun": Color("d0dcff"), "sun_energy": 1.1,
		"sun_rot": Vector3(-0.65, -0.5, 0), "ambient": Color("4a5060"), "ambient_energy": 0.55,
	},
}


static func build(parent: Node, theme: String, shadows: bool) -> DirectionalLight3D:
	var t: Dictionary = THEMES[theme]
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = t["sky_top"]
	sky_mat.sky_horizon_color = t["sky_horizon"]
	sky_mat.ground_bottom_color = t["ground"]
	sky_mat.ground_horizon_color = t["sky_horizon"].darkened(0.3)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = t["ambient"]
	env.ambient_light_energy = t["ambient_energy"]
	env.fog_enabled = true
	env.fog_light_color = t["fog"]
	env.fog_density = t["fog_density"]
	env.fog_sky_affect = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = t["sun"]
	sun.light_energy = t["sun_energy"]
	sun.rotation = t["sun_rot"]
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 60.0
	parent.add_child(sun)
	return sun
