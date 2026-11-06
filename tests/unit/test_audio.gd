extends TestCase
## Audio foundation: buses, catalog, voice limits, loops, music, settings.

var listener: Node3D


func before_each() -> void:
	listener = Node3D.new()
	add_child(listener)
	AudioManager.listener_override = listener
	AudioManager.stop_world_sounds()
	AudioManager.reset_stats()


func after_each() -> void:
	AudioManager.listener_override = null
	AudioManager.stop_world_sounds()
	AudioManager.stop_all_loops(0.0)


func test_required_buses_exist_and_route_to_master() -> void:
	for bus in [&"Master", &"Music", &"Ambience", &"SFX", &"Weapons", &"Impacts", &"UI", &"Voice"]:
		var idx := AudioServer.get_bus_index(bus)
		check(idx >= 0, "bus %s exists" % bus)
	for bus in [&"Music", &"Ambience", &"SFX", &"UI", &"Voice"]:
		var idx := AudioServer.get_bus_index(bus)
		check_eq(AudioServer.get_bus_send(idx), &"Master", "bus %s sends to Master" % bus)
	for bus in [&"Weapons", &"Impacts"]:
		var idx := AudioServer.get_bus_index(bus)
		check_eq(AudioServer.get_bus_send(idx), &"SFX", "bus %s sends to SFX" % bus)


func test_every_catalog_event_has_audio() -> void:
	for id: String in SoundCatalog.EVENTS:
		var ev: SoundEvent = AudioManager.events.get(StringName(id))
		check(ev != null, "event %s built" % id)
		if ev:
			check(not ev.streams.is_empty(), "event %s has audio files" % id)
			check(AudioServer.get_bus_index(ev.bus) >= 0, "event %s uses an existing bus (%s)" % [id, ev.bus])


func test_required_feature_sounds_present() -> void:
	# The audio requirements list, one event per requirement.
	for id in [&"katana_swing_light", &"katana_swing_heavy", &"blade_clash", &"katana_hit", &"matchlock_fire",
			&"reload_ram", &"hurt", &"death_cry", &"battle_distant_loop", &"battle_crowd_loop", &"battle_cry",
			&"amb_wind_loop", &"objective_captured", &"objective_lost", &"capture_tick", &"ticket_warning",
			&"ui_click", &"ui_hover"]:
		check(AudioManager.has_event(id), "sound event %s available" % id)
	for track in [&"menu", &"battle", &"victory", &"defeat"]:
		check(Music.has_track(track), "music track %s available" % track)


func test_positional_sound_plays_on_3d_voice() -> void:
	var p := AudioManager.play(&"katana_hit", Vector3(3, 0, 0))
	check(p is AudioStreamPlayer3D, "positional event uses a 3D player")
	if p:
		check_near((p as AudioStreamPlayer3D).global_position.x, 3.0, 0.01, "player placed at the sound position")
		check_eq((p as AudioStreamPlayer3D).bus, &"Weapons", "katana_hit routed to Weapons")
	var ui := AudioManager.play(&"ui_click")
	check(ui is AudioStreamPlayer, "UI event uses a 2D player")
	check_eq(AudioManager.stats.played, 2, "both sounds counted as played")


func test_out_of_range_sound_is_culled() -> void:
	var p := AudioManager.play(&"footstep", Vector3(500, 0, 0))
	check(p == null, "footstep 500 m away is not played")
	check_eq(AudioManager.stats.culled_distance, 1, "cull counted")


func test_distant_gunshot_switches_to_far_variant() -> void:
	var p := AudioManager.play(&"matchlock_fire", Vector3(200, 0, 0))
	check(p != null, "a gunshot 200 m away is still audible")
	if p:
		var path: String = (p as AudioStreamPlayer3D).stream.resource_path
		check(path.contains("matchlock_fire_far"), "far gunshot uses the matchlock_fire_far variant (%s)" % path)


func test_per_event_instance_cap() -> void:
	var cap: int = AudioManager.events[&"footstep"].max_instances
	var ok := 0
	for i in cap + 5:
		if AudioManager.play(&"footstep", Vector3(1, 0, 0)):
			ok += 1
	check_eq(ok, cap, "no more than max_instances footsteps at once")
	check(AudioManager.stats.capped >= 5, "excess footsteps counted as capped")


func test_closer_copy_replaces_farther_copy_at_cap() -> void:
	var cap: int = AudioManager.events[&"footstep"].max_instances
	for i in cap:
		AudioManager.play(&"footstep", Vector3(20, 0, 0))
	var near := AudioManager.play(&"footstep", Vector3(1, 0, 0))
	check(near != null, "a nearer footstep replaces a far one when the cap is reached")


func test_cooldown_blocks_rapid_repeats() -> void:
	check(AudioManager.play(&"ticket_warning") != null, "first ticket warning plays")
	check(AudioManager.play(&"ticket_warning") == null, "second ticket warning within cooldown is blocked")
	check_eq(AudioManager.stats.cooldown, 1, "cooldown counted")


func test_voice_stealing_prefers_important_sounds() -> void:
	# Fill every 3D voice with quiet, unimportant bird calls.
	var birds := 0
	var ev: SoundEvent = AudioManager.events[&"amb_bird"]
	var old_max := ev.max_instances
	ev.max_instances = 999
	for i in AudioManager.POOL_3D + 4:
		if AudioManager.play(&"amb_bird", Vector3(10 + i * 0.1, 0, 0)):
			birds += 1
	check_eq(birds, AudioManager.POOL_3D, "birds fill the 3D pool, the rest are dropped")
	var shot := AudioManager.play(&"matchlock_fire", Vector3(5, 0, 0))
	check(shot != null, "a gunshot steals a voice from a bird")
	check(AudioManager.stats.stolen >= 1, "steal counted")
	# Reverse: with the pool full of gunshots, a bird must not steal.
	AudioManager.stop_world_sounds()
	var gev: SoundEvent = AudioManager.events[&"matchlock_fire"]
	var gmax := gev.max_instances
	gev.max_instances = 999
	for i in AudioManager.POOL_3D:
		AudioManager.play(&"matchlock_fire", Vector3(5, 0, 0))
	check(AudioManager.play(&"amb_bird", Vector3(10, 0, 0)) == null, "a bird cannot steal from gunshots")
	gev.max_instances = gmax
	ev.max_instances = old_max


func test_loops_start_and_stop() -> void:
	var loop := AudioManager.start_loop(&"battle_distant_loop", null, 0.0, 0.0)
	check(loop is AudioStreamPlayer, "loop player created")
	if loop:
		check(loop.playing, "loop is playing")
		var s: AudioStream = loop.stream
		check(s is AudioStreamWAV and (s as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "loop stream set to loop forward")
		check_eq(loop.bus, &"Ambience", "battle bed routed to Ambience")
		AudioManager.stop_loop(loop, 0.0)
		await frames(2)
		check(not is_instance_valid(loop), "stopped loop is freed")


func test_music_crossfade() -> void:
	Music.play(&"menu", 0.0)
	check_eq(Music.current, &"menu", "menu track current")
	check(Music.is_playing(), "music playing")
	Music.play(&"battle", 0.2)
	check_eq(Music.current, &"battle", "battle track current after switch")
	await seconds(0.4)
	var playing := 0
	for d in Music._decks:
		if d.playing:
			playing += 1
	check_eq(playing, 1, "old deck stops after the crossfade")
	Music.stop(0.0)


func test_volume_settings_drive_buses() -> void:
	var old_path := Settings.path
	Settings.path = "user://test_settings.cfg"
	var before := Settings.volume(&"SFX")
	Settings.set_volume(&"SFX", 0.25)
	check_near(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(&"SFX")), 0.25, 0.01, "SFX bus follows the setting")
	Settings.set_volume(&"Music", 0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "volume 0 mutes the bus")
	Settings.load_settings()
	check_near(Settings.volume(&"SFX"), 0.25, 0.001, "setting persisted to disk and reloaded")
	Settings.set_volume(&"SFX", before)
	Settings.set_volume(&"Music", Settings.DEFAULTS["audio/Music"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))
	Settings.path = old_path
	Settings.load_settings()
	Settings.apply_all()
