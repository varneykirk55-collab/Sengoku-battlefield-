class_name SettingsPanel
extends PanelContainer
## Volume per audio category, controls and video settings. Changes apply and save immediately.

signal closed

const BUS_LABELS := {
	&"Master": "Master",
	&"Music": "Music",
	&"Ambience": "Ambience",
	&"SFX": "Effects",
	&"Weapons": "Weapons",
	&"Impacts": "Impacts",
	&"UI": "Interface",
	&"Voice": "Voices",
}
## A sound played when a slider is released, so the player hears the new level.
const PREVIEW := {&"Music": &"", &"Ambience": &"amb_gust", &"SFX": &"footstep", &"Weapons": &"katana_hit", &"Impacts": &"bullet_hit_ground", &"UI": &"ui_confirm", &"Voice": &"battle_cry", &"Master": &"ui_confirm"}

var sliders: Dictionary = {}  # bus -> HSlider


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UIStyle.label("SETTINGS", 30, UIStyle.GOLD))
	box.add_child(UIStyle.label("Audio", 20, UIStyle.MUTED))
	for bus: StringName in Settings.AUDIO_BUSES:
		box.add_child(_slider_row(BUS_LABELS[bus], Settings.volume(bus), 0.0, 1.0,
			func(v: float): Settings.set_volume(bus, v), bus))
	box.add_child(UIStyle.label("Controls", 20, UIStyle.MUTED))
	box.add_child(_slider_row("Mouse sensitivity", Settings.get_value("controls/mouse_sensitivity"), 0.2, 3.0,
		func(v: float): Settings.set_value("controls/mouse_sensitivity", v)))
	box.add_child(_slider_row("Gamepad sensitivity", Settings.get_value("controls/gamepad_sensitivity"), 0.2, 3.0,
		func(v: float): Settings.set_value("controls/gamepad_sensitivity", v)))
	box.add_child(_check("Invert look Y", "controls/invert_y"))
	box.add_child(UIStyle.label("Video", 20, UIStyle.MUTED))
	box.add_child(_slider_row("Field of view", Settings.get_value("video/fov"), 60.0, 100.0,
		func(v: float): Settings.set_value("video/fov", v)))
	box.add_child(_check("Fullscreen", "video/fullscreen"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var reset := UIStyle.button("Reset to defaults", _on_reset)
	reset.custom_minimum_size.x = 0
	row.add_child(reset)
	var back := UIStyle.button("Back", func(): closed.emit(), &"ui_back")
	back.custom_minimum_size.x = 0
	row.add_child(back)
	box.add_child(row)
	back.call_deferred("grab_focus")


func _slider_row(text: String, value: float, lo: float, hi: float, on_change: Callable, bus: StringName = &"") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UIStyle.label(text, 18)
	l.custom_minimum_size.x = 220
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(300, 28)
	s.focus_mode = Control.FOCUS_ALL
	var pct := UIStyle.label("", 16, UIStyle.MUTED)
	pct.custom_minimum_size.x = 56
	var show := func(v: float): pct.text = ("%d%%" % roundi(v * 100.0)) if hi <= 1.0 else ("%.2f" % v if hi < 10 else "%d" % roundi(v))
	show.call(value)
	s.value_changed.connect(func(v: float):
		on_change.call(v)
		show.call(v))
	if bus != &"":
		sliders[bus] = s
		s.drag_ended.connect(func(_changed: bool): _preview(bus))
	row.add_child(s)
	row.add_child(pct)
	return row


func _check(text: String, key: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on: bool): Settings.set_value(key, on))
	UIStyle.wire_sounds(c)
	return c


func _preview(bus: StringName) -> void:
	var ev: StringName = PREVIEW.get(bus, &"")
	if ev != &"":
		AudioManager.play(ev)


func _on_reset() -> void:
	Settings.reset_to_defaults()
	for bus: StringName in sliders:
		(sliders[bus] as HSlider).set_value_no_signal(Settings.volume(bus))
