@tool
extends EditorPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
const DOT_USER: String = "user://editor/fancy_folder_icons.dat"
const RULES_FILE = "user://fancy_folder_icons_rules.json"
var largeIconCache := {}
var smallIconCache := {}
var rules: Dictionary = {}

var _buffer: Dictionary = {}
var _tree: Tree = null
var _busy: bool = false

var _menu_service: EditorContextMenuPlugin = null
var _popup: Window = null

var _tchild: TreeItem = null
var _tdelta: int = 0

var _docky: Docky = null

var size: Vector2 = Vector2(12.0, 12.0)

var _is_saving: bool = false

var textureAppliesToNestedFolders := true
func get_buffer() -> Dictionary:
  var buffer = _buffer
  for key in rules:
    buffer[key] = rules[key]
  return buffer

class Docky extends RefCounted:
  var drawing: bool = false
  var dock: ItemList = null
  
  var plugin: Object = null
  
  func _init(set_plugin: Object) -> void:
    plugin = set_plugin

  func update_icons() -> void:
    if !dock:
      return
    var buffer: Dictionary = plugin.get_buffer()
    var mt: Dictionary = {}
    
    for x: int in dock.item_count:
      var data: String = str(dock.get_item_metadata(x))
      mt[data] = [x, 0]
    # log.pp(mt, buffer)
    for m: String in mt.keys():
      for key: String in buffer.keys():
        if plugin.matches(key, m, buffer[key]):
          # log.pp("matched", key, m, buffer[key])
          if buffer[key] is ImageTexture:
            mt[m][1] = m.length() + 1
            dock.set_item_icon(mt[m][0], buffer[key])
            break
          else:
            var tx: Texture2D
            var texture_path = plugin.matches(key, m, buffer[key])
            if texture_path in plugin.largeIconCache:
              tx = plugin.largeIconCache[texture_path]
            else:
              tx = load(texture_path)
              var img: Image = tx.get_image()
              mt[m][1] = m.length() + 1
              img.resize(int(plugin.size.x) * 4, int(plugin.size.y) * 4)
              tx = ImageTexture.create_from_image(img)
            dock.set_item_icon(mt[m][0], tx)
            break
    _dispose.call_deferred()
    return
    
  func _dispose() -> void:
    var o: Variant = self
    for __: int in range(2):
      await Engine.get_main_loop().process_frame
    if is_instance_valid(o):
      o.set_deferred(&"drawing", false)
  
  func _on_change() -> void:
    if drawing:
      return
    drawing = true
    update_icons.call_deferred()
  
  func update(new_dock: ItemList) -> void:
    dock = new_dock
    
    if !dock.draw.is_connected(_on_change):
      dock.draw.connect(_on_change)
    
    #if dock.item_count > 0:
      #var icon : Texture2D = dock.get_item_icon(0)

func _setup() -> void:
  var dir: String = DOT_USER.get_base_dir()
  if !DirAccess.dir_exists_absolute(dir):
    DirAccess.make_dir_recursive_absolute(dir)
    return
  if FileAccess.file_exists(DOT_USER):
    var cfg: ConfigFile = ConfigFile.new()
    if OK != cfg.load(DOT_USER): return
    _buffer = cfg.get_value("DAT", "PTH", {})

func _quick_save() -> void:
  if FileAccess.file_exists(DOT_USER):
    var cfg: ConfigFile = ConfigFile.new()
    if OK != cfg.load(DOT_USER): return
    cfg.set_value("DAT", "PTH", _buffer)
    cfg = null
  set_deferred(&"_is_saving", false)

#region callbacks
func _moved_callback(a0: String, b0: String) -> void:
  if a0 != b0:
    if _buffer.has(a0):
      _buffer[b0] = _buffer[a0]
      _buffer.erase(a0)
      save_queue()

func _remove_callback(path: String) -> void:
  if _buffer.has(path):
    _buffer.erase(path)
    save_queue()
#endregion

func _def_update() -> void:
  update.call_deferred()

func update() -> void:
  # if _buffer.size() == 0: return
  if _busy: return
  _busy = true
  var root: TreeItem = _tree.get_root()
  var item: TreeItem = root.get_first_child()

  while null != item and item.get_metadata(0) != "res://":
    item = item.get_next()

  if _enable_icons_on_split:
    var dock: ItemList = get_docky()
    if dock:
      if !is_instance_valid(_docky):
        _docky = Docky.new(self )
      _docky.update(dock)
    elif is_instance_valid(_docky):
      _docky = null
  elif is_instance_valid(_docky):
    _docky = null

  _explore(item)
  
  if is_instance_valid(_docky):
    _docky.update_icons()
    
  set_deferred(&"_busy", false)

func matches(key, item, retval):
  if key == item:
    return retval
  var splitKey: Array = (key.split("/") as Array).filter(func(e): return e)
  var splitItem: Array = (item.split("/") as Array).filter(func(e): return e)
  if len(splitItem) < len(splitKey):
    return false

  var itemrep: Array[String] = []
  var splitKeyIdx = -1
  var splitItemIdx = -1
  while splitItemIdx + 1 < len(splitItem):
    splitKeyIdx += 1
    splitItemIdx += 1
    if splitItemIdx >= len(splitItem) or splitKeyIdx >= len(splitKey):
      # log.pp("len ", key, item, retval, "splitItemIdx ", splitItemIdx, "splitKeyIdx", splitKeyIdx)
      return false
    if splitKey[splitKeyIdx] == splitItem[splitItemIdx]:
      continue
    if splitKey[splitKeyIdx][0] == '$':
      var num := int(splitKey[splitKeyIdx].substr(1, -1))
      if num in itemrep:
        continue
    if splitKey[splitKeyIdx] == '**':
      var v = ""
      var extra = 1 + (len(splitItem) - len(splitKey))
      for ii in range(splitItemIdx, splitItemIdx + extra):
        v += '/' + splitItem[ii]
      itemrep.append(v.substr(1))
      # log.pp((len(splitItem) - len(splitKey)), splitItem, v, itemrep, key, item, extra, "extra!!")
      splitItemIdx += extra - 1
      continue

    if splitKey[splitKeyIdx] == '*':
      itemrep.append(splitItem[splitItemIdx])
      continue
    return false
  # log.pp("result:", itemrep, splitKey, splitItem, key, item, retval)
  var newRetVal = []
  for pospath in (retval.split("||") as Array).map(func(e): return e.split("/")):
    newRetVal.append([])
    for part in pospath:
      for ii in range(0, len(itemrep)):
        if part == "$" + str(ii + 1):
          newRetVal[len(newRetVal) - 1].append(itemrep[ii])
        else:
          newRetVal[len(newRetVal) - 1].append(part)
  newRetVal = newRetVal.map(func(e): return "/".join(e))
  for path in newRetVal:
    if FileAccess.file_exists(path):
      return path
  errQueue.append([newRetVal, " does not exist, ITEM:", item])
  return false
var errQueue = []
func _explore(item: TreeItem, texture: Texture2D = null, as_root: bool = true) -> void:
  var buffer = get_buffer()
  var meta: String = str(item.get_metadata(0))
  if buffer.has(meta) and buffer[meta] is Texture2D:
    texture = buffer[meta]
    as_root = true
  if !textureAppliesToNestedFolders:
    texture = null
  errQueue = []
  for key in buffer:
    if matches(key, meta, buffer[key]):
      if buffer[key] is ImageTexture:
        texture = buffer[key]
        continue

      var tx: Texture2D
      var texture_path = matches(key, meta, buffer[key])
      if texture_path in smallIconCache:
        tx = smallIconCache[texture_path]
      else:
        tx = load(texture_path)
        var img: Image = tx.get_image()
        img.resize(int(size.x), int(size.y))
        tx = ImageTexture.create_from_image(img)
      texture = tx
      errQueue = []
      break
  if errQueue:
    for err in errQueue:
      log.err(err)
      
  if texture != null:
    if as_root or !FileAccess.file_exists(meta):
      item.set_icon(0, texture)

  for i: TreeItem in item.get_children():
    _explore(i, texture, false)

func _get_dummy_tree_node() -> void:
  set_physics_process(false)
  var root: TreeItem = _tree.get_root()
  if root:
    _tchild = root.get_first_child()
  if is_instance_valid(_tchild):
    var icon_size: Texture2D = _tchild.get_icon(0)
    if icon_size:
      size = icon_size.get_size()
    set_physics_process(true)

func _on_select_texture(tx: Texture2D, texture_path: String, paths: PackedStringArray) -> void:
  if tx.get_size() != size:
    print("Image selected '", texture_path.get_file(), "' size: ", tx.get_size(), " resized to ", size.x, "x", size.y)
    var img: Image = tx.get_image()
    img.resize(int(size.x), int(size.y))
    tx = ImageTexture.create_from_image(img)
  for p: String in paths:
    _buffer[p] = tx
  _def_update()
  save_queue()

func save_queue() -> void:
  if _is_saving:
    return
  _is_saving = true
  _quick_save.call_deferred()

func _on_reset_texture(paths: PackedStringArray) -> void:
  for p: String in paths:
    if _buffer.has(p):
      _buffer.erase(p)
  var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
  if fs: fs.filesystem_changed.emit()

func _on_iconize(paths: PackedStringArray) -> void:
  const PATH: String = "res://addons/fancy_folder_icons/scene/icon_selector.tscn"
  var pop: Window = get_node_or_null("_POP_ICONIZER_")
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
  var out: ItemList = null
  var dock: Control = EditorInterface.get_file_system_dock()
  if dock:
    out = dock.find_child("*FileSystemList*", true, false)
  return out
  
func _ready() -> void:
  set_physics_process(false)
  var dock: FileSystemDock = EditorInterface.get_file_system_dock()
  var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
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
  
var _enable_icons_on_split: bool = true

func _enter_tree() -> void:
  _setup()

  _menu_service = ResourceLoader.load("res://addons/fancy_folder_icons/menu_fancy.gd").new()
  _menu_service.iconize_paths.connect(_on_iconize)
  
  var vp: Viewport = Engine.get_main_loop().root
  vp.focus_entered.connect(_on_wnd)
  vp.focus_exited.connect(_out_wnd)
  
  var editor: EditorSettings = EditorInterface.get_editor_settings()
  if editor:
    editor.settings_changed.connect(_on_change_settings)
    if !editor.has_setting("plugin/fancy_folder_icons/enable_icons_on_split"):
      editor.set_setting("plugin/fancy_folder_icons/enable_icons_on_split", true)
    else:
      _enable_icons_on_split = editor.get_setting("plugin/fancy_folder_icons/enable_icons_on_split")
  ProjectSettings.settings_changed.connect(_on_change_settings)
  var temp = JSON.parse_string(FileAccess.get_file_as_string(RULES_FILE))
  if FileAccess.file_exists(RULES_FILE):
    if temp and "rules" in temp:
      rules = temp.rules
  if FileAccess.file_exists(RULES_FILE):
    if temp and "textureAppliesToNestedFolders" in temp:
      textureAppliesToNestedFolders = temp.textureAppliesToNestedFolders
  ProjectSettings.set_setting("plugin/fancy_folder_icons/rules", rules)
  ProjectSettings.set_setting("plugin/fancy_folder_icons/textureAppliesToNestedFolders", textureAppliesToNestedFolders)
  PROPERTY_HINT_TYPE_STRING
  var property_info = {
    "name": "plugin/fancy_folder_icons/rules",
    "type": TYPE_DICTIONARY,
    "hint": PROPERTY_HINT_DICTIONARY_TYPE,
    "hint_string": (
      "%d/%d:*" % [TYPE_STRING, PROPERTY_HINT_DIR]
      +";" +
      "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_FILE_PATH, "*.png,*.jpg,*.jpeg,*.gif,*.svg,*.ico,*.bmp,*.tga,*.webp"]
    )
  }
  log.pp(property_info.hint_string)

  ProjectSettings.add_property_info(property_info)

func _on_change_settings() -> void:
  var editor: EditorSettings = EditorInterface.get_editor_settings()
  if editor:
    var settings: PackedStringArray = editor.get_changed_settings()
    if "plugin/fancy_folder_icons/enable_icons_on_split" in settings:
      _enable_icons_on_split = editor.get_setting("plugin/fancy_folder_icons/enable_icons_on_split")
  rules = ProjectSettings.get_setting("plugin/fancy_folder_icons/rules", {})
  textureAppliesToNestedFolders = ProjectSettings.get_setting("plugin/fancy_folder_icons/textureAppliesToNestedFolders", true)
  FileAccess.open(RULES_FILE, FileAccess.WRITE_READ).store_string(JSON.stringify({"rules": rules, "textureAppliesToNestedFolders": textureAppliesToNestedFolders}, "  "))
      
func _exit_tree() -> void:
  if is_instance_valid(_popup):
    _popup.queue_free()

  if is_instance_valid(_menu_service):
    remove_context_menu_plugin(_menu_service)

  var dock: FileSystemDock = EditorInterface.get_file_system_dock()
  var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
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

  var editor: EditorSettings = EditorInterface.get_editor_settings()
  if editor:
    editor.settings_changed.disconnect(_on_change_settings)
  
  #region user_dat
  var cfg: ConfigFile = ConfigFile.new()
  for k: String in _buffer.keys():
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
    
  var vp: Viewport = Engine.get_main_loop().root
  vp.focus_entered.disconnect(_on_wnd)
  vp.focus_exited.disconnect(_out_wnd)
  
func _on_wnd() -> void: set_physics_process(true)
func _out_wnd() -> void: set_physics_process(false)

#region rescue_fav
func _n(n: Node) -> bool:
  if n is Tree:
    var t: TreeItem = (n.get_root())
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
