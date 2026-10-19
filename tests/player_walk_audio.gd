extends SceneTree
const Walking=preload("res://scripts/audio/player_walk.gd")
var checks:=0
var failures:=0
class PausedGame:
 var paused:=true
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 if AudioServer.get_bus_index("Effects")<0:
  AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,"Effects")
 var sound=Walking.new();root.add_child(sound)
 require(sound.stream is AudioStreamMP3 and sound.stream.get_length()>3,"The supplied MP3 is available as an exported runtime asset")
 require(sound.stream.loop and sound.bus==&"Effects","Walking loops on the existing effects volume bus")
 require(not sound.playing,"Idle does not start the sound")
 sound.set_walking(true);sound.advance_fade(.1)
 require(sound.playing and is_equal_approx(sound.gain,.5),"Walking enters smoothly at half volume after 0.1 seconds")
 sound.set_walking(true);sound.advance_fade(.1)
 require(is_equal_approx(sound.gain,1.0),"Repeated walking updates do not restart the 0.2-second envelope")
 sound.set_walking(false);sound.advance_fade(.1)
 require(sound.playing and is_equal_approx(sound.gain,.5),"Stopping remains audible during the fade instead of cutting playback")
 sound.advance_fade(.1)
 require(not sound.playing and is_zero_approx(sound.gain),"Playback stops only after the complete 0.2-second fade")
 sound.set_walking(true);sound.advance_fade(.08)
 var previous:float=sound.gain
 sound.set_walking(false)
 require(sound.gain==previous,"Reversing a fade has no volume discontinuity")
 sound.advance_fade(.04);previous=sound.gain;sound.set_walking(true)
 require(sound.gain==previous,"Resuming before silence starts from the current gain")
 sound.advance_fade(.2)
 require(is_equal_approx(sound.gain,1.0),"An interrupted fade can recover to full walking volume")
 require(Walking.is_walking(2.0,true,false,0) and Walking.is_walking(.6,true,false,0),"Forward and slow grounded walking enable the loop")
 require(not Walking.is_walking(0,true,false,0),"A blocked or stationary player has no walking sound")
 require(not Walking.is_walking(2,false,false,0) and not Walking.is_walking(2,true,true,0),"Jumping and sliding disable the loop")
 require(not Walking.is_walking(4.48,true,false,1),"Running does not use the walking loop")
 sound.play(sound.stream.get_length()-.04)
 await create_timer(.3).timeout
 var playback:AudioStreamPlayback=sound.get_stream_playback()
 require(sound.playing and playback.get_loop_count()>0,"The MP3 actually wraps at its end while walking continues")
 playback=null
 sound.free()
 var player=load("res://scripts/prototype_3d/player.gd").new();root.add_child(player)
 player.set_physics_process(false)
 player.game=PausedGame.new();player.walking_sound.set_walking(true);player.walking_sound.advance_fade(.2)
 player._physics_process(1.0/60)
 require(not player.walking_sound.walking,"The player's early pause return initiates the same fade-out")
 player.walking_sound.advance_fade(.2)
 require(not player.walking_sound.playing,"Paused walking playback stops after its fade")
 player.free()
 await process_frame
 print("%s: %d walking-audio, fade, interruption, loop and player-pause checks"%["PASS" if failures==0 else "FAIL",checks]);quit(1 if failures else 0)
