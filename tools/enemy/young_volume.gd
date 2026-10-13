extends "res://tools/continuous_actor.gd"
## Same continuous ellipsoid/two-bone skin authoring as the player.
## Source paint is attached to body parts; runtime uses whole baked sprites.
const CROPS := [Rect2i(85,61,259,220),Rect2i(495,61,241,220),Rect2i(975,64,256,217),Rect2i(1466,61,239,220)]
const FUR := Color8(132,96,80)
const STONE := Color8(170,162,135)
const PINK := Color8(185,128,109)
const MOSS := Color8(154,155,65)
const IVORY := Color8(220,207,164)
var paint_transform := Transform3D.IDENTITY
var limb_lengths: Array[Vector2] = []
func _ready() -> void:
	mesh_node = MeshInstance3D.new(); add_child(mesh_node)
	body_material = ShaderMaterial.new(); body_material.shader = preload("res://shaders/baked_young.gdshader")
	mesh_node.material_override = body_material
	var original: Image = preload("res://assets/enemies/first/reference_views.png").get_image()
	var names := ["front","right_view","back","left_view"]
	for i in 4: body_material.set_shader_parameter(names[i],ImageTexture.create_from_image(original.get_region(CROPS[i])))
func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	for point in [a,b,c]:
		var rest: Vector3 = paint_transform.affine_inverse()*point
		surface.set_uv(Vector2(0.5+rest.z/35.0,surface_tag))
		surface.set_uv2(Vector2(0.5+rest.x/38.0,1.0-rest.y/32.0))
		surface.set_color(color); surface.add_vertex(point)
func volume(center: Vector3,size: Vector3,color: Color,tag: float,body: Transform3D) -> void:
	surface_tag = tag; paint_transform = body
	ellipsoid(body*center,size,color,body.basis)
func limb(root_point: Vector3,target: Vector3,a: float,b: float,pole: Vector3,radius: float,body: Transform3D) -> Dictionary:
	var joints := Pose.joint(root_point,target,a,b,pole)
	limb_lengths.append(Vector2(joints.root.distance_to(joints.joint),joints.joint.distance_to(joints.end)))
	paint_transform = body; surface_tag = 0
	tube([body*joints.root,body*joints.joint,body*joints.end],radius,radius*0.8,FUR,false,12)
	return joints
func pose(state: String,phase: float,direction: int,left: bool = true) -> void:
	rotation.y = PI/2-direction*TAU/16
	var paint_direction := fposmod((direction-4)/4.0,4.0)
	body_material.set_shader_parameter("view",floori(paint_direction))
	body_material.set_shader_parameter("next_view",(floori(paint_direction)+1)%4)
	body_material.set_shader_parameter("view_blend",smoothstep(0,1,fposmod(paint_direction,1.0)))
	surface = SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	limb_lengths.clear()
	var walking := state == "walk"
	var attacking := state == "attack" and phase > 0.0 and phase < 1.0
	var effort := sin(phase*PI) if attacking else 0.0
	var bob := -0.35*(1-cos(phase*TAU*2)) if walking else -0.25*effort
	var lean := -0.04*effort
	var body := Transform3D(Basis(Vector3.RIGHT,lean),Vector3(0,bob,0))
	volume(Vector3(0,11.5,-1.5),Vector3(9.3,8.5,7),FUR,0,body)
	volume(Vector3(0,21,2.5),Vector3(9.5,8.6,7.8),FUR,0,body)
	# A compact muzzle, eyes and tusks stay attached to the same skull.
	volume(Vector3(0,16.8,10.6),Vector3(5.2,3,3.7),PINK,2,body)
	for side in [-1.0,1.0]:
		volume(Vector3(side*1.8,17.2,14),Vector3(0.7,0.65,0.45),Color8(65,40,30),2,body)
		volume(Vector3(side*5.7,20.4,9.6),Vector3(1.65,1.25,1.1),Color8(40,31,21),2,body)
		volume(Vector3(side*5.7,20.5,10.45),Vector3(0.72,0.65,0.32),Color8(183,62,43),2,body)
		volume(Vector3(side*5.85,20.95,10.4),Vector3(1.8,0.45,0.6),FUR*0.72,2,body)
		volume(Vector3(side*6.0,21.0,10.85),Vector3(0.32,0.32,0.2),IVORY,2,body)
		volume(Vector3(side*8.6,26,2),Vector3(2.2,1.6,1.4),FUR,0,body)
		volume(Vector3(side*8.8,26.2,3.1),Vector3(1.4,0.8,0.45),PINK,2,body)
		surface_tag = 2; paint_transform = body
		tube([body*Vector3(side*4,14,9),body*Vector3(side*6.8,15.5,11),body*Vector3(side*5.2,18.2,11.9)],1.6,0.12,IVORY,false,8)
	volume(Vector3(0,9,-8),Vector3(1.0,1.2,0.6),PINK,2,body)
	for side in [-1.0,1.0]: volume(Vector3(side*2,13.4,12),Vector3(0.5,1.1,0.45),IVORY,2,body)
	# Green crest matches the young reference rather than the adult silhouette.
	for i in 7:
		var z := -3.5+i*1.3
		volume(Vector3(0,28.9,z),Vector3(3.7,2.4-absf(i-3)*0.3,1.3),MOSS,2,body)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var gait := Pose.gait(phase+index*0.5,0.29) if walking else {"z":0.0,"lift":0.0,"pitch":0.0}
		var foot := Vector3(side*5.5,1.5+float(gait.lift)-bob,1.5+float(gait.z))
		var leg := limb(Vector3(side*5.5,8.5,-1),foot,4.4,4.2,Vector3(0,0,1),2.2,body)
		var shoe := Transform3D(body.basis,body*leg.end)
		# Foot and toes move as one part; no detached lower leg.
		volume(Vector3.ZERO,Vector3(2.6,1.45,3.3),FUR,0,shoe)
		for toe in 3: volume(Vector3((toe-1)*1.1,-0.25,2.4),Vector3(0.5,0.65,1.1),IVORY,2,shoe)
		var rest := Vector3(side*12.4,10.8,5.5)
		var hand := rest
		if walking: hand += Vector3(0,0,-float(gait.z)*0.45)
		if attacking:
			if (index == 1) == left:
				var windup := Vector3(side*12.0,14.5,1)
				var impact := Vector3(side*9.3,16.7,13.3)
				hand = Pose.gesture(rest,windup,impact,phase,&"fist")
			else: hand = rest.lerp(Vector3(side*10.5,14.5,7),effort*0.5)
		var arm := limb(Vector3(side*8,20,0.7),hand,6.3,6.6,Vector3(side,0,-0.3),2.55,body)
		var fist := Transform3D(body.basis,body*arm.end)
		# Stable hand-local paint prevents moving stone textures during the punch.
		var rest_fist := Transform3D(Basis.IDENTITY,rest)
		paint_transform = fist*rest_fist.affine_inverse(); surface_tag = 1
		ellipsoid(fist.origin,Vector3(4.6,4.0,4.5),STONE,fist.basis)
		for ridge in 3:
			ellipsoid(fist*Vector3((ridge-1)*2,0.9,3.4),Vector3(1.2,1.5,1.2),STONE*0.92,fist.basis)
	surface.generate_normals(); mesh_node.mesh = surface.commit()
