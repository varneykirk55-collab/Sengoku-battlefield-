class_name AmbienceDirector
extends Node
## Environmental sound for the battlefield: wind and field beds, birds calling from the treeline,
## occasional gusts. From M4 it also drives the distant-battle and crowd beds from combat
## intensity (Events.combat_noise).

var beds: Array[Node] = []
var _next_bird := 3.0
var _next_gust := 8.0


func _ready() -> void:
	beds.append(AudioManager.start_loop(&"amb_wind_loop", null, -6.0, 3.0))
	beds.append(AudioManager.start_loop(&"amb_field_loop", null, -2.0, 3.0))


func _process(delta: float) -> void:
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
