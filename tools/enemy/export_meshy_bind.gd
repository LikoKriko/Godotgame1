extends SceneTree
## Export the current bind chains for the Blender bone-heat conversion.
func _initialize():
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():push_error("Pass -- /absolute/output/joints.json");quit(1);return
 var pose=preload("res://scripts/prototype_3d/young_pose.gd").sample(&"attack",0)
 var bones=[{"name":"body","a":[0,8.5,-6],"b":[0,19,-1],"parent":-1},{"name":"head","a":[0,17.5,15],"b":[0,27,7],"parent":0}]
 for kind in [&"legs",&"arms"]:
  for side in 2:
   var chain:Dictionary=pose[kind][side];var start=bones.size()
   var points=[chain.root,chain.joint,chain.end,chain.end+Vector3(0,0,2.5)]
   var names=["thigh","shin","foot"] if kind==&"legs" else ["upper_arm","forearm","fist"]
   for j in 3:
    var a:Vector3=points[j];var b:Vector3=points[j+1]
    bones.append({"name":names[j]+"_"+str(side),"a":[a.x,a.y,a.z],"b":[b.x,b.y,b.z],"parent":0 if j==0 else start+j-1})
 var file=FileAccess.open(args[0],FileAccess.WRITE);file.store_string(JSON.stringify(bones));file.close();quit()
