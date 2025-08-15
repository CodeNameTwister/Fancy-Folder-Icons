@tool
extends Control
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
const DOT_USER : String = "user://editor/fancy_folder_icon_recents.dat"

func reorder(new_tx : Texture2D) -> void:
	if is_instance_valid(new_tx):
		var exist : bool = false
		var last_path : String = new_tx.resource_path
		for x : Node in get_children():
			if x is TextureRect:
				if x.texture != null:
					if (!last_path.is_empty() and last_path == x.path) or new_tx == x.texture:
						if x.texture != new_tx:
							x.texture = new_tx
						exist = true
						break
		if exist:
			return
		var last_texture : Texture2D = new_tx
		for x : Node in get_children():
			if x is TextureRect:
				var _current_texture : Texture2D = x.texture
				var _current_path : String = x.path
				x.path = last_path
				x.texture = last_texture
				last_texture = _current_texture
				last_path = _current_path
				x.queue_redraw()

func enable_by_path(p : String) -> void:
	for x : Node in get_children():
		if x is TextureRect:
			if null != x.texture:
				if x.path == p:
					x.enable()
				else:
					x.reset()

func _setup() -> void:
	var folder : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_absolute(folder)
		return
	if FileAccess.file_exists(DOT_USER):
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		var _icons : PackedStringArray = cfg.get_value("RECENTS", "ICONS", [])

		var append : Array[Texture2D] = []
		for x : String in _icons:
			if FileAccess.file_exists(x):
				if ResourceLoader.exists(x):
					var r : Resource = ResourceLoader.load(x)
					if r is Texture2D:
						append.append(r)
						if append.size() >= get_child_count():break
				else:
					var image : Image = Image.load_from_file(x)
					if is_instance_valid(image):
						if image.is_compressed():
							image.decompress()
						var tx : Texture2D = ImageTexture.create_from_image(image)
						if tx is Texture2D:
							append.append(tx)
							if append.size() >= get_child_count():break

		if append.size() > 0:
			var index : int = 0
			for x : Node in get_children():
				if x is TextureRect:
					var tx : Variant = append[index]
					if tx is Texture2D:
						x.texture = tx
						x.path = tx.resource_path
					index += 1
					if index >= append.size():break

func _on_exit() -> void:
	var pack : PackedStringArray = []
	for x : Node in get_children():
		if x is TextureRect:
			var tx : Texture2D = x.texture
			if null != tx:
				var path : String = x.path
				if path.is_empty():continue
				pack.append(path)
	if pack.size() > 0:
		var cfg : ConfigFile = ConfigFile.new()
		cfg.set_value("RECENTS", "ICONS", pack)
		if OK != cfg.save(DOT_USER):
			push_warning("Can not save recent icons changes!")


func _ready() -> void:
	_setup()
	tree_exiting.connect(_on_exit)
