extends RefCounted
## Integer hashing is shared with the GPU. No coordinate-local random streams.
static var calibration_cache: Dictionary = {}
const TYPES := [&"normal",&"dark",&"vegetation",&"dirt"]
var seed_value := 73129
var profile
var thresholds := Vector3(0.57,0.64,0.70)
var existing_paths := false
var influences: Array[Dictionary] = []
static func hash_at(x: int,y: int,seed_number: int) -> float:
 var value := ((x*374761393) ^ (y*668265263) ^ seed_number)&0xffffffff
 value = ((value ^ (value >> 13))*1274126177)&0xffffffff
 value = (value ^ (value >> 16))&0xffffffff
 return float(value&0x00ffffff)/16777215.0
func noise_at(point: Vector2) -> float:
 var x := floori(point.x); var y := floori(point.y)
 var f := point-Vector2(x,y); f = f*f*(Vector2.ONE*3-f*2)
 return lerpf(lerpf(hash_at(x,y,seed_value),hash_at(x+1,y,seed_value),f.x),lerpf(hash_at(x,y+1,seed_value),hash_at(x+1,y+1,seed_value),f.x),f.y)
func field(point: Vector2) -> float:
 var p: Vector2 = point/profile.region_scale
 return noise_at(p)*0.70+noise_at(p*2.17+Vector2(37,19))*0.22+noise_at(p*5.31+Vector2(-11,73))*0.08
func configure(seed_number: int,configuration) -> void:
 seed_value = seed_number; profile = configuration; influences.clear()
 var key := "%d:%s:%s" % [seed_number,profile.region_scale,profile.proportions]
 if calibration_cache.has(key): thresholds = calibration_cache[key]; return
 # Quantiles calibrate proportions rather than assuming noise has a uniform histogram.
 var values: Array[float] = []
 for y in 96:
  for x in 96: values.append(field(Vector2((x-48)*593.0,(y-48)*617.0)))
 values.sort()
 var p: Vector4 = profile.proportions; p /= p.x+p.y+p.z+p.w
 var cumulative := [p.x,p.x+p.y,p.x+p.y+p.z]
 for i in 3:
  thresholds[i] = -1.0 if cumulative[i] <= 0 else (2.0 if cumulative[i] >= 1 else values[clampi(roundi(cumulative[i]*(values.size()-1)),0,values.size()-1)])
 if calibration_cache.size() >= 8: calibration_cache.erase(calibration_cache.keys()[0])
 calibration_cache[key] = thresholds
func weights_at(point: Vector2) -> Vector4:
 var value := field(point); var edge: float = profile.transition_width
 var a := smoothstep(thresholds.x-edge,thresholds.x+edge,value)
 var b := smoothstep(thresholds.y-edge,thresholds.y+edge,value)
 var c := smoothstep(thresholds.z-edge,thresholds.z+edge,value)
 var weights := Vector4(1-a,a-b,b-c,c)
 var path := path_mask(point) if existing_paths else 0.0
 weights = weights.lerp(Vector4(0,0,0,1),path)
 for influence in influences:
  var amount := influence_mask(point,influence)
  var target := Vector4.ZERO; target[TYPES.find(influence.type)] = 1
  weights = weights.lerp(target,amount)
 return weights
func type_at(point: Vector2) -> StringName:
 var weights := weights_at(point); var best := 0
 for i in range(1,4):
  if weights[i] > weights[best]: best = i
 return TYPES[best]
func vegetation_density(point: Vector2) -> float:
 var weights := weights_at(point)
 return clampf((weights.x*0.30+weights.z*0.85+weights.y*0.12)*(0.5+noise_at(point/95.0)),0,1)
func add_influence(id: StringName,type: StringName,rect: Rect2,strength: float = 1) -> bool:
 if not TYPES.has(type) or not rect.has_area() or strength <= 0: return false
 for i in range(influences.size()-1,-1,-1):
  if influences[i].id == id: influences.remove_at(i)
 influences.append({"id":id,"type":type,"rect":rect,"strength":clampf(strength,0,1)}); return true
func influence_mask(point: Vector2,influence: Dictionary) -> float:
 var rect: Rect2 = influence.rect
 var radius: Vector2 = rect.size/2
 var distance: float = ((point-rect.get_center())/radius).length()
 return (1-smoothstep(0.78,1.12,distance+(noise_at(point/38)-0.5)*0.12))*influence.strength
func path_mask(point: Vector2) -> float:
 var horizontal := 24*sin(point.x/210)+10*sin(point.x/93)
 var vertical := 24*sin(point.y/245)-10*sin(point.y/110)
 var distance := minf(absf(point.y-horizontal),absf(point.x-vertical))
 return 1-smoothstep(44.0,72.0,distance+(noise_at(point/38)-0.5)*12)
