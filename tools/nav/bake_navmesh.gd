extends Node
## Bakes the battlefield's navigation mesh and saves it to Battlefield.NAV_PATH.
## Run with tools/bake_navmesh.sh whenever the map layout changes.

func _ready() -> void:
	var field := Battlefield.new()
	field.load_navigation = false
	add_child(field)
	await get_tree().physics_frame
	var t := Time.get_ticks_msec()
	var nm := Battlefield.make_navigation_mesh()
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, field)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	var err := ResourceSaver.save(nm, Battlefield.NAV_PATH, ResourceSaver.FLAG_COMPRESS)
	print("[navbake] polygons=%d vertices=%d time=%dms save=%s -> %s" % [nm.get_polygon_count(), nm.get_vertices().size(),
		Time.get_ticks_msec() - t, error_string(err), Battlefield.NAV_PATH])
	AudioManager.quit_game(0 if err == OK and nm.get_polygon_count() > 0 else 1)
