shader_type spatial;
render_mode cull_disabled;
uniform sampler2D painted_materials : source_color, filter_nearest_mipmap, repeat_disable;
uniform bool use_painted_materials = false;
uniform sampler2D front_reference : source_color, filter_nearest_mipmap, repeat_disable;
uniform sampler2D back_reference : source_color, filter_nearest_mipmap, repeat_disable;
void fragment() {
 ALBEDO = COLOR.rgb;
 if (UV.y > 0.5) {
  vec2 grid=vec2(1086.0,1448.0);
  vec2 coordinate=(floor(UV2*grid/2.0)*2.0+1.0)/grid;
  vec3 paint=UV.y<1.5?texture(front_reference,coordinate).rgb:texture(back_reference,coordinate).rgb;
  // Exclude the dark studio background; retain the source's controlled palette.
  float flesh=step(paint.b*1.25,paint.r)*step(paint.g*1.08,paint.r);
  float cloth=1.0-step(0.60,COLOR.r);
  float usable=max(flesh,cloth*step(0.12,max(paint.r,max(paint.g,paint.b))));
  ALBEDO=mix(COLOR.rgb,floor(paint*47.0+0.5)/47.0,usable*0.75);
 } else if (use_painted_materials && UV2.x >= 0.0) {
  // Nearest sampling preserves the pixel grid; mip levels avoid distant shimmer.
  vec3 painted = texture(painted_materials,UV2).rgb;
  // Retain the authored palette; the atlas adds restrained pixel detail.
  vec3 reference = UV2.y >= 0.5 ? (UV2.x >= 0.5 ? vec3(0.502,0.329,0.169) : vec3(0.259,0.169,0.118)) : (UV2.x >= 0.5 ? vec3(0.376,0.302,0.2) : vec3(0.816,0.549,0.333));
  ALBEDO = COLOR.rgb * mix(vec3(1.0),clamp(painted / max(reference,vec3(0.08)),vec3(0.72),vec3(1.28)),UV.x==3.0?0.15:1.0);
 }
 ROUGHNESS = 0.95;
}
