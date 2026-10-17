extends RefCounted
## Preview sequence only: no perception, pursuit targets or combat rules.
const DURATIONS:=[10.0,20.0,40.0]
const LABELS:Array[StringName]=[&"free",&"pursuit",&"flee"]
const WAIT_SECONDS:=5.0
const FLEE_RUN_SECONDS:=8.0
const FLEE_REST_SECONDS:=2.0
var stage:StringName=&"warmup"
var kind:=0
var elapsed:=0.0
func running() -> bool:
 return stage==&"run" and (kind!=2 or fposmod(elapsed,10.0)<FLEE_RUN_SECONDS)
func resting() -> bool:return stage==&"rest" or (stage==&"run" and not running())
func advance(delta:float) -> Dictionary:
 var run_seconds:=0.0;var walk_seconds:=0.0
 var remaining:=maxf(0,delta)
 while remaining>.000000001:
  var duration:float=DURATIONS[kind] if stage==&"run" else WAIT_SECONDS
  var boundary:=duration
  if stage==&"run" and kind==2:
   var part:=fposmod(elapsed,10.0)
   boundary=minf(duration,elapsed+(8.0-part if part<8.0 else 10.0-part))
  var step:=minf(remaining,maxf(0,boundary-elapsed))
  if running():run_seconds+=step
  elif stage==&"warmup":walk_seconds+=step
  elapsed+=step;remaining-=step
  if elapsed>=duration-.000000001:
   if stage==&"warmup":stage=&"run"
   elif stage==&"run":stage=&"rest"
   else:stage=&"run";kind=(kind+1)%DURATIONS.size()
   elapsed=0
  elif step<=.000000001:
   # Snap a floating-point boundary before consuming the next segment.
   elapsed=boundary
 return {"run_seconds":run_seconds,"walk_seconds":walk_seconds}
func snapshot() -> Dictionary:return {"stage":String(stage),"kind":kind,"elapsed":elapsed}
static func valid(data) -> bool:
 if not data is Dictionary or data.get("stage") not in ["warmup","run","rest"]:return false
 if not data.get("kind") is float and not data.get("kind") is int:return false
 if not is_finite(data.kind) or data.kind<0 or data.kind>2 or data.kind!=int(data.kind):return false
 if not data.get("elapsed") is float and not data.get("elapsed") is int:return false
 return is_finite(data.elapsed) and data.elapsed>=0 and data.elapsed<=(DURATIONS[int(data.kind)] if data.stage=="run" else WAIT_SECONDS)
func restore(data:Dictionary) -> void:stage=StringName(data.stage);kind=int(data.kind);elapsed=data.elapsed
