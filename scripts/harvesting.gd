extends RefCounted
## Resource definitions shared with the seeded 3D layout; no 2D interaction.
const REACH := 40.0
const NONE := Vector2i(99999, 99999)
const TYPES := {
	1: {"name": "Roca", "material": "piedra", "hits": 3, "yield": 4, "branch": 1},
	2: {"name": "Árbol", "material": "madera", "hits": 3, "yield": 4, "branch": 0},
	4: {"name": "Arbolito joven", "material": "fibra", "hits": 2, "yield": 3, "branch": 0}
	,5: {"name":"Bardana","material":"hoja_bardana","hits":1,"yield":5,"branch":0}
}
var world
var bag
var meshes
var nodes: Dictionary = {}
var inventory := {"madera": 0, "piedra": 0, "chatarra": 0, "fibra": 0, "palo": 0}

func configure(map, inventory_model = null, hit_meshes = null) -> void:
	world = map
	bag = inventory_model
	meshes = hit_meshes
	nodes.clear()
	inventory = {"madera": 0, "piedra": 0, "chatarra": 0, "fibra": 0, "palo": 0}
	inventory["hoja_bardana"] = 0
	for cell in world.props:
		var kind: int = world.props[cell]
		if not TYPES.has(kind):
			continue
		var data: Dictionary = TYPES[kind].duplicate()
		if kind == 5: data["yield"] = 5 if world.burdock[cell] == 1 else 3
		data["hand_collectable"] = kind == 1 and preload("res://scripts/nature_variants.gd").profile(1,world.prop_variants[cell]).size_index == 0
		if data["hand_collectable"]:
			data["name"] = "Piedra pequeña"
			data["hits"] = 1
			data["yield"] = 1+posmod((cell.x*73856093) ^ (cell.y*19349663) ^ world.seed_value,3)
		data["footprint"] = Rect2i(cell, Vector2i(2, 2) if world.large_rocks.has(cell) else Vector2i.ONE)
		if kind == 1 and not data.hand_collectable:
			var size_index: int = preload("res://scripts/nature_variants.gd").profile(1,world.prop_variants[cell]).size_index
			var size_progress := clampf((size_index-1)/3.0,0,1)
			data["name"] = "Roca grande" if size_index == 4 else "Roca"
			data["hits"] = roundi(lerpf(4,12,size_progress))
			data["yield"] = roundi(lerpf(4,15,size_progress))
		data["remaining"] = data["hits"]
		nodes[cell] = data
