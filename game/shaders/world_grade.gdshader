shader_type canvas_item;
// V1.2 F2：戰場調色（只蓋在戰場範圍，介面不經過這裡）。暖色暗部、微提對比與飽和，像暖光下的桌面沙盤。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	vec3 g = c;
	float l = dot(g, vec3(0.299, 0.587, 0.114));
	g = mix(vec3(l), g, 1.07);                        // 飽和 +7%
	g = (g - 0.5) * 1.05 + 0.5;                       // 對比 +5%
	g += vec3(0.030, 0.014, -0.012) * (1.0 - l);      // 暗部偏暖
	g *= vec3(1.015, 1.0, 0.975);                     // 整體微暖
	COLOR = vec4(mix(c, clamp(g, 0.0, 1.0), strength), 1.0);
}
