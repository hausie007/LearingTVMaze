class_name ReleaseVersionInfo
extends RefCounted

const RELEASE_VERSION_PATH := "res://data/release_version.txt"

static func read_packaged_label() -> String:
	if not FileAccess.file_exists(RELEASE_VERSION_PATH):
		return ""
	var file := FileAccess.open(RELEASE_VERSION_PATH, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()

static func format_label(version_name: String, build_code: String) -> String:
	version_name = version_name.strip_edges()
	build_code = build_code.strip_edges()
	if version_name.is_empty() and build_code.is_empty():
		return ""
	if version_name.is_empty():
		return "build %s" % build_code
	if build_code.is_empty():
		return version_name
	return "%s build %s" % [version_name, build_code]
