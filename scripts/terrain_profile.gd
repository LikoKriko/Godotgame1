extends Resource
## All terrain tuning lives here; percentages are normalized automatically.
@export var chunk_size := 512
@export var chunks_per_frame := 2
@export var preload_chunks := 1
@export var retain_chunks := 2
@export var cache_limit := 96
@export var pixel_step := 1.0
@export var region_scale := 720.0
@export var transition_width := 0.028
@export var texture_span := 144.0
@export var proportions := Vector4(0.675,0.105,0.12,0.10)
@export var texture_paths: Array[String] = ["res://assets/environment/imported/terreno1_claro_1.png","res://assets/environment/imported/terreno1_oscuro_1.png","res://assets/environment/imported/terreno1_claro_2.png","res://assets/environment/imported/terreno1_claro_1_Path.png"]
func valid() -> bool:
 return chunk_size >= 32 and chunk_size <= 4096 and chunks_per_frame >= 1 and preload_chunks >= 0 and retain_chunks >= preload_chunks and cache_limit >= 1 and pixel_step > 0 and region_scale > 0 and texture_span > 0 and transition_width > 0 and proportions.x >= 0 and proportions.y >= 0 and proportions.z >= 0 and proportions.w >= 0 and proportions.x+proportions.y+proportions.z+proportions.w > 0
