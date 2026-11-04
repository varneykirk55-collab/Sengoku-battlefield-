class_name PauseMenu
extends CanvasLayer
## Esc / Start: pauses the battle. Resume, settings, or leave to the main menu.

signal quit_to_menu

var _panel: PanelContainer
var _menu: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.make_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 12)
	_panel.add_child(_menu)
	_menu.add_child(UIStyle.label("PAUSED", 30, UIStyle.GOLD))
	_menu.add_child(UIStyle.button("Resume", close, &"ui_back"))
	_menu.add_child(UIStyle.button("Settings", _open_settings))
	_menu.add_child(UIStyle.button("Leave the battle", func() -> void: quit_to_menu.emit(), &"ui_back"))
	visible = false


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play(&"ui_confirm")
	_menu.get_child(1).call_deferred("grab_focus")


func close() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
		_panel.visible = true
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	_panel.visible = false
	_settings = SettingsPanel.new()
	(_panel.get_parent() as Control).add_child(_settings)
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_settings = null
		_panel.visible = true
		_menu.get_child(2).call_deferred("grab_focus"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			if _settings:
				_settings.closed.emit()
			else:
				close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventMouseButton:
		pass
	elif not visible and event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # click back into the game window
