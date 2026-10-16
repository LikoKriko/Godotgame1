extends RefCounted
## Crops preserve original uploads; rock silhouettes are ordered by their drawn area.
const ROCKS := [
	{"file":"res://assets/environment/imported/piedra_05_roca_pequena.png","rect":Rect2(275, 108, 699, 487)},
	{"file":"res://assets/environment/imported/piedra_10_variante_derivada.png","rect":Rect2(46, 228, 859, 541)},
	{"file":"res://assets/environment/imported/piedra_01_rocas_redondeadas.png","rect":Rect2(145, 291, 992, 638)},
	{"file":"res://assets/environment/imported/piedra_04_roca_baja.png","rect":Rect2(47, 306, 1194, 625)},
	{"file":"res://assets/environment/imported/piedra_07_rocas_agrietadas.png","rect":Rect2(173, 217, 989, 777)},
	{"file":"res://assets/environment/imported/piedra_09_roca_redondeada.png","rect":Rect2(72, 300, 1131, 712)},
	{"file":"res://assets/environment/imported/piedra_02_lajas.png","rect":Rect2(22, 214, 1237, 784)},
	{"file":"res://assets/environment/imported/piedra_03_formacion_vertical.png","rect":Rect2(165, 64, 875, 1120)},
	{"file":"res://assets/environment/imported/piedra_08_monticulo.png","rect":Rect2(50, 199, 1188, 874)},
	{"file":"res://assets/environment/imported/piedra_06_roca_irregular.png","rect":Rect2(43, 133, 1148, 934)},
]
const GRASS := [
	{"file":"res://assets/environment/imported/cesped_01.png","rect":Rect2(176, 546, 666, 373)},
	{"file":"res://assets/environment/imported/cesped_02.png","rect":Rect2(176, 336, 941, 732)},
	{"file":"res://assets/environment/imported/cesped_03.png","rect":Rect2(331, 370, 669, 464)},
	{"file":"res://assets/environment/imported/cesped_04.png","rect":Rect2(129, 418, 1045, 495)},
	{"file":"res://assets/environment/imported/cesped_05.png","rect":Rect2(71, 590, 1139, 205)},
	{"file":"res://assets/environment/imported/cesped_06.png","rect":Rect2(246, 329, 860, 715)},
	{"file":"res://assets/environment/imported/cesped_07.png","rect":Rect2(99, 409, 1090, 422)},
	{"file":"res://assets/environment/imported/cesped_08.png","rect":Rect2(336, 410, 441, 286)},
	{"file":"res://assets/environment/imported/cesped_09.png","rect":Rect2(403, 330, 411, 258)},
	{"file":"res://assets/environment/imported/cesped_10.png","rect":Rect2(209, 417, 790, 455)},
	{"file":"res://assets/environment/imported/cesped_11.png","rect":Rect2(99, 516, 924, 310)},
	{"file":"res://assets/environment/imported/cesped_12.png","rect":Rect2(319, 438, 541, 495)},
	{"file":"res://assets/environment/imported/cesped_13.png","rect":Rect2(0,0,146,46)},
	{"file":"res://assets/environment/imported/cesped_14.png","rect":Rect2(0,0,146,44)},
	{"file":"res://assets/environment/imported/cesped_15.png","rect":Rect2(0,0,146,69)},
	{"file":"res://assets/environment/imported/cesped_16.png","rect":Rect2(0,0,146,42)},
	{"file":"res://assets/environment/imported/cesped_17.png","rect":Rect2(0,0,146,44)},
]
static var textures: Dictionary = {}
static func texture(record: Dictionary) -> AtlasTexture:
	if not textures.has(record.file):
		var result := AtlasTexture.new()
		result.atlas = load(record.file)
		result.region = record.rect
		textures[record.file] = result
	return textures[record.file]
