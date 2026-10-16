extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor:=Node3D.new();root.add_child(actor)
 var instance:=MeshInstance3D.new();actor.add_child(instance)
 var rig=preload("res://scripts/prototype_3d/humanoid_rig.gd").new();rig.initialize_imported(actor,instance)
 var definitions:=[]
 for i in rig.rest.size():
  var a:Vector3=rig.rest[i].origin;var b:=a+Vector3.UP*3
  if i<3:b=rig.rest[i+1].origin
  elif i in [4,5,7,8,10,11,13,14]:b=rig.rest[i+1].origin
  elif i in [6,9]:b=a+(a-rig.rest[i-1].origin).normalized()*3
  definitions.append({"name":rig.skeleton.get_bone_name(i),"a":[a.x,a.y,a.z],"b":[b.x,b.y,b.z],"parent":rig.parents[i]})
 var file:=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE);file.store_string(JSON.stringify(definitions));file.close()
 var clips=preload("res://scripts/prototype_3d/survivor_animation.gd")
 print("Prepared ",definitions.size()," original bones; ",clips.STATES.size()," animation states, ",clips.FAMILIES.size()," equipment families")
 actor.free();quit()
