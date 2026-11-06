extends Node
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	print("[probe] start")
	var field := Battlefield.new()
	field.load_navigation = false
	add_child(field)
	print("[probe] %dms children=%d pine_surf=%s" % [
		Time.get_ticks_msec()-t0, field.get_child_count(),
		str(field._pine_mesh.get_surface_count() if field._pine_mesh else -1)])
	get_tree().quit(0)
