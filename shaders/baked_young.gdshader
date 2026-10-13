shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D front : filter_nearest;
uniform sampler2D right_view : filter_nearest;
uniform sampler2D back : filter_nearest;
uniform sampler2D left_view : filter_nearest;
uniform int view = 0;
uniform int next_view = 1;
uniform float view_blend = 0.0;
vec3 painted_color(int index, vec2 face_uv, vec2 side_uv, vec3 base, float tag) {
	vec4 paint = texture(front,face_uv);
	if (index == 1) paint = texture(left_view,vec2(1.0-side_uv.x,face_uv.y));
	if (index == 2) paint = texture(back,vec2(1.0-face_uv.x,face_uv.y));
	if (index == 3) paint = texture(right_view,vec2(side_uv.x,face_uv.y));
	vec3 pigment = base;
	// Facial landmarks use attached geometry, never a projected flat eye.
	bool neutral = max(paint.r,max(paint.g,paint.b))-min(paint.r,min(paint.g,paint.b)) < 0.14;
	if (tag < 0.5 && paint.a > 0.8 && paint.r > paint.g*1.08 && paint.g > paint.b*1.12 && paint.r < 0.65)
		pigment = mix(base,paint.rgb,0.65);
	if (tag > 0.5 && tag < 1.5 && paint.a > 0.8 && neutral && paint.r > 0.35)
		pigment = mix(base,paint.rgb,0.65);
	if (tag < 0.5 && paint.a > 0.8 && paint.g > paint.r*0.9 && paint.b < paint.g*0.65)
		pigment = mix(base,paint.rgb,0.8);
	return pigment;
}
void fragment() {
	vec3 pigment = mix(painted_color(view,UV2,UV,COLOR.rgb,UV.y),painted_color(next_view,UV2,UV,COLOR.rgb,UV.y),view_blend);
	float diffuse = max(dot(normalize(NORMAL),normalize(vec3(-0.3,0.75,0.6))),0.0);
	ALBEDO = pigment*(0.82+floor(diffuse*4.0)*0.065);
}
