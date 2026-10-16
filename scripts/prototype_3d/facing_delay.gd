extends RefCounted
## A time history, rather than a debounce: continuous mouse motion still follows.
const SECONDS:=0.15
var clock:=0.0
var history:Array[Dictionary]=[]
func sample(offset:Vector3,delta:float) -> Vector3:
 if history.is_empty():history.append({"time":-SECONDS,"offset":offset})
 clock+=maxf(0,delta)
 history.append({"time":clock,"offset":offset})
 var target:=clock-SECONDS
 while history.size()>2 and history[1].time<=target:history.pop_front()
 var a:Dictionary=history[0];var b:Dictionary=history[1]
 var amount:=clampf((target-a.time)/maxf(.000001,b.time-a.time),0,1)
 return (a.offset as Vector3).lerp(b.offset,amount)
