extends "res://scripts/inventory_panel.gd"
## Same storage, recipes, repair and navigation; portrait and map are real 3D.
var portrait_view:SubViewport
var portrait_actor:Node3D
var quick_buttons:Array[Button]=[]
func configure(inventory,owner_game=null) -> void:
 icon_provider=preload("res://scripts/prototype_3d/item_icons.gd")
 build_portrait()
 super.configure(inventory,owner_game)
 var layout_content:=content
 content=inventory_page
 details.position=Vector2(834,582);details.size=Vector2(440,146)
 for i in 6:
  var button:=make_button(Vector2(834+i*72,770),Vector2(64,64))
  button.kind=&"quick";button.slot=i;button.pressed.connect(select_quick.bind(i));quick_buttons.append(button)
 var heading:=label("ACCESO RÁPIDO",Vector2(834,736),18)
 heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
 content=layout_content;refresh()
 visibility_changed.connect(func():portrait_view.render_target_update_mode=SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED)
func build_portrait() -> void:
 portrait_view=SubViewport.new();portrait_view.size=Vector2i(256,512)
 portrait_view.transparent_bg=true;portrait_view.own_world_3d=true
 portrait_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;add_child(portrait_view)
 portrait_actor=preload("res://scripts/prototype_3d/survivor_model.gd").new();portrait_view.add_child(portrait_actor)
 var bounds:AABB=portrait_actor.author_bounds()
 portrait_actor.scale=Vector3.ONE*(1.75/bounds.size.y);portrait_actor.position.y=-bounds.position.y*portrait_actor.scale.y
 portrait_actor.animate(&"idle",0,false)
 var camera:=Camera3D.new();camera.position=Vector3(0,0.96,3.1);camera.look_at_from_position(camera.position,Vector3(0,0.93,0));camera.fov=38;portrait_view.add_child(camera)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-25,0);portrait_view.add_child(light)
 var ambient:=WorldEnvironment.new();var environment:=Environment.new();environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_energy=0.65;ambient.environment=environment;portrait_view.add_child(ambient)
func update_portrait() -> void:
 if portrait==null:return
 portrait.texture=portrait_view.get_texture()
 portrait_actor.wear(model.equipment[&"torso"])
 portrait_view.render_target_update_mode=SubViewport.UPDATE_ONCE if visible else SubViewport.UPDATE_DISABLED
func refresh() -> void:
 super.refresh()
 for i in quick_buttons.size():
  show_item(quick_buttons[i],model.quick_slots[i])
  quick_buttons[i].self_modulate=Color("d9bf72") if chosen_quick==i else Color.WHITE
func make_map_view() -> Control:return preload("res://scripts/prototype_3d/map_view.gd").new()
