@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
const DOT_USER : String = "user://editor/fancy_folder_icons.dat"

var _buffer : Dictionary = {}
var _tree : Tree = null
var _busy : bool = false

var _menu_service : EditorContextMenuPlugin = null
var _popup : Window = null

var _tchild : TreeItem = null
var _tdelta : int = 0

func _setup() -> void:
	var dir : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	if FileAccess.file_exists(DOT_USER):
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		_buffer = cfg.get_value("DAT", "PTH", {})

#region callbacks
func _moved_callback(a : String, b : String ) -> void:
	if a != b:
		if _buffer.has(a):
			_buffer[b] = _buffer[a]
			_buffer.erase(a)

func _remove_callback(path : String) -> void:
	if _buffer.has(path):
		_buffer.erase(path)
#endregion

func _def_update() -> void:
	update.call_deferred()

func update() -> void:
	if _buffer.size() == 0:return
	if _busy:return
	_busy = true
	var root : TreeItem = _tree.get_root()
	var item : TreeItem = root.get_first_child()

	while null != item and item.get_metadata(0) != "res://":
		item = item.get_next()

	_explore(item)
	set_deferred(&"_busy", false)

func _explore(item : TreeItem, texture : Texture2D = null, as_root : bool = true) -> void:
	var meta : String = str(item.get_metadata(0))
	if _buffer.has(meta):
		texture = _buffer[meta]
		as_root = true

	if texture != null:
		if as_root or !FileAccess.file_exists(meta):
			item.set_icon(0, texture)

	for i : TreeItem in item.get_children():
		_explore(i, texture, false)

func _get_dummy_tree_node() -> void:
	set_physics_process(false)
	var root : TreeItem = _tree.get_root()
	if root:
		_tchild = root.get_first_child()
	if is_instance_valid(_tchild):
		set_physics_process(true)

func _on_select_texture(tx : Texture2D, texture_path : String, paths : PackedStringArray) -> void:
	if tx.get_size() != Vector2(16, 16):
		print("Image selected '", texture_path.get_file(), "' size: ", tx.get_size(), " resized to 16x16")
		var img : Image = tx.get_image()
		img.resize(16, 16)
		tx = ImageTexture.create_from_image(img)
	for p : String in paths:
		_buffer[p] = tx
	_def_update()

func _on_reset_texture(paths : PackedStringArray) -> void:
	for p : String in paths:
		if _buffer.has(p):
			_buffer.erase(p)
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	if fs: fs.filesystem_changed.emit()

func _on_iconize(paths : PackedStringArray) -> void:
	const PATH : String = "res://addons/fancy_folder_icons/scene/icon_selector.tscn"
	var pop : Window = get_node_or_null("_POP_ICONIZER_")
	if pop == null:
		pop = (ResourceLoader.load(PATH) as PackedScene).instantiate()
		pop.name = "_POP_ICONIZER_"
		add_child(pop)
	if pop.on_set_texture.is_connected(_on_select_texture):
		pop.on_set_texture.disconnect(_on_select_texture)
	if pop.on_reset_texture.is_connected(_on_reset_texture):
		pop.on_reset_texture.disconnect(_on_reset_texture)
	pop.on_set_texture.connect(_on_select_texture.bind(paths))
	pop.on_reset_texture.connect(_on_reset_texture.bind(paths))
	pop.popup_centered()

func _ready() -> void:
	set_physics_process(false)
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	_n(dock)

	_get_dummy_tree_node()

	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _menu_service)

	dock.files_moved.connect(_moved_callback)
	dock.folder_moved.connect(_moved_callback)
	dock.folder_removed.connect(_remove_callback)
	dock.file_removed.connect(_remove_callback)
	dock.folder_color_changed.connect(_def_update)
	fs.filesystem_changed.connect(_def_update)

	_def_update()

func _enter_tree() -> void:
	_setup()

	_menu_service = ResourceLoader.load("res://addons/fancy_folder_icons/menu_fancy.gd").new()
	_menu_service.iconize_paths.connect(_on_iconize)

func _exit_tree() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()

	if is_instance_valid(_menu_service):
		remove_context_menu_plugin(_menu_service)

	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	if dock.files_moved.is_connected(_moved_callback):
		dock.files_moved.disconnect(_moved_callback)
	if dock.folder_moved.is_connected(_moved_callback):
		dock.folder_moved.disconnect(_moved_callback)
	if dock.folder_removed.is_connected(_remove_callback):
		dock.folder_removed.disconnect(_remove_callback)
	if dock.file_removed.is_connected(_remove_callback):
		dock.file_removed.disconnect(_remove_callback)
	if dock.folder_color_changed.is_connected(_def_update):
		dock.folder_color_changed.disconnect(_def_update)
	if fs.filesystem_changed.is_connected(_def_update):
		fs.filesystem_changed.disconnect(_def_update)

	#region user_dat
	var cfg : ConfigFile = ConfigFile.new()
	for k : String in _buffer.keys():
		if !DirAccess.dir_exists_absolute(k) and !FileAccess.file_exists(k):
			_buffer.erase(k)
			continue
	cfg.set_value("DAT", "PTH", _buffer)
	if OK != cfg.save(DOT_USER):
		push_warning("Error on save HideFolders!")
	#endregion

	_menu_service = null
	_buffer.clear()

	if !fs.is_queued_for_deletion():
		fs.filesystem_changed.emit()

#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			while t != null:
				if t.get_metadata(0) == "res://":
					_tree = n
					return true
				t = t.get_next()
	for x in n.get_children():
		if _n(x): return true
	return false
#endregion

func _physics_process(_delta: float) -> void:
	_tdelta += 1
	if _tdelta > 60:
		_tdelta = 0
		if !is_instance_valid(_tchild):
			_get_dummy_tree_node()
			_def_update()
