class_name SoundTestPanel
extends PanelContainer
## Lists every sound event so placeholders can be auditioned (and replacements checked).
## Positional events are played at a point that orbits the listener so panning is audible.

signal closed

const GROUPS := [
	["Katana", ["katana_swing_light", "katana_swing_heavy", "katana_hit", "katana_hit_world", "katana_draw", "blade_clash", "blade_block"]],
	["Matchlock", ["matchlock_fire", "matchlock_fire_far", "matchlock_dry", "reload_powder", "reload_ball", "reload_ram", "reload_prime", "reload_match", "bullet_whiz", "bullet_hit_flesh", "bullet_hit_ground"]],
	["Soldiers", ["footstep", "land", "hurt", "death_cry", "body_fall", "battle_cry", "respawn"]],
	["Objectives & UI", ["match_start", "objective_captured", "objective_lost", "objective_contested", "capture_tick", "ticket_warning", "hit_marker", "kill_marker"]],
	["Ambience", ["amb_bird", "amb_gust"]],
]
const LOOPS := ["amb_wind_loop", "amb_field_loop", "battle_distant_loop", "battle_crowd_loop"]
const MUSIC := ["menu", "battle", "victory", "defeat"]

var _loops: Dictionary = {}
var _angle := 0.0


func _ready() -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	add_child(outer)
	outer.add_child(UIStyle.label("SOUND TEST", 30, UIStyle.GOLD))
	outer.add_child(UIStyle.label("All sounds are temporary placeholders (TEMP_ files).", 15, UIStyle.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(980, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for group in GROUPS:
		box.add_child(UIStyle.label(group[0], 19, UIStyle.MUTED))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		for id: String in group[1]:
			flow.add_child(_small_button(id, func(): _play(StringName(id))))
		box.add_child(flow)
	box.add_child(UIStyle.label("Ambience loops (toggle)", 19, UIStyle.MUTED))
	var lf := HFlowContainer.new()
	lf.add_theme_constant_override("h_separation", 8)
	for id: String in LOOPS:
		var b := _small_button(id, func(): pass)
		b.toggle_mode = true
		b.toggled.connect(func(on: bool): _toggle_loop(StringName(id), on))
		lf.add_child(b)
	box.add_child(lf)
	box.add_child(UIStyle.label("Music", 19, UIStyle.MUTED))
	var mf := HFlowContainer.new()
	mf.add_theme_constant_override("h_separation", 8)
	for id: String in MUSIC:
		mf.add_child(_small_button(id, func():
			if id in ["victory", "defeat"]:
				Music.play_stinger(StringName(id), &"menu")
			else:
				Music.play(StringName(id))))
	box.add_child(mf)
	var back := UIStyle.button("Back", _close, &"ui_back")
	outer.add_child(back)
	back.call_deferred("grab_focus")


func _small_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.add_theme_font_size_override("font_size", 15)
	b.disabled = not (AudioManager.has_event(StringName(text)) or Music.has_track(StringName(text)))
	UIStyle.wire_sounds(b, &"")
	return b


func _play(id: StringName) -> void:
	var ev: SoundEvent = AudioManager.events.get(id)
	if ev and ev.spatial:
		# Orbit the listener so left/right panning and distance are audible in the test.
		_angle += 1.3
		var dist := minf(ev.max_distance * 0.25, 12.0)
		AudioManager.play(id, AudioManager.listener_position() + Vector3(cos(_angle), 0.0, sin(_angle)) * dist)
	else:
		AudioManager.play(id)


func _toggle_loop(id: StringName, on: bool) -> void:
	if on:
		_loops[id] = AudioManager.start_loop(id)
	elif _loops.has(id):
		AudioManager.stop_loop(_loops[id])
		_loops.erase(id)


func _close() -> void:
	for id: StringName in _loops:
		AudioManager.stop_loop(_loops[id], 0.5)
	_loops.clear()
	if Music.current != &"menu":
		Music.play(&"menu")
	closed.emit()
