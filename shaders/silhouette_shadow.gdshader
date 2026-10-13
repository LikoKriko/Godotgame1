shader_type canvas_item;
render_mode unshaded;
uniform float opacity = 0.25;
uniform float softness = 1.0;
uniform float foot_uv_y = 1.0;
uniform vec4 uv_rect = vec4(0.0,0.0,1.0,1.0);
float inside_uv(vec2 uv) {
	return step(uv_rect.x,uv.x)*step(uv.x,uv_rect.z)*step(uv_rect.y,uv.y)*step(uv.y,uv_rect.w);
}
void fragment() {
	float local_y = (UV.y-uv_rect.y)/max(uv_rect.w-uv_rect.y,0.001);
	float height = clamp((foot_uv_y-local_y)/max(foot_uv_y,0.001),0.0,1.0);
	// Screen derivatives preserve a restrained penumbra at every zoom/size.
	vec2 dx = dFdx(UV)*softness*mix(0.35,1.4,height);
	vec2 dy = dFdy(UV)*softness*mix(0.35,1.4,height);
	float alpha = texture(TEXTURE,UV).a*0.5;
	alpha += (texture(TEXTURE,UV+dx).a*inside_uv(UV+dx)+texture(TEXTURE,UV-dx).a*inside_uv(UV-dx)+texture(TEXTURE,UV+dy).a*inside_uv(UV+dy)+texture(TEXTURE,UV-dy).a*inside_uv(UV-dy))*0.125;
	COLOR = vec4(vec3(0.025,0.035,0.05),alpha*opacity*(1.0-height*0.18));
}
