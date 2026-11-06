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
var weapon_name: Label
var weapon_status: Label
var weapon_bar: ProgressBar
var marker: Control

var _respawn_at := 0.0
var _flash := 0.0
var _dir_root: Control
var _dir_arrows: Dictionary = {}  # side -> {ctrl, strength}
var _last_attacker: Node = null


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.make_theme()
	add_child(root)

	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.color = Color(0.6, 0.0, 0.0, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)

	_dir_root = Control.new()
	_dir_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dir_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dir_root)
	for side in [&"front", &"back", &"left", &"right"]:
		var a := DamageArrow.new()
		a.side = side
		_dir_root.add_child(a)
		_dir_arrows[side] = a

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

	var wp := VBoxContainer.new()
	wp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	wp.offset_left = -360
	wp.offset_top = -140
	wp.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(wp)
	weapon_name = UIStyle.label("", 26)
	weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wp.add_child(weapon_name)
	weapon_status = UIStyle.label("", 17, UIStyle.MUTED)
	weapon_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wp.add_child(weapon_status)
	weapon_bar = ProgressBar.new()
	weapon_bar.custom_minimum_size = Vector2(320, 8)
	weapon_bar.show_percentage = false
	weapon_bar.max_value = 1.0
	wp.add_child(weapon_bar)

	marker = HitMarker.new()
	marker.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(marker)
	Events.damage_dealt.connect(_on_damage_dealt)
	Events.soldier_killed.connect(_on_killed)

	hint = UIStyle.label("LMB/RMB attack · Q switch · R reload · V camera · Tab score · Esc", 14, UIStyle.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -700
	hint.offset_top = -32
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
	s.damaged.connect(func(_s: Soldier, amount: float, src: Node) -> void:
		_flash = clampf(_flash + amount / 60.0, 0.0, 0.55)
		_last_attacker = src
		_pulse_direction(src, amount))
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
	damage_flash.color.a = _flash * 0.45
	for a in _dir_arrows.values():
		(a as DamageArrow).tick(delta)
	if death_panel.visible:
		_update_death_text()
	_update_weapon()


func _update_weapon() -> void:
	if player == null or player.weapons == null or player.weapons.current() == null:
		return
	var w := player.weapons.current()
	weapon_name.text = w.display_name
	weapon_status.text = w.status_text() if not player.weapons.switching() else "..."
	var p := w.progress()
	weapon_bar.visible = p >= 0.0
	if p >= 0.0:
		weapon_bar.value = p
	crosshair.modulate.a = 0.35 if w is KatanaWeapon else 1.0
	(crosshair as Crosshair).spread = (w as MatchlockWeapon).spread() if w is MatchlockWeapon else 0.0
	crosshair.queue_redraw()



func _pulse_direction(src: Node, amount: float) -> void:
	if player == null or src == null or not (src is Node3D):
		return
	var to := (src as Node3D).global_position - player.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var local := player.global_transform.basis.inverse() * to.normalized()
	var fwd := -local.z
	var right := local.x
	var side: StringName = &"front"
	if absf(fwd) >= absf(right):
		side = &"front" if fwd > 0.0 else &"back"
	else:
		side = &"right" if right > 0.0 else &"left"
	var strength := clampf(amount / 40.0, 0.35, 1.0)
	(_dir_arrows[side] as DamageArrow).pulse(strength)


func _on_damage_dealt(attacker: Node, _victim: Node, _amount: float, _kind: StringName) -> void:
	if attacker == player:
		(marker as HitMarker).flash(false)
		AudioManager.play(&"hit_marker")


func _on_killed(victim: Node, killer: Node) -> void:
	if killer == player and victim != player:
		(marker as HitMarker).flash(true)
		AudioManager.play(&"kill_marker")


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


class HitMarker extends Control:
	var _t := 0.0
	var _kill := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(40, 40)
		position -= Vector2(20, 20)

	func flash(kill: bool) -> void:
		_t = 0.35 if kill else 0.2
		_kill = kill
		queue_redraw()

	func _process(delta: float) -> void:
		if _t > 0.0:
			_t -= delta
			queue_redraw()

	func _draw() -> void:
		if _t <= 0.0:
			return
		var c := Vector2(20, 20)
		var col := UIStyle.VERMILION if _kill else Color.WHITE
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + d * 7.0, c + d * 14.0, col, 3.0 if _kill else 2.0)


class Crosshair extends Control:
	## Matchlock spread in degrees (0 for the katana).
	var spread := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(24, 24)
		position -= Vector2(12, 12)

	func _draw() -> void:
		var c := Vector2(12, 12)
		var col := Color(1, 1, 1, 0.85)
		draw_circle(c, 2.0, col)
		var gap := 6.0 + spread * 6.0
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(c + d * gap, c + d * (gap + 5.0), col, 2.0)

class DamageArrow extends Control:
	## Minimal edge chevron: front/back/left/right of the screen.
	var side: StringName = &"front"
	var _str := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func pulse(strength: float) -> void:
		_str = maxf(_str, strength)
		queue_redraw()

	func tick(delta: float) -> void:
		if _str > 0.0:
			_str = maxf(0.0, _str - delta * 1.4)
			queue_redraw()

	func _draw() -> void:
		if _str <= 0.01:
			return
		var s := size
		var col := Color(0.85, 0.12, 0.08, 0.55 * _str)
		var w := 70.0
		var h := 14.0
		var pts: PackedVector2Array
		match side:
			&"front":
				var c := Vector2(s.x * 0.5, 36.0)
				pts = PackedVector2Array([c + Vector2(0, -h), c + Vector2(w * 0.5, h), c + Vector2(-w * 0.5, h)])
			&"back":
				var c := Vector2(s.x * 0.5, s.y - 36.0)
				pts = PackedVector2Array([c + Vector2(0, h), c + Vector2(w * 0.5, -h), c + Vector2(-w * 0.5, -h)])
			&"left":
				var c := Vector2(40.0, s.y * 0.5)
				pts = PackedVector2Array([c + Vector2(-h, 0), c + Vector2(h, w * 0.5), c + Vector2(h, -w * 0.5)])
			&"right":
				var c := Vector2(s.x - 40.0, s.y * 0.5)
				pts = PackedVector2Array([c + Vector2(h, 0), c + Vector2(-h, w * 0.5), c + Vector2(-h, -w * 0.5)])
		if pts.size() == 3:
			draw_colored_polygon(pts, col)

