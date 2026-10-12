shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool protect_body = false;
uniform sampler2D body_mask : filter_nearest;
uniform sampler2D item_texture : filter_nearest;
uniform vec4 source_rect = vec4(0,0,1,1);
uniform vec2 source_size = vec2(1,1);
uniform bool bow = false;
uniform bool clear_black = false;
uniform vec2 string_top = vec2(0,0);
uniform vec2 string_bottom = vec2(0,0);
uniform float string_width = 1.0;
void fragment() {
	if (protect_body && texture(body_mask,SCREEN_UV).a > 0.5) discard;
	vec4 paint = texture(item_texture,UV);
	vec2 point = (UV-source_rect.xy)/source_rect.zw*source_size;
	if (bow) {
		vec2 axis = string_bottom-string_top;
		float t = clamp(dot(point-string_top,axis)/max(dot(axis,axis),1.0),0.0,1.0);
		if (t > 0.07 && t < 0.93 && distance(point,string_top+axis*t) < string_width) paint.a = 0.0;
		if (clear_black && max(paint.r,max(paint.g,paint.b)) < 0.035) paint.a = 0.0;
	}
	ALBEDO = paint.rgb;
	ALPHA = paint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.22;
}
