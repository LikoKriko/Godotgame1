extends Node3D
const Pose = preload("res://scripts/continuous_body_pose.gd")
const Tools = preload("res://scripts/tool_sprites.gd")
const SKIN := Color8(208,140,85)
const CLOTH := Color8(96,77,51)
const HAIR_VIEWS = preload("res://assets/characters/complete/reference_views.png")
const HEADS := [Vector2(242,64),Vector2(684,64),Vector2(1104,64),Vector2(1555,64),Vector2(245,480),Vector2(667,478),Vector2(1082,480),Vector2(1557,480)]
const Armor = preload("res://tools/torso_armor.gd")
var armor_id: StringName = &""
var nocked_arrow_enabled := true
var surface_tag := 0.0
var body_material: ShaderMaterial
var surface: SurfaceTool
var core_mesh: MeshInstance3D
var mesh_node: MeshInstance3D
var tool: Sprite3D
var last_pose: Dictionary = {}
var head_center := Vector3.ZERO
var grip_error := 0.0
var camera_up := Vector3(0,0.97,-0.24).normalized()
var visual_override: Dictionary = {}
var tool_material: ShaderMaterial
var bow_ends: Array[Vector3] = []

func _ready() -> void:
	mesh_node = MeshInstance3D.new()
	body_material = ShaderMaterial.new()
	body_material.shader = preload("res://shaders/baked_skin.gdshader")
	mesh_node.material_override = body_material
	add_child(mesh_node)
	core_mesh = MeshInstance3D.new()
	core_mesh.material_override = body_material
	core_mesh.visible = false
	add_child(core_mesh)
	tool = Sprite3D.new()
	for sprite in [tool]:
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.22
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	tool_material = ShaderMaterial.new()
	tool_material.shader = preload("res://shaders/baked_tool.gdshader")
	tool.material_override = tool_material

func vertex(point: Vector3, color: Color) -> void:
	surface.set_uv(Vector2(surface_tag,0))
	surface.set_uv2(Vector2.ZERO)
	surface.set_color(color)
	surface.add_vertex(point)

func triangle(a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	vertex(a,color); vertex(b,color); vertex(c,color)

func ellipsoid(center: Vector3,size: Vector3,color: Color,basis: Basis = Basis.IDENTITY) -> void:
	for row in 8:
		for column in 12:
			var p := []
			for index in [[row,column],[row+1,column],[row+1,column+1],[row,column+1]]:
				var latitude: float = index[0]*PI/8
				var longitude: float = index[1]*TAU/12
				p.append(center+basis*(Vector3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))*size))
			triangle(p[0],p[1],p[2],color)
			triangle(p[0],p[2],p[3],color)

func tube(joints: Array, radius_a: float,radius_b: float,color: Color,shorts: bool = false,steps: int = 12) -> void:
	# One uninterrupted surface spans BOTH bones. There is no knee/elbow cut.
	var centers: Array[Vector3] = []
	var rings: Array = []
	for section in steps+1:
		var t := section/float(steps)
		var center: Vector3
		if t <= 0.5:
			center = joints[0].lerp(joints[1],t*2)
		else:
			center = joints[1].lerp(joints[2],(t-0.5)*2)
		centers.append(center)
	for section in steps+1:
		var t := section/float(steps)
		var tangent := (centers[mini(steps,section+1)]-centers[maxi(0,section-1)]).normalized()
		var across := tangent.cross(Vector3.FORWARD).normalized()
		if across.length_squared() < 0.01: across = Vector3.RIGHT
		var other := tangent.cross(across).normalized()
		var radius := lerpf(radius_a,radius_b,t)
		if shorts and t < 0.36: radius += 0.7*(1-smoothstep(0.28,0.36,t))
		var ring: Array[Vector3] = []
		for segment in 10:
			var angle := segment*TAU/10
			ring.append(centers[section]+(across*cos(angle)+other*sin(angle))*radius)
		rings.append(ring)
	for section in steps:
		var cloth_section := shorts and section < 4
		for segment in 10:
			var tint := CLOTH if cloth_section and not (section == 3 and segment%3 == 1) else color
			var next := (segment+1)%10
			triangle(rings[section][segment],rings[section+1][segment],rings[section+1][next],tint)
			triangle(rings[section][segment],rings[section+1][next],rings[section][next],tint)
	for segment in 10:
		triangle(centers[0],rings[0][(segment+1)%10],rings[0][segment],CLOTH if shorts else color)
		triangle(centers[steps],rings[steps][segment],rings[steps][(segment+1)%10],color)

func integrated_head(torso: Transform3D,actor_basis: Basis,direction: int,pose_state: StringName) -> void:
	var index := posmod(2-roundi(direction/2.0),8)
	var source := Rect2(HEADS[index].x-105,HEADS[index].y,210,130)
	body_material.set_shader_parameter("head_reference",HAIR_VIEWS)
	body_material.set_shader_parameter("reference_rect",Vector4(source.position.x/HAIR_VIEWS.get_width(),source.position.y/HAIR_VIEWS.get_height(),source.size.x/HAIR_VIEWS.get_width(),source.size.y/HAIR_VIEWS.get_height()))
	# The neck and skull share the torso translation and its attachment pivot.
	# Counter-rotate the skull gently about the neck so running lean cannot
	# stretch the face or pull it backwards away from the shoulders.
	var neck := torso*Vector3(0,48.5,0)
	var stable_up := Vector3.UP.lerp(torso.basis*Vector3.UP,0.12).normalized()
	var center := actor_basis*(neck+stable_up*7.9)
	head_center = center
	var inverse := actor_basis.inverse()
	var join := inverse*(center-camera_up*7.5)
	tube([torso*Vector3(0,46.8,0),(torso*Vector3(0,46.8,0)).lerp(join,0.5),join],2.4,2.1,SKIN,false,4)
	var half_x := Vector3.RIGHT*(210.0/130*18.5*0.72/2)
	var half_y := camera_up*(18.5/2)
	var corners := [center-half_x+half_y,center+half_x+half_y,center+half_x-half_y,center-half_x-half_y]
	var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
	for corner in [0,1,2,0,2,3]:
		surface.set_uv(Vector2(3,0))
		surface.set_uv2(uv[corner])
		surface.set_color(SKIN)
		surface.add_vertex(inverse*corners[corner])
	surface_tag = 0

func tool_geometry(item: StringName) -> Dictionary:
	var data: Dictionary = visual_override.duplicate() if not visual_override.is_empty() else Tools.geometry(item).duplicate()
	if data.is_empty(): return data
	if visual_override.is_empty():
		if Tools.DATA.has(item):
			for anchor in ["support","string_top","string_bottom"]:
				if Tools.DATA[item].has(anchor): data[anchor] = Tools.DATA[item][anchor]-Tools.DATA[item]["rect"].position
			if item == &"bow": data["string_width"] = 20.0
	var original: Texture2D = data["texture"]
	var span: float = data.get("display_size",Tools.DISPLAY_SIZES.get(item,32.0))
	var target := original.get_size()*span/maxf(original.get_width(),original.get_height())
	var styled: Texture2D = preload("res://scripts/visual_style.gd").normalized(original,target,false,item == &"bow")
	var ratio := styled.get_size()/original.get_size()
	data["texture"] = styled
	if data.has("string_top"): data["string_width"] = data.get("string_width",8.0)*sqrt(ratio.x*ratio.y)
	for name in ["grip","contact","support","string_top","string_bottom"]:
		if data.has(name): data[name] *= ratio
	return data

func place_tool(data: Dictionary,grip: Vector3,shaft: Vector3,actor_basis: Basis,item: StringName) -> Dictionary:
	var source_axis: Vector2 = (data["contact"]-data["grip"]).normalized()
	var direction := (actor_basis*shaft).normalized()
	var plane_axis := -(actor_basis*Vector3.BACK) if item == &"bow" else Vector3.RIGHT
	var across := plane_axis-direction*direction.dot(plane_axis)
	if across.length_squared() < 0.03: across = camera_up-direction*direction.dot(camera_up)
	across = across.normalized()
	var x_axis := direction*source_axis.x-across*source_axis.y
	var y_axis := direction*source_axis.y+across*source_axis.x
	var texture: Texture2D = data["texture"]
	var pixels: float = data.get("display_size",Tools.DISPLAY_SIZES.get(item,32.0))/maxf(texture.get_width(),texture.get_height())
	var center: Vector2 = texture.get_size()/2-data["grip"]
	var world_grip := actor_basis*grip
	tool.texture = texture
	var raw: Texture2D = texture.atlas if texture is AtlasTexture else texture
	var region: Rect2 = texture.region if texture is AtlasTexture else Rect2(Vector2.ZERO,texture.get_size())
	tool_material.set_shader_parameter("item_texture",raw)
	tool_material.set_shader_parameter("source_rect",Vector4(region.position.x/raw.get_width(),region.position.y/raw.get_height(),region.size.x/raw.get_width(),region.size.y/raw.get_height()))
	tool_material.set_shader_parameter("source_size",texture.get_size())
	tool_material.set_shader_parameter("bow",data.has("string_top"))
	tool_material.set_shader_parameter("clear_black",data.get("clear_black",false))
	tool_material.set_shader_parameter("string_top",data.get("string_top",Vector2.ZERO))
	tool_material.set_shader_parameter("string_bottom",data.get("string_bottom",Vector2.ZERO))
	tool_material.set_shader_parameter("string_width",data.get("string_width",1.0))
	tool.pixel_size = pixels
	tool.basis = Basis(x_axis,-y_axis,x_axis.cross(-y_axis)).orthonormalized()
	tool.position = world_grip+(x_axis*center.x+y_axis*center.y)*pixels
	bow_ends.clear()
	if data.has("string_top"):
		for endpoint in [data["string_top"],data["string_bottom"]]:
			var point: Vector2 = endpoint-data["grip"]
			bow_ends.append(actor_basis.inverse()*(world_grip+(x_axis*point.x+y_axis*point.y)*pixels))
	var support := world_grip
	if data.has("support"):
		var offset: Vector2 = data["support"]-data["grip"]
		support += (x_axis*offset.x+y_axis*offset.y)*pixels
	return {"support":actor_basis.inverse()*support,"grip":grip}

func build(item: StringName,family: StringName,state: StringName,phase: float,direction: int,stop_phase: float = 0.20,stop_amplitude: float = 1.0) -> void:
	var pose := Pose.sample(family,state,phase,stop_phase,stop_amplitude,direction)
	if state == &"action" and (phase <= 0 or phase >= 1): pose = Pose.sample(family,&"idle",0,0.20,1.0,direction)
	last_pose = pose
	var yaw := PI/2-direction*TAU/16
	var actor_basis := Basis(Vector3.UP,yaw)
	var hands: Array[Vector3] = pose["hands"].duplicate()
	tool.visible = item != &""
	grip_error = 0
	if tool.visible:
		var geometry := tool_geometry(item)
		var grip: Vector3 = pose["grip"]
		var active: int = pose["active"]
		for attempt in 24:
			var placement := place_tool(geometry,grip,pose["shaft"],actor_basis,item)
			var support: Vector3 = placement["support"]
			var centers: Array[Vector3] = [pose["shoulders"][active]]
			if family in [&"axe",&"pickaxe"]:
				centers.append(pose["shoulders"][1-active]-(support-grip))
			for center in centers:
				if center.distance_to(grip) > 18.8:
					grip = center+center.direction_to(grip)*18.8
				elif center.distance_to(grip) < 8.15:
					grip = center+center.direction_to(grip)*8.15
		var placement := place_tool(geometry,grip,pose["shaft"],actor_basis,item)
		hands[active] = grip
		if family in [&"axe",&"pickaxe"]: hands[1-active] = placement["support"]
		pose["grip"] = grip
	surface_tag = 0
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso: Transform3D = pose["body"]
	# All body surfaces belong to one mesh; root joints stay inside the torso.
	for section in [[Vector3(0,35,0),Vector3(6.5,8.5,3.0)], [Vector3(0,42,0),Vector3(8.6,5.0,3.5)], [Vector3(0,48,0),Vector3(2.6,3.1,2.6)]]:
		ellipsoid(torso*section[0],section[1],SKIN,torso.basis)
	for side in [-1,1]:
		ellipsoid(torso*Vector3(side*7.4,44.6,0),Vector3(2.6,2.9,2.7),SKIN,torso.basis)
		ellipsoid(torso*Vector3(side*3.3,41,2.9),Vector3(3.6,2.9,1.2),SKIN,torso.basis)
		ellipsoid(torso*Vector3(side*1.6,36.0,2.8),Vector3(1.7,2.1,0.55),SKIN.lightened(0.025),torso.basis)
		ellipsoid(torso*Vector3(side*1.5,32.8,2.7),Vector3(1.55,1.6,0.4),SKIN,torso.basis)
		ellipsoid(torso*Vector3(side*3.2,41.0,4.0),Vector3(0.35,0.3,0.18),SKIN.darkened(0.23),torso.basis)
	ellipsoid(torso*Vector3(0,27.7,0),Vector3(7.2,3.5,3.5),CLOTH,torso.basis)
	if armor_id != &"":
		ellipsoid(torso*Vector3(0,35.5,0),Vector3(7.1,9.0,3.9),Color8(92,72,41),torso.basis)
		body_material.set_shader_parameter("armor_texture",Armor.texture_for(armor_id))
		Armor.append(surface,torso,armor_id)
	integrated_head(torso,actor_basis,direction,state)
	surface.generate_normals()
	core_mesh.mesh = surface.commit()
	core_mesh.basis = actor_basis
	for side in 2:
		surface_tag = 0
		var leg: Dictionary = pose["legs"][side]
		tube([leg["root"],leg["joint"],leg["end"]],2.65,1.55,SKIN,true)
		var ankle: Vector3 = leg["end"]
		var foot_basis := Basis(Vector3.RIGHT,leg["pitch"])
		ellipsoid(ankle+foot_basis*Vector3(0,-0.6,1.4),Vector3(2.5,1.35,3.5),SKIN,foot_basis)
		for toe in 4:
			ellipsoid(ankle+foot_basis*Vector3(-1.2+toe*0.8,-0.9,4.4-toe*0.16),Vector3(0.55,0.65,0.75),SKIN,foot_basis)
		var shoulder: Vector3 = pose["shoulders"][side]
		var pole := Vector3(1,0,-1) if family == &"bow" and side == 1 else Vector3(-0.35 if side == 0 else 0.35,-1,0)
		var arm := Pose.joint(shoulder,hands[side],Pose.UPPER_ARM,Pose.FOREARM,pole)
		if tool.visible and (family in [&"axe",&"pickaxe"] or side == pose["active"]):
			grip_error = maxf(grip_error,arm["end"].distance_to(hands[side]))
		surface_tag = 1 if side == 0 else 2
		tube([arm["root"],arm["joint"],arm["end"]],2.2,1.35,SKIN)
		ellipsoid(arm["end"],Vector3(1.45,1.7,1.5),SKIN)
		pose["hands"][side] = arm["end"]
		surface_tag = 0
		var patch: Vector3 = leg["root"].lerp(leg["joint"],0.17)+Vector3(0,0,2.9)
		ellipsoid(patch,Vector3(1.0,1.1,0.14),Color8(130,86,46))
	if family == &"bow":
		surface_tag = 4
		var string_mid := (bow_ends[0]+bow_ends[1])/2
		if state == &"action" and phase < 0.5:
			string_mid = string_mid.lerp(pose["hands"][1],smoothstep(0.2,0.44,phase))
		tube([bow_ends[0],bow_ends[0].lerp(string_mid,0.5),string_mid],0.12,0.12,Color8(123,125,119),false,2)
		tube([string_mid,string_mid.lerp(bow_ends[1],0.5),bow_ends[1]],0.12,0.12,Color8(123,125,119),false,2)
		if nocked_arrow_enabled and (state != &"action" or phase < 0.5 or phase > 0.97):
			var arrow_base: Vector3 = pose["hands"][1]
			var arrow_axis := arrow_base.direction_to(pose["hands"][0]+Vector3(0,1,0))
			tube([arrow_base,arrow_base+arrow_axis*12,arrow_base+arrow_axis*24],0.6,0.6,Color8(174,133,75),false,2)
			ellipsoid(arrow_base+arrow_axis*24,Vector3(0.8,0.8,1.0),Color8(158,160,151))
	surface_tag = 0
	# Cord and small fabric patches remain attached to the pelvis/thigh surfaces.
	for index in 24:
		var a := index*TAU/24
		var b := (index+1)*TAU/24
		tube([torso*Vector3(cos(a)*6.7,29.3,sin(a)*3.4),torso*Vector3(cos((a+b)/2)*6.7,29.3,sin((a+b)/2)*3.4),torso*Vector3(cos(b)*6.7,29.3,sin(b)*3.4)],0.25,0.25,Color8(128,84,43),false,2)
	for side in [-1,1]:
		tube([torso*Vector3(0,29.2,3.7),torso*Vector3(side*0.5,27.9,3.8),torso*Vector3(side*0.8,26.4,3.7)],0.27,0.22,Color8(131,86,44))
	surface.generate_normals()
	mesh_node.mesh = surface.commit()
	mesh_node.basis = actor_basis

func show_core_only() -> void:
	mesh_node.hide()
	tool.hide()
	core_mesh.show()

func restore_full(item: StringName) -> void:
	core_mesh.hide()
	mesh_node.show()
	tool.visible = item != &""
