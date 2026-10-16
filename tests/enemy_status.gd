extends SceneTree
const Effects = preload("res://scripts/status_effects.gd")
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool,label: String):
 checks += 1
 if not ok: failures += 1; push_error(label)
func run():
 var states := Effects.new()
 require(states.apply(&"stun") and states.remaining(&"stun") == 1.5,"Stun defaults to exactly 1.5 seconds")
 states.advance(0.75); require(is_equal_approx(states.fraction(&"stun"),0.5),"Circular status fill follows remaining duration")
 require(Effects.valid_snapshot(states.active),"Timed effects use validated serializable data")
 states.advance(0.75); require(states.active.is_empty(),"Expired indicators disappear")
 require(not states.apply(&"unknown") and states.active.is_empty(),"Undefined states cannot create broken indicators")
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var enemy = game.enemies.enemy
 for direction in 16:
  enemy.heading = direction*TAU/16; enemy.effects.active.clear(); enemy.standing = false; enemy.stun(1.5); enemy.update_sprite()
  require(enemy.current_sheet.ends_with("stun_fall.png"),"Four-legged stun begins with its fall")
  var expected: float = enemy.sprite.position.y+(enemy.silhouette_tops["res://assets/enemies/first/stun_fall.png:%d:0" % direction]-48)/1.5
  require(is_equal_approx(enemy.status_indicator.position.y+5,expected-3),"Counter bottom remains three units above the actual exported silhouette")
  enemy.advance(0.24); enemy.update_sprite()
  require(enemy.atlas.atlas.resource_path.ends_with("stun_hold.png"),"After 0.24 seconds the creature lies on the floor")
  enemy.advance(1.02); enemy.update_sprite()
  require(enemy.atlas.atlas.resource_path.ends_with("stun_rise.png"),"Final 0.24 seconds display recovery")
  enemy.advance(0.24); enemy.update_sprite()
  require(enemy.stun_remaining == 0 and not enemy.status_indicator.visible,"At 1.5 seconds movement resumes and the counter disappears")
 var idle := Image.load_from_file("res://assets/enemies/first/idle.png")
 var floor_image := Image.load_from_file("res://assets/enemies/first/stun_hold.png")
 var rise := Image.load_from_file("res://assets/enemies/first/stun_rise.png")
 for direction in 16:
  var rest := idle.get_region(Rect2i(0,direction*96,96,96)).get_data()
  var floor_data := floor_image.get_region(Rect2i(0,direction*96,96,96)).get_data()
  require(rise.get_region(Rect2i(0,direction*96,96,96)).get_data() == floor_data,"Recovery starts with the exact floor pose")
  require(rise.get_region(Rect2i(480,direction*96,96,96)).get_data() == rest,"Recovery returns to the exact standing-on-four-legs idle")
  for clip in ["stun_fall","stun_fall_left","stun_fall_right"]:
   var sheet := Image.load_from_file("res://assets/enemies/first/"+clip+".png")
   require(sheet.get_region(Rect2i(480,direction*96,96,96)).get_data() == floor_data,"Every fall ends at the identical floor pose")
 print("%s: %d generic enemy status checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); game.free(); quit(1 if failures else 0)
