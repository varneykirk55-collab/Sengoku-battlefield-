extends SceneTree
func _init():
	for f in OS.get_environment("GLBS").split(" "):
		var ps: PackedScene = load(f)
		if ps == null:
			print("FAIL ", f); continue
		var r := ps.instantiate()
		var box := AABB(); var first := true; var tris := 0
		for mi in r.find_children("*", "MeshInstance3D", true, false):
			var t: Transform3D = (mi as Node3D).global_transform if (mi as Node3D).is_inside_tree() else _xf(mi, r)
			var a: AABB = t * (mi as MeshInstance3D).mesh.get_aabb()
			var raw: AABB = (mi as MeshInstance3D).mesh.get_aabb()
			box = a if first else box.merge(a); first = false
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var arr = (mi as MeshInstance3D).mesh.surface_get_arrays(s)
				tris += (arr[Mesh.ARRAY_INDEX].size() if arr[Mesh.ARRAY_INDEX] else arr[Mesh.ARRAY_VERTEX].size())/3
			print("   mesh ", mi.name, " raw=", raw.size, " xf_scale=", t.basis.get_scale())
		print("AABB ", f.get_file(), " size=", box.size, " pos=", box.position, " tris=", tris)
		r.free()
	quit()
func _xf(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	while n != root and n != null:
		t = (n as Node3D).transform * t if n is Node3D else t
		n = n.get_parent()
	return t
