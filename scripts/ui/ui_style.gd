class_name UIStyle
extends RefCounted
## Shared look for the placeholder UI: ink-black lacquer panels, paper text, vermilion and gold.
## Adapted from Kengeki's UIStyle.

const INK := Color(0.06, 0.055, 0.06, 0.9)
const PAPER := Color(0.93, 0.9, 0.84)
const MUTED := Color(0.66, 0.63, 0.58)
const VERMILION := Color(0.78, 0.2, 0.13)
const GOLD := Color(0.84, 0.68, 0.3)
## Faction colours: 0 = Oda (red), 1 = Takeda-style blue placeholder.
const FACTION_COLORS := [Color(0.82, 0.22, 0.16), Color(0.22, 0.42, 0.85)]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var panel := StyleBoxFlat.new()
	panel.bg_color = INK
	panel.border_color = Color(VERMILION, 0.9)
	panel.border_width_left = 3
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 20
	panel.content_margin_bottom = 20
	t.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.15, 0.15, 0.95)
		match state:
			"hover", "focus":
				sb.bg_color = Color(0.32, 0.12, 0.09, 0.95)
				sb.border_color = GOLD
				sb.border_width_left = 3
			"pressed":
				sb.bg_color = VERMILION
			"disabled":
				sb.bg_color = Color(0.12, 0.12, 0.12, 0.6)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 9
		sb.content_margin_bottom = 9
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(MUTED, 0.6))
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_color", "CheckBox", PAPER)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.05, 0.05, 0.05, 0.75)
	bar_bg.border_color = Color(0, 0, 0, 0.9)
	bar_bg.set_border_width_all(1)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill(VERMILION))
	return t


static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb


static func label(text: String, size: int = 18, color: Color = PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Adds hover/click sounds to a button (and focus sound for gamepad navigation).
static func wire_sounds(button: BaseButton, click_event: StringName = &"ui_click") -> void:
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			AudioManager.play(&"ui_hover"))
	button.focus_entered.connect(func() -> void: AudioManager.play(&"ui_hover"))
	if click_event != &"":
		button.pressed.connect(func() -> void: AudioManager.play(click_event))


static func button(text: String, on_pressed: Callable, click_event: StringName = &"ui_click") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 0)
	b.pressed.connect(on_pressed)
	wire_sounds(b, click_event)
	return b
