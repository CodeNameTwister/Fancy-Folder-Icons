@tool
extends HBoxContainer
#{
	#"type": "plugin",
	#"codeRepository": "https://github.com/CodeNameTwister",
	#"description": "Fancy Folder Icons addon for godot 4",
	#"license": "https://spdx.org/licenses/MIT",
	#"name": "Twister",
	#"version": "1.0.1"
#}
const DOT_USER : String = "user://editor/fancy_folder_icon_recents.dat"

func reorder(new_tx : Texture2D) -> void:
	var exist : bool = false
	for x : Node in get_children():
		if x is TextureRect:
			if new_tx == x.texture:
				exist = true
				break
	if exist:return
	for x : Node in get_children():
		if x is TextureRect:
			var last : Texture2D = x.texture
			x.texture = new_tx
			new_tx = last

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
				var r : Resource = ResourceLoader.load(x)
				if r is Texture2D:
					append.append(r)
					if append.size() >= get_child_count():break

		if append.size() > 0:
			var index : int = 0
			for x : Node in get_children():
				if x is TextureRect:
					x.texture = append[index]
					index += 1
					if index >= append.size():break

func _on_exit() -> void:
	var pack : PackedStringArray = []
	for x : Node in get_children():
		if x is TextureRect:
			var tx : Texture2D = x.texture
			if null != tx:
				var path : String = tx.path
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
