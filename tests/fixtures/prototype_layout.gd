extends Node3D
func populate(game) -> void:
 var units:=1.75/64.0
 for point in [Vector3(0,0,-1.6),Vector3(3,0,-4),Vector3(-3,0,-5),Vector3(5,0,3)]:
  var tree := preload("res://scripts/prototype_3d/tree_model.gd").new(); game.add_child(tree); tree.position = point; tree.scale = Vector3.ONE*0.65
 for index in game.get_tree().get_nodes_in_group("prototype_trees").size():
  var tree=game.get_tree().get_nodes_in_group("prototype_trees")[index]
  var center:Vector2=Vector2(tree.position.x,tree.position.z)/units
  game.terrain.sampler.add_influence(StringName("tree_%d"%index),&"dirt",Rect2(center-Vector2.ONE*25,Vector2.ONE*50),0.65)
 game.terrain.refresh_influences()
 var rock_points:=[Vector3(3,0,2.5),Vector3(4,0,-2.2),Vector3(-3,0,1.5),Vector3(8,0,-7)]
 for i in rock_points.size():
  var rock:=preload("res://scripts/prototype_3d/rock.gd").new();game.add_child(rock);rock.position=rock_points[i];rock.configure()
 var water:=preload("res://scripts/prototype_3d/water_source.gd").new();game.add_child(water);water.position=Vector3(-2,0,4)
 # A solid test wall also provides an explicit camera collision case.
 var wall := StaticBody3D.new(); game.add_child(wall); wall.position = Vector3(-6,1,-2)
 var collider := CollisionShape3D.new(); var block := BoxShape3D.new(); block.size = Vector3(0.5,2,5); collider.shape = block; wall.add_child(collider)
 var visual := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = block.size; visual.mesh = cube
 var paint := StandardMaterial3D.new(); paint.albedo_color = Color("686257"); paint.roughness = 1.0; visual.material_override = paint; wall.add_child(visual)
