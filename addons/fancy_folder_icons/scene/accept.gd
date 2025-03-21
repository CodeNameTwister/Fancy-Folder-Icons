@tool
extends Button
#{
	#"type": "plugin",
	#"codeRepository": "https://github.com/CodeNameTwister",
	#"description": "Fancy Folder Icons addon for godot 4",
	#"license": "https://spdx.org/licenses/MIT",
	#"name": "Twister",
	#"version": "1.0.1"
#}
var _nx : Color = Color.YELLOW
var _delta : float = 0.0

func _process(delta: float) -> void:
	_delta += delta * 4.0
	if _delta >= 1.0:
		_delta = 0.0
		set(&"theme_override_colors/font_color", _nx)
		if _nx == Color.YELLOW:
			_nx = Color.DARK_GRAY
		else:
			_nx = Color.YELLOW
		return
	var c_color : Color = get(&"theme_override_colors/font_color")
	set(&"theme_override_colors/font_color", lerp(c_color, _nx, _delta))

func _ready() -> void:
	set_process(false)
	disabled = true
	owner.enable_accept_changes_button.connect(_on_enable)
	set(&"theme_override_colors/font_color", Color.WHITE)

func _on_enable(e : bool) -> void:
	disabled = !e
	set_process(e)
	if !e:
		set(&"theme_override_colors/font_color", Color.WHITE)

func _on_pressed() -> void:
	owner.accept_changes()
