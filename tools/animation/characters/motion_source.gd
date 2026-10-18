extends RefCounted
## Authoring only. Runtime samples the reduced native Animation tracks.
const CLIPS:Array[StringName]=[&"walk",&"run",&"jump",&"slide",&"slide_back",&"slide_left",&"slide_right",&"slide_forward_left",&"slide_forward_right",&"slide_back_left",&"slide_back_right",&"death",&"axe",&"pickaxe",&"sword"]
static func smooth5(a:float,b:float,t:float) -> float:
 var x:=clampf((t-a)/(b-a),0,1)
 return x*x*x*(x*(x*6-15)+10)
static func foot(t:float,running:bool) -> Vector3:
 var support:=.40 if running else .60
 # Metres covered in one nominal cycle, converted to 64-unit author space.
 var stride:float=(3.2*.585 if running else 2.0*.78)/(1.75/64)*support*.5
 var p:=fposmod(t,1.0)
 if p<support:
  return Vector3(lerpf(stride,-stride,p/support),0,0)
 var u:float=(p-support)/(1-support)
 # Hermite end velocities match the planted foot's backward speed, avoiding
 # a stop/reversal pop at toe-off and heel contact. Lift softens on landing.
 var velocity:float=-2*stride/support*(1-support)
 var z:float=(2*u*u*u-3*u*u+1)*-stride+(u*u*u-2*u*u+u)*velocity+(-2*u*u*u+3*u*u)*stride+(u*u*u-u*u)*velocity
 var lift:float=pow(sin(u*PI),1.5)*(8.2 if running else 4.8)
 return Vector3(z,lift,-sin(u*PI)*(.26 if running else .14))
static func sample(clip:StringName,t:float) -> Dictionary:
 if clip in [&"walk",&"run"]:
  var run:=clip==&"run";var wave:=sin(t*TAU)
  return {&"foot_l":foot(t,run),&"foot_r":foot(t+.5,run),&"body":Vector3(-wave*(.17 if run else .25),-(.85 if run else .55)*(1-cos(t*TAU*2))*.5,0),&"chest":Vector3(.14 if run else .015,-wave*(.025 if run else .035),-wave*.008),&"pelvis":Vector3(0,wave*(.025 if run else .035),wave*.009),&"arms":Vector3(cos(t*TAU)*(.36 if run else .20),cos((t+.5)*TAU)*(.36 if run else .20),0)}
 if clip==&"jump":
  var compress:=smooth5(.0,.10,t)*(1-smooth5(.10,.23,t))
  var flight:=smooth5(.08,.35,t)*(1-smooth5(.70,.96,t))
  var land:=smooth5(.73,.87,t)*(1-smooth5(.87,1,t))
  return {&"body":Vector3(0,-1.1*compress-1.8*land,-.2*compress),&"chest":Vector3(.045*compress-.035*flight+.065*land,0,0),&"foot_l":Vector3(-1.4*flight,3.4*flight,0),&"foot_r":Vector3(-2.5*flight,2.8*flight,-.06*flight),&"arms":Vector3(1.5*flight,4.2*flight,flight)}
 if String(clip).begins_with("slide"):
  var back:=String(clip).begins_with("slide_back")
  var side:float=-1 if String(clip).ends_with("left") else (1 if String(clip).ends_with("right") else 0)
  var lateral:=clip in [&"slide_left",&"slide_right"]
  var yaw:float=side*(PI*.5 if lateral else PI*.25)
  var enter:=smooth5(0,.34,t);var rise:=smooth5(.72,1,t);var load:=enter*(1-rise)
  var foot_l:=Vector3(-4.8,3.1,14.5) if not back else Vector3(-5.2,3.2,23)
  var foot_r:=Vector3(4.4,2.5,26) if not back else Vector3(4.8,3.4,12)
  if side<0:var previous:=foot_l;foot_l=Vector3(-foot_r.x,foot_r.y,foot_r.z);foot_r=Vector3(-previous.x,previous.y,previous.z)
  var turn:=Basis(Vector3.UP,yaw if not back else yaw*.40)
  return {&"timing":Vector3(enter,rise,load),&"hip":Vector3((-.35 if not back else .35)+side*.7,4.8 if not back else 5.7,-1.5 if not back else -3),&"pelvis":Vector3(-.32 if not back else -.18,yaw*.30,(-.08 if back else .10) if side==0 else -side*.14),&"curl":Vector3(.30 if not back else .35,yaw,0),&"foot_l":turn*foot_l,&"foot_r":turn*foot_r,&"hand_l":Vector3(-9.5,43,13),&"hand_r":Vector3(9.5,43,13)}
 if clip==&"death":
  var kneel:=smooth5(0,.38,t);var fall:=smooth5(.40,.84,t);var spread:=smooth5(.62,1,t)
  var hip:=Vector3(0,lerpf(31,15.6,kneel),lerpf(0,2,kneel)).lerp(Vector3(0,5.8,4),fall)
  var result:Dictionary={&"hip":hip,&"angles":Vector3(lerpf(.10*kneel,PI/2,fall),0,0),&"timing":Vector3(kneel,fall,spread)}
  for side in 2:
   var s:float=-1 if side==0 else 1;var suffix:="_l" if side==0 else "_r"
   result[StringName("foot"+suffix)]=Vector3(s*3.7,2.1+sin(PI*.88*kneel)*8.03,lerpf(0,-11.5,kneel)).lerp(Vector3(s*11.5,4.0,-16),fall)
   result[StringName("foot_angles"+suffix)]=Vector3(lerpf(PI*.88*kneel,2.45,fall),s*.35*spread,0)
   var hand:=Vector3(s*9.1874,29.3538,2.9257).lerp(Vector3(s*11,16,10),kneel)
   result[StringName("hand"+suffix)]=hand.lerp(Vector3(s*18,5.0,20),fall).lerp(Vector3(s*23,4.0,18),spread)
   result[StringName("pole"+suffix)]=Vector3.BACK.lerp(Vector3(s,-.12,0),fall).normalized()
  return result
 # Distinct tool rhythms: measured preparation, fast strike, short resistance,
 # extraction and recovery. The contact at .5 is pinned by the reducer.
 var wind:=Vector3(-3,44,17);var wind_axis:=Vector3(.58,.80,.12)
 var hit:=Vector3(-1,34,15);var hit_axis:=Vector3(.14,.20,.97)
 if clip==&"pickaxe":wind=Vector3(-1.5,46,16);wind_axis=Vector3(.05,.99,.10);hit=Vector3(-1,29,16);hit_axis=Vector3(0,-.45,.89)
 elif clip==&"sword":wind=Vector3(12,41,11);wind_axis=Vector3(.25,.93,-.26);hit=Vector3(1,36,15);hit_axis=Vector3(-.55,-.15,.82)
 var preparation:=smooth5(0,.28,t)
 var strike:=pow(clampf((t-.28)/.22,0,1),2.1)
 var hold:=smooth5(.52,.65,t)
 var recover:=smooth5(.65,.90,t)
 var settle:=smooth5(.90,1,t)
 var load:=smooth5(0,.28,t)*(1-smooth5(.52,.9,t))
 var drive:=smooth5(.28,.5,t)*(1-smooth5(.62,1,t))
 return {&"wind":wind,&"wind_axis":wind_axis,&"hit":hit,&"hit_axis":hit_axis,&"timing":Vector3(preparation,strike,hold),&"recovery":Vector3(recover,settle,smooth5(.52,.66,t)*(1-smooth5(.88,1,t))),&"effort":Vector3(load,drive,smooth5(0,.28,t)*(1-smooth5(.62,1,t)))}
