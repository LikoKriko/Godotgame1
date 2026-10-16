extends SceneTree
var checks:=0
var failures:=0
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func _initialize():
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/complete/manifest.json"))
 for armor in ["","burdock_armor__"]:
  var death:Dictionary=manifest.items[armor+"bare"].clips.death
  require(death.frames==16 and death.directions==16,"Complete death has all directions")
  for item in ["apple","berries","ration"]:
   var clips:Dictionary=manifest.items[armor+item].clips
   require(clips.eat.frames==12 and clips.eat.directions==16,"Each food has 12 complete poses in 16 directions")
   require(clips.eat_walk.equip_frames==12 and clips.eat_walk.paths.size()==12,"Food stages contain independent walking phases")
   for path in clips.eat_walk.paths:
    var texture:Texture2D=load(path)
    require(texture!=null and texture.get_width()==2304 and texture.get_height()==3072,"Walking food pages stay below GPU dimensions")
    var picture:=texture.get_image()
    for direction in 16:
     for frame in 12:
      var bounds:=picture.get_region(Rect2i(frame*192,direction*192,192,192)).get_used_rect()
      require(bounds.has_area() and bounds.position.x>0 and bounds.position.y>0 and bounds.end.x<192 and bounds.end.y<192,"No limb or food clips at a frame edge")
  var image:Image=load(death.path).get_image()
  for direction in 16:
   for frame in 16:
    var bounds:=image.get_region(Rect2i(frame*192,direction*192,192,192)).get_used_rect()
    require(bounds.has_area() and bounds.position.x>0 and bounds.end.x<192 and bounds.position.y>0 and bounds.end.y<192,"Complete falling body stays within frame")
 var enemy:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/first/manifest.json"))
 require(enemy.death.frames==16 and enemy.death.directions==16 and enemy.corpse.frames==1,"Enemy has death and persistent prone pose in 16 directions")
 print("%s: %d food/death export checks, %d failures" %["PASS" if failures==0 else "FAIL",checks,failures]);quit(1 if failures else 0)
