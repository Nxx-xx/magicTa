shader_type canvas_item;
render_mode unshaded;

// The clock comes from the board, so reduced motion freezes every effect.
uniform float seconds = 0.0;
uniform bool backdrop = false;

float pool(vec2 uv, vec2 center, vec2 radius) {
	vec2 p = (uv - center) / radius;
	return exp(-dot(p, p) * 2.5);
}

void fragment() {
	vec2 uv = UV;
	if (backdrop) {
		vec2 d = vec2(0.018);
		vec3 soft = texture(TEXTURE, uv).rgb * 0.28;
		soft += texture(TEXTURE, uv + d).rgb * 0.18;
		soft += texture(TEXTURE, uv - d).rgb * 0.18;
		soft += texture(TEXTURE, uv + vec2(d.x, -d.y)).rgb * 0.18;
		soft += texture(TEXTURE, uv + vec2(-d.x, d.y)).rgb * 0.18;
		COLOR = vec4(mix(vec3(0.035, 0.060, 0.070), soft * vec3(0.23, 0.29, 0.33), 0.65), 1.0);
	} else {
		// This ellipse sits entirely inside the painted water, away from the bank.
		float water = 1.0 - smoothstep(0.45, 1.0, length((uv - vec2(0.876, 0.463)) / vec2(0.067, 0.060)));
		uv.x += water * sin(uv.y * 170.0 + seconds * 1.1) * 0.00065;
		uv.y += water * cos(uv.x * 155.0 + seconds * 0.9) * 0.00035;
		vec3 color = texture(TEXTURE, uv).rgb;
		float shimmer = sin(uv.y * 270.0 + seconds * 1.15) * sin(uv.x * 65.0 - seconds * 0.5);
		color += vec3(0.11, 0.24, 0.27) * water * shimmer * 0.045;
		float flicker = sin(seconds * 4.1) * 0.55 + sin(seconds * 6.7 + 0.8) * 0.30;
		float fire = pool(uv, vec2(0.612, 0.638), vec2(0.082, 0.068));
		float lamps = pool(uv, vec2(0.432, 0.125), vec2(0.037)) + pool(uv, vec2(0.571, 0.125), vec2(0.037));
		color += vec3(1.0, 0.40, 0.08) * (fire * 0.035 + lamps * 0.014) * flicker;
		float edge = smoothstep(0.30, 0.69, distance(UV, vec2(0.5)));
		color *= 1.0 - edge * 0.12;
		COLOR = vec4(color, 1.0);
	}
}
