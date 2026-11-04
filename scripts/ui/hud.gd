class_name HUD
extends CanvasLayer
## In-battle overlay: health, crosshair, damage flash, death / respawn countdown.
## Weapon (M2) and objective / ticket (M5) panels attach here as milestones land.

var player: Soldier
var health_bar: ProgressBar
var health_label: Label
var crosshair: Control
var damage_flash: ColorRect
var death_panel: PanelContainer
var death_label: Label
var hint: Label
var root: Control

var _respawn_at := 0.0
var _flash := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.make_theme()
	add_child(root)

	damage_flash = ColorRect.new()
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)

	crosshair = Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(crosshair)

	var hp := VBoxContainer.new()
	hp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hp.offset_left = 40
	hp.offset_top = -90
	root.add_child(hp)
	health_label = UIStyle.label("100", 26)
	hp.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(300, 14)
	health_bar.show_percentage = false
	health_bar.max_value = 100
	health_bar.value = 100
	hp.add_child(health_bar)

	hint = UIStyle.label("V camera · F2 test damage · Esc pause", 14, UIStyle.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -420
	hint.offset_top = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(hint)

	death_panel = PanelContainer.new()
	death_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	death_panel.visible = false
	root.add_child(death_panel)
	death_label = UIStyle.label("", 28)
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_panel.add_child(death_label)


func bind_player(s: Soldier) -> void:
	player = s
	s.health.changed.connect(_on_health_changed)
	s.damaged.connect(func(_s: Soldier, amount: float, _src: Node) -> void:
		_flash = clampf(_flash + amount / 60.0, 0.0, 0.7))
	_on_health_changed(s.health.current, s.health.max_health)


func show_death(killer: Node, respawn_delay: float) -> void:
	death_panel.visible = true
	crosshair.visible = false
	var who := "the battlefield"
	if killer is Soldier and killer != player:
		who = (killer as Soldier).display_name
	death_label.set_meta("who", who)
	_respawn_at = Time.get_ticks_msec() / 1000.0 + respawn_delay
	_update_death_text()


func hide_death() -> void:
	death_panel.visible = false
	crosshair.visible = true


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 0.9)
	damage_flash.color.a = _flash * 0.6
	if death_panel.visible:
		_update_death_text()


func _update_death_text() -> void:
	var left := maxf(0.0, _respawn_at - Time.get_ticks_msec() / 1000.0)
	death_label.text = "Killed by %s\nRejoining the battle in %d" % [death_label.get_meta("who", "?"), ceili(left)]
	death_panel.position = (root.size - death_panel.size) * 0.5


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = str(ceili(current))
	var low := current / maximum < 0.35
	health_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.VERMILION if low else Color(0.85, 0.8, 0.7)))


class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 24)
		position -= Vector2(12, 12)

	func _draw() -> void:
		var c := Vector2(12, 12)
		var col := Color(1, 1, 1, 0.85)
		draw_circle(c, 2.0, col)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * 6.0, c + d * 11.0, col, 2.0)
