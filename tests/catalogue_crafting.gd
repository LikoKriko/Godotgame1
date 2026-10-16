extends SceneTree
const Save = preload("res://scripts/save_game.gd")
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func require(ok: bool,text: String):
 checks += 1
 if not ok: failures += 1; push_error(text)
func run():
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 game.inventory_panel.open_section(1)
 var page = game.inventory_panel.creation_page; page.set_process(false)
 game.bag.add(&"piedra",2); game.bag.add(&"palo",2); game.bag.add(&"cuerda",1)
 var before = game.bag.fork(); page.select_recipe(&"pickaxe"); page.create_selected()
 require(page.is_crafting() and page.remaining == 2 and game.bag.count(&"piedra") == 0,"Inputs reserved for a two-second creation")
 page.create_selected(); page.select_recipe(&"axe")
 require(page.pending == &"pickaxe" and page.selected == &"pickaxe","Repeated input cannot change or duplicate an active job")
 page.advance_creation(1.0); page.cancel_creation()
 require(game.bag.slots == before.slots and game.bag.quick_slots == before.quick_slots,"Cancel refunds exact ingredients, slot positions and identities")
 page.create_selected(); game.inventory_panel.open_section(0)
 require(not page.is_crafting() and game.bag.slots == before.slots,"Changing tabs refunds the reservation")
 game.inventory_panel.open_section(1); page.create_selected(); game.inventory_panel.hide()
 require(not page.is_crafting() and game.bag.slots == before.slots,"Closing the popup refunds the reservation")
 game.inventory_panel.open_section(1); page.create_selected()
 require(game.styled_hud.quick_buttons[0].crafting_locked(),"Quick storage cannot move reserved ingredients while crafting")
 page.advance_creation(1.999); require(page.is_crafting(),"No early delivery")
 page.advance_creation(0.001); require(not page.is_crafting() and game.bag.count(&"pickaxe") == before.count(&"pickaxe")+1,"Exactly one output after two seconds")
 for id in page.recipe_buttons:
  require(page.recipe_buttons[id].fit_horizontal == Control.SIZE_SHRINK_BEGIN,"Recipes align left")
 require(page.position.x+page.object_name.position.x == 685 and page.position.x+page.create_button.position.x == 685,"Selected object and controls start at popup midpoint")
 require(page.animation_area.position.y == page.size.y*2/3,"Final third reserved for the future animation")
 game.inventory_panel.hide(); var catalog = game.item_catalog; catalog.open_catalog()
 require(catalog.entries.columns == 4 and catalog.status.text.is_empty(),"Catalogue uses four columns without the old explanatory message")
 for button in catalog.buttons.values():
  require(button.get_node("Artwork").size.y > button.get_node("Caption").get_theme_font_size("font_size"),"Catalogue art is larger than text")
 var old_level: int = game.level; var points: int = game.skill_points
 catalog.add_level(); require(game.level == old_level+1 and game.skill_points == points+1,"Debug level grants one shared improvement point")
 var primary = game.enemies.enemy
 catalog.spawn_enemy(); require(game.enemies.enemy == primary and game.enemies.additional.size() == 1,"Spawning keeps the existing enemy and adds a new young enemy")
 var extra = game.enemies.additional[0].enemy
 require(extra.position.distance_to(game.player) <= 160 and game.world.walkable(extra.position,9),"Additional enemy starts nearby on clear terrain")
 game.enemies.activate_parry(); require(game.enemies.additional[0].parry.last_activation == game.enemies.parry.last_activation,"Parry also reaches additional enemies")
 var saved := Save.capture(game)
 require(Save.valid(saved) and Save.restore(game,saved) and game.enemies.additional.size() == 1,"Save/load preserves the additional enemy")
 require(game.enemies.additional[0].enemy.position.is_equal_approx(extra.position) if is_instance_valid(extra) else game.enemies.additional[0].enemy.position.distance_to(game.player) <= 160,"Restored enemy retains a nearby position")
 catalog.hide(); game.inventory_panel.open_section(1); page.set_process(true)
 game.bag.add(&"piedra",2); game.bag.add(&"palo",2); game.bag.add(&"cuerda",1)
 var tools_before: int = game.bag.count(&"pickaxe")
 page.select_recipe(&"pickaxe"); page.create_button.pressed.emit()
 require(page.is_crafting(),"Crear button starts a real scheduled job")
 await create_timer(2.1).timeout
 require(not page.is_crafting() and game.bag.count(&"pickaxe") == tools_before+1,"UI processing completes crafting while gameplay is paused")
 print("%s: %d catalogue/creation checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); quit(1 if failures else 0)
