@tool
extends EditorPlugin

const WriterScript := preload("res://addons/release_version_export/release_version_writer.gd")
const ReleaseVersionInfoScript := preload("res://scripts/release_version_info.gd")

var _export_plugin: EditorExportPlugin = null
var _last_export_presets_modified_time: int = 0

func _enter_tree() -> void:
	_export_plugin = WriterScript.new()
	add_export_plugin(_export_plugin)
	_sync_release_version_file()
	_last_export_presets_modified_time = _export_presets_modified_time()
	set_process(true)

func _exit_tree() -> void:
	set_process(false)
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null

func _process(_delta: float) -> void:
	var modified_time := _export_presets_modified_time()
	if modified_time == 0 or modified_time == _last_export_presets_modified_time:
		return
	_last_export_presets_modified_time = modified_time
	_sync_release_version_file()

func _sync_release_version_file() -> void:
	var label := WriterScript.build_release_label_from_saved_preset()
	if label.is_empty() or label == ReleaseVersionInfoScript.read_packaged_label():
		return
	var err := WriterScript.write_release_version_file(label)
	if err != OK:
		push_warning("Release version file could not be synced from export preset: %d" % err)

func _export_presets_modified_time() -> int:
	return int(FileAccess.get_modified_time(WriterScript.EXPORT_PRESETS_PATH))
