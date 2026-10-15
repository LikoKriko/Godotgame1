shader_type spatial;
render_mode cull_disabled;
uniform sampler2D painted_materials : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool use_painted_materials = false;
uniform sampler2D front_reference : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D back_reference : source_color, filter_nearest_mipmap, repeat_disable;
varying vec4 reference_data;
void vertex() { reference_data = CUSTOM0; }
float paint_mask(vec3 paint, float cloth) {
 float flesh=step(paint.b*1.25,paint.r)*step(paint.g*1.08,paint.r);
 float high=max(paint.r,max(paint.g,paint.b));
 float low=min(paint.r,min(paint.g,paint.b));
 float chroma=(high-low)/max(high,0.001);
 float cloth_mask=step(0.22,chroma)*step(0.12,high)*(1.0-step(paint.g*1.30,paint.r));
 return cloth>0.5?cloth_mask:flesh;
}
void fragment() {
 ALBEDO = COLOR.rgb;
 if (UV.y > 0.5) {
  vec2 grid=vec2(1086.0,1448.0);
  vec2 coordinate=(floor(UV2*grid/2.0)*2.0+1.0)/grid;
  vec2 rear=(floor(reference_data.xy*grid/2.0)*2.0+1.0)/grid;
  vec3 front_paint=texture(front_reference,coordinate).rgb;
  vec3 rear_paint=texture(back_reference,rear).rgb;
  float front_mask=paint_mask(front_paint,reference_data.w);
  float rear_mask=paint_mask(rear_paint,reference_data.w);
  vec3 front_color=mix(COLOR.rgb,floor(front_paint*47.0+0.5)/47.0,front_mask*0.75);
  vec3 rear_color=mix(COLOR.rgb,floor(rear_paint*47.0+0.5)/47.0,rear_mask*0.75);
  ALBEDO=mix(rear_color,front_color,reference_data.z);
 } else if (use_painted_materials && UV2.x >= 0.0) {
  // Nearest sampling preserves the pixel grid; mip levels avoid distant shimmer.
  vec3 painted = texture(painted_materials,UV2).rgb;
  // Retain the authored palette; the atlas adds restrained pixel detail.
  vec3 reference = UV2.y >= 0.5 ? (UV2.x >= 0.5 ? vec3(0.502,0.329,0.169) : vec3(0.259,0.169,0.118)) : (UV2.x >= 0.5 ? vec3(0.376,0.302,0.2) : vec3(0.816,0.549,0.333));
  ALBEDO = COLOR.rgb * mix(vec3(1.0),clamp(painted / max(reference,vec3(0.08)),vec3(0.72),vec3(1.28)),UV.x==3.0?0.15:1.0);
 }
 ROUGHNESS = 0.95;
}
