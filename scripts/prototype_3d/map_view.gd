extends Control
## Orthographic overview of the finite 3D test ground, without fog of war.
var game
var ground:Texture2D
static var ground_cache:Dictionary={}
func _ready():
 mouse_filter=Control.MOUSE_FILTER_IGNORE;texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 add_to_group("prototype_maps")
 refresh_terrain()
func refresh_terrain() -> void:
 if game==null or game.terrain==null:return
 var sampler=game.terrain.sampler
 var cache_key:=str(sampler.seed_value)+str(sampler.thresholds)+str(sampler.influences)+str(sampler.existing_paths)+str(game.world_bounds)
 if not ground_cache.has(cache_key):
  var image:=Image.create(64,64,false,Image.FORMAT_RGB8)
  var palette:=[Color("57603c"),Color("30392c"),Color("657747"),Color("776648")]
  for y in 64:
   for x in 64:
    var point:Vector2=(Vector2(x+0.5,y+0.5)/64*game.world_bounds.size+game.world_bounds.position)/game.terrain.METRES_PER_UNIT
    var weights:Vector4=sampler.weights_at(point);var color:=Color(0,0,0,1)
    for i in 4:color.r+=palette[i].r*weights[i];color.g+=palette[i].g*weights[i];color.b+=palette[i].b*weights[i]
    image.set_pixel(x,y,color)
  if ground_cache.size()>=4:ground_cache.clear()
  ground_cache[cache_key]=ImageTexture.create_from_image(image)
 ground=ground_cache[cache_key]
func project(point:Vector3) -> Vector2:return (Vector2(point.x,point.z)-game.world_bounds.position)/game.world_bounds.size*size
func _process(_delta:float) -> void:
 if is_visible_in_tree():queue_redraw()
func _draw() -> void:
 if game==null:return
 if ground!=null:draw_texture_rect(ground,Rect2(Vector2.ZERO,size),false)
 else:draw_rect(Rect2(Vector2.ZERO,size),Color("414a31"))
 for tree in get_tree().get_nodes_in_group("prototype_trees"):
  if tree.visible:draw_circle(project(tree.global_position),maxf(2,size.x*0.016),Color("72804a"))
 if game.use_test_layout:draw_rect(Rect2(project(Vector3(-6.25,0,-4.5)),Vector2(0.5,5.0)/game.world_bounds.size*size),Color("939080"))
 for enemy in get_tree().get_nodes_in_group("prototype_enemies"):
  if enemy.health>0:draw_circle(project(enemy.global_position),maxf(1.5,size.x*0.008),Color("b47a66"))
 var point:=project(game.player.global_position);draw_circle(point,3,Color("e0dac1"))
 var forward:Vector3=game.camera_rig.facing();draw_line(point,point+Vector2(forward.x,forward.z)*8,Color.WHITE,1)

func refresh() -> void:queue_redraw()
