extends SceneTree
const Source=preload("res://tools/animation/characters/motion_source.gd")
const OUTPUT="res://assets/characters/prototype_3d/motion/controls.res"
const SAMPLES:=600
func _initialize():
 var library:=AnimationLibrary.new();var total:=0;var dense:=0
 for name in Source.CLIPS:
  var clip:=Animation.new();clip.length=1.0
  if name in [&"walk",&"run"]:clip.loop_mode=Animation.LOOP_LINEAR
  var values:Array[Dictionary]=[]
  for frame in SAMPLES+1:values.append(Source.sample(name,frame/float(SAMPLES)))
  for control in values[0]:
   var track:=clip.add_track(Animation.TYPE_POSITION_3D);clip.track_set_path(track,NodePath(control))
   var pinned:Array[int]=[0,SAMPLES]
   var contacts:Array=[0.0,.28,.5,.52,.65,.90,1.0]
   if name in [&"walk",&"run"]:contacts=[0.0,.5,1.0,.4 if name==&"run" else .6,.9 if name==&"run" else .1]
   elif name==&"jump":contacts=[0.0,.1,.23,.35,.70,.87,.96,1.0]
   elif String(name).begins_with("slide"):contacts=[0.0,.34,.72,1.0]
   elif name==&"death":contacts=[0.0,.38,.40,.62,.84,1.0]
   var constant:=true
   for value in values:
    if value[control]!=values[0][control]:constant=false;break
   for phase in contacts:pinned.append(roundi(phase*SAMPLES))
   if constant:pinned=[0,0]
   pinned.sort();var kept:Dictionary={}
   var angular:=String(control) in ["chest","pelvis","spine","shoulders","arms","angles","curl","wind_axis","hit_axis","foot_angles_l","foot_angles_r","effort","timing","recovery"]
   var tolerance:=.0004 if angular else .018
   for index in range(pinned.size()-1):reduce(values,control,pinned[index],pinned[index+1],tolerance,kept)
   var indices:=kept.keys();indices.sort()
   for index in indices:clip.position_track_insert_key(track,index/float(SAMPLES),values[index][control])
   dense+=values.size();total+=indices.size()
  library.add_animation(name,clip)
 assert(ResourceSaver.save(library,OUTPUT,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Baked control tracks: ",total," keys from ",dense," dense samples")
 quit()
func reduce(values:Array[Dictionary],control:StringName,a:int,b:int,tolerance:float,kept:Dictionary):
 kept[a]=true;kept[b]=true
 var worst:=tolerance;var split:=-1
 for i in range(a+1,b):
  var expected:Vector3=values[a][control].lerp(values[b][control],float(i-a)/(b-a))
  var error:float=expected.distance_to(values[i][control])
  if error>worst:worst=error;split=i
 if split>=0:reduce(values,control,a,split,tolerance,kept);reduce(values,control,split,b,tolerance,kept)
