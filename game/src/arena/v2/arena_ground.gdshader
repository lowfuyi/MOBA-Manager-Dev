// Arena v2 ground (MATCH-SIM-V2-DESIGN 11.4): one quad over the arena; each pixel is cast back to the ground plane through the
// tilted pinhole camera of ArenaCam (same uniforms), then the baked island texture is read. Outside the island: the dark mist,
// and a vignette over everything. One draw call, one texture read per pixel. Presentation only.
shader_type canvas_item;

uniform sampler2D ground_tex : filter_linear_mipmap, repeat_disable;
uniform vec3 cam_c;
uniform vec3 cam_f;
uniform vec3 cam_u;
uniform vec3 cam_r;
uniform float focal = 1000.0;
uniform vec2 view = vec2(720.0, 760.0);
uniform float xs = 0.9474;
uniform float flip = 0.0;
uniform float margin = 0.06;
uniform vec4 fog_near : source_color = vec4(0.055, 0.075, 0.105, 1.0);
uniform vec4 fog_far : source_color = vec4(0.11, 0.13, 0.17, 1.0);
uniform float vignette = 0.55;

void fragment() {
	vec2 s = UV * view;
	vec3 d = cam_f + cam_r * ((s.x - view.x * 0.5) / focal) - cam_u * ((s.y - view.y * 0.5) / focal);
	// the mist: lighter toward the horizon
	vec4 col = mix(fog_far, fog_near, clamp(UV.y * 1.2, 0.0, 1.0));
	if (d.y < -0.000001) {
		float t = -cam_c.y / d.y;
		vec3 w = cam_c + d * t;
		float gy = w.z + 0.5;
		vec2 cp = vec2(w.x / xs + 0.5, flip > 0.5 ? 1.0 - gy : gy);
		vec2 tuv = (cp + vec2(margin)) / (1.0 + 2.0 * margin);
		if (tuv.x >= 0.0 && tuv.x <= 1.0 && tuv.y >= 0.0 && tuv.y <= 1.0) {
			vec4 g = texture(ground_tex, tuv);
			// far ground fades a little into the mist (depth cue)
			float haze = clamp((t - 0.9) * 0.35, 0.0, 0.35);
			col = mix(col, mix(g, fog_far, haze), g.a);
		}
	}
	vec2 q = UV - vec2(0.5, 0.55);
	col.rgb *= 1.0 - vignette * dot(q, q) * 1.7;
	COLOR = col;
}
