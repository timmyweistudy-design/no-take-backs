shader_type canvas_item;
// V1.2 F2：地塊調色（烘焙時套一次，執行時零成本；介面與兵不經過這裡）。暖色暗部、微提對比與飽和，像暖光下的桌面沙盤。
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 g = src.rgb;
	float l = dot(g, vec3(0.299, 0.587, 0.114));
	g = mix(vec3(l), g, 1.07);
	g = (g - 0.5) * 1.05 + 0.5;
	g += vec3(0.030, 0.014, -0.012) * (1.0 - l);
	g *= vec3(1.015, 1.0, 0.975);
	COLOR = vec4(clamp(g, 0.0, 1.0), src.a);
}
