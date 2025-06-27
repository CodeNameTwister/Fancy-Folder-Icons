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

var _docky : Docky = null

var size : Vector2 = Vector2(12.0, 12.0)

var _is_saving : bool = false

func get_buffer() -> Dictionary:
	return _buffer

class Docky extends RefCounted:
	var drawing : bool = false
	var dock : ItemList = null
	
	var plugin : Object = null
	
	func _init(set_plugin : Object) -> void:
		plugin = set_plugin
	
	func update_icons() -> void:
		if !dock:
			return
		var buffer : Dictionary = plugin.get_buffer()
		var mt : Dictionary = {}
		
		for x : int in dock.item_count:
			var data : String = str(dock.get_item_metadata(x))
			mt[data] = [x, 0]
		
		for key : String in buffer.keys():
			for m : String in mt.keys():
				if m == key:
					mt[m][1] = m.length() + 1
					dock.set_item_icon(mt[m][0], buffer[key])
					
				elif m.get_extension().is_empty() and m.begins_with(key):
					var l : int = key.length()
					if mt[m][1] < l:
						mt[m][1] = l
						dock.set_item_icon(mt[m][0], buffer[key])
		_dispose.call_deferred()
		return
		
	func _dispose() -> void:
		var o : Variant = self
		for __ : int in range(2):
			await Engine.get_main_loop().process_frame
		if is_instance_valid(o):
			o.set_deferred(&"drawing", false)
	
	func _on_change() -> void:
		if drawing:
			return
		drawing = true
		update_icons.call_deferred()
	
	func update(new_dock : ItemList) -> void:
		dock = new_dock
		
		if !dock.draw.is_connected(_on_change):
			dock.draw.connect(_on_change)
		
		#if dock.item_count > 0:
			#var icon : Texture2D = dock.get_item_icon(0)

func _setup() -> void:
	var dir : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	if FileAccess.file_exists(DOT_USER):
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		_buffer = cfg.get_value("DAT", "PTH", {})

func _quick_save() -> void:
	if FileAccess.file_exists(DOT_USER):
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		cfg.set_value("DAT", "PTH", _buffer)
		cfg = null
	set_deferred(&"_is_saving" , false)

#region callbacks
func _moved_callback(a0 : String, b0 : String ) -> void:
	if a0 != b0:
		if _buffer.has(a0):
			_buffer[b0] = _buffer[a0]
			_buffer.erase(a0)
			save_queue()

func _remove_callback(path : String) -> void:
	if _buffer.has(path):
		_buffer.erase(path)
		save_queue()
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

	if _enable_icons_on_split:
		var dock : ItemList = get_docky()
		if dock:
			if !is_instance_valid(_docky):
				_docky = Docky.new(self)
			_docky.update(dock)
		elif is_instance_valid(_docky):
			_docky = null
	elif is_instance_valid(_docky):
		_docky = null

	_explore(item)
	
	if is_instance_valid(_docky):
		_docky.update_icons()
		
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
		var icon_size : Texture2D = _tchild.get_icon(0)
		if icon_size:
			size = icon_size.get_size()
		set_physics_process(true)

func _on_select_texture(tx : Texture2D, texture_path : String, paths : PackedStringArray) -> void:
	if tx.get_size() != size:
		print("Image selected '", texture_path.get_file(), "' size: ", tx.get_size(), " resized to ", size.x, "x", size.y)
		var img : Image = tx.get_image()
		img.resize(int(size.x), int(size.y))
		tx = ImageTexture.create_from_image(img)
	for p : String in paths:
		_buffer[p] = tx
	_def_update()
	save_queue()

func save_queue() -> void:
	if _is_saving:
		return
	_is_saving = true
	_quick_save.call_deferred()

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
		pop.plugin = self
		add_child(pop)
	if pop.on_set_texture.is_connected(_on_select_texture):
		pop.on_set_texture.disconnect(_on_select_texture)
	if pop.on_reset_texture.is_connected(_on_reset_texture):
		pop.on_reset_texture.disconnect(_on_reset_texture)
	pop.on_set_texture.connect(_on_select_texture.bind(paths))
	pop.on_reset_texture.connect(_on_reset_texture.bind(paths))
	pop.popup_centered()

func get_docky() -> ItemList:
	var out : ItemList = null
	var dock : Control = EditorInterface.get_file_system_dock()
	if dock:
		out = dock.find_child("*FileSystemList*", true, false)
	return out
	

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


var _enable_icons_on_split : bool = true
func _enter_tree() -> void:
	_setup()

	_menu_service = ResourceLoader.load("res://addons/fancy_folder_icons/menu_fancy.gd").new()
	_menu_service.iconize_paths.connect(_on_iconize)
	
	var vp : Viewport = Engine.get_main_loop().root
	vp.focus_entered.connect(_on_wnd)
	vp.focus_exited.connect(_out_wnd)
	
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		editor.settings_changed.connect(_on_change_settings)
		if !editor.has_setting("plugin/fancy_folder_icons/enable_icons_on_split"):
			editor.set_setting("plugin/fancy_folder_icons/enable_icons_on_split", true)
		else:
			_enable_icons_on_split = editor.get_setting("plugin/fancy_folder_icons/enable_icons_on_split")

func _on_change_settings() -> void:
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		var settings : PackedStringArray = editor.get_changed_settings()
		if "plugin/fancy_folder_icons/enable_icons_on_split" in settings:
			_enable_icons_on_split = editor.get_setting("plugin/fancy_folder_icons/enable_icons_on_split")
			
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

	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		editor.settings_changed.disconnect(_on_change_settings)
	

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
		
	var vp : Viewport = Engine.get_main_loop().root
	vp.focus_entered.disconnect(_on_wnd)
	vp.focus_exited.disconnect(_out_wnd)
	
func _on_wnd() -> void:set_physics_process(true)
func _out_wnd() -> void:set_physics_process(false)

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
