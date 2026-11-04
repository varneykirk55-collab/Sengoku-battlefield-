class_name CapturePoint
extends Area3D
## One conquest objective (A, B or C): a ring on the ground, a tall flag in the owner's colour
## and its letter. Soldiers inside the radius capture it (rules in M5).

signal owner_changed(point: CapturePoint, new_owner: int, old_owner: int)

const NEUTRAL := -1
const NEUTRAL_COLOR := Color(0.92, 0.9, 0.84)

@export var objective_id: StringName = &"A"
@export var radius := 12.0

## -1 neutral, otherwise the owning faction.
var owner_faction := NEUTRAL
## -1..1: negative = faction 1 progress, positive = faction 0 progress (M5).
var progress := 0.0
var contested := false

var _flag_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _label: Label3D
var _flag: MeshInstance3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Soldier.LAYER_SOLDIERS
	monitorable = false
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 8.0
	cs.shape = shape
	cs.position = Vector3(0, 2.0, 0)
	add_child(cs)
	add_to_group("capture_points")
	_build_visuals()
	_refresh_colors()


func set_owner_faction(f: int) -> void:
	if f == owner_faction:
		return
	var old := owner_faction
	owner_faction = f
	_refresh_colors()
	owner_changed.emit(self, f, old)


func color() -> Color:
	return NEUTRAL_COLOR if owner_faction == NEUTRAL else UIStyle.FACTION_COLORS[owner_faction]


## Soldiers currently standing in the point, per faction: [count_0, count_1].
func soldiers_inside() -> Array[int]:
	var counts: Array[int] = [0, 0]
	for b in get_overlapping_bodies():
		var s := b as Soldier
		if s and s.alive and s.faction >= 0 and s.faction < 2:
			counts[s.faction] += 1
	return counts


func _build_visuals() -> void:
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.25
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _ring_mat
	ring.scale = Vector3(1, 0.15, 1)
	ring.position.y = 0.35
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.06
	pm.bottom_radius = 0.09
	pm.height = 9.0
	pole.mesh = pm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.25, 0.17, 0.1)
	pole.material_override = wood
	pole.position.y = 4.5
	add_child(pole)
	_flag_mat = StandardMaterial3D.new()
	_flag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flag = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.4, 3.6, 0.04)
	_flag.mesh = fm
	_flag.material_override = _flag_mat
	_flag.position = Vector3(0.75, 6.9, 0)
	add_child(_flag)
	_label = Label3D.new()
	_label.text = String(objective_id)
	_label.font_size = 160
	_label.outline_size = 24
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 10.4
	_label.pixel_size = 0.01
	add_child(_label)


func _refresh_colors() -> void:
	var c := color()
	_flag_mat.albedo_color = c
	_ring_mat.albedo_color = Color(c, 0.75)
	_label.modulate = c
