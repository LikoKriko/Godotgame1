shader_type spatial;
render_mode cull_disabled;
uniform sampler2D detail : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 observers[8];
uniform vec4 forwards[8];
uniform int history_count = 0;
varying flat float mip_bias;
float distance_budget(float d) {
 if(d>=90.0)return 0.35;
 if(d>=75.0)return 0.45;
 if(d>=65.0)return 0.65;
 if(d>=50.0)return 0.8;
 if(d>=40.0)return 0.9;
 if(d>=30.0)return 0.95;
 return 1.0;
}
void vertex() {
 vec3 center=(MODEL_MATRIX*vec4(UV2.x,0.01,UV2.y,1.0)).xyz;
 float quality=1.0;bool old_rear=false;bool recovering=false;float elapsed=0.0;
 for(int i=0;i<8;i++) {
  if(i>=history_count)break;
  vec3 offset=center-observers[i].xyz;
  float d=length(offset);bool rear=d>=50.0 && dot(offset,forwards[i].xyz)<0.0;
  float target=rear?min(0.5,distance_budget(d)):distance_budget(d);
  if(i==0)quality=target;
  else {
   if(old_rear && !rear) { recovering=true;elapsed=0.0; }
   if(rear || target<=quality) { quality=target;elapsed=0.0;if(rear)recovering=false; }
   else if(recovering) {
    elapsed+=observers[i].w;float steps=floor((elapsed+0.000001)/0.1);elapsed-=steps*0.1;
    quality=min(target,quality+steps*0.1);
    if(quality>=target) { recovering=false;elapsed=0.0; }
   } else quality=target;
  }
  old_rear=rear;
 }
 mip_bias=-log2(max(quality,0.01));
}
void fragment() {
 ALBEDO=tint.rgb*COLOR.rgb*texture(detail,UV,mip_bias).rgb;
 ROUGHNESS=1.0;
}
