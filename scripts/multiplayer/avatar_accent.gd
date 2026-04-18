extends RefCounted

const DEFAULT_ACCENT := Color("#1188FF")
const MIN_SATURATION := 0.58
const MIN_VALUE := 0.80

static func build_palette_from_frames(frames: Array[Texture2D]) -> Dictionary:
	var accent := extract_dominant_accent(frames)
	return build_palette_from_accent(accent)

static func extract_dominant_accent(frames: Array[Texture2D]) -> Color:
	var hue_x := 0.0
	var hue_y := 0.0
	var sat_sum := 0.0
	var val_sum := 0.0
	var weight_sum := 0.0

	var sample_count := min(frames.size(), 4)
	for frame_idx in range(sample_count):
		var texture: Texture2D = frames[frame_idx]
		if texture == null:
			continue

		var image := texture.get_image()
		if image == null or image.is_empty():
			continue

		if image.get_format() != Image.FORMAT_RGBA8:
			image.convert(Image.FORMAT_RGBA8)

		var width := image.get_width()
		var height := image.get_height()
		if width <= 0 or height <= 0:
			continue

		var step := max(1, int(sqrt(float(width * height) / 256.0)))
		for y in range(0, height, step):
			for x in range(0, width, step):
				var px := image.get_pixel(x, y)
				if px.a < 0.12:
					continue

				var saturation := px.s
				var value := px.v
				if saturation < 0.12 and value < 0.35:
					continue

				var weight := px.a * (0.20 + saturation * 0.80) * (0.30 + value * 0.70)
				if saturation < 0.18:
					weight *= 0.35
				if value < 0.25:
					weight *= 0.55

				var hue := px.h * TAU
				hue_x += cos(hue) * weight
				hue_y += sin(hue) * weight
				sat_sum += saturation * weight
				val_sum += value * weight
				weight_sum += weight

	if weight_sum <= 0.001:
		return DEFAULT_ACCENT

	var hue_ratio := fposmod(atan2(hue_y, hue_x) / TAU, 1.0)
	var avg_sat := sat_sum / weight_sum
	var avg_val := val_sum / weight_sum

	if avg_sat < 0.18:
		hue_ratio = DEFAULT_ACCENT.h
		avg_sat = 0.74
		avg_val = 0.90

	var accent := Color.from_hsv(
		hue_ratio,
		clampf(0.62 + avg_sat * 0.30, MIN_SATURATION, 0.95),
		clampf(0.84 + (avg_val - 0.5) * 0.18, MIN_VALUE, 0.98),
		1.0
	)
	return _normalize_for_visibility(accent)

static func build_palette_from_accent(accent: Color) -> Dictionary:
	var safe_accent := _normalize_for_visibility(accent)
	var border := safe_accent.darkened(0.20)
	if border.get_luminance() < 0.28:
		border = safe_accent.darkened(0.30)

	var fill := safe_accent.lightened(0.08)
	var highlight := safe_accent.lightened(0.16)
	var text := UIColors.TEXT_ON_BRIGHT if fill.get_luminance() > 0.62 else UIColors.TEXT_PRIMARY

	return {
		"accent": safe_accent,
		"border": border,
		"fill": fill,
		"highlight": highlight,
		"text": text,
	}

static func _normalize_for_visibility(color: Color) -> Color:
	var safe := color
	if safe.a <= 0.0:
		safe.a = 1.0

	var hue := safe.h
	var saturation := safe.s
	var value := safe.v

	if saturation < 0.22:
		saturation = 0.74
	else:
		saturation = clampf(0.64 + saturation * 0.26, MIN_SATURATION, 0.95)

	value = clampf(maxf(value, 0.80), MIN_VALUE, 0.98)
	safe = Color.from_hsv(hue, saturation, value, 1.0)

	if safe.get_luminance() < 0.54:
		safe = safe.lightened(0.20)
	elif safe.get_luminance() > 0.92:
		safe = safe.darkened(0.08)

	return safe
