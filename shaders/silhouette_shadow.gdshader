shader_type canvas_item;
render_mode unshaded;
uniform float opacity = 0.25;
void fragment() {
	// Keep the actual animated alpha silhouette; no bounding-box shadow.
	COLOR = vec4(vec3(0.025,0.035,0.05),texture(TEXTURE,UV).a*opacity);
}
