extends Node
## Fixed-angle environment screenshots for before/after comparison.
## Env vars: SHOT_OUT_DIR (required), SHOT_TAG (before|after), SHOT_WAIT (default 1.2)

const CAMERAS := [
	# Fixed cameras — identical for before/after comparison
	["01_overview_se", Vector3(165, 95, 195), Vector3(0, 8, -20)],
	["02_overview_nw", Vector3(-165, 95, -195), Vector3(0, 8, 20)],
	["03_hill_b", Vector3(-28, 22, 32), Vector3(0, 10, 0)],
	["04_camp_south", Vector3(35, 18, 155), Vector3(0, 4, 128)],
	["05_stream_valley", Vector3(-40, 14, -55), Vector3(20, 2, -75)],
	["06_midfield_lane", Vector3(-70, 16, 80), Vector3(-20, 6, 20)],
	["07_arch_objective_a", Vector3(-30, 12, 70), Vector3(-55, 3, 45)],
	["08_arch_objective_c", Vector3(80, 12, -20), Vector3(55, 3, -45)],
	["09_camp_north_gate", Vector3(-30, 14, -95), Vector3(0, 4, -128)],
	["10_grass_closeup", Vector3(-38, 2.6, 66), Vector3(-26, 0.4, 52)],
	["11_gameplay_eye", Vector3(4, 2.2, 112), Vector3(0, 6, 0)],
]

func _ready() -> void:
	var out_dir := OS.get_environment("SHOT_OUT_DIR")
	var tag := OS.get_environment("SHOT_TAG")
	if tag == "":
		tag = "shot"
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.2
	DirAccess.make_dir_recursive_absolute(out_dir)

	var field := Battlefield.new()
	field.name = "Field"
	add_child(field)
	await get_tree().process_frame
	await get_tree().process_frame

	var cam := Camera3D.new()
	cam.far = 1200.0
	cam.fov = 55.0
	add_child(cam)
	cam.current = true

	var only := OS.get_environment("SHOT_ONLY")
	for spec in CAMERAS:
		if only != "" and not (spec[0] as String) in only.split(","):
			continue
		cam.global_position = spec[1]
		cam.look_at(spec[2], Vector3.UP)
		await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s_%s.png" % [out_dir, tag, spec[0]]
		img.save_png(path)
		print("[env_capture] saved ", path, " ", img.get_size())

	print("[env_capture] done ", CAMERAS.size(), " shots")
	get_tree().quit()
