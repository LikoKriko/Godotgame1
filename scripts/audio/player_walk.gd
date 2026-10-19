extends AudioStreamPlayer
## Local player foley; the Effects bus follows the existing audio settings.
const SOUND=preload("res://assets/audio/characters/caminata_personaje1.mp3")
const FADE_SECONDS:=.2
var walking:=false
var gain:=0.0
var fade_from:=0.0
var fade_to:=0.0
var fade_elapsed:=FADE_SECONDS
func _init() -> void:
 stream=SOUND.duplicate();stream.loop=true
 bus=&"Effects";volume_db=-80.0
 set_process(false)
static func is_walking(speed:float,grounded:bool,special_motion:bool,sprint_weight:float) -> bool:
 return grounded and not special_motion and speed>.03 and sprint_weight<.01
func set_walking(active:bool) -> void:
 if walking==active:return
 walking=active;fade_from=gain;fade_to=1.0 if active else 0.0;fade_elapsed=0.0
 if active and not playing:play()
 set_process(true)
func _process(delta:float) -> void:advance_fade(delta)
func advance_fade(delta:float) -> void:
 fade_elapsed=minf(FADE_SECONDS,fade_elapsed+maxf(0,delta))
 gain=lerpf(fade_from,fade_to,smoothstep(0,FADE_SECONDS,fade_elapsed))
 volume_db=linear_to_db(maxf(gain,.0001))
 if fade_elapsed>=FADE_SECONDS:
  if not walking:stop()
  set_process(false)
