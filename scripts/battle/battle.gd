class_name Battle
extends Node3D
## The match scene: builds the battlefield, spawns soldiers, runs respawns, and hosts the HUD,
## pause menu, music and ambience. Later milestones add the AI armies (M4) and conquest (M5).

signal player_spawned(soldier: Soldier)

const SOLDIER_SCENE := preload("res://scenes/soldier.tscn")

@export var player_faction := 0
@export var respawn_delay := 5.0
## M2 test range: idle enemy soldiers to cut and shoot (replaced by the AI armies in M4).
@export var training_targets := true
const PLAYER_LOADOUT: Array[StringName] = [&"katana", &"matchlock"]

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
	if training_targets:
		_spawn_training_targets()
	_start_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player_spawned.emit(player)


## Builds the map. M1 uses a simple test ground; M3 replaces it with the battlefield.
func _build_field() -> Node3D:
	var ground := PrototypeGround.new()
	ground.name = "Field"
	return ground


func spawn_soldier(faction: int, as_player: bool = false, loadout: Array[StringName] = PLAYER_LOADOUT) -> Soldier:
	var s: Soldier = SOLDIER_SCENE.instantiate()
	s.faction = faction
	s.is_player = as_player
	s.name = ("Player" if as_player else "Soldier_%d_%d" % [faction, soldiers.size()])
	var xform := spawn_transform(faction)
	s.look_yaw = xform.basis.get_euler().y
	add_child(s)
	s.global_position = xform.origin
	s.equip_loadout(loadout)
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


## Idle enemies (and one ally) at several ranges; they come back a few seconds after dying.
func _spawn_training_targets() -> void:
	var spots := [
		[1, Vector3(0, 0, -12), [&"katana"]], [1, Vector3(3, 0, -14), [&"katana"]],
		[1, Vector3(-8, 0, -30), [&"matchlock", &"katana"]], [1, Vector3(10, 0, -55), [&"matchlock", &"katana"]],
		[0, Vector3(-4, 0, -6), [&"katana"]],
	]
	for spot in spots:
		var loadout: Array[StringName] = []
		loadout.assign(spot[2])
		var s := spawn_soldier(spot[0], false, loadout)
		s.display_name = "Training enemy" if spot[0] != player_faction else "Ally"
		var home := Transform3D(Basis(Vector3.UP, 0.0 if spot[0] == player_faction else PI), spot[1] + Vector3(0, 0.3, 0))
		s.respawn_at(home)
		s.died.connect(func(dead: Soldier, _k: Node) -> void:
			get_tree().create_timer(4.0, false).timeout.connect(func() -> void:
				if is_instance_valid(dead):
					dead.respawn_at(home)))


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
