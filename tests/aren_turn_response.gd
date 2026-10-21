extends SceneTree
const Turning=preload("res://scripts/animation/terrain/aren_turn_response.gd")
var failures:Array[String]=[]
var checks:=0
var longest_turn:=0.0
func check(value:bool,message:String) -> void:
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func _initialize() -> void:
 for fps in [30,60,120]:
  var dt:float=1.0/fps
  for timing in [1.0,1.1,1.25]:
   for sprint in [false,true]:
    for degrees in [45,90,135,180,-180,179,-179]:
     var response=Turning.new();response.style_timing=timing;response.support_factor=.1
     var forward:=Vector2(0,-1)
     for frame in fps*3:response.advance(forward,sprint,0,dt)
     var initial_speed:float=response.speed
     var target:=forward.rotated(deg_to_rad(degrees))
     var total_rotation:=0.0
     var arrival:=-1.0
     for frame in fps*2:
      var old:float=response.heading
      var old_error:float=Turning.shortest_angle(old,atan2(target.x,target.y))
      var velocity:Vector2=response.advance(target,sprint,0,dt)
      var rotation:float=Turning.shortest_angle(old,response.heading)
      total_rotation+=absf(rotation)
      var error:float=absf(Turning.shortest_angle(response.heading,atan2(target.x,target.y)))
      if arrival<0 and error<deg_to_rad(5):arrival=(frame+1)*dt
      check(absf(response.heading)<=PI,"Heading accumulated outside signed half-turn")
      check(absf(rotation)<=deg_to_rad(360)/timing*dt+.0001,"Angular speed exceeded bound")
      check(rotation*old_error>=-.000001 or absf(absf(old_error)-PI)<.000001,"Turn took the longer arc")
      check(velocity.length()>=initial_speed*.199,"Corner discarded all momentum")
      if absi(degrees)<=90:check(velocity.length()>=initial_speed*.78,"Moderate turn braked excessively")
      check(not response.reversing(),"Turn reintroduced a zero-speed hold")
      check(velocity.normalized().dot(Vector2(sin(response.heading),cos(response.heading)))>.9999,"Motion disagrees with heading")
     check(total_rotation<=deg_to_rad(absi(degrees))+.0001,"Turn accumulated an extra revolution")
     check(arrival>0 and arrival<1.15,"Turn remained unresponsive for too long")
     longest_turn=maxf(longest_turn,arrival)
     # Immediate alternating requests must follow the shortest arc every tick.
     for index in 8:
      target=forward.rotated(deg_to_rad([45,90,-135,180,-45,135,-90,0][index]))
      for frame in ceili(.22*fps):
       var old:float=response.heading
       var error:float=Turning.shortest_angle(old,atan2(target.x,target.y))
       response.advance(target,sprint,0,dt)
       var rotation:float=Turning.shortest_angle(old,response.heading)
       check(rotation*error>=-.000001 or absf(absf(error)-PI)<.000001,"Consecutive input continued in the wrong direction")
     for frame in fps*3:response.advance(Vector2.ZERO,false,0,dt)
     check(response.speed<.00001 and not response.reversing(),"Released input did not settle")
 print("Aren turning: ",checks," checks, ",failures.size()," failures; slowest arrival within 5 degrees: ",longest_turn," s")
 quit(0 if failures.is_empty() else 1)
