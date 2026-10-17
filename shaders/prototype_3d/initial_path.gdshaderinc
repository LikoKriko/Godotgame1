uniform bool initial_relief = false;
uniform vec2 trial_path_origin=vec2(0.0);
uniform vec4 trial_path_curve=vec4(3.0,.065,1.2,.17);
uniform vec2 trial_path_widths=vec2(1.6,2.6);
uniform vec4 trial_path_ends=vec4(-96.0,-88.0,5.0,10.0);
float initial_path(vec2 units) {
 if(!initial_relief)return 0.0;
 vec2 p=units*(1.75/64.0)-trial_path_origin;
 float x=trial_path_curve.x*sin(-p.y*trial_path_curve.y)+trial_path_curve.z*sin(-p.y*trial_path_curve.w);
 return (1.0-smoothstep(trial_path_widths.x,trial_path_widths.y,abs(p.x-x)))*smoothstep(trial_path_ends.x,trial_path_ends.y,p.y)*(1.0-smoothstep(trial_path_ends.z,trial_path_ends.w,p.y));
}
