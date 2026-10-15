shader_type spatial;
render_mode cull_front, unshaded;
uniform float thickness = 0.035;
void vertex() { VERTEX += NORMAL * thickness; }
// A fine material-coloured edge avoids black seams between every overlapping
// lock while preserving the creature's exterior silhouette.
void fragment() { ALBEDO = COLOR.rgb * 0.42; }
