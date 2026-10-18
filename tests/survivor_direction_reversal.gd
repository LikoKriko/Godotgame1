extends SceneTree
const Response=preload('res://scripts/prototype_3d/movement_response.gd')
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<14:push_error(message)
func _initialize():call_deferred('run')
func run():
 for fps in [30,60,120]:
  var dt:float=1.0/fps
  for sprint in [false,true]:
   for x in [-1,0,1]:
    for y in [-1,0,1]:
     if x==0 and y==0:continue
     var response:=Response.new()
     var input:=Vector2(x,y).normalized()
     var scale:float=Response.direction_multiplier(input)
     for frame in fps*2:response.advance(input,sprint,0,dt,scale)
     var old_speed:float=response.speed
     var reverse:=-input
     var reverse_scale:float=Response.direction_multiplier(reverse)
     response.advance(reverse,sprint,0,0,reverse_scale)
     require(response.stage==&'reverse_brake' and response.speed==old_speed,'Opposite input begins braking without changing speed or direction on its first sample')
     var factor:float=Response.SPRINT_MULTIPLIER if sprint else 1.0
     var duration:=.8*factor
     require(absf(response.reverse_scale-factor)<.00001,'Running reversal duration scales by the same 2.24 speed multiplier')
     var elapsed:=0.0;var previous:float=response.speed
     while elapsed<duration-.00000001:
      var step:=minf(dt,duration-elapsed)
      response.advance(reverse,sprint,0,step,reverse_scale);elapsed+=step
      require(response.speed<=previous+.00001,'Reversal braking decreases speed monotonically')
      if response.speed>.0001:require(response.direction.dot(input)>.9999,'Braking keeps travelling in the outgoing direction until rest')
      previous=response.speed
     require(response.stage==&'reverse_hold' and response.speed==0 and response.direction.is_zero_approx(),'Braking reaches exact rest after the requested duration')
     var hold:=.1*factor
     response.advance(reverse,sprint,0,hold*.5,reverse_scale)
     require(response.stage==&'reverse_hold' and response.speed==0,'The midpoint of the hold has exactly zero planar velocity')
     var data:Dictionary=JSON.parse_string(JSON.stringify(response.snapshot()))
     require(Response.valid(data),'The saved hold remains valid after a JSON round trip')
     var restored:=Response.new();restored.restore(data)
     restored.advance(reverse,sprint,0,hold*.5,reverse_scale)
     response.advance(reverse,sprint,0,hold*.5,reverse_scale)
     require(response.speed==0 and restored.stage==response.stage and absf(restored.elapsed-response.elapsed)<.00000001 and absf(restored.speed-response.speed)<.00000001 and restored.direction.distance_to(response.direction)<.000001,'The full hold elapses before startup and restoring preserves its remaining time')
     var startup:=Response.new();startup.restore(response.snapshot())
     startup.advance(reverse,sprint,0,.16 if sprint else .24,reverse_scale)
     require(absf(startup.speed-reverse_scale)<.00001,'Restart preserves the existing walk acceleration or sprint entry duration')
     if sprint:
      startup.advance(reverse,true,0,1.0,reverse_scale)
      require(absf(startup.speed-reverse_scale*Response.SPRINT_MULTIPLIER)<.00001,'Sprint restart preserves one additional second to reach maximum speed')
     response.advance(reverse,sprint,0,dt,reverse_scale)
     require(response.speed>0 and response.direction.dot(reverse)>.9999,'Startup begins in the selected opposite direction after the hold')
     for frame in fps*2:response.advance(reverse,sprint,0,dt,reverse_scale)
     require(absf(response.speed-reverse_scale*(Response.SPRINT_MULTIPLIER if sprint else 1))<.00001,'The restarted walk or sprint eventually reaches its proper directional limit')
  var response:=Response.new()
  for frame in fps:response.advance(Vector2.UP,false,0,dt)
  response.advance(Vector2.RIGHT,false,0,dt)
  require(not response.reversing() and response.direction.dot(Vector2.UP)>0 and response.direction.dot(Vector2.RIGHT)>0,'A ninety-degree turn steers smoothly without requesting a reversal stop')
  var saved:=response.snapshot();var restored:=Response.new();restored.restore(saved)
  for frame in fps:
   response.advance(Vector2.RIGHT,false,0,dt);restored.advance(Vector2.RIGHT,false,0,dt)
   require(response.direction.distance_to(restored.direction)<.00001,'Saving during ordinary steering preserves the physical trajectory')
  require(response.direction.dot(Vector2.RIGHT)>.9999,'Ordinary steering converges to the selected direction')
 for sprint in [false,true]:
  var braking:=Response.new();braking.advance(Vector2.UP,sprint,0,2)
  braking.advance(Vector2.DOWN,sprint,0,.2,.3)
  var encoded:Dictionary=JSON.parse_string(JSON.stringify(braking.snapshot()))
  require(Response.valid(encoded),'A braking snapshot validates before the hold begins')
  var resumed:=Response.new();resumed.restore(encoded)
  braking.advance(Vector2.DOWN,sprint,0,.3,.3);resumed.advance(Vector2.DOWN,sprint,0,.3,.3)
  require(braking.stage==resumed.stage and absf(braking.speed-resumed.speed)<.000001 and absf(braking.elapsed-resumed.elapsed)<.000001 and braking.direction.distance_to(resumed.direction)<.000001,'Restoring during braking preserves the remaining speed curve and outgoing direction')
 var stopped:=Response.new();stopped.advance(Vector2.UP,false,0,1)
 stopped.advance(Vector2.DOWN,false,0,.3,.3)
 stopped.advance(Vector2.ZERO,false,0,2)
 require(stopped.speed==0 and stopped.stage==&'idle','Releasing movement during braking never restarts the character automatically')
 var changed:=Response.new();changed.advance(Vector2.UP,false,0,1)
 changed.advance(Vector2.DOWN,false,0,.2,.3)
 changed.advance(Vector2.RIGHT,false,0,.71)
 require(changed.speed>0 and changed.direction.dot(Vector2.RIGHT)>.9999,'The buffered direction can be corrected before startup')
 var airborne:=Response.new();airborne.advance(Vector2.UP,false,0,1)
 airborne.advance(Vector2.DOWN,false,0,.1,.3,false)
 require(not airborne.reversing() and airborne.direction.dot(Vector2.DOWN)>.9999,'Airborne steering retains its existing direct control without a grounded reversal hold')
 var near_turn:=Response.new();near_turn.advance(Vector2.UP,false,0,1)
 near_turn.advance(Vector2.UP.rotated(deg_to_rad(179)),false,0,.01)
 require(not near_turn.reversing(),'A turn of 179 degrees remains ordinary steering rather than the special 180-degree stop')
 var legacy:=Response.new().snapshot();legacy.erase('pending_direction');legacy.erase('reverse_scale');legacy.erase('reference_scale')
 require(Response.valid(legacy),'Older save envelopes remain compatible')
 await live_run()
 print('%s: %d reversal timing, steering, sprint ratio, interrupt and save checks'%['PASS' if failures==0 else 'FAIL',checks]);quit(1 if failures else 0)

func key(code:int,pressed:bool) -> void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
 Input.parse_input_event(event);Input.flush_buffered_events()
func live_run():
 var game=load('res://scenes/prototype_3d/day_zero_3d.tscn').instantiate();game.use_test_layout=true;root.add_child(game)
 game.set_physics_process(false);game.player.set_physics_process(false);game.settings.values.auto_run=false
 for enemy in get_nodes_in_group('prototype_enemies'):enemy.set_physics_process(false)
 var player=game.player;player.position=Vector3(12,.01,12);player.equipped=false
 for frame in 12:
  player._physics_process(1.0/60);await physics_frame
 key(KEY_W,true)
 for frame in 30:
  player._physics_process(1.0/60);await physics_frame
 var outgoing:=Vector2(player.velocity.x,player.velocity.z).normalized()
 require(player.movement_response.speed>.99,'Live walking reaches full speed before requesting the opposite direction')
 key(KEY_W,false);key(KEY_S,true)
 for frame in 48:
  player._physics_process(1.0/60);await physics_frame
  require(Vector2(player.velocity.x,player.velocity.z).dot(outgoing)>=-.0001,'Live reversal never moves backward during its outgoing braking phase')
 require(player.movement_response.stage==&'reverse_hold','Live walking enters its hold after exactly 0.8 seconds')
 var position:Vector3=player.position
 game.environment_content=load('res://scripts/prototype_3d/world_content.gd').new();game.add_child(game.environment_content)
 var Save=load('res://scripts/prototype_3d/save_game.gd')
 var saved:Dictionary=Save.capture(game)
 require(Save.valid(saved) and Save.restore(game,saved),'A live save/load preserves the reversal hold in the game')
 for frame in 6:
  player._physics_process(1.0/60);await physics_frame
  require(Vector2(player.velocity.x,player.velocity.z).length()<.00001,'The live player remains fully stopped throughout the 0.1-second hold')
  require(Vector2(player.position.x-position.x,player.position.z-position.z).length()<.00001,'Holding does not produce root drift after save/load')
 player._physics_process(1.0/60);await physics_frame
 require(Vector2(player.velocity.x,player.velocity.z).dot(outgoing)<0,'The live player restarts in the opposite direction after the complete hold')
 require(player.model.steering_is_physical,'Player feet follow the physically eased direction without a second visual delay')
 key(KEY_CTRL,true)
 for frame in 30:
  player._physics_process(1.0/60);await physics_frame
 key(KEY_S,false);key(KEY_W,true)
 player._physics_process(1.0/60);await physics_frame
 require(player.movement_response.stage==&'reverse_brake' and player.model.last_pose.clip_state==&'crouch_walk','Crouched reversal retains its own walking pose during braking')
 require((player.model.last_pose.pelvis*Vector3(0,31,0)).y<28,'Reversal braking never raises a crouched player into a standing pose')
 key(KEY_W,false);key(KEY_CTRL,false);game.free()
