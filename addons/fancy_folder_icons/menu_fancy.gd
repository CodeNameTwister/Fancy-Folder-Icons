@tool
extends EditorContextMenuPlugin
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#	Fancy Folder Icons
#
#	Folder Icons addon for addon godot 4
#	https://github.com/CodeNameTwister/Fancy-Folder-Icons
#	author:	"Twister"
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#region godotengine_repository_icons
const ICON : Texture = preload("res://addons/fancy_folder_icons/ZoomMore.svg")
#endregion

signal iconize_paths(path : Variant)

func _popup_menu(paths: PackedStringArray) -> void:
	var _process : bool = false
	for p : String in paths:
		if FileAccess.file_exists(p) or DirAccess.dir_exists_absolute(p):
			# The translation in tool mode doesn't seem to work at the moment, I'll leave the code anyway.
			var locale : String = OS.get_locale_language()
			var translation: Translation = TranslationServer.get_translation_object(locale)
			add_context_menu_item("{0} {1}".format([_get_tr(translation,&"Custom"), _get_tr(translation,&"Icon")]).capitalize(), _on_pick_cmd.bind(paths), ICON)
			break

# v4.5.beta1.official [46c495ca2] Error, not receive arg0 values.Add commentMore actions
func _on_pick_cmd(arg0 : Variant, arg1_fallvar : Variant = null) -> void:
	if arg0 is PackedStringArray and arg0.size() > 0:
		iconize_paths.emit(arg0)
	elif arg1_fallvar is PackedStringArray and arg1_fallvar.size() > 0:
		iconize_paths.emit(arg1_fallvar)
	
func _get_tr(translation : Translation, msg : StringName) -> StringName:
	if translation == null:
		return msg
	var new_msg : StringName = translation.get_message(msg)
	if new_msg.is_empty():
		return msg
	return new_msg
