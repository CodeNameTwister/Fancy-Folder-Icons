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
		set_meta(&"path", null)
		if null != value:
			if value is Resource:
				var new_path : String = (value as Resource).resource_path
				if !new_path.is_empty():
					path = new_path
			if value is Texture2D:
				value.set_meta(&"path", value.resource_path)
		if path.is_empty():
			path = str(get_index())
		texture = value
		return true
	return false

func _ready() -> void:
	set_process(false)
	gui_input.connect(_on_gui)
	# I prevent using UID because of some bugs sometimes, Maybe i'll lose my fear of UIDs in future versions of Godot.
	path = "res://addons/fancy_folder_icons/samples/Folder.svg"
	if is_instance_valid(texture):
		if texture.resource_path == null:
			texture = null
		else:
			path = texture.resource_path
	else:
		#Placeholder
		texture = ResourceLoader.load("res://addons/fancy_folder_icons/samples/Folder.svg")
		path = texture.resource_path
	set_meta(&"path", path)

func _on_gui(i : InputEvent) -> void:
	if i is InputEventMouseButton:
		if i.button_index == 1 and i.pressed:
			if texture == null:
				return
			owner.select_texture(texture, path, modulate)

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
