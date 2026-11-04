extends Node
## Screenshot helper for cloud QA (software rendering, so it shows layout, not final GPU looks).
##   SHOT_SCENE=res://scenes/main_menu.tscn SHOT_OUT=/tmp/menu.png SHOT_WAIT=1.5 \
##     tools/screenshot.sh
## Optional SHOT_SETUP: name of a method on the loaded scene's root to call before waiting.

func _ready() -> void:
	var scene_path := OS.get_environment("SHOT_SCENE")
	var out := OS.get_environment("SHOT_OUT")
	var wait := float(OS.get_environment("SHOT_WAIT")) if OS.get_environment("SHOT_WAIT") != "" else 1.0
	var inst: Node = load(scene_path).instantiate()
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var setup := OS.get_environment("SHOT_SETUP")
	if setup != "" and inst.has_method(setup):
		await inst.call(setup)
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("[capture] saved ", out, " ", img.get_size())
	AudioManager.quit_game()
