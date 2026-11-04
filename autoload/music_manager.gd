extends Node
## Music with smooth crossfades between two decks.
##
##     Music.play(&"battle")                    # crossfade to a looping track
##     Music.play_stinger(&"victory")           # one-shot cue (victory / defeat)
##     Music.stop()
##
## Tracks are the files in res://audio/music/: "<id>.<ext>" or placeholder "TEMP_<id>.<ext>".
## A real file named battle.ogg wins over TEMP_battle.wav, so replacing music needs no code.

signal track_changed(id: StringName)

const MUSIC_ROOT := "res://audio/music"
## Tracks that should loop when played with play().
const LOOPING: Array[StringName] = [&"menu", &"battle"]

var tracks: Dictionary = {}  # StringName -> AudioStream
var current: StringName = &""

var _decks: Array[AudioStreamPlayer] = []
var _active := 0
var _tweens: Array[Tween] = [null, null]
var _after_stinger: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_tracks()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Deck%d" % i
		p.bus = &"Music"
		p.volume_db = -60.0
		p.finished.connect(_on_deck_finished.bind(i))
		add_child(p)
		_decks.append(p)


func has_track(id: StringName) -> bool:
	return tracks.has(id)


func is_playing() -> bool:
	return _decks[_active].playing


## Crossfades to a looping track. Does nothing if that track is already playing.
func play(id: StringName, fade: float = 1.5) -> void:
	_after_stinger = &""
	if id == current and _decks[_active].playing:
		return
	_switch_to(id, fade, LOOPING.has(id))


## Plays a one-shot cue. With `then`, crossfades to that looping track once the cue ends.
func play_stinger(id: StringName, then: StringName = &"", fade: float = 0.4) -> void:
	_switch_to(id, fade, false)
	_after_stinger = then


func stop(fade: float = 1.5) -> void:
	_after_stinger = &""
	current = &""
	for i in 2:
		_fade_deck(i, -60.0, fade, true)


func _switch_to(id: StringName, fade: float, looping: bool) -> void:
	var stream: AudioStream = tracks.get(id)
	if stream == null:
		push_warning("[Music] No track '%s' in %s" % [id, MUSIC_ROOT])
		return
	var old := _active
	_active = 1 - _active
	var deck := _decks[_active]
	deck.stream = SoundEvent.make_looping(stream) if looping else stream
	deck.volume_db = -60.0 if fade > 0.0 else 0.0
	deck.play()
	_fade_deck(_active, 0.0, fade, false)
	_fade_deck(old, -60.0, fade, true)
	current = id
	track_changed.emit(id)


func _fade_deck(i: int, to_db: float, seconds: float, stop_after: bool) -> void:
	if _tweens[i] and _tweens[i].is_valid():
		_tweens[i].kill()
	var deck := _decks[i]
	if seconds <= 0.0:
		deck.volume_db = to_db
		if stop_after:
			deck.stop()
		return
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(v: float): deck.volume_db = linear_to_db(maxf(v, 0.0001)),
		db_to_linear(deck.volume_db), db_to_linear(to_db), seconds)
	if stop_after:
		tw.tween_callback(deck.stop)
	_tweens[i] = tw


func _on_deck_finished(i: int) -> void:
	if i == _active and _after_stinger != &"":
		var next := _after_stinger
		_after_stinger = &""
		_switch_to(next, 2.0, LOOPING.has(next))


func _load_tracks() -> void:
	tracks.clear()
	if not DirAccess.dir_exists_absolute(MUSIC_ROOT):
		return
	var found := {}
	for file in DirAccess.get_files_at(MUSIC_ROOT):
		var clean := file.trim_suffix(".import").trim_suffix(".remap")
		if not SoundCatalog.AUDIO_EXTENSIONS.has(clean.get_extension().to_lower()):
			continue
		var base := clean.get_basename()
		var placeholder := base.begins_with("TEMP_")
		var id := StringName(base.trim_prefix("TEMP_"))
		# Real files override placeholders with the same id.
		if found.has(id) and placeholder:
			continue
		found[id] = clean
	for id: StringName in found:
		var s := load(MUSIC_ROOT.path_join(found[id])) as AudioStream
		if s:
			tracks[id] = s


func _exit_tree() -> void:
	for d in _decks:
		d.stop()
		d.stream = null
	tracks.clear()
