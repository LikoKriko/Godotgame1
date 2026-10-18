extends Resource
## Shared sun-shadow parameters. The trial and its captured baseline use the
## same apply path, so the graphics switch can compare them without restarting.
const PROPERTIES:Array[StringName]=[&"directional_shadow_mode",&"directional_shadow_max_distance",&"directional_shadow_split_1",&"directional_shadow_split_2",&"directional_shadow_split_3",&"directional_shadow_blend_splits",&"directional_shadow_fade_start",&"shadow_bias",&"shadow_normal_bias"]
@export var directional_shadow_mode:int=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
@export var directional_shadow_max_distance:=60.0
@export var directional_shadow_split_1:=0.12
@export var directional_shadow_split_2:=0.30
@export var directional_shadow_split_3:=0.60
@export var directional_shadow_blend_splits:=true
@export var directional_shadow_fade_start:=0.80
@export var shadow_bias:=0.08
@export var shadow_normal_bias:=1.5
# Compatibility maps LOW/MEDIUM to five PCF taps and HIGH to thirteen.
@export var filter_quality:int=RenderingServer.SHADOW_QUALITY_SOFT_HIGH
func capture(light:DirectionalLight3D) -> void:
 for property in PROPERTIES:set(property,light.get(property))
 filter_quality=int(ProjectSettings.get_setting_with_override("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))
func apply(light:DirectionalLight3D) -> void:
 for property in PROPERTIES:light.set(property,get(property))
 RenderingServer.directional_soft_shadow_filter_set_quality(filter_quality)
