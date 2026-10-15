shader_type spatial;
render_mode cull_disabled;
uniform sampler2D reference_views : source_color, filter_nearest_mipmap, repeat_disable;
void fragment(){
 // Stable pixel sampling in bind UVs: details stay attached to the skin.
 vec2 texels=vec2(textureSize(reference_views,0));
 vec2 pixel_uv=(floor(UV2*texels/2.0)*2.0+1.0)/texels;
 vec4 reference=texture(reference_views,pixel_uv);
 reference.rgb=floor(reference.rgb*31.0+0.5)/31.0;
 float usable=step(0.5,reference.a)*step(0.025,dot(reference.rgb,vec3(0.2126,0.7152,0.0722)));
 ALBEDO=mix(pow(COLOR.rgb,vec3(2.2)),reference.rgb,UV.y*usable);
 ROUGHNESS=0.97;
}
