class_name ConquestHUD
extends Control
## Conquest overlay: tickets for both sides, the A/B/C strip (owner colour, capture progress,
## contested flash), a capture bar while the player stands on a point, the scoreboard (hold Tab)
## and the victory / defeat screen.

signal fight_again
signal return_to_menu

var conquest: ConquestMode
var battle: Node
var player_faction := 0

var _tickets: Array[Label] = []
var _ticket_bars: Array[ProgressBar] = []
var _chips: Dictionary = {}  # CapturePoint -> {panel, label, bar, style}
var _capture_box: VBoxContainer
var _capture_label: Label
var _capture_bar: ProgressBar
var _scoreboard: PanelContainer
var _score_text: RichTextLabel
var _end: PanelContainer
var _end_title: Label
var _end_detail: Label
var _time := 0.0


func setup(cq: ConquestMode, b: Node, player_side: int) -> void:
	conquest = cq
	battle = b
	player_faction = player_side
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_capture_box()
	_build_scoreboard()
	_build_end_screen()


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 14
	bar.offset_bottom = 90
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var sides := [player_faction, 1 - player_faction]
	for i in 2:
		var f: int = sides[i]
		var box := VBoxContainer.new()
		box.custom_minimum_size.x = 170
		var name_l := UIStyle.label("YOUR ARMY" if f == player_faction else "ENEMY", 14, UIStyle.MUTED)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var t := UIStyle.label("0", 30, UIStyle.FACTION_COLORS[f])
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(170, 6)
		pb.max_value = conquest.config.starting_tickets
		pb.fill_mode = ProgressBar.FILL_BEGIN_TO_END if i == 1 else ProgressBar.FILL_END_TO_BEGIN
		pb.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.FACTION_COLORS[f]))
		box.add_child(name_l)
		box.add_child(t)
		box.add_child(pb)
		_tickets.append(t)
		_ticket_bars.append(pb)
		if i == 0:
			bar.add_child(box)
			for cp in conquest.points:
				bar.add_child(_make_chip(cp))
		else:
			bar.add_child(box)


func _make_chip(cp: CapturePoint) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_border_width_all(3)
	style.border_color = cp.color()
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var l := UIStyle.label(String(cp.objective_id), 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(44, 5)
	pb.max_value = 1.0
	box.add_child(pb)
	_chips[cp] = {"panel": panel, "label": l, "bar": pb, "style": style}
	return panel


func _build_capture_box() -> void:
	_capture_box = VBoxContainer.new()
	_capture_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_capture_box.offset_top = 112
	_capture_box.offset_bottom = 160
	_capture_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_capture_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_box.visible = false
	add_child(_capture_box)
	_capture_label = UIStyle.label("", 20)
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_capture_box.add_child(_capture_label)
	_capture_bar = ProgressBar.new()
	_capture_bar.show_percentage = false
	_capture_bar.custom_minimum_size = Vector2(320, 10)
	_capture_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_capture_bar.max_value = 1.0
	_capture_box.add_child(_capture_bar)


func _build_scoreboard() -> void:
	_scoreboard = PanelContainer.new()
	_scoreboard.custom_minimum_size = Vector2(640, 0)
	_scoreboard.visible = false
	add_child(_centered(_scoreboard))
	_score_text = RichTextLabel.new()
	_score_text.bbcode_enabled = true
	_score_text.fit_content = true
	_score_text.custom_minimum_size = Vector2(600, 200)
	_score_text.add_theme_font_size_override("normal_font_size", 17)
	_score_text.add_theme_font_size_override("bold_font_size", 17)
	_scoreboard.add_child(_score_text)


func _build_end_screen() -> void:
	_end = PanelContainer.new()
	_end.custom_minimum_size = Vector2(460, 0)
	_end.visible = false
	add_child(_centered(_end))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_end.add_child(box)
	_end_title = UIStyle.label("", 64)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_title)
	_end_detail = UIStyle.label("", 20)
	_end_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_end_detail)
	var again := UIStyle.button("Fight again", func() -> void: fight_again.emit(), &"ui_confirm")
	again.name = "FightAgain"
	box.add_child(again)
	box.add_child(UIStyle.button("Return to menu", func() -> void: return_to_menu.emit(), &"ui_back"))


func _centered(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


func show_end(winner: int) -> void:
	_end.visible = true
	_scoreboard.visible = false
	_capture_box.visible = false
	var won := winner == player_faction
	_end_title.text = "VICTORY" if won else ("DEFEAT" if winner >= 0 else "DRAW")
	_end_title.add_theme_color_override("font_color", UIStyle.GOLD if won else UIStyle.VERMILION)
	var p: Soldier = battle.player
	_end_detail.text = "Tickets  %d : %d\nYour kills %d   deaths %d" % [
		conquest.ticket_count(player_faction), conquest.ticket_count(1 - player_faction), p.kills, p.deaths]
	(_end.find_child("FightAgain", true, false) as Button).call_deferred("grab_focus")


func is_end_visible() -> bool:
	return _end.visible


func _process(delta: float) -> void:
	if conquest == null:
		return
	_time += delta
	var sides := [player_faction, 1 - player_faction]
	for i in 2:
		_tickets[i].text = str(conquest.ticket_count(sides[i]))
		_ticket_bars[i].value = conquest.ticket_count(sides[i])
	for cp: CapturePoint in _chips:
		var chip: Dictionary = _chips[cp]
		var c := cp.color()
		if cp.contested:
			c = c.lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 10.0))
		(chip.style as StyleBoxFlat).border_color = c
		(chip.label as Label).add_theme_color_override("font_color", c)
		var bar := chip.bar as ProgressBar
		bar.value = absf(cp.progress)
		var lead := 0 if cp.progress > 0.0 else 1
		bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(UIStyle.FACTION_COLORS[lead]))
	_update_capture_box()
	_scoreboard.visible = Input.is_action_pressed("scoreboard") and not _end.visible
	if _scoreboard.visible:
		_update_scoreboard()


func _update_capture_box() -> void:
	var p: Soldier = battle.player
	var here: CapturePoint = null
	if p and p.alive and not _end.visible:
		for cp in conquest.points:
			if p.global_position.distance_to(cp.global_position) < cp.radius:
				here = cp
	_capture_box.visible = here != null
	if here == null:
		return
	var mine := here.owner_faction == player_faction
	var ours := (here.progress > 0.0) == (player_faction == 0)
	if here.contested:
		_capture_label.text = "%s — CONTESTED" % here.objective_id
	elif mine and absf(here.progress) >= 1.0:
		_capture_label.text = "%s — held" % here.objective_id
	elif here.owner_faction == 1 - player_faction:
		_capture_label.text = "Neutralising %s" % here.objective_id
	else:
		_capture_label.text = "Capturing %s" % here.objective_id
	_capture_bar.value = absf(here.progress)
	var col: Color = UIStyle.FACTION_COLORS[player_faction if ours else 1 - player_faction]
	_capture_bar.add_theme_stylebox_override("fill", UIStyle.bar_fill(col))


func _update_scoreboard() -> void:
	var t := ""
	for f in [player_faction, 1 - player_faction]:
		var col := (UIStyle.FACTION_COLORS[f] as Color).to_html(false)
		t += "[color=#%s][b]%s — %d tickets[/b][/color]\n" % [col, "YOUR ARMY" if f == player_faction else "ENEMY", conquest.ticket_count(f)]
		t += "[table=3][cell][color=#9a958c]Soldier[/color][/cell][cell][color=#9a958c]  Kills[/color][/cell][cell][color=#9a958c]  Deaths[/color][/cell]"
		var rows: Array = battle.soldiers.filter(func(s: Soldier) -> bool: return s.faction == f)
		rows.sort_custom(func(a: Soldier, b: Soldier) -> bool:
			return a.is_player or (not b.is_player and a.kills > b.kills))
		for s: Soldier in rows.slice(0, 8):
			var who := "You" if s.is_player else s.display_name
			var b0 := "[b][color=#d7ad4f]" if s.is_player else ""
			var b1 := "[/color][/b]" if s.is_player else ""
			t += "[cell]%s%s%s[/cell][cell]  %s%d%s[/cell][cell]  %s%d%s[/cell]" % [b0, who, b1, b0, s.kills, b1, b0, s.deaths, b1]
		t += "[/table]\n\n"
	_score_text.text = t
