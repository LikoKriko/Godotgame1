extends SceneTree
## Only the allowed prone/Idle endpoints; never samples the previous getup.
const OUT="res://assets/characters/prototype_3d/generated/aren_getup_blender_v2/authoring/endpoints.json"
func _initialize():call_deferred("run")
func row(t:Transform3D,scale:float) -> Array:
 return [[t.basis.x.x,t.basis.x.y,t.basis.x.z],[t.basis.y.x,t.basis.y.y,t.basis.y.z],[t.basis.z.x,t.basis.z.y,t.basis.z.z],[t.origin.x*scale,t.origin.y*scale,t.origin.z*scale]]
func run() -> void:
 var actor=load("res://scenes/prototype_3d/aren_extreme_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false);actor.position=Vector3.ZERO
 actor.apply_extreme(actor.GETUP)
 var start:Array=actor.native.posed.duplicate()
 actor.apply_extreme(actor.END)
 var bones:Array=[]
 for bone in actor.native.parents.size():
  bones.append({"name":str(actor.native.skeleton.get_bone_name(bone)).replace("smartrig_","smartrig:"),"rest":row(actor.native.rest[bone],actor.SCALE),"prone":row(start[bone],actor.SCALE),"idle":row(actor.native.posed[bone],actor.SCALE)})
 var file:=FileAccess.open(OUT,FileAccess.WRITE);file.store_string(JSON.stringify({"source":"f87bdc13; actual grounded prone and approved Idle only","bones":bones},"  ")+"\n");file.close()
 actor.free();print("EXPORTED ONLY TWO ENDPOINTS, 66 native bones");quit()
