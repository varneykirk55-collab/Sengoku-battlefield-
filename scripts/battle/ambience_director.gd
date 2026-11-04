class_name AmbienceDirector
extends Node
## Environmental sound for the battlefield: wind and field beds, birds calling from the treeline,
## occasional gusts — plus, when armies are fighting, two battle beds driven by combat intensity:
##   battle_distant_loop  fighting far from the listener (rolling volleys, roar)
##   battle_crowd_loop    fighting close to the listener (shouting soldiers)
## Every Events.combat_noise adds to near or far intensity, which decays over a few seconds.

const NEAR_RADIUS := 45.0
## Bed volume range (dB): silent-ish at no intensity, loud in a big melee.
const DISTANT_DB := Vector2(-24.0, -3.0)
const CROWD_DB := Vector2(-34.0, -6.0)

var battle_beds := false
var beds: Array[Node] = []
var distant_bed: Node
var crowd_bed: Node
## Smoothed intensities (roughly "loud events per second").
var near_intensity := 0.0
var far_intensity := 0.0
var _next_bird := 3.0
var _next_gust := 8.0


func _ready() -> void:
	beds.append(AudioManager.start_loop(&"amb_wind_loop", null, -6.0, 3.0))
	beds.append(AudioManager.start_loop(&"amb_field_loop", null, -2.0, 3.0))
	if battle_beds:
		distant_bed = AudioManager.start_loop(&"battle_distant_loop", null, DISTANT_DB.x, 4.0)
		crowd_bed = AudioManager.start_loop(&"battle_crowd_loop", null, CROWD_DB.x, 4.0)
		beds.append(distant_bed)
		beds.append(crowd_bed)
		Events.combat_noise.connect(_on_combat_noise)


func _on_combat_noise(pos: Vector3, loudness: float) -> void:
	if AudioManager.listener_position().distance_to(pos) < NEAR_RADIUS:
		near_intensity += loudness
	else:
		far_intensity += loudness


func _update_battle_beds(delta: float) -> void:
	near_intensity *= exp(-delta / 4.0)
	far_intensity *= exp(-delta / 6.0)
	var far_t := clampf(far_intensity / 12.0, 0.0, 1.0)
	var near_t := clampf(near_intensity / 8.0, 0.0, 1.0)
	_set_bed(distant_bed, lerpf(DISTANT_DB.x, DISTANT_DB.y, sqrt(far_t)))
	_set_bed(crowd_bed, lerpf(CROWD_DB.x, CROWD_DB.y, sqrt(near_t)))


func _set_bed(bed: Variant, db: float) -> void:
	if not is_instance_valid(bed):
		return
	var tw: Variant = bed.get_meta("fade_tween", null)
	if tw is Tween and (tw as Tween).is_valid() and (tw as Tween).is_running():
		return  # still fading in
	bed.set("volume_db", lerpf(float(bed.get("volume_db")), db, 0.05))


func _process(delta: float) -> void:
	if battle_beds:
		_update_battle_beds(delta)
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = randf_range(3.0, 9.0)
		# Somewhere in the trees around the listener.
		var a := randf() * TAU
		var p := AudioManager.listener_position() + Vector3(cos(a), 0.0, sin(a)) * randf_range(25.0, 60.0) + Vector3(0, 8, 0)
		AudioManager.play(&"amb_bird", p, -4.0)
	_next_gust -= delta
	if _next_gust <= 0.0:
		_next_gust = randf_range(12.0, 25.0)
		AudioManager.play(&"amb_gust", null, -3.0)


func _exit_tree() -> void:
	for b in beds:
		AudioManager.stop_loop(b, 0.0)
