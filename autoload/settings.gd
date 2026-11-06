extends Node
## Persistent player settings stored in user://settings.cfg.
## Audio volumes are applied straight to the matching AudioServer buses.

signal changed(key: String)

const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"Ambience", &"SFX", &"Weapons", &"Impacts", &"UI", &"Voice"]
const DEFAULTS := {
	"audio/Master": 0.9,
	"audio/Music": 0.55,
	"audio/Ambience": 0.8,
	"audio/SFX": 0.9,
	"audio/Weapons": 1.0,
	"audio/Impacts": 1.0,
	"audio/UI": 0.8,
	"audio/Voice": 0.85,
	"controls/mouse_sensitivity": 1.0,
	"controls/gamepad_sensitivity": 1.0,
	"controls/invert_y": false,
	"video/fov": 75.0,
	"video/fullscreen": false,
}

## Tests point this at a scratch file so they never touch the player's real settings.
var path := "user://settings.cfg"
var _values: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_all()


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant, persist: bool = true) -> void:
	_values[key] = value
	if key.begins_with("audio/"):
		_apply_bus(StringName(key.trim_prefix("audio/")))
	elif key == "video/fullscreen":
		_apply_fullscreen()
	changed.emit(key)
	if persist:
		save_settings()


## Linear 0..1 volume for a bus.
func volume(bus: StringName) -> float:
	return float(get_value("audio/" + bus))


func set_volume(bus: StringName, linear: float) -> void:
	set_value("audio/" + bus, clampf(linear, 0.0, 1.0))


func apply_all() -> void:
	for bus in AUDIO_BUSES:
		_apply_bus(bus)
	_apply_fullscreen()


func load_settings() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key: String in DEFAULTS:
		var parts := key.split("/")
		if cfg.has_section_key(parts[0], parts[1]):
			_values[key] = cfg.get_value(parts[0], parts[1])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in _values:
		var parts := key.split("/")
		cfg.set_value(parts[0], parts[1], _values[key])
	var err := cfg.save(path)
	if err != OK:
		push_warning("[Settings] Could not save %s (error %d)" % [path, err])


func reset_to_defaults() -> void:
	_values = DEFAULTS.duplicate()
	apply_all()
	save_settings()


func _apply_bus(bus: StringName) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	var v := volume(bus)
	AudioServer.set_bus_volume_linear(idx, v)
	AudioServer.set_bus_mute(idx, v <= 0.001)


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var full: bool = get_value("video/fullscreen")
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
