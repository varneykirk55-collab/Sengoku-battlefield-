class_name SoundEvent
extends Resource
## One named sound ("matchlock_fire", "objective_captured", ...) and the rules for playing it.
## Gameplay code only ever names the event; the audio files behind it live in
## res://audio/sfx/<id>/ and can be swapped without touching code.

@export var id: StringName
## Variations. One is picked at random per play, never the same one twice in a row.
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var volume_db := 0.0
## Random +/- volume and pitch per play, so repeated sounds don't sound mechanical.
@export var volume_jitter_db := 1.5
@export var pitch_jitter := 0.06

@export_group("Space")
## Positional (AudioStreamPlayer3D) when played with a position; UI cues are not spatial.
@export var spatial := true
## Beyond this distance from the listener the sound is not played at all.
@export var max_distance := 60.0
## Distance at which the sound is at full volume (bigger = louder sound carries further).
@export var unit_size := 8.0
## Optional distant version: past far_distance, far_event plays instead (e.g. muffled gunshot).
@export var far_event: StringName = &""
@export var far_distance := 0.0

@export_group("Voice limits")
## 0..100. When every voice is busy, the least important voice (low priority, far away) is stolen.
@export_range(0, 100) var priority := 50
## How many copies of this event may sound at once.
@export var max_instances := 6
## Minimum seconds between two plays of this event.
@export var cooldown := 0.0
## Loops forever when started with AudioManager.start_loop().
@export var loop := false

var _last_index := -1


func pick() -> AudioStream:
	if streams.is_empty():
		return null
	if streams.size() == 1:
		return streams[0]
	var i := randi() % streams.size()
	if i == _last_index:
		i = (i + 1) % streams.size()
	_last_index = i
	return streams[i]


## Returns a looping copy of a stream (the imported file itself is left unchanged).
static func make_looping(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		var s := stream.duplicate()
		s.set("loop", true)
		return s
	return stream
