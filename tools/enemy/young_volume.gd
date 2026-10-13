extends Node3D
## Reconstruct a continuous textured visual hull from the user's four views.
## Only the exported full sprites are used in game; this rig is authoring data.
const HEIGHT := 32
const CROPS := [Rect2i(85,61,259,220),Rect2i(495,61,241,220),Rect2i(975,64,256,217),Rect2i(1466,61,239,220)]
const NORMALS := [Vector3i(0,0,1),Vector3i(1,0,0),Vector3i(0,0,-1),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0)]
var pictures: Array[Image] = []
var points: Array[Vector3] = []
var faces: Array = []
var view_colors: Dictionary = {}
var mesh_node := MeshInstance3D.new()
var width := 38.0
var depth := 35.0

func _ready() -> void:
	add_child(mesh_node)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_node.material_override = material
	var original := Image.load_from_file("res://assets/enemies/first/reference_views.png")
	for rect in CROPS: pictures.append(original.get_region(rect))
	width = HEIGHT*CROPS[0].size.x/float(CROPS[0].size.y)
	depth = HEIGHT*CROPS[1].size.x/float(CROPS[1].size.y)
	var occupied := {}
	for y in HEIGHT:
		for x in range(-ceili(width/2),ceili(width/2)):
			for z in range(-ceili(depth/2),ceili(depth/2)):
				var center := Vector3(x+0.5,y+0.5,z+0.5)
				var inside := true
				for view in 4:
					if sample(center,view).a < 0.75: inside = false; break
				if inside: occupied[Vector3i(x,y,z)] = true
	var vertices := {}
	for cell in occupied:
		for side in 6:
			if occupied.has(cell+NORMALS[side]): continue
			var normal := Vector3(NORMALS[side])
			var tangent := Vector3.RIGHT if side in [0,2,4,5] else Vector3.FORWARD
			var up := normal.cross(tangent)
			var center := Vector3(cell)+Vector3.ONE/2+normal/2
			var quad := []
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point: Vector3 = center+tangent*corner.x/2+up*corner.y/2
				if not vertices.has(point): vertices[point] = points.size(); points.append(point)
				quad.append(vertices[point])
			var view := side if side < 4 else (0 if center.z >= 0 else 2)
			var color := sample(center-normal*0.5,view)
			color.a = 1
			if side == 5: color = color.darkened(0.08)
			faces.append([quad,color,Vector3(cell)+Vector3.ONE/2])
	print("Young volume: %d occupied cells, %d shared vertices, %d faces" % [occupied.size(),points.size(),faces.size()])

func sample(point: Vector3,view: int) -> Color:
	var horizontal := point.x/width if view in [0,2] else point.z/depth
	if view in [2,3]: horizontal = -horizontal
	var uv := Vector2(0.5+horizontal,1-point.y/HEIGHT)
	if uv.x < 0 or uv.x >= 1 or uv.y < 0 or uv.y >= 1: return Color.TRANSPARENT
	var picture := pictures[view]
	var color := picture.get_pixel(clampi(int(uv.x*picture.get_width()),0,picture.get_width()-1),clampi(int(uv.y*picture.get_height()),0,picture.get_height()-1))
	if maxf(color.r,maxf(color.g,color.b)) < 0.08: color.a = 0
	return color

func deform(point: Vector3,state: String,phase: float,left: bool) -> Vector3:
	var result := point
	var gait := sin(phase*TAU)
	var side := 1.0 if point.x >= 0 else -1.0
	var leg := 1-smoothstep(8,14,point.y)
	var arm := smoothstep(8,13,absf(point.x))*(1-smoothstep(24,29,point.y))*smoothstep(6,10,point.y)
	if state == "walk":
		var stride := gait*side
		result.z += stride*4*leg
		result.y += maxf(0,-stride)*1.7*leg
		# A broad shoulder blend keeps the textured stone fists attached.
		result.z -= stride*2*arm
		result.y += (1-absf(gait))*0.45
	elif state == "attack":
		var amount: float
		if phase <= 0.28: amount = -0.35*smoothstep(0,0.28,phase)
		elif phase <= 0.5: amount = lerpf(-0.35,1,smoothstep(0.28,0.5,phase))
		elif phase <= 0.64: amount = lerpf(1,0.35,smoothstep(0.5,0.64,phase))
		else: amount = 0.35*(1-smoothstep(0.64,1,phase))
		var active := (side > 0) == left
		if active:
			result.z += amount*9*arm
			result.x -= side*amount*2*arm
			result.y += amount*4.5*arm
		else: result.z -= amount*1.2*arm
		var body := smoothstep(5,15,point.y)
		result.z += amount*1.6*body
	return result

func pose(state: String,phase: float,direction: int,left: bool = true) -> void:
	rotation.y = PI/2-direction*TAU/16
	# Project the same view across all visible faces; sampling each cube's normal
	# separately produces horizontal colour seams at voxel steps in side views.
	if not view_colors.has(direction):
		var colors := PackedColorArray()
		var source: int = [3,0,1,2][posmod(roundi(direction/4.0),4)]
		for face in faces:
			var color := sample(face[2],source)
			if color.a < 0.75: color = face[1]
			color.a = 1; colors.append(color)
		view_colors[direction] = colors
	var transformed := PackedVector3Array()
	for point in points: transformed.append(deform(point,state,phase,left))
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in faces.size():
		var face: Array = faces[i]
		surface.set_color(view_colors[direction][i])
		for index in [0,1,2,0,2,3]: surface.add_vertex(transformed[face[0][index]])
	mesh_node.mesh = surface.commit()
