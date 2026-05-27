@tool
extends EditorExportPlugin

const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const ReleaseVersionInfoScript := preload("res://scripts/release_version_info.gd")
const ANDROID_PLATFORM := "Android"

var _current_release_label := ""

func _get_name() -> String:
	return "ReleaseVersionWriter"

func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_current_release_label = ""
	if not _is_android_export(features, path):
		return

	_current_release_label = build_release_label_from_export_preset(get_export_preset())
	if _current_release_label.is_empty():
		_current_release_label = build_release_label_from_saved_preset()

	if _current_release_label.is_empty():
		push_warning("Release version file was not updated because the Android export version is empty.")
		return

	var err := write_release_version_file(_current_release_label)
	if err != OK:
		push_warning("Release version file could not be written: %d" % err)
	add_file(ReleaseVersionInfoScript.RELEASE_VERSION_PATH, _version_file_bytes(_current_release_label), false)

func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	if _current_release_label.is_empty() or not _is_android_export(features, path):
		return
	if not _is_release_version_path(path):
		return
	add_file(path, _version_file_bytes(_current_release_label), true)

static func build_release_label_from_export_preset(preset: EditorExportPreset) -> String:
	if preset == null:
		return ""
	var version_name := ""
	var version_code := ""
	if preset.has(&"version/name"):
		version_name = _clean_string(preset.get_version(&"version/name", false))
	if preset.has(&"version/code"):
		version_code = _clean_string(preset.get_or_env(&"version/code", ""))
	return ReleaseVersionInfoScript.format_label(version_name, version_code)

static func build_release_label_from_saved_preset() -> String:
	var export_config := ConfigFile.new()
	var err := export_config.load(EXPORT_PRESETS_PATH)
	if err != OK:
		return ""

	var options_section := _android_options_section(export_config)
	if options_section.is_empty():
		return ""

	var version_name := _clean_string(export_config.get_value(options_section, "version/name", ""))
	var version_code := _clean_string(export_config.get_value(options_section, "version/code", ""))
	return ReleaseVersionInfoScript.format_label(version_name, version_code)

static func write_release_version_file(label: String) -> Error:
	var file := FileAccess.open(ReleaseVersionInfoScript.RELEASE_VERSION_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("%s\n" % label.strip_edges())
	return OK

static func _android_options_section(export_config: ConfigFile) -> String:
	for section in export_config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var platform := _clean_string(export_config.get_value(section, "platform", ""))
		if platform == ANDROID_PLATFORM:
			var options_section := "%s.options" % section
			if export_config.has_section(options_section):
				return options_section
	return ""

static func _is_android_export(features: PackedStringArray, export_path: String) -> bool:
	for feature in features:
		if String(feature).to_lower() == "android":
			return true
	var extension := export_path.get_extension().to_lower()
	return extension == "apk" or extension == "aab"

static func _is_release_version_path(path: String) -> bool:
	var normalized_path := path.trim_prefix("res://")
	var normalized_release_path := ReleaseVersionInfoScript.RELEASE_VERSION_PATH.trim_prefix("res://")
	return normalized_path == normalized_release_path

static func _version_file_bytes(label: String) -> PackedByteArray:
	return ("%s\n" % label.strip_edges()).to_utf8_buffer()

static func _clean_string(value: Variant) -> String:
	if value == null:
		return ""
	return str(value).strip_edges()
