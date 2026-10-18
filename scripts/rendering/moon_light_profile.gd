extends Resource
## A single, faint directional moon follows the shared clock. It casts shadows
## only at night and does not change the solar shadow filter or atlas size.
@export var color:=Color(0.64,0.74,1.0)
@export_range(0,1) var energy:=0.16
@export_range(0,1) var shadow_opacity:=0.18
@export var shadow_distance:=40.0
@export var night_background:=Color("111b2b")
func configure(light:DirectionalLight3D) -> void:
 light.light_color=color
 light.shadow_opacity=shadow_opacity
 light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
 light.directional_shadow_max_distance=shadow_distance
 light.directional_shadow_split_1=0.25
 light.directional_shadow_blend_splits=true
 light.directional_shadow_fade_start=0.8
 light.shadow_bias=0.08
 light.shadow_normal_bias=1.5
func update(light:DirectionalLight3D,state:Dictionary,enabled:bool) -> void:
 var strength:float=state.strength if enabled else 0.0
 light.visible=strength>0.001
 light.shadow_enabled=light.visible
 light.light_energy=energy*strength
 light.rotation_degrees=Vector3(-lerpf(18,68,state.elevation),lerpf(110,250,state.progress),0)
