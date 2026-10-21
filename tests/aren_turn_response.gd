extends SceneTree
const Turning=preload("res://scripts/animation/terrain/aren_turn_response.gd")
var failures:Array[String]=[]
var checks:=0
func check(value:bool,message:String) -> void:
 checks+=1
 if not value and message not in failures:failures.append(message);push_error(message)
func _initialize() -> void:
 for fps in [30,60,120]:
  var dt:float=1.0/fps
  for timing in [1.0,1.1,1.25]:
   for sprint in [false,true]:
    for degrees in [45,90,150,180,-180]:
     var response=Turning.new();response.style_timing=timing
     var forward:=Vector2(0,-1)
     for frame in fps*3:response.advance(forward,sprint,0,dt)
     var target:=forward.rotated(deg_to_rad(degrees))
     var braked:=false;var held:=false
     for frame in fps*6:
      var old:float=response.heading
      var velocity:Vector2=response.advance(target,sprint,0,dt)
      var angular:float=absf(wrapf(response.heading-old,-PI,PI))/dt
      check(angular<=deg_to_rad(180)/timing+.0001,"Angular bound exceeded")
      check(is_finite(velocity.length()),"Non-finite velocity")
      if response.stage==&"reverse_brake":braked=true
      if response.pivoting:
       held=true;check(velocity.length()<.00001,"Pivot accelerated before alignment")
      if not velocity.is_zero_approx():
       check(velocity.normalized().dot(Vector2(sin(response.heading),cos(response.heading)))>.9999,"Motion disagrees with body heading")
     check(absf(wrapf(atan2(target.x,target.y)-response.heading,-PI,PI))<.02,"Turn did not converge")
     if absi(degrees)>=150:check(braked and held,"Reversal skipped braking or pivot")
     # Releasing controls during a reversal must settle rather than stick.
     response.advance(-target,sprint,0,dt)
     for frame in fps*3:response.advance(Vector2.ZERO,false,0,dt)
     check(response.speed<.00001 and not response.reversing(),"Interrupted turn did not settle")
 print("Aren turning: ",checks," checks, ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
