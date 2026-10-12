shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec4 pixel = texture(TEXTURE,UV);
	float value = max(pixel.r,max(pixel.g,pixel.b));
	vec3 color = pixel.rgb * vec3(0.72,0.76,0.72);
	float outline = 1.0-smoothstep(0.09,0.24,value);
	color = mix(color,vec3(0.20,0.23,0.21),outline);
	color = mix(vec3(0.235,0.295,0.205),color,0.58);
	COLOR = vec4(color,pixel.a);
}
