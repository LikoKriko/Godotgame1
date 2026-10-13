shader_type spatial;
render_mode unshaded, cull_disabled;
uniform bool protect_bow_arm = false;
uniform bool debug_left_arm = false;
uniform bool debug_right_arm = false;
uniform sampler2D body_mask : filter_nearest;
uniform sampler2D armor_texture : filter_nearest;
uniform sampler2D head_reference : filter_nearest;
uniform vec4 reference_rect;
void fragment() {
	// Both arms and the procedural cord/arrow belong behind the back in upper views.
	bool bow_part = (UV.x > 0.5 && UV.x < 2.5) || (UV.x > 3.5 && UV.x < 4.5);
	if (protect_bow_arm && bow_part && texture(body_mask,SCREEN_UV).a > 0.5) discard;
	float diffuse = max(dot(normalize(NORMAL), normalize(vec3(-0.25,0.7,0.6))),0.0);
	float light = 0.80 + floor(diffuse*4.0)/4.0*0.25;
	vec3 skin = COLOR.rgb;
	if (UV.x > 2.5 && UV.x < 3.5) {
		vec4 paint = texture(head_reference,reference_rect.xy+UV2*reference_rect.zw);
		if (paint.a < 0.22) discard;
		skin = paint.rgb;
		// Harmonize face skin with the body palette while retaining eye/hair art.
		if (paint.r > 0.68 && paint.g > 0.42 && paint.r > paint.g*1.15 && paint.g > paint.b*1.15) {
			float shade = clamp(round((paint.r/0.88)*10.0)/10.0,0.80,1.05);
			skin = COLOR.rgb*shade;
			light = 1.0;
		}
	}
	if (UV.x > 4.5) {
		vec4 paint = texture(armor_texture,UV2);
		if (paint.a < 0.22 || max(paint.r,max(paint.g,paint.b)) < 0.08) discard;
		skin = paint.rgb;
	}
	bool marked = (debug_left_arm && UV.x > 0.5 && UV.x < 1.5) || (debug_right_arm && UV.x > 1.5 && UV.x < 2.5);
	ALBEDO = marked ? vec3(1,0,1) : skin * light;
}
