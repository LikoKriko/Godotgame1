extends SceneTree
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func require(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func run():
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);game.set_process(false)
 game.bag.select_tool(&"pickaxe");game.equipping=false;game.player=Vector2.ZERO
 var aim:=Vector2(60,40);game.start_work(aim)
 require(is_equal_approx(game.movement.heading,aim.angle()),"Click fixes the strike heading")
 game.advance_work(0.01,Vector2(-60,-40))
 require(game.work_aim==aim and is_equal_approx(game.movement.heading,aim.angle()),"Cursor cannot redirect a strike")
 game.cancel_work()
 game.bag.add(&"apple",1)
 var index: int=-1
 for i in game.bag.CAPACITY:
  if game.bag.slots[i].get("id")==&"apple":index=i;break
 var count:int=game.bag.count(&"apple")
 game.consume_item(index)
 require(game.life.eating() and game.bag.count(&"apple")==count,"Food starts a deferred complete-sprite animation")
 game.life.advance(0.5)
 game.gameplay_settings.values.auto_run=true
 var press:=InputEventKey.new();press.physical_keycode=KEY_D;press.keycode=KEY_D;press.pressed=true;Input.parse_input_event(press);Input.flush_buffered_events()
 var before:Vector2=game.player;game._process(0.1)

 require(not game.running and game.player.distance_to(before)<=7.01 and game.player!=before,"Automatic running is forced to walking during eating")
 var released:=press.duplicate();released.pressed=false;Input.parse_input_event(released);Input.flush_buffered_events()
 game.life.advance(0.59);require(game.bag.count(&"apple")==count,"No food or calories committed before 1.2s")
 game.life.advance(0.01);require(game.bag.count(&"apple")==count-1 and game.nutrition.calories_today==95,"Food consumed exactly once on completion")
 var depth=load("res://scripts/world_depth.gd")
 var enemy=game.enemies.enemy;enemy.position=Vector2(100,-10);game.player=Vector2(400,400)
 require(depth.opacity(game,Rect2(80,-40,40,70),30)==0.75,"Object covering another creature is 25% transparent")
 game.player=Vector2(100,-10)
 require(depth.opacity(game,Rect2(80,-65,40,100),30)==0.35,"Player occlusion takes priority")
 require(depth.layer(20)<depth.layer(40),"All entities share foot depth ordering")
 var cycle=load("res://scripts/day_cycle.gd").new();var day:int=cycle.day;var hour:float=cycle.hour
 cycle.advance(960);require(cycle.day==day+1 and is_equal_approx(cycle.hour,hour),"One complete day lasts 16 minutes")
 print("%s: %d direction/food/depth checks, %d failures" %["PASS" if failures==0 else "FAIL",checks,failures]);game.free();quit(1 if failures else 0)
