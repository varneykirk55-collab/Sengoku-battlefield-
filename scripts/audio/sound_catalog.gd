class_name SoundCatalog
extends RefCounted
## Every sound event in the game and its playback rules.
##
## Audio files are discovered by folder: everything in res://audio/sfx/<event_id>/ becomes a
## variation of that event. To replace a placeholder, drop new .wav/.ogg/.mp3 files into the
## folder and delete the TEMP_ ones. To tune loudness, range or voice limits, edit the table below.
##
## Keys: bus, vol (dB), pri (0-100), max (simultaneous), range (m), unit (m), cool (s),
##       spatial (bool), loop (bool), far / far_at (distant-variant event and switch distance),
##       pitch (pitch jitter).

const SFX_ROOT := "res://audio/sfx"
const AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]

const EVENTS := {
	# --- katana ---
	"katana_swing_light": {"pri": 40, "max": 8, "range": 35, "unit": 6, "vol": -2},
	"katana_swing_heavy": {"pri": 45, "max": 6, "range": 40, "unit": 7},
	"katana_hit": {"pri": 70, "max": 8, "range": 45, "unit": 8},
	"katana_hit_world": {"pri": 35, "max": 4, "range": 35, "unit": 6},
	"katana_draw": {"pri": 30, "max": 3, "range": 25, "unit": 4},
	"blade_clash": {"pri": 65, "max": 6, "range": 50, "unit": 8},
	"blade_block": {"pri": 55, "max": 6, "range": 45, "unit": 7},
	# --- matchlock ---
	"matchlock_fire": {"pri": 90, "max": 8, "range": 90, "unit": 22, "pitch": 0.04, "far": "matchlock_fire_far", "far_at": 70},
	"matchlock_fire_far": {"pri": 60, "max": 5, "range": 600, "unit": 70, "pitch": 0.05},
	"matchlock_dry": {"pri": 40, "max": 2, "range": 20, "unit": 4},
	"reload_powder": {"pri": 35, "max": 4, "range": 20, "unit": 4},
	"reload_ball": {"pri": 35, "max": 4, "range": 20, "unit": 4},
	"reload_ram": {"pri": 35, "max": 4, "range": 20, "unit": 4},
	"reload_prime": {"pri": 35, "max": 4, "range": 20, "unit": 4},
	"reload_match": {"pri": 35, "max": 4, "range": 20, "unit": 4},
	"weapon_raise": {"pri": 30, "max": 3, "range": 15, "unit": 3},
	"weapon_lower": {"pri": 30, "max": 3, "range": 15, "unit": 3},
	"bullet_whiz": {"pri": 80, "max": 3, "range": 20, "unit": 4},
	"bullet_hit_flesh": {"pri": 70, "max": 6, "range": 50, "unit": 8},
	"bullet_hit_ground": {"pri": 40, "max": 6, "range": 50, "unit": 8},
	"bullet_hit_wood": {"pri": 40, "max": 6, "range": 50, "unit": 8},
	# --- bodies ---
	"footstep": {"pri": 20, "max": 10, "range": 25, "unit": 3, "vol": -4},
	"land": {"pri": 25, "max": 6, "range": 25, "unit": 4},
	"hurt": {"pri": 55, "max": 6, "range": 45, "unit": 7},
	"death_cry": {"pri": 60, "max": 5, "range": 60, "unit": 9},
	"body_fall": {"pri": 40, "max": 5, "range": 35, "unit": 6},
	"battle_cry": {"bus": "Voice", "pri": 45, "max": 4, "range": 70, "unit": 10, "cool": 0.3},
	# --- player feedback & UI (not positional) ---
	"respawn": {"bus": "UI", "spatial": false, "pri": 90, "max": 1},
	"ui_hover": {"bus": "UI", "spatial": false, "pri": 100, "max": 2, "cool": 0.04},
	"ui_click": {"bus": "UI", "spatial": false, "pri": 100, "max": 3},
	"ui_confirm": {"bus": "UI", "spatial": false, "pri": 100, "max": 2},
	"ui_back": {"bus": "UI", "spatial": false, "pri": 100, "max": 2},
	"capture_tick": {"bus": "UI", "spatial": false, "pri": 95, "max": 1, "cool": 0.35, "pitch": 0.0},
	"hit_marker": {"bus": "UI", "spatial": false, "pri": 95, "max": 3},
	"kill_marker": {"bus": "UI", "spatial": false, "pri": 95, "max": 2},
	"match_start": {"bus": "UI", "spatial": false, "pri": 100, "max": 1, "pitch": 0.0},
	"objective_captured": {"bus": "UI", "spatial": false, "pri": 100, "max": 1, "pitch": 0.0},
	"objective_lost": {"bus": "UI", "spatial": false, "pri": 100, "max": 1, "pitch": 0.0},
	"objective_contested": {"bus": "UI", "spatial": false, "pri": 95, "max": 1, "cool": 1.0, "pitch": 0.0},
	"ticket_warning": {"bus": "UI", "spatial": false, "pri": 100, "max": 1, "cool": 5.0, "pitch": 0.0},
	# --- ambience ---
	"amb_bird": {"bus": "Ambience", "pri": 10, "max": 3, "range": 90, "unit": 12},
	"amb_gust": {"bus": "Ambience", "spatial": false, "pri": 15, "max": 1, "cool": 4.0},
	"amb_wind_loop": {"bus": "Ambience", "spatial": false, "loop": true, "pri": 20, "max": 1},
	"amb_field_loop": {"bus": "Ambience", "spatial": false, "loop": true, "pri": 20, "max": 1},
	"battle_distant_loop": {"bus": "Ambience", "spatial": false, "loop": true, "pri": 30, "max": 1},
	"battle_crowd_loop": {"bus": "Ambience", "spatial": false, "loop": true, "pri": 30, "max": 1},
}


## Builds SoundEvent resources for the whole catalog, loading each event's audio folder.
static func build() -> Dictionary:
	var out := {}
	for id: String in EVENTS:
		out[StringName(id)] = make_event(StringName(id), EVENTS[id], load_streams(SFX_ROOT.path_join(id)))
	return out


static func make_event(id: StringName, d: Dictionary, streams: Array[AudioStream]) -> SoundEvent:
	var e := SoundEvent.new()
	e.id = id
	e.streams = streams
	e.bus = StringName(d.get("bus", "SFX"))
	e.volume_db = float(d.get("vol", 0.0))
	e.pitch_jitter = float(d.get("pitch", 0.06))
	e.spatial = bool(d.get("spatial", true))
	e.max_distance = float(d.get("range", 60.0))
	e.unit_size = float(d.get("unit", 8.0))
	e.far_event = StringName(d.get("far", ""))
	e.far_distance = float(d.get("far_at", 0.0))
	e.priority = int(d.get("pri", 50))
	e.max_instances = int(d.get("max", 6))
	e.cooldown = float(d.get("cool", 0.0))
	e.loop = bool(d.get("loop", false))
	if e.loop:
		e.volume_jitter_db = 0.0
		e.pitch_jitter = 0.0
	return e


## Loads every audio file in a folder. Works in the editor and in exported builds
## (where the folder lists .import / .remap entries instead of the source files).
static func load_streams(dir_path: String) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var names := {}
	for file in DirAccess.get_files_at(dir_path):
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if AUDIO_EXTENSIONS.has(clean.get_extension().to_lower()):
			names[clean] = true
	var sorted: Array = names.keys()
	sorted.sort()
	for file: String in sorted:
		var stream := load(dir_path.path_join(file)) as AudioStream
		if stream:
			out.append(stream)
	return out
