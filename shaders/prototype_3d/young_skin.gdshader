shader_type spatial;
render_mode cull_disabled;
uniform sampler2D reference_views : source_color, filter_nearest_mipmap, repeat_disable;
varying vec4 front_back_uv;
varying vec4 side_uv;
varying vec4 reference_weights;
void vertex() {
 front_back_uv=CUSTOM0;side_uv=CUSTOM1;reference_weights=CUSTOM2;
}
vec4 fur_sample(vec2 coordinate) {
 vec2 size=vec2(textureSize(reference_views,0));
 vec2 pixel=(floor(coordinate*size/2.0)*2.0+1.0)/size;
 vec4 paint=texture(reference_views,pixel);
 // Brown fur only. Pink skin, golden moss, red eyes, ivory, stone and the
 // neutral studio have their own surfaces and cannot bleed onto the coat.
 float usable=step(0.5,paint.a)*step(paint.g*1.16,paint.r);
 usable*=step(paint.b*1.24,paint.g)*step(paint.r,paint.g*2.0);
 usable*=step(0.028,dot(paint.rgb,vec3(0.2126,0.7152,0.0722)));
 return vec4(floor(paint.rgb*47.0+0.5)/47.0,usable);
}
void fragment() {
 ALBEDO=pow(COLOR.rgb,vec3(1.6));
 if (UV.y>0.0) {
  vec4 a=fur_sample(front_back_uv.xy);
  vec4 b=fur_sample(front_back_uv.zw);
  vec4 c=fur_sample(side_uv.xy);
  vec4 d=fur_sample(side_uv.zw);
  vec4 weights=reference_weights*vec4(a.a,b.a,c.a,d.a);
  float total=dot(weights,vec4(1.0));
  vec3 paint=(a.rgb*weights.x+b.rgb*weights.y+c.rgb*weights.z+d.rgb*weights.w)/max(total,0.0001);
  ALBEDO=mix(ALBEDO,paint,UV.y*clamp(total,0.0,1.0));
 }
 ROUGHNESS=0.97;
}
