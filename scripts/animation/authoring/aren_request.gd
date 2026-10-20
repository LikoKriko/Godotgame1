extends RefCounted
## Deliberately bounded language: unknown requests fail instead of inventing motion.
const PRESETS = {
 "natural": {"stride":1.0,"cadence":1.0,"arms":1.0,"lean":0.0,"fatigue":0.0,"caution":0.0,"tension":0.0,"anticipation":0.0},
 "cautious": {"stride":0.78,"cadence":0.86,"arms":0.60,"lean":0.025,"fatigue":0.0,"caution":0.8,"tension":0.5,"anticipation":0.04},
 "tired": {"stride":0.85,"cadence":0.80,"arms":0.65,"lean":0.065,"fatigue":0.8,"caution":0.0,"tension":0.0,"anticipation":0.0}
}
const LIMITS = {"stride":Vector2(0.6,1.2),"cadence":Vector2(0.65,1.3),"arms":Vector2(0.3,1.3),"lean":Vector2(-0.03,0.10),"fatigue":Vector2(0,1),"caution":Vector2(0,1),"tension":Vector2(0,1),"anticipation":Vector2(0,0.08),"torso_flow":Vector2(0,1),"pelvis_sway":Vector2(.2,1)}
static func parameters(preset:String,overrides:Dictionary={}) -> Dictionary:
 if not PRESETS.has(preset):return {"ok":false,"error":"Unknown preset: "+preset}
 var values:Dictionary=PRESETS[preset].duplicate()
 values.merge({"torso_flow":0.0,"pelvis_sway":1.0})
 values.merge({"run_flow":0.0,"run_cadence":1.0,"run_speed":0.0,"run_arms":1.0,"run_body_motion":1.0,"run_posture":1.0,"run_lift":1.0,"idle_flow":0.0,"idle_period":4.5,"idle_breath":1.0,"idle_balance":1.0})
 var limits:Dictionary=LIMITS.duplicate()
 limits.merge({"run_flow":Vector2(0,1),"run_cadence":Vector2(.85,1.1),"run_speed":Vector2(0,8),"run_arms":Vector2(.5,1.1),"run_body_motion":Vector2(.4,1),"run_posture":Vector2(.6,1),"run_lift":Vector2(.6,1),"idle_flow":Vector2(0,1),"idle_period":Vector2(3.5,6),"idle_breath":Vector2(.3,1.5),"idle_balance":Vector2(0,1)})
 for key in overrides:
  if not limits.has(key) or not (overrides[key] is float or overrides[key] is int):return {"ok":false,"error":"Unknown or nonnumeric parameter: "+str(key)}
  var value:float=overrides[key]
  if not is_finite(value) or value<limits[key].x-0.000001 or value>limits[key].y+0.000001:return {"ok":false,"error":"Parameter out of range: "+str(key)}
  values[key]=value
 return {"ok":true,"values":values,"preset":preset}
static func parse(sentence:String) -> Dictionary:
 var text:=sentence.to_lower().replace("á","a").replace("é","e").replace("í","i").replace("ó","o").replace("ú","u")
 var words:=text.replace(","," ").replace("."," ").split(" ",false)
 var allowed:="genera generar crea crear una un de aren caminata caminar camina carrera correr corre y natural cautelosa cauteloso cansada cansado zancada media corta larga brazos moderados moderado sin deslizamiento pies de los con paso pasos animacion animaciones para"
 for word in words:
  if word not in allowed.split(" "):return {"ok":false,"error":"Unsupported request term: "+word+"; use documented parameters"}
 var walking:= "caminata" in text or "caminar" in words or "camina" in words
 var running:= "carrera" in text or "correr" in words or "corre" in words
 if not walking and not running:return {"ok":false,"error":"Specify caminar or correr"}
 if ("cautelosa" in text or "cauteloso" in text) and ("cansada" in text or "cansado" in text):return {"ok":false,"error":"Choose one preset; combine traits through explicit parameters"}
 var preset:="cautious" if "cautelos" in text else ("tired" if "cansad" in text else "natural")
 var overrides:Dictionary={}
 if "corta" in words:overrides.stride=0.7
 if "larga" in words:overrides.stride=1.1
 if "moderados" in words or "moderado" in words:overrides.arms=0.7
 var result:=parameters(preset,overrides)
 result["requested_motion"]="walk+run" if walking and running else ("walk" if walking else "run")
 return result
