extends SceneTree
## Measure the visible native foot in world space, not just its control target.
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _initialize():call_deferred('run')
func run():
 var actor=load('res://scripts/prototype_3d/survivor_model.gd').new();root.add_child(actor)
 var clips=actor.Clips
 var cycle:float=clips.cycle_distance(0)/clips.gait_playback_rate(0)
 require(cycle/2>.95 and cycle/2<1.0,'Walking takes almost one second per full cycle at two metres per second')
 require((1-clips.Gait.WALK_SUPPORT)*cycle/2>.70,'The walking leg recovers gradually instead of flicking forward')
 for family in [&'',&'axe',&'bow']:
  actor.family_override=family
  for x in [-1,0,1]:
   for z in [-1,0,1]:
    if x==0 and z==0:continue
    var direction:=Vector3(x*sin(clips.Gait.DIAGONAL_ANGLE) if z!=0 else x,0,z*cos(clips.Gait.DIAGONAL_ANGLE) if x!=0 else z).normalized()
    var directional_cycle:float=clips.cycle_distance(0,0,direction)/clips.gait_playback_rate(0)
    require(absf(directional_cycle-cycle*clips.Gait.backward_stride(direction))<.00001,'Rearward walking shortens its stride while preserving the intended cadence')
    var support:float=clips.Gait.WALK_SUPPORT*clips.directional_stride(direction)*lerpf(1,clips.LATERAL_STEP_SCALE,smoothstep(sqrt(.5),1,absf(direction.x)))
    for side in 2:
     for frame in 12:
      # Stay within the planted interval, including the shorter side contacts.
      var phase:float=support*lerpf(.20,.75,frame/11.0)
      var advance:=support*.005
      actor.animate(&'walk',fposmod(phase-side*.5,1),family!=&'',0,fposmod(phase-side*.5,1),direction)
      var a:Vector3=actor.native.posed[actor.native.legs[side].ids[2]].origin*(1.75/64)
      actor.animate(&'walk',fposmod(phase+advance-side*.5,1),family!=&'',0,fposmod(phase+advance-side*.5,1),direction)
      var b:Vector3=actor.native.posed[actor.native.legs[side].ids[2]].origin*(1.75/64)
      for speed in [.6,2.0]:
       var delta:float=advance*directional_cycle/speed
       var slip:Vector3=(b-a)/delta+direction*speed
       require(Vector2(slip.x,slip.z).length()<.15,'Visible walking support stays planted at the real movement speed: %s %s %s'%[family,direction,side])
 actor.free();print('%s: %d walking cadence, recovery duration and native world-contact checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)
