extends SceneTree
func _initialize():call_deferred("run")
func key(code:int,pressed:bool):
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func run():
 var world=load("res://scenes/prototype_3d/day_zero_3d.tscn").instantiate();root.add_child(world)
 world.settings.values.auto_run=false
 world.player.position=Vector3(10,0.1,10)
 for i in 30:await physics_frame
 key(KEY_W,true);key(KEY_SHIFT,true)
 for i in 8:await physics_frame
 assert(world.player.velocity.length()>3.0,"Running moves the actual character")
 key(KEY_CTRL,true)
 for i in 3:await physics_frame
 assert(world.player.locomotion.sliding(),"Ctrl while running begins a slide")
 key(KEY_SPACE,true)
 for i in 3:await physics_frame
 assert(world.player.locomotion.from_slide and world.player.velocity.y>0,"Jump retains slide inertia")
 for code in [KEY_W,KEY_SHIFT,KEY_SPACE,KEY_CTRL]:key(code,false)
 for i in 50:await physics_frame
 key(KEY_CTRL,true)
 for i in 15:await physics_frame
 assert(world.player.locomotion.crouch>0.9,"Ctrl while standing crouches")
 key(KEY_W,true)
 for i in 4:await physics_frame
 assert(world.player.velocity.length()<1.1,"Crouch walk uses the reduced speed")
 key(KEY_W,false);key(KEY_CTRL,false)
 for i in 8:await physics_frame
 world.player.play_preview(&"",&"pickup");key(KEY_W,true)
 for i in 4:await physics_frame
 assert(world.player.velocity.length()>0.65 and world.player.velocity.length()<0.9,"Pickup reduces movement by 60 percent")
 for i in 60:await physics_frame
 assert(world.player.velocity.length()>1.9,"Pickup recovers normal speed after its half-second recovery")
 world.settings.values.auto_run=true;world.player.play_preview(&"food",&"eat")
 for i in 4:await physics_frame
 assert(world.player.velocity.length()<2.1,"Eating forces walking even with auto-run enabled")
 key(KEY_W,false);world.settings.values.auto_run=false
 print("PASS: live 3D run, slide, slide jump, crouch, pickup recovery and eating movement")
 world.free();quit()
