extends Node
## Registers every input action at startup so keyboard/mouse and gamepad bindings live in one place.
## (Same approach as Kengeki's GameInput.) Actions can be rebound later through InputMap.
##
## Weapon actions are context-sensitive:
##   katana     primary = light attack, secondary = heavy attack
##   matchlock  primary = fire,         secondary = aim (hold)

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"reload": [KEY_R],
	"switch_weapon": [KEY_Q],
	"weapon_katana": [KEY_1],
	"weapon_matchlock": [KEY_2],
	"toggle_camera": [KEY_V],
	"scoreboard": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}

const MOUSE := {
	"primary": [MOUSE_BUTTON_LEFT],
	"secondary": [MOUSE_BUTTON_RIGHT],
	"switch_weapon": [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN],
}

const JOY_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	"reload": [JOY_BUTTON_X],
	"switch_weapon": [JOY_BUTTON_Y],
	"weapon_katana": [JOY_BUTTON_DPAD_LEFT],
	"weapon_matchlock": [JOY_BUTTON_DPAD_RIGHT],
	"toggle_camera": [JOY_BUTTON_DPAD_UP],
	"scoreboard": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
}

## action: [axis, direction]
const JOY_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"primary": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"secondary": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

## All gameplay actions (used by tests to confirm every action has both a PC and a gamepad binding).
static func gameplay_actions() -> Array[String]:
	var out: Array[String] = []
	for table in [KEYS, MOUSE, JOY_BUTTONS, JOY_AXES]:
		for action: String in table:
			if not out.has(action):
				out.append(action)
	return out


func _enter_tree() -> void:
	for action: String in KEYS:
		_ensure(action)
		for keycode in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			_add(action, ev)
	for action: String in MOUSE:
		_ensure(action)
		for button in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			_add(action, ev)
	for action: String in JOY_BUTTONS:
		_ensure(action)
		for button in JOY_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			_add(action, ev)
	for action: String in JOY_AXES:
		_ensure(action, 0.2)
		var ev := InputEventJoypadMotion.new()
		ev.axis = JOY_AXES[action][0]
		ev.axis_value = JOY_AXES[action][1]
		_add(action, ev)


func _ensure(action: String, deadzone: float = 0.5) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


## Right-stick look vector (x = yaw, y = pitch), already scaled by the gamepad sensitivity setting.
func look_vector() -> Vector2:
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	return v * float(Settings.get_value("controls/gamepad_sensitivity"))
