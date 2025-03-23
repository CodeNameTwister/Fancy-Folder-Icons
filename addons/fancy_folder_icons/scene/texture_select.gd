@tool
extends TextureRect
#{
	#"type": "plugin",
	#"codeRepository": "https://github.com/CodeNameTwister",
	#"description": "Fancy Folder Icons addon for godot 4",
	#"license": "https://spdx.org/licenses/MIT",
	#"name": "Twister",
	#"version": "1.0.1.1"
#}

var _nxt : Color = Color.DARK_GRAY
var _fps : float = 0.0

var path : String = ""

func _set(property: StringName, value: Variant) -> bool:
	if property == &"texture":
		if null != value and value is Texture2D:
			var new_path : String = (value as Texture2D).resource_path
			if !new_path.is_empty():
				path = new_path
			if value.get_size() != Vector2(16.0, 16.0):
				var img : Image = value.get_image()
				img.resize(16, 16)
				texture = ImageTexture.create_from_image(img)
				return true
	return false

func _ready() -> void:
	set_process(false)
	gui_input.connect(_on_gui)

func _on_gui(i : InputEvent) -> void:
	if i is InputEventMouseButton:
		if i.button_index == 1 and i.pressed:
			owner.select_texture(texture, path)

func enable() -> void:
	set_process(true)

func reset() -> void:
	set_process(false)
	modulate = Color.WHITE
	_nxt = Color.DARK_GRAY

func _process(delta: float) -> void:
	_fps += delta * 4.0
	if _fps >= 1.0:
		_fps = 0.0
		modulate = _nxt
		if _nxt == Color.DARK_GRAY:
			_nxt = Color.WHITE
		else:
			_nxt = Color.DARK_GRAY
		return
	modulate = lerp(modulate, _nxt, _fps)
