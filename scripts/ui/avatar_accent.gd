class_name AvatarAccent
extends RefCounted

const SAMPLE_SIZE: int = 32
const MAX_FRAMES_TO_SAMPLE: int = 4
const HUE_BUCKETS: int = 24
const MIN_ALPHA: float = 0.16
const MIN_SAT_FOR_WEIGHT: float = 0.10
const FALLBACK_ACCENT: Color = Color("#5AC8FF")

static var _palette_cache: Dictionary = {}

static func palette_from_character_id(character_id: String) -> Dictionary:
	if character_id.is_empty():
		return safe_palette()

	if _palette_cache.has(character_id):
		return (_palette_cache[character_id] as Dictionary).duplicate(true)

	var preview_data: Dictionary = CharacterCatalog.get_preview_data_by_id(character_id)
	var palette: Dictionary = palette_from_preview_data(preview_data)
	if palette.is_empty():
		palette = safe_palette()

	_palette_cache[character_id] = palette.duplicate(true)
	return palette.duplicate(true)

static func palette_from_preview_data(preview_data: Dictionary) -> Dictionary:
	var frames: Array[Texture2D] = []
	for item in preview_data.get("frames", []):
		if item is Texture2D:
			frames.append(item)
	return palette_from_frames(frames)

static func palette_from_frames(frames: Array[Texture2D]) -> Dictionary:
	var accent: Color = _extract_accent_from_frames(frames)
	return _build_palette(accent)

static func safe_palette() -> Dictionary:
	return _build_palette(FALLBACK_ACCENT)

static func _extract_accent_from_frames(frames: Array[Texture2D]) -> Color:
	if frames.is_empty():
		return FALLBACK_ACCENT

	var sampled_frames: Array[Texture2D] = _sample_frames(frames)
	var bucket_weight: Array[float] = []
	var bucket_sat: Array[float] = []
	var bucket_val: Array[float] = []
	var bucket_hx: Array[float] = []
	var bucket_hy: Array[float] = []
	bucket_weight.resize(HUE_BUCKETS)
	bucket_sat.resize(HUE_BUCKETS)
	bucket_val.resize(HUE_BUCKETS)
	bucket_hx.resize(HUE_BUCKETS)
	bucket_hy.resize(HUE_BUCKETS)
	for i in range(HUE_BUCKETS):
		bucket_weight[i] = 0.0
		bucket_sat[i] = 0.0
		bucket_val[i] = 0.0
		bucket_hx[i] = 0.0
		bucket_hy[i] = 0.0

	for texture in sampled_frames:
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue

		var width: int = image.get_width()
		var height: int = image.get_height()
		if width <= 0 or height <= 0:
			continue

		if max(width, height) > SAMPLE_SIZE:
			var target_w: int = max(1, int(round(float(width) * float(SAMPLE_SIZE) / float(max(width, height)))))
			var target_h: int = max(1, int(round(float(height) * float(SAMPLE_SIZE) / float(max(width, height)))))
			image.resize(target_w, target_h)
			width = image.get_width()
			height = image.get_height()

		var step: int = max(1, int(floor(min(width, height) / 14.0)))
		for y in range(0, height, step):
			for x in range(0, width, step):
				var color: Color = image.get_pixel(x, y)
				if color.a < MIN_ALPHA:
					continue

				var hsv: Vector3 = _rgb_to_hsv(color)
				var pixel_hue: float = hsv.x
				var pixel_sat: float = hsv.y
				var pixel_val: float = hsv.z

				var weight: float = color.a * (0.16 + pixel_sat * 1.55) * (0.30 + pixel_val * 0.70)
				if pixel_sat < MIN_SAT_FOR_WEIGHT:
					# Keep grayscale pixels from dominating the result.
					weight *= 0.10 + pixel_sat * 0.90
				if pixel_val < 0.16:
					weight *= 0.35
				if weight <= 0.0:
					continue

				var bucket: int = int(floor(pixel_hue * float(HUE_BUCKETS))) % HUE_BUCKETS
				bucket_weight[bucket] += weight
				bucket_sat[bucket] += pixel_sat * weight
				bucket_val[bucket] += pixel_val * weight
				bucket_hx[bucket] += cos(pixel_hue * TAU) * weight
				bucket_hy[bucket] += sin(pixel_hue * TAU) * weight

	var best_bucket: int = -1
	var best_weight: float = 0.0
	for i in range(HUE_BUCKETS):
		if bucket_weight[i] > best_weight:
			best_weight = bucket_weight[i]
			best_bucket = i

	if best_bucket < 0 or best_weight <= 0.0001:
		return FALLBACK_ACCENT

	var hue: float = 0.0
	if abs(bucket_hx[best_bucket]) > 0.0001 or abs(bucket_hy[best_bucket]) > 0.0001:
		hue = fposmod(atan2(bucket_hy[best_bucket], bucket_hx[best_bucket]) / TAU, 1.0)
	else:
		hue = (float(best_bucket) + 0.5) / float(HUE_BUCKETS)

	var saturation: float = bucket_sat[best_bucket] / best_weight
	var value: float = bucket_val[best_bucket] / best_weight
	return _safe_accent_from_hsv(hue, saturation, value)

static func _sample_frames(frames: Array[Texture2D]) -> Array[Texture2D]:
	if frames.size() <= MAX_FRAMES_TO_SAMPLE:
		return frames.duplicate()

	var result: Array[Texture2D] = []
	var stride: int = max(1, int(ceil(float(frames.size()) / float(MAX_FRAMES_TO_SAMPLE))))
	for i in range(0, frames.size(), stride):
		var texture: Texture2D = frames[i]
		if texture != null:
			result.append(texture)
		if result.size() >= MAX_FRAMES_TO_SAMPLE:
			break
	return result

static func _rgb_to_hsv(color: Color) -> Vector3:
	var r: float = color.r
	var g: float = color.g
	var b: float = color.b
	var max_c: float = max(r, max(g, b))
	var min_c: float = min(r, min(g, b))
	var delta: float = max_c - min_c

	var hue: float = 0.0
	if delta > 0.000001:
		if max_c == r:
			hue = fposmod((g - b) / delta, 6.0)
		elif max_c == g:
			hue = ((b - r) / delta) + 2.0
		else:
			hue = ((r - g) / delta) + 4.0
		hue /= 6.0

	var saturation: float = 0.0 if max_c <= 0.000001 else delta / max_c
	return Vector3(hue, saturation, max_c)

static func _safe_accent_from_hsv(hue: float, saturation: float, value: float) -> Color:
	var clean_hue: float = fposmod(hue, 1.0)

	# Push low-saturation results into a vivid but still believable range.
	var safe_saturation: float = clampf(0.58 + saturation * 0.30, 0.58, 0.96)
	if saturation < 0.18:
		safe_saturation = 0.72

	# Keep the accent bright enough to stay readable against the dark UI shell.
	var safe_value: float = clampf(0.82 + value * 0.14, 0.78, 0.98)
	if value < 0.38:
		safe_value = max(safe_value, 0.86)

	var accent: Color = Color.from_hsv(clean_hue, safe_saturation, safe_value, 1.0)
	if accent.get_luminance() < 0.48:
		accent = Color.from_hsv(clean_hue, safe_saturation, min(0.98, safe_value + 0.08), 1.0)
	return accent

static func _build_palette(accent: Color) -> Dictionary:
	var safe_accent: Color = accent
	if safe_accent.get_luminance() < 0.45:
		var accent_hsv: Vector3 = _rgb_to_hsv(safe_accent)
		safe_accent = Color.from_hsv(accent_hsv.x, max(0.62, accent_hsv.y), 0.90, 1.0)

	var soft: Color = safe_accent.lerp(Color.WHITE, 0.18)
	var vivid: Color = safe_accent.lerp(Color.WHITE, 0.34)
	var safe_hsv: Vector3 = _rgb_to_hsv(safe_accent)
	var deep: Color = Color.from_hsv(
		safe_hsv.x,
		clampf(safe_hsv.y * 1.02, 0.58, 1.0),
		clampf(safe_hsv.z * 0.82, 0.58, 0.90),
		1.0
	)
	var shell: Color = UIColors.BG_DARK.lerp(safe_accent, 0.14)
	var shell_hover: Color = UIColors.BG_DARK.lerp(soft, 0.18)
	var border: Color = safe_accent.lerp(Color.WHITE, 0.12)
	var text_on_accent: Color = UIColors.TEXT_ON_BRIGHT if safe_accent.get_luminance() > 0.66 else UIColors.TEXT_PRIMARY

	return {
		"accent": safe_accent,
		"accent_soft": soft,
		"accent_vivid": vivid,
		"accent_deep": deep,
		"shell": shell,
		"shell_hover": shell_hover,
		"border": border,
		"text": text_on_accent,
	}
