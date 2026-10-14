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
var head_look_adjust := 0.0
var head_yaw := 0.0
const HEAD_SCALE := 0.85
const ABDOMEN_WIDTH_SCALE := 0.65
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
func head_volume(center: Vector3,size: Vector3,color: Color,tag: float,body: Transform3D) -> void:
	var anchor := Vector3(0,21,2.5)
	var basis := (body.basis*Basis(Vector3.UP,head_yaw)*Basis(Vector3.RIGHT,-head_look_adjust)).scaled(Vector3.ONE*HEAD_SCALE)
	volume(center,size,color,tag,Transform3D(basis,body*anchor-basis*anchor))
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
	var walking := state in ["walk","run"]
	var running := state == "run"
	var seated := 1.0 if state == "sit" else (smoothstep(0,1,phase) if state == "sit_down" else (1-smoothstep(0,1,phase) if state == "sit_up" else 0.0))
	head_yaw = sin(phase*TAU)*0.12*seated
	var entering := state == "enter_attack"
	var attacking := state in ["attack","enter_attack"]
	var falling := state.begins_with("stun_fall")
	var recovering := state == "stun_rise"
	var fallen := smoothstep(0,1,phase) if falling else (1.0-smoothstep(0,1,phase) if recovering else (1.0 if state == "stun_hold" else 0.0))
	var standing := 1.0 if attacking else 0.0
	if falling and state != "stun_fall": standing = 1.0-fallen
	if entering: standing = smoothstep(0,0.25,phase)
	if state == "lower": standing = 1.0-smoothstep(0,1,phase)
	var effort := sin(phase*PI) if attacking else 0.0
	if falling and state != "stun_fall": effort = 1.0-fallen
	var bob := -(0.30 if running else 0.16)*(1-cos(phase*TAU*4)) if walking else -0.2*effort
	var lean := lerpf(0.96,-0.04*effort,standing)
	lean = lerpf(lean,0.14,seated)
	var pivot := Vector3(0,8.5,-2.5)
	var body_basis := Basis(Vector3.RIGHT,lean)
	if fallen > 0: body_basis = Basis(Vector3.BACK,1.2*fallen)*body_basis
	if walking: body_basis = Basis(Vector3.BACK,0.025*sin(phase*TAU))*body_basis
	var body := Transform3D(body_basis,pivot-body_basis*pivot+Vector3(0,bob-0.8*fallen-3.0*seated,0))
	head_look_adjust = lean*(1.0-standing)*(1-seated)+(0.045*sin(phase*TAU*2) if state == "feed" else 0.0)
	volume(Vector3(0,11.5,-1.5),Vector3(9.3*ABDOMEN_WIDTH_SCALE,8.5,7),FUR,0,body)
	head_volume(Vector3(0,21,2.5),Vector3(9.5,8.6,7.8),FUR,0,body)
	# A narrow digging muzzle and tiny folded ears, retaining the reference
	# cheek markings. No pig disk nose, boar tusks or separate head billboard.
	head_volume(Vector3(0,17.3,10.5),Vector3(3.5,2.4,4.6),FUR.lightened(0.10),0,body)
	head_volume(Vector3(0,17,14.7),Vector3(1.8,1.0,0.9),PINK,2,body)
	head_volume(Vector3(0,17.4,15.3),Vector3(0.65,0.4,0.2),Color8(80,43,34),2,body)
	for side in [-1.0,1.0]:
		head_volume(Vector3(side*5.7,20.4,9.6),Vector3(1.65,1.25,1.1),Color8(40,31,21),2,body)
		head_volume(Vector3(side*5.7,20.5,10.45),Vector3(0.72,0.65,0.32),Color8(183,62,43),2,body)
		head_volume(Vector3(side*5.85,20.95,10.4),Vector3(1.8,0.45,0.6),FUR*0.72,2,body)
		head_volume(Vector3(side*6,21,10.85),Vector3(0.32,0.32,0.2),IVORY,2,body)
		head_volume(Vector3(side*8.6,25.3,1.5),Vector3(1.6,0.85,1.2),FUR,0,body)
		head_volume(Vector3(side*8.8,25.4,2.4),Vector3(0.95,0.5,0.35),PINK,2,body)
		for mark in 2:
			head_volume(Vector3(side*(5.1+mark*1.0),17.3-mark*0.8,10.1),Vector3(1.2,0.45,0.6),IVORY,2,body)
	for side in [-1.0,1.0]: head_volume(Vector3(side*1.4,14.5,12.7),Vector3(0.45,0.65,0.45),IVORY,2,body)
	volume(Vector3(0,9,-8),Vector3(1.0,1.2,0.6),PINK,2,body)
	# Green crest matches the young reference rather than the adult silhouette.
	for i in 7:
		var z := -3.5+i*1.3
		head_volume(Vector3(0,28.9,z),Vector3(3.7,2.4-absf(i-3)*0.3,1.3),MOSS,2,body)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		# Four separate transfers, with three feet supporting the weight.
		var hind := Pose.stance_swing(phase+index*0.5,2.8,1.7) if walking else {"z":0.0,"lift":0.0,"pitch":0.0}
		var front := Pose.stance_swing(phase+0.25+index*0.5,2.8,1.25) if walking else {"z":0.0,"lift":0.0,"pitch":0.0}
		var foot_world := Vector3(side*5.5,1.5+float(hind.lift),lerpf(-4.6,1.5,standing)+float(hind.z))
		foot_world = foot_world.lerp(Vector3(side*6.5,1.45,6),seated)
		foot_world = foot_world.lerp(Vector3(side*9.0,1.5,-6.0),fallen)
		var leg := limb(Vector3(side*5.5,8.5,-1),body.affine_inverse()*foot_world,4.4,4.2,Vector3(0,0,1),2.2,body)
		var shoe := Transform3D(Basis(Vector3.RIGHT,float(hind.pitch)),body*leg.end)
		volume(Vector3.ZERO,Vector3(2.6,1.45,3.3),FUR,0,shoe)
		for toe in 3: volume(Vector3((toe-1)*1.1,-0.25,2.4),Vector3(0.5,0.65,1.1),IVORY,2,shoe)
		var rest := Vector3(side*12.4,10.8,5.5)
		var quad_world := Vector3(side*10.4,4.0+float(front.lift),12.2+float(front.z))
		var hand_world := quad_world.lerp(body*rest,standing)
		hand_world = hand_world.lerp(Vector3(side*12.2,4.0,3.0),seated)
		if falling and state != "stun_fall":
			var initial := Pose.gesture(rest,Vector3(side*12,14.5,1),Vector3(side*9.3,16.7,13.3),0.5,&"fist") if (index == 1) == left else rest.lerp(Vector3(side*10.5,14.5,7),0.5)
			hand_world = (body*initial).lerp(quad_world,fallen)
		if attacking:
			var hand := rest
			if (index == 1) == left:
				hand = Pose.gesture(rest,Vector3(side*12,14.5,1),Vector3(side*9.3,16.7,13.3),phase,&"fist")
			else: hand = rest.lerp(Vector3(side*10.5,14.5,7),effort*0.5)
			hand_world = quad_world.lerp(body*hand,standing)
		hand_world = hand_world.lerp(Vector3(side*16.3,4.0,12.2),fallen)
		var arm := limb(Vector3(side*8,20,0.7),body.affine_inverse()*hand_world,6.3,6.6,Vector3(side,0,-0.3),2.55,body)
		var fist := Transform3D(Basis.IDENTITY.slerp(body.basis,standing),body*arm.end)
		var rest_fist := Transform3D(Basis.IDENTITY,rest)
		paint_transform = fist*rest_fist.affine_inverse(); surface_tag = 1
		ellipsoid(fist.origin,Vector3(4.6,4.0,4.5),STONE,fist.basis)
		for ridge in 3: ellipsoid(fist*Vector3((ridge-1)*2,0.9,3.4),Vector3(1.2,1.5,1.2),STONE*0.92,fist.basis)
	surface.generate_normals(); mesh_node.mesh = surface.commit()
	mesh_node.position.y = maxf(0,-mesh_node.mesh.get_aabb().position.y)
