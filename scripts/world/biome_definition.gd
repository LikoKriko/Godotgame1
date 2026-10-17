extends Resource
## Population rules; the TerrainProfile supplies the four existing ground layers.
@export var biome_id:StringName=&"temperate"
@export var density_normal:=.30
@export var density_dark:=.12
@export var density_vegetation:=.85
@export var density_noise_scale:=95.0
@export_range(0,1) var tree_fraction:=.65
@export_range(0,1) var rock_threshold:=.94
@export_range(0,1) var sapling_threshold:=.91
@export_range(0,1) var plant_threshold:=.88
@export_range(0,1) var path_clearance:=.2
func valid() -> bool:
 return not biome_id.is_empty() and is_finite(density_normal) and is_finite(density_dark) and is_finite(density_vegetation) and density_normal>=0 and density_dark>=0 and density_vegetation>=0 and is_finite(density_noise_scale) and density_noise_scale>0 and is_finite(tree_fraction) and tree_fraction>=0 and tree_fraction<=1 and is_finite(plant_threshold) and is_finite(sapling_threshold) and is_finite(rock_threshold) and 0<=plant_threshold and plant_threshold<=sapling_threshold and sapling_threshold<=rock_threshold and rock_threshold<=1 and is_finite(path_clearance) and path_clearance>=0 and path_clearance<=1
func resource_kind(roll:float,density:float) -> int:
 return 2 if roll<density*tree_fraction else (1 if roll>rock_threshold else (4 if roll>sapling_threshold else (5 if roll>plant_threshold else 0)))
