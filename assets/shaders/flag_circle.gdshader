shader_type canvas_item;

// Secondary texture for regional variation diagonal split flag
uniform sampler2D texture_b : hint_default_black;
uniform bool is_split = false;

// Premium styling parameters
uniform vec4 border_color : source_color = vec4(0.965, 0.929, 0.847, 1.0); // #F6EDD8 (Parchment Cream)
uniform float border_width : hint_range(0.0, 0.1) = 0.04;
uniform float shadow_softness : hint_range(0.0, 0.1) = 0.06;

// Texture aspect ratios to prevent squashing/stretching
uniform float aspect_ratio_a = 1.0;
uniform float aspect_ratio_b = 1.0;

// Customizable UV offsets for primary and secondary flags
uniform vec2 uv_offset_a = vec2(0.0);
uniform vec2 uv_offset_b = vec2(0.0);

vec2 crop_uv(vec2 uv, float aspect) {
	if (aspect > 1.0) {
		return vec2(0.5 + (uv.x - 0.5) / aspect, uv.y);
	} else if (aspect < 1.0) {
		return vec2(uv.x, 0.5 + (uv.y - 0.5) * aspect);
	}
	return uv;
}

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);
	
	// Smooth anti-aliased circular mask
	float circle_alpha = 1.0 - smoothstep(0.48, 0.50, dist);
	
	// Base flag color selection
	vec4 flag_color = vec4(0.0);
	
	if (is_split) {
		// Ascending diagonal: uv.x + uv.y = 0.
		// - uv.x + uv.y < 0.0 is the Top-Left half (Primary flag: GB, ES, PT)
		// - uv.x + uv.y > 0.0 is the Bottom-Right half (Secondary flag: US, MX, BR)
		float line_val = uv.x + uv.y;
		
		// Premium 3D Overlapping Plate Effect:
		// Draw a gorgeous soft drop-shadow from the top-left plate onto the bottom-right plate.
		if (line_val < 0.0) {
			// Primary flag (Top-Left)
			vec2 cropped = crop_uv(UV, aspect_ratio_a);
			vec2 shifted = clamp(cropped + uv_offset_a, 0.0, 1.0);
			flag_color = texture(TEXTURE, shifted);
		} else {
			// Secondary flag (Bottom-Right)
			vec2 cropped = crop_uv(UV, aspect_ratio_b);
			vec2 shifted = clamp(cropped + uv_offset_b, 0.0, 1.0);
			vec4 color_b = texture(texture_b, shifted);
			
			// Apply soft shadow from the overlapping top-left plate
			float shadow_factor = smoothstep(0.0, shadow_softness, line_val);
			// Darken the secondary flag near the seam to give high-fidelity depth
			flag_color = mix(color_b * 0.45, color_b, shadow_factor);
		}
		
		// Crisp white/parchment divider seam representing the overlap edge
		float divider_width = 0.012;
		if (abs(line_val) < divider_width) {
			float shine = 1.0 - abs(line_val) / divider_width;
			flag_color = mix(flag_color, border_color, shine);
		}
	} else {
		vec2 cropped = crop_uv(UV, aspect_ratio_a);
		vec2 shifted = clamp(cropped + uv_offset_a, 0.0, 1.0);
		flag_color = texture(TEXTURE, shifted);
	}
	
	// Apply a beautiful 3D glossy dome/glassmorphism effect
	// 1. Radial Vignette for rich color depth
	float vignette = 1.0 - dist * 0.45;
	flag_color.rgb *= vignette;
	
	// 2. Glossy high-light shine in the top-left quadrant of the circle
	vec2 light_dir = normalize(vec2(-0.35, -0.35));
	float spec = max(0.0, dot(normalize(uv), light_dir));
	float highlight = pow(spec, 10.0) * 0.22 * (1.0 - smoothstep(0.18, 0.42, dist));
	flag_color.rgb += vec3(highlight);
	
	// 3. Crisp outer border rim to frame the flag beautifully
	float border_mask = smoothstep(0.50 - border_width, 0.50, dist);
	vec4 final_color = mix(flag_color, border_color, border_mask);
	
	COLOR = vec4(final_color.rgb, final_color.a * circle_alpha);
}
