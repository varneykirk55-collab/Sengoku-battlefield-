class_name Battle
extends Node3D
## The match scene: builds the battlefield, spawns soldiers, runs respawns, and hosts the HUD,
## pause menu, music and ambience. Later milestones add the AI armies (M4) and conquest (M5).

signal player_spawned(soldier: Soldier)

const SOLDIER_SCENE := preload("res://scenes/soldier.tscn")

@export var player_faction := 0
@export var respawn_delay := 5.0

var field: Node3D
var player: Soldier
var hud: HUD
var pause_menu: PauseMenu
var soldiers: Array[Soldier] = []
var ambience: Array[Node] = []


func _ready() -> void:
	field = _build_field()
	add_child(field)
	hud = HUD.new()
	add_child(hud)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.quit_to_menu.connect(_quit_to_menu)
	player = spawn_soldier(player_faction, true)
	hud.bind_player(player)
	player.died.connect(_on_player_died)
	_start_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player_spawned.emit(player)


## Builds the map. M1 uses a simple test ground; M3 replaces it with the battlefield.
func _build_field() -> Node3D:
	var ground := PrototypeGround.new()
	ground.name = "Field"
	return ground


func spawn_soldier(faction: int, as_player: bool = false) -> Soldier:
	var s: Soldier = SOLDIER_SCENE.instantiate()
	s.faction = faction
	s.name = ("Player" if as_player else "Soldier_%d_%d" % [faction, soldiers.size()])
	var xform := spawn_transform(faction)
	s.look_yaw = xform.basis.get_euler().y
	add_child(s)
	s.global_position = xform.origin
	if as_player:
		var pc := PlayerController.new()
		pc.name = "PlayerController"
		s.add_child(pc)
	soldiers.append(s)
	Events.soldier_spawned.emit(s)
	return s


## A spawn point for a faction, with a little scatter so soldiers don't stack.
func spawn_transform(faction: int) -> Transform3D:
	var points := get_tree().get_nodes_in_group("spawn_%d" % faction)
	if points.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	var p: Node3D = points[randi() % points.size()]
	var offset := Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
	return Transform3D(p.global_basis, p.global_position + offset)


func _on_player_died(_s: Soldier, killer: Node) -> void:
	hud.show_death(killer, respawn_delay)
	get_tree().create_timer(respawn_delay, false).timeout.connect(_respawn_player)


func _respawn_player() -> void:
	if not is_instance_valid(player):
		return
	player.respawn_at(spawn_transform(player.faction))
	AudioManager.play(&"respawn")
	hud.hide_death()


func _start_audio() -> void:
	Music.play(&"battle", 3.0)
	ambience.append(AudioManager.start_loop(&"amb_wind_loop", null, -6.0, 3.0))
	ambience.append(AudioManager.start_loop(&"amb_field_loop", null, -2.0, 3.0))
	AudioManager.play(&"match_start")


func _quit_to_menu() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_all_loops(0.3)
	AudioManager.stop_world_sounds()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _exit_tree() -> void:
	for a in ambience:
		AudioManager.stop_loop(a, 0.0)
