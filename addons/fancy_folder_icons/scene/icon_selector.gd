@tool
extends Window
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
@export var texture_container : Control
@export var line_edit : LineEdit
@export var file_dialog : FileDialog
@export var timer : Timer

@warning_ignore("unused_signal")
signal on_set_texture(new_tx : Texture, path : String)
@warning_ignore("unused_signal")
signal on_reset_texture()

signal enable_accept_changes_button(e : bool)

var _selected : Texture2D = null
var _path : String = ""

func _call_reorder(tx : Texture) -> void:
	if texture_container:
		texture_container.reorder(tx)

func select_texture(tx: Texture2D, path : String) -> void:
	_selected = null
	_path = path
	if tx:
		line_edit.text = path
		_selected = tx
		_call_reorder(tx)
		_on_line_edit_text_changed(line_edit.text)
		return
	enable_accept_changes_button.emit(false)

func accept_changes() -> void:
	_call_reorder(_selected)
	on_set_texture.emit(_selected, _path)
	hide.call_deferred()

func _ready() -> void:
	enable_accept_changes_button.emit(false)

func close_requested() -> void:
	enable_accept_changes_button.emit(false)
	hide.call_deferred()

func _on_close_requested() -> void:
	close_requested()

func _on_reset_pressed() -> void:
	on_reset_texture.emit()
	hide.call_deferred()

func _on_exit_pressed() -> void:
	close_requested()

func _on_go_back_requested() -> void:
	close_requested()

func _on_visibility_changed() -> void:
	line_edit.text = ""
	enable_accept_changes_button.emit(false)
	texture_container.enable_by_path("")

	if !timer:return
	if !visible:
		timer.start(120)
	else:
		if !timer.is_stopped():
			timer.stop()


func _on_line_edit_text_changed(path: String) -> void:
	enable_accept_changes_button.emit(line_edit.text.length() > 0)
	texture_container.enable_by_path(path)

func _on_explore_pressed() -> void:
	if file_dialog and !file_dialog.visible:
		file_dialog.popup_centered()

func _on_file_dialog_file_selected(path: String) -> void:
	if ResourceLoader.exists(path):
		var r : Resource = ResourceLoader.load(path)
		if r is Texture2D:
			select_texture(r, path)

func _on_timer_timeout() -> void:
	name = "_qd"
	queue_free()
