extends SceneTree
const Models=preload("res://scripts/prototype_3d/item_models.gd")
const Inventory=preload("res://scripts/inventory.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var bag=Inventory.new();bag.reset()
 for id in Models.SUPPORTED:
  var item:Dictionary=bag.make_item(id,1)
  var original:=item.duplicate(true)
  var first:Node3D=Models.create(item);var second:Node3D=Models.create(item)
  require(first!=null and first.get_child_count()>0,"Every supported item builds solid geometry: "+String(id))
  var bounds:=Models.bounds(first)
  require(bounds.position.y>=0 and bounds.position.y<0.004 and bounds.size.is_finite() and bounds.size.length()>0.02,"Model rests directly on ground with finite dimensions: "+String(id))
  var shared:=first.get_child_count()==second.get_child_count()
  for i in first.get_child_count():
   var mesh:MeshInstance3D=first.get_child(i);shared=shared and mesh.mesh==second.get_child(i).mesh and mesh.material_override==second.get_child(i).material_override
   require(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON,"Physical object casts its own silhouette")
  require(shared,"Repeated drops reuse meshes and materials")
  require(item==original,"Building geometry cannot mutate quantity, uses or uid")
  item.quantity+=1;item.uid+=100;item.uses-=1
  require(Models.state_key(item)==Models.state_key(original),"Stack count/wear/identity do not duplicate cosmetic resources")
  first.free();second.free()
 var empty:Dictionary=bag.make_item(&"botella",1);empty.water_ml=0
 var half:=empty.duplicate(true);half.water_ml=250
 var full:=empty.duplicate(true);full.water_ml=500
 require(Models.state_key({"id":&"water"})==Models.state_key(full),"Legacy water reuses the current full-bottle model")
 var bottle_a:Node3D=Models.create(empty);var bottle_b:Node3D=Models.create(half);var bottle_c:Node3D=Models.create(full)
 require(Models.state_key(empty)!=Models.state_key(full) and Models.state_key(half)!=Models.state_key(full),"Bottle mesh cache separates visible water states")
 require(bottle_b.get_child_count()==bottle_a.get_child_count()+1 and bottle_c.get_child_count()==bottle_b.get_child_count(),"Water changes add the liquid surface without altering the item record")
 bottle_a.free();bottle_b.free();bottle_c.free()
 for id in [&"knife",&"fibra",&"leaf_helmet"]:require(not Models.supported(id) and Models.create({"id":id})==null,"Unavailable designs keep explicit provisional markers")
 var game=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();game.use_test_layout=true;root.add_child(game);game.set_physics_process(false);game.player.set_physics_process(false)
 await physics_frame
 var worn:=bag.make_item(&"axe",1);worn.uses=17
 var drop=game.corpse_loot.spawn_drop(worn,Vector3(9,0.15,9))
 require(drop.item.uses==17 and not drop.visual is Sprite3D,"Real drop keeps wear and uses the solid model")
 require(absf(drop.global_position.y)<0.01,"New drop settles on actual ground")
 var skin:Node3D=drop.visual;require(skin.get_child(0) is MeshInstance3D,"Drop has depth-tested render geometry")
 var restore=game.corpse_loot.spawn_drop(full,Vector3(12,0.3,12),false)
 require(restore.global_position==Vector3(12,0.3,12),"Loading preserves an exact saved position without resnapping")
 game.player.equipped=false;game.bag.active_quick_uid=-1
 require(game.corpse_loot.pickup(drop),"The new visual keeps the existing free-hand pickup path")
 var recovered:=false
 for slot in game.bag.slots:
  if slot.get("id")==&"axe" and slot.get("uses")==17:recovered=true
 require(recovered,"Picking up the model retains individual wear")
 game.free();print("%s: %d physical item, shared resource, water and pickup checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
