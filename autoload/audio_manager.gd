extends Node
## Central sound playback. Gameplay code names a sound event; AudioManager decides whether,
## where and how it plays:
##
##     AudioManager.play(&"matchlock_fire", muzzle_position)   # positional (3D)
##     AudioManager.play(&"objective_captured")                # 2D cue (UI / stingers)
##     var wind := AudioManager.start_loop(&"amb_wind_loop")   # until stop_loop(wind)
##
## Each event (see SoundCatalog) carries its bus, priority, voice cap, cooldown and audible range,
## so a large battle cannot flood the mixer:
##   * sounds beyond their audible range are not played,
##   * each event has a cap on simultaneous copies,
##   * when every voice is busy, the least important voice (low priority, far away) is stolen,
##     and a new sound that is less important than everything playing is dropped.

## Emitted for every sound that actually starts (tests and debugging listen to this).
signal sound_played(id: StringName, position: Variant)

const BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"UI", &"Voice"]
const POOL_3D := 40
const POOL_2D := 16

var events: Dictionary = {}  # StringName -> SoundEvent
## Tests set this to place the listener without a camera.
var listener_override: Node3D = null
## Counters for tests and profiling: played, culled_distance, capped, cooldown, stolen, dropped, missing.
var stats := {}

var _clock := 0.0
var _listener_cached := Vector3.ZERO
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
## player -> {event, priority, distance, end}
var _voices: Dictionary = {}
var _last_played: Dictionary = {}
var _loops: Array[Node] = []
var _missing_reported: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	Settings.apply_all()
	reset_stats()
	events = SoundCatalog.build()
	var empty: Array[String] = []
	for id: StringName in events:
		if (events[id] as SoundEvent).streams.is_empty():
			empty.append(String(id))
	if not empty.is_empty():
		push_warning("[AudioManager] No audio files for: " + ", ".join(empty))
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice3D_%d" % i
		p.process_mode = Node.PROCESS_MODE_PAUSABLE  # world sounds pause with the game
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.attenuation_filter_cutoff_hz = 7000.0  # distant sounds lose their top end
		p.attenuation_filter_db = -14.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.name = "Voice2D_%d" % i
		add_child(p2)
		_pool_2d.append(p2)


func _process(delta: float) -> void:
	_clock += delta
	_listener_cached = _compute_listener()


func _physics_process(_delta: float) -> void:
	_listener_cached = _compute_listener()


## Makes sure the six game buses exist even if the bus layout resource is missing.
func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


func reset_stats() -> void:
	stats = {"played": 0, "culled_distance": 0, "capped": 0, "cooldown": 0, "stolen": 0, "dropped": 0, "missing": 0}


func has_event(id: StringName) -> bool:
	return events.has(id) and not (events[id] as SoundEvent).streams.is_empty()


## Plays a sound event. Pass a world position for positional sounds; omit it for 2D cues.
## Returns the player used, or null if the sound was culled, capped or dropped.
func play(id: StringName, position: Variant = null, volume_offset_db: float = 0.0, pitch_scale: float = 1.0) -> Node:
	var ev: SoundEvent = events.get(id)
	if ev == null or ev.streams.is_empty():
		_report_missing(id)
		return null
	if ev.cooldown > 0.0 and _clock - float(_last_played.get(id, -1e9)) < ev.cooldown:
		stats.cooldown += 1
		return null
	var spatial := ev.spatial and position is Vector3
	var distance := 0.0
	if spatial:
		distance = listener_position().distance_to(position)
		if ev.far_event != &"" and distance > ev.far_distance and has_event(ev.far_event):
			return play(ev.far_event, position, volume_offset_db, pitch_scale)
		if distance > ev.max_distance:
			stats.culled_distance += 1
			return null
	var importance := _importance(ev.priority, distance)
	var player: Node = null
	if _count_active(id) >= ev.max_instances:
		# At the cap: replace the least important copy of this same event, if the new one matters more.
		var victim := _least_important(func(info): return info.event == id)
		if victim == null or _importance(_voices[victim].priority, _voices[victim].distance) >= importance:
			stats.capped += 1
			return null
		if (victim is AudioStreamPlayer3D) != spatial:
			stats.capped += 1
			return null
		_stop_voice(victim)
		player = victim
	else:
		player = _free_voice(spatial)
		if player == null:
			var victim := _least_important(func(info): return (info.player is AudioStreamPlayer3D) == spatial)
			if victim == null or _importance(_voices[victim].priority, _voices[victim].distance) >= importance:
				stats.dropped += 1
				return null
			_stop_voice(victim)
			stats.stolen += 1
			player = victim
	var stream := ev.pick()
	var pitch := pitch_scale * (1.0 + randf_range(-ev.pitch_jitter, ev.pitch_jitter))
	var vol := ev.volume_db + volume_offset_db + randf_range(-ev.volume_jitter_db, ev.volume_jitter_db) * 0.5
	if spatial:
		var p3 := player as AudioStreamPlayer3D
		p3.bus = ev.bus
		p3.unit_size = ev.unit_size
		p3.max_distance = ev.max_distance
		p3.global_position = position
		p3.stream = stream
		p3.volume_db = vol
		p3.pitch_scale = pitch
		p3.play()
	else:
		var p2 := player as AudioStreamPlayer
		p2.bus = ev.bus
		p2.stream = stream
		p2.volume_db = vol
		p2.pitch_scale = pitch
		p2.play()
	var length := stream.get_length() / maxf(pitch, 0.01) if stream.get_length() > 0.0 else 2.0
	_voices[player] = {"player": player, "event": id, "priority": ev.priority, "distance": distance, "end": _clock + length + 0.05}
	_last_played[id] = _clock
	stats.played += 1
	sound_played.emit(id, position)
	return player


## Starts a looping sound (ambience beds). With `attach_to`, it follows that node in 3D.
## Returns the player; pass it to stop_loop() or set_loop_volume().
func start_loop(id: StringName, attach_to: Node3D = null, volume_offset_db: float = 0.0, fade_in: float = 1.5) -> Node:
	var ev: SoundEvent = events.get(id)
	if ev == null or ev.streams.is_empty():
		_report_missing(id)
		return null
	var stream := SoundEvent.make_looping(ev.pick())
	var player: Node
	if attach_to:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = ev.unit_size
		p3.max_distance = ev.max_distance
		attach_to.add_child(p3)
		player = p3
	else:
		player = AudioStreamPlayer.new()
		add_child(player)
	player.name = "Loop_" + String(id)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.set("bus", ev.bus)
	player.set("stream", stream)
	player.set_meta("target_db", ev.volume_db + volume_offset_db)
	player.set("volume_db", -60.0 if fade_in > 0.0 else ev.volume_db + volume_offset_db)
	player.call("play", randf() * maxf(stream.get_length() - 0.1, 0.0))
	if fade_in > 0.0:
		_fade(player, ev.volume_db + volume_offset_db, fade_in)
	_loops.append(player)
	return player


func set_loop_volume(player: Variant, volume_db: float, fade: float = 0.5) -> void:
	if is_instance_valid(player):
		player.set_meta("target_db", volume_db)
		_fade(player, volume_db, fade)


func stop_loop(player: Variant, fade_out: float = 1.0) -> void:
	if not is_instance_valid(player):
		return
	_loops.erase(player)
	if fade_out <= 0.0 or not player.is_inside_tree():
		player.queue_free()
		return
	var tw := _fade(player, -60.0, fade_out)
	tw.finished.connect(player.queue_free)


func stop_all_loops(fade_out: float = 1.0) -> void:
	for p in _loops.duplicate():
		stop_loop(p, fade_out)


## Stops every positional sound (used when leaving a battle).
func stop_world_sounds() -> void:
	for p in _pool_3d:
		_stop_voice(p)


func active_voice_count() -> int:
	var n := 0
	for p: Node in _voices:
		if _is_busy(p):
			n += 1
	return n


## Where the player's ears are (the active camera). Cached once per frame.
func listener_position() -> Vector3:
	if is_instance_valid(listener_override):
		return listener_override.global_position
	return _listener_cached


func _compute_listener() -> Vector3:
	if is_instance_valid(listener_override):
		return listener_override.global_position
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp else null
	return cam.global_position if cam else Vector3.ZERO


# ----------------------------------------------------------------------------- internals
func _importance(priority: int, distance: float) -> float:
	# Priority dominates; distance halves importance every ~25 m.
	return float(priority) / (1.0 + distance / 25.0)


func _is_busy(p: Node) -> bool:
	if not _voices.has(p):
		return false
	if _clock > float(_voices[p].end):
		return false
	return p.get("playing")


func _count_active(id: StringName) -> int:
	var n := 0
	for p: Node in _voices:
		if _voices[p].event == id and _is_busy(p):
			n += 1
	return n


func _free_voice(spatial: bool) -> Node:
	var pool: Array = _pool_3d if spatial else _pool_2d
	for p: Node in pool:
		if not _is_busy(p):
			return p
	return null


func _least_important(filter: Callable) -> Node:
	var best: Node = null
	var best_score := INF
	for p: Node in _voices:
		var info: Dictionary = _voices[p]
		if not _is_busy(p) or not filter.call(info):
			continue
		var score := _importance(info.priority, info.distance)
		if score < best_score:
			best_score = score
			best = p
	return best


func _stop_voice(p: Node) -> void:
	p.call("stop")
	_voices.erase(p)


func _fade(player: Node, to_db: float, seconds: float) -> Tween:
	# Bound to the player, so the tween dies with it if the player is freed mid-fade.
	if player.has_meta("fade_tween"):
		var old: Tween = player.get_meta("fade_tween")
		if old and old.is_valid():
			old.kill()
	var tw := player.create_tween()
	player.set_meta("fade_tween", tw)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var from_lin := db_to_linear(float(player.get("volume_db")))
	var setter := func(v: float) -> void:
		if is_instance_valid(player):
			player.set("volume_db", linear_to_db(maxf(v, 0.0001)))
	tw.tween_method(setter, from_lin, db_to_linear(to_db), maxf(seconds, 0.01))
	return tw


func _report_missing(id: StringName) -> void:
	stats.missing += 1
	if not _missing_reported.has(id):
		_missing_reported[id] = true
		push_warning("[AudioManager] Unknown or empty sound event '%s'" % id)


## Stops every sound (world, UI, loops, music) and waits for the mixer to release them.
## Call before quitting so the engine shuts down cleanly: `await AudioManager.shutdown()`.
func shutdown() -> void:
	stop_world_sounds()
	for p in _pool_2d:
		_stop_voice(p)
	stop_all_loops(0.0)
	Music.stop(0.0)
	for i in 6:
		await get_tree().process_frame


## Quits the game after stopping all audio.
func quit_game(exit_code: int = 0) -> void:
	await shutdown()
	get_tree().quit(exit_code)


func _exit_tree() -> void:
	# Release streams so the engine shuts down without "resource still in use" warnings.
	for p in _pool_3d + _pool_2d:
		p.stop()
		p.stream = null
	for p in _loops:
		if is_instance_valid(p):
			p.call("stop")
			p.set("stream", null)
	_voices.clear()
	events.clear()
