shader_type canvas_item;
render_mode unshaded, skip_vertex_transform;
uniform vec2 sun_direction = vec2(1.0,0.0);
uniform float stretch = 1.0;
uniform float opacity = 0.25;
uniform float softness = 1.0;
varying float contact_y;
void vertex() {
	float approach = smoothstep(0.2,1.0,VERTEX.y/max(COLOR.r,0.001));
	contact_y = mix(COLOR.g,COLOR.r,approach);
	vec2 point = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
	vec2 contact = (MODEL_MATRIX*vec4(VERTEX.x,contact_y,0.0,1.0)).xy;
	float height = max(0.0,contact.y-point.y);
	VERTEX = vec2(point.x,contact.y)+sun_direction*stretch*height;
}
float inside(vec2 uv) {return step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);}
void fragment() {
	float height = clamp((contact_y-UV.y)/max(contact_y,0.001),0.0,1.0);
	vec2 dx = dFdx(UV)*softness*mix(0.25,1.1,height);
	vec2 dy = dFdy(UV)*softness*mix(0.25,1.1,height);
	float alpha = texture(TEXTURE,UV).a*0.5;
	alpha += (texture(TEXTURE,UV+dx).a*inside(UV+dx)+texture(TEXTURE,UV-dx).a*inside(UV-dx)+texture(TEXTURE,UV+dy).a*inside(UV+dy)+texture(TEXTURE,UV-dy).a*inside(UV-dy))*0.125;
	COLOR = vec4(vec3(0.025,0.035,0.05),alpha*opacity);
}
