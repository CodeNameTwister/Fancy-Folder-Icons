@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
var DOT_USER : String = "res://addons/fancy_folder_icons/user/fancy_folder_icons.dat"


var size : Vector2 = Vector2(12.0, 12.0) #ICON SIZE


var _buffer : Dictionary = {}
var _tree : Tree = null
var _busy : bool = false

var _menu_service : EditorContextMenuPlugin = null
var _popup : Window = null

var _is_saving : bool = false

var _ref_buffer : Dictionary = {}

var _scan_request : bool = false

func scan() ->void:
	if _scan_request:
		return
	_scan_request = true
	var rf : EditorFileSystem = EditorInterface.get_resource_filesystem()
	rf.scan()
	set_deferred(&"_scan_request", false)

func get_buffer() -> Dictionary:
	return _buffer
	
func _on_changes() -> void:
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		var packed : PackedStringArray = editor.get_changed_settings()
		if "plugin/fancy_folder_icons/save_location" in packed:
			var new_path : String = editor.get_setting("plugin/fancy_folder_icons/save_location")		
			if new_path.is_empty():
				editor.set_setting("plugin/fancy_folder_icons/save_location", DOT_USER)
			else:
				DOT_USER = new_path
			_setup(false)

func _init() -> void:
	var editor : EditorSettings = EditorInterface.get_editor_settings()
	if editor:
		if !editor.has_setting("plugin/fancy_folder_icons/save_location"):
			editor.set_setting("plugin/fancy_folder_icons/save_location", DOT_USER)
		else:
			var new_path : String = editor.get_setting("plugin/fancy_folder_icons/save_location")		
			if new_path.is_empty():
				editor.set_setting("plugin/fancy_folder_icons/save_location", DOT_USER)
			else:
				DOT_USER = new_path
		editor.settings_changed.connect(_on_changes)

func _setup(load_buffer : bool = true) -> void:
	var dir : String = DOT_USER.get_base_dir()
	if !DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		return
	#if DOT_USER == "res://addons/fancy_folder_icons/user/fancy_folder_icons.dat":
		#(?) Do not ignore a possible important folder.
		#if !FileAccess.file_exists(dir.path_join(".gdignore")):
			#var file : FileAccess = FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)
			#file.store_string("Fancy Folder Icons Saved Folder")
			#file.close()	
		
	if !load_buffer:
		return
		
	if !FileAccess.file_exists(DOT_USER):
		if FileAccess.file_exists("user://editor/fancy_folder_icons.dat"):
			var cfg : ConfigFile = ConfigFile.new()
			if OK != cfg.load("user://editor/fancy_folder_icons.dat"):return
			_buffer = cfg.get_value("DAT", "PTH", {})
			if _buffer.size() > 0 and _quick_save() == OK:
					print("[Fancy Folder Icons] Loaded from old version, now is secure manual delete: ", ProjectSettings.globalize_path("user://editor/fancy_folder_icons.dat"))
	else:
		var cfg : ConfigFile = ConfigFile.new()
		if OK != cfg.load(DOT_USER):return
		_buffer = cfg.get_value("DAT", "PTH", {})
		
	_clear_buff(_buffer)
	
func _clear_buff(buffer : Dictionary) -> void:
	for x : Variant in buffer.keys():
		var value : Variant = buffer[x]
		if x is String:
			if !DirAccess.dir_exists_absolute(x) and !FileAccess.file_exists(x):
				buffer.erase(x)
				continue
		if value is Texture2D:
			value = _resize_to_explorer_icon(value, x)
			buffer[x] = value

func _quick_save() -> int:
	var cfg : ConfigFile = ConfigFile.new()
	var result : int = -1
	if FileAccess.file_exists(DOT_USER):
		cfg.load(DOT_USER)
	cfg.set_value("DAT", "PTH", _buffer)
	result = cfg.save(DOT_USER)
	cfg = null
	set_deferred(&"_is_saving" , false)
	return result

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
	set_process(true)

func _update_draw(x : Variant) -> void:
	for __ : int in range(2):
		var tree : SceneTree = get_tree()
		if !is_instance_valid(tree):
			return
		await tree.process_frame
			
		if is_instance_valid(x):
			if x is Tree:
				var _root: TreeItem = x.get_root()
				if _root != null:
					var child : TreeItem = _root.get_first_child()
					if child == null or child.get_custom_color(0) == Color.GRAY:
						return
					child.set_custom_color(0, Color.GRAY)
					var value : Variant = _root.get_metadata(0)
					if value == null:
						if child:
							value = child.get_metadata(0)
							if value is String and (value == "Favorites" or DirAccess.dir_exists_absolute(value) or FileAccess.file_exists(value)):
								_explore(_root)
								return
					elif value is String:
						if FileAccess.file_exists(value):
							_explore(_root)
					elif value is RefCounted:
						if value.get(&"_saved_path") is String:
							_tabby_explore(_root)
			elif x is ItemList:
				if x.item_count > 0:
					var color : Color = x.get_item_custom_fg_color(0)
					if color != Color.GRAY:
						x.set_item_custom_fg_color(0, Color.GRAY)
						var m : Variant = x.get_item_metadata(0)
						if m is String and (DirAccess.dir_exists_absolute(m) or FileAccess.file_exists(m)):
							for y : int in x.item_count:
								var path : Variant = x.get_item_metadata(y)
								if path is String:
									if _buffer.has(path):
										if x.max_columns == 1:
											x.set_item_icon(y, _buffer[path])
										else:
											x.set_item_icon(y, _get_item_texture(_buffer[path]))
									elif path.get_extension().is_empty():
										var tmp : String = path.path_join("")
										if _buffer.has(tmp):
											if x.max_columns == 1:
												x.set_item_icon(y, _buffer[tmp])
											else:
												x.set_item_icon(y, _get_item_texture(_buffer[tmp]))
										else:
											path = path.substr(0, path.rfind("/", path.length()-2)).path_join("")
											if _buffer.has(path):
												if x.max_columns == 1:
													x.set_item_icon(y, _buffer[path])
												else:
													x.set_item_icon(y, _get_item_texture(_buffer[path]))
						elif m is Dictionary and m.has("path"):
							for y : int in x.item_count:
								var data : Variant = x.get_item_metadata(y)
								if data is Dictionary and data.has("path"):
									var path : Variant = data["path"]
									if path is String:
										if _buffer.has(path):
											if x.max_columns == 1:
												x.set_item_icon(y, _buffer[path])
											else:
												x.set_item_icon(y, _get_item_texture(_buffer[path]))
										elif path.get_extension().is_empty():
											var tmp : String = path.path_join("")
											if _buffer.has(tmp):
												if x.max_columns == 1:
													x.set_item_icon(y, _buffer[tmp])
												else:
													x.set_item_icon(y, _get_item_texture(_buffer[tmp]))
											else:
												path = path.substr(0, path.rfind("/", path.length()-2)).path_join("")
												if _buffer.has(path):
													if x.max_columns == 1:
														x.set_item_icon(y, _buffer[path])
													else:
														x.set_item_icon(y, _get_item_texture(_buffer[path]))
						else:
							if x is Control:
								if x.draw.is_connected(_update_draw):
									x.draw.disconnect(_update_draw)

func update() -> void:
	if _busy or _buffer.size() == 0 or _tree == null:
		return
	_busy = true
	for x : Variant in _ref_buffer.keys():
		if !is_instance_valid(x):
			_ref_buffer.erase(x)
			continue
		if x is Tree:
			var _root: TreeItem = x.get_root()
			if _root != null:
				var child : TreeItem = _root.get_first_child()
				if child == null:
					continue
				var value : Variant = _root.get_metadata(0)
				if value == null:
					if child:
						value = child.get_metadata(0)
						if value is String and (value == "Favorites" or DirAccess.dir_exists_absolute(value) or FileAccess.file_exists(value)):
							if !x.draw.is_connected(_update_draw):
								x.draw.connect(_update_draw.bind(x))
							_update_draw(x)
							continue
				elif value is String:
					if FileAccess.file_exists(value):
						if !x.draw.is_connected(_update_draw):
							x.draw.connect(_update_draw.bind(x))
						_update_draw(x)
						continue
				elif value is RefCounted:
					if value.get(&"_saved_path") is String:
						if !x.draw.is_connected(_update_draw):
							x.draw.connect(_update_draw.bind(x))
						_update_draw(x)
						continue
		elif x is ItemList:
			if !x.draw.is_connected(_update_draw):
				x.draw.connect(_update_draw.bind(x))
			if x.item_count > 0:
				var m : Variant = x.get_item_metadata(0)
				if m is String and (DirAccess.dir_exists_absolute(m) or FileAccess.file_exists(m)):
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
					_update_draw(x)
				elif m is Dictionary and m.has("path"):
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
					_update_draw(x)
				else:
					if !x.draw.is_connected(_update_draw):
						x.draw.connect(_update_draw.bind(x))
			continue
		
	set_deferred(&"_busy", false)

func _is_tabby(tree : Tree, root : TreeItem) -> bool:
	var meta : Variant = root.get_metadata(0)
	if meta is RefCounted:
		if meta.get(&"_saved_path") is String:
			if !tree.draw.is_connected(_update_draw):
				tree.draw.connect(_update_draw.bind(tree))
			return true
	return false

func _tabby_explore(item : TreeItem, texture : Texture2D = null, as_root : bool = true) -> void:
	var meta : Variant = item.get_metadata(0)
	if meta is RefCounted:
		meta = meta.get(&"_saved_path")
		if meta is String:
			if _buffer.has(meta):
				texture = _buffer[meta]
				as_root = true

			if texture != null:
				if as_root or !FileAccess.file_exists(meta):
					item.set_icon(0, texture)

			for i : TreeItem in item.get_children():
				_tabby_explore(i, texture, false)

func _explore(item : TreeItem, texture : Texture2D = null, as_root : bool = true) -> void:
	var meta : Variant = str(item.get_metadata(0))
	
	if _buffer.has(meta):
		texture = _buffer[meta]
		as_root = true

	if texture != null:
		if as_root or !FileAccess.file_exists(meta):
			item.set_icon(0, texture)

	for i : TreeItem in item.get_children():
		_explore(i, texture, false)

func _resize_to_explorer_icon(tx : Texture2D, key: Variant) -> Texture2D:
	if tx.get_size() != size:
		var tx_size : Vector2 = tx.get_size()		
		var img : Image = tx.get_image()
		var path : String = tx.resource_path
		
		if img.is_compressed():
			img.decompress()
		
		var mb : float = maxf(minf(tx_size.x, tx_size.y), size.x)
		tx_size.x = maxf(minf(tx_size.x - maxf(mb - size.x, 0.0), size.x), 1.0)
		tx_size.y = maxf(minf(tx_size.y - maxf(mb - size.y, 0.0), size.y), 1.0)
		
		if tx_size.x < size.x and tx_size.y < size.y:
			mb = maxf(tx_size.x, tx_size.y)
			tx_size.x += size.x - mb
			tx_size.y += size.y - mb
		
		img.resize(int(tx_size.x), int(tx_size.y), Image.INTERPOLATE_LANCZOS)
		tx = ImageTexture.create_from_image(img)
		
		if path.is_empty() or !FileAccess.file_exists(path):
			path = DOT_USER.get_base_dir().path_join(str(key).get_file())
			var index : int = 0
			var new_path : String = path + str(index) + ".png"
			while FileAccess.file_exists(new_path):
				#DUPLICATED
				if ResourceLoader.exists(new_path):
					var res : Resource = ResourceLoader.load(new_path)
					if res is Texture and res == tx:
						break
				
				index += 1
				new_path = path + str(index) + ".png"
			path = new_path
			ResourceSaver.save(tx, path)
			tx.resource_path = path
			scan.call_deferred()
		
		tx.set_meta(&"path", path)
	return tx

func _on_select_texture(tx : Texture2D, texture_path : String, _modulate : Color, paths : PackedStringArray) -> void:
	if tx.get_size() != size:
		print("Image selected '", texture_path.get_file(), "' size: ", tx.get_size(), " resized to ", size.x, "x", size.y)
		tx = _resize_to_explorer_icon(tx, texture_path)
		
	for p : String in paths:
		_buffer[p] = tx
	
	_def_update()
	save_queue()
	
	EditorInterface.get_resource_filesystem().scan()

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

func _ready() -> void:
	set_physics_process(false)
	var dock : FileSystemDock = EditorInterface.get_file_system_dock()
	var fs : EditorFileSystem = EditorInterface.get_resource_filesystem()
	
	_n(dock)
	_setup()

	if _tree.draw.is_connected(_update_draw):
		_tree.draw.connect(_update_draw.bind(_tree))

	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, _menu_service)

	dock.files_moved.connect(_moved_callback)
	dock.folder_moved.connect(_moved_callback)
	dock.folder_removed.connect(_remove_callback)
	dock.file_removed.connect(_remove_callback)
	dock.folder_color_changed.connect(_def_update)
	fs.filesystem_changed.connect(_def_update)

	_def_update()
#var _enable_icons_on_split : bool = true

func _on_child(n : Node) -> void:
	if n is Tree:
		if !_ref_buffer.has(n):
			_ref_buffer[n] = null
			_def_update()
	if n is ItemList:
		if !_ref_buffer.has(n):
			_ref_buffer[n] = null
			_def_update()
	for x : Node in n.get_children():
		_on_child(x)

func _enter_tree() -> void:
	var root : Node = get_tree().root
	get_tree().node_added.connect(_on_child)
	_on_child(root)

	_menu_service = ResourceLoader.load("res://addons/fancy_folder_icons/menu_fancy.gd").new()
	_menu_service.iconize_paths.connect(_on_iconize)
	
	var vp : Viewport = Engine.get_main_loop().root
	vp.focus_entered.connect(_on_wnd)
	vp.focus_exited.connect(_out_wnd)
			
func _exit_tree() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()

	if is_instance_valid(_menu_service):
		remove_context_menu_plugin(_menu_service)

	if get_tree().node_added.is_connected(_on_child):
		get_tree().node_added.disconnect(_on_child)
			

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
		editor.settings_changed.disconnect(_on_changes)
	

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

func _process(_delta: float) -> void:
	set_process(false)
	update()
	
#region rescue_fav
func _n(n : Node) -> bool:
	if n is Tree:
		var t : TreeItem = (n.get_root())
		if null != t:
			t = t.get_first_child()
			while t != null:
				if t.get_metadata(0) == "res://":
					_tree = n
					var tx : Texture2D = t.get_icon(0)
					if tx:
						size = tx.get_size()
					return true
				t = t.get_next()
	for x in n.get_children():
		if _n(x): return true
	return false
#endregion

func _get_item_texture(texture : Texture2D) -> Texture2D:
	if texture.get_size() != size:
		return texture
	else:
		var path : String = texture.resource_path
		if path.is_empty() and texture.has_meta(&"path"):
			path = texture.get_meta(&"path")
		if path.get_extension() != "svg" and not FileAccess.file_exists(path):
			return texture
		
		if !ResourceLoader.exists(path):
			var image : Image = Image.load_from_file(path)
			if is_instance_valid(image):
				if image.is_compressed():
					image.decompress()
				var tx : Texture2D = ImageTexture.create_from_image(image)
				if tx is Texture2D:
					return tx
			else:
				return null
		return ResourceLoader.load(path)
