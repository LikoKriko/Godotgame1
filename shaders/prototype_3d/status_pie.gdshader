shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float remaining=1.0;
uniform vec4 status_color:source_color=vec4(0.902,0.875,0.651,1.0);
void fragment(){
 vec2 p=UV-vec2(0.5);float radius=length(p);
 if(radius>0.48)discard;
 float angle=mod(atan(p.x,-p.y)+6.2831853,6.2831853);
 vec3 paint=vec3(0.11,0.115,0.12);
 if(radius<0.455){if(angle<(1.0-remaining)*6.2831853)discard;paint=status_color.rgb;}
 ALBEDO=paint;
}
