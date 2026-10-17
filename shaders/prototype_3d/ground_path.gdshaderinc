// Exact road masks in both the initial and cached material; natural dirt is
// a biome, not a road. Preserve the authored PNG colour without soil recolouring.
float ground_path(vec2 point) {
 float amount=0.0;
 if(existing_paths) {
  float horizontal=24.0*sin(point.x/210.0)+10.0*sin(point.x/93.0);
  float vertical=24.0*sin(point.y/245.0)-10.0*sin(point.y/110.0);
  float distance=min(abs(point.y-horizontal),abs(point.x-vertical));
  amount=1.0-smoothstep(44.0,72.0,distance+(noise_at(point/38.0)-0.5)*12.0);
 }
 return max(amount,initial_path(point));
}
