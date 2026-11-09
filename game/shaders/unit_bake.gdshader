shader_type canvas_item;
// V1.2 D1：角色圖集烘焙後處理（只在烘焙時跑一次，每幀貼圖成本不變）。
// ① 外輪廓：沿 alpha 往外擴 radius 像素，用隊伍墨色（藍方冷深褐、紅方暖深焦茶）；部件自己的描邊變成較細的內線。
// ② 頂亮底暗：依格子內高度，上半疊暖光、下半疊冷影（左右翻面不穿幫，不做左右光）。
uniform vec4 ink0 : source_color = vec4(0.114, 0.102, 0.149, 1.0);
uniform vec4 ink1 : source_color = vec4(0.157, 0.086, 0.071, 1.0);
uniform float cell = 192.0;
uniform float per = 28.0;
uniform float cols = 16.0;
uniform float radius = 3.0;
uniform float hi_amt = 0.09;
uniform float sh_amt = 0.20;
uniform float y_off = -1.0;   // V1.5.1：圖鑑大圖用：格子頂端在 y_off（≥0 時只算一格、不循環）；圖集用預設 -1

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	float cidx = floor(px.y / cell) * cols + floor(px.x / cell);
	float team = mod(floor(cidx / per), 2.0);
	vec4 ink = team < 0.5 ? ink0 : ink1;
	float a = 0.0;
	for (int r = 1; r <= 2; r++) {
		float rr = radius * float(r) / 2.0;
		for (int i = 0; i < 16; i++) {
			float ang = 6.2831853 * (float(i) + 0.5 * float(r)) / 16.0;
			a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * rr * TEXTURE_PIXEL_SIZE).a);
		}
	}
	vec3 col = c.rgb;
	float ly = y_off >= 0.0 ? clamp((px.y - y_off) / cell, 0.0, 1.0) : mod(px.y, cell) / cell;
	float hi = clamp((0.50 - ly) / 0.28, 0.0, 1.0) * hi_amt;
	float sh = clamp((ly - 0.62) / 0.20, 0.0, 1.0) * sh_amt;
	col = mix(col, vec3(1.0, 0.953, 0.839), hi);
	col = mix(col, col * vec3(0.48, 0.42, 0.58), sh);
	float oa = a * ink.a;
	float outa = c.a + oa * (1.0 - c.a);
	vec3 rgb = outa > 0.0 ? (col * c.a + ink.rgb * oa * (1.0 - c.a)) / outa : vec3(0.0);
	COLOR = vec4(rgb, outa);
}
