@tool
extends TextureRect
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

var _nxt : Color = Color.DARK_GRAY
var _fps : float = 0.0

var path : String = ""

func _set(property: StringName, value: Variant) -> bool:
	if property == &"texture":
		if null != value:
			if value is Resource:
				var new_path : String = (value as Resource).resource_path
				if !new_path.is_empty():
					path = new_path
			
			if value is Texture2D:
				if value.get_size() != Vector2(16.0, 16.0):
					var img : Image = value.get_image()
					img.resize(16, 16)
					texture = ImageTexture.create_from_image(img)
					return true
		if path.is_empty():
			path = str(get_index())
		texture = value
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
