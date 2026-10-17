uniform bool initial_relief = false;
float initial_path(vec2 units) {
 if(!initial_relief)return 0.0;
 vec2 p=units*(1.75/64.0);
 float x=3.0*sin(-p.y*.065)+1.2*sin(-p.y*.17);
 return (1.0-smoothstep(1.6,2.6,abs(p.x-x)))*smoothstep(-96.0,-88.0,p.y)*(1.0-smoothstep(5.0,10.0,p.y));
}
vec3 initial_soil(vec3 sampled,float amount) {
 // Reuse the pixel pattern with a controlled soil palette on the trial path.
 float value=dot(sampled,vec3(.299,.587,.114))*.6+.06;
 return mix(sampled,value*vec3(1.9,1.35,.85),amount);
}
