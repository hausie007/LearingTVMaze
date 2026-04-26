## wifi_helper.gd
## ---------------------------------------------------------------------------
## Small utility to detect the current WiFi network name on supported platforms.
## Returns an empty string when detection is not possible.
## ---------------------------------------------------------------------------
class_name WiFiHelper
extends RefCounted

static func get_wifi_name() -> String:
	var os_name := OS.get_name()

	if os_name == "macOS":
		return _get_wifi_name_macos()
	elif os_name == "Android":
		return _get_wifi_name_android()
	elif os_name in ["Linux", "FreeBSD"]:
		return _get_wifi_name_linux()
	elif os_name == "Windows":
		return _get_wifi_name_windows()
	return ""

static func _get_wifi_name_macos() -> String:
	var output: Array = []
	# Try the newer macOS 15+ approach first (airport was removed)
	var err := OS.execute("networksetup", ["-getairportnetwork", "en0"], output)
	if err == OK and not output.is_empty():
		var line := String(output[0]).strip_edges()
		# Output format: "Current Wi-Fi Network: MyNetworkName"
		var prefix := "Current Wi-Fi Network: "
		if line.begins_with(prefix):
			return line.substr(prefix.length())
	return ""

static func _get_wifi_name_android() -> String:
	# Android restricts SSID access; return empty and let UI show fallback
	return ""

static func _get_wifi_name_linux() -> String:
	var output: Array = []
	var err := OS.execute("iwgetid", ["-r"], output)
	if err == OK and not output.is_empty():
		return String(output[0]).strip_edges()
	return ""

static func _get_wifi_name_windows() -> String:
	var output: Array = []
	var err := OS.execute("netsh", ["wlan", "show", "interfaces"], output)
	if err == OK and not output.is_empty():
		var text := String(output[0])
		for line in text.split("\n"):
			var stripped := line.strip_edges()
			if stripped.begins_with("SSID") and not stripped.begins_with("BSSID"):
				var parts := stripped.split(":")
				if parts.size() >= 2:
					return parts[1].strip_edges()
	return ""
