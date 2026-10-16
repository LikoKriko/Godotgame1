extends SceneTree
const Settings = preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	require(Settings.DEFAULTS.hud_size == 1,"HUD defaults to the chosen smallest level")
	for level in range(1,7):
		var factor := Settings.hud_scale(level)
		require(is_equal_approx(factor*factor,0.4*(1+0.2*(level-1))),"Six size levels change area, not the percentage of each side")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	require(game.styled_hud.shortcuts.size() == 3,"Only the three requested controls remain")
	require(game.interaction.text == "","Other lower prompts and skill hotkey hints are gone")
	var overlay = game.styled_hud
	require(game.get_children().filter(func(node): return node.get_script() != null and str(node.get_script().resource_path).contains("survival_status")).is_empty(),"Old HUD widgets are replaced rather than duplicated")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
		root.size = dimensions
		for level in range(1,7):
			game.gameplay_settings.values.hud_size = level
			game.fit_hud()
			overlay.fit()
			var mini: Rect2 = overlay.map_frame.get_global_rect()
			require(is_equal_approx(mini.position.y,18) and is_equal_approx(mini.end.x,dimensions.x-18),"Minimap stays at the top right")
			var food: Rect2 = overlay.food.get_global_rect()
			var water: Rect2 = overlay.water.get_global_rect()
			require(is_equal_approx(food.end.y,water.position.y) and food.position.x == water.position.x,"Food and hydration remain adjacent at the lower left")
			var controls: Rect2 = overlay.shortcuts[2].get_global_rect()
			require(is_equal_approx(controls.end.x,dimensions.x-18) and controls.position.y > dimensions.y/2,"Shortcuts stay at the lower right")
			require(not water.intersects(overlay.quick_bar.get_global_rect()) and not controls.intersects(overlay.skill_bar.get_global_rect()),"HUD widgets never overlap")
			var factor: float = Settings.hud_scale(level)
			require(overlay.quick_bar.scale.is_equal_approx(Vector2.ONE*factor) and overlay.life.scale.is_equal_approx(Vector2.ONE*factor),"Labels, frames and widgets share area scaling")
	key(KEY_M)
	require(game.world_map.visible and game.is_paused() and not game.inventory_panel.visible,"M opens full map and pauses gameplay")
	var map = game.world_map.drawing
	require(map.ground.get_size() == Vector2(game.world.SIZE),"Entire procedural terrain is present immediately")
	require(map.world_to_map(game.world.bounds.position).is_equal_approx(Vector2.ZERO) and map.world_to_map(game.world.bounds.end).is_equal_approx(map.size),"World corners map to display corners without stretching its aspect")
	require(map.world_to_map(game.player).is_equal_approx(map.size/2),"Player marker uses the actual world position")
	game.skill_points = 1; game.buy_improvement(&"speed",true)
	key(KEY_Z)
	require(game.progression.active[&"speed"] == 0,"Map blocks gameplay ability shortcuts while paused")
	var held: StringName = game.bag.held_id()
	key(KEY_1)
	require(game.bag.held_id() == held,"Map blocks weapon selection shortcuts")
	var hour: float = game.day_cycle.hour
	game._process(20)
	require(game.day_cycle.hour == hour,"Map suspends day, needs and movement")
	key(KEY_M)
	require(not game.world_map.visible and not game.is_paused(),"M closes map and resumes")
	key(KEY_I); key(KEY_M)
	require(game.world_map.visible and not game.inventory_panel.visible,"Map replaces inventory rather than stacking modals")
	key(KEY_T)
	require(not game.world_map.visible and game.inventory_panel.navigation.current_tab == 1,"T leaves map and opens creation")
	game.inventory_panel.hide(); key(KEY_M); key(KEY_ESCAPE)
	require(not game.world_map.visible and not game.is_paused(),"Esc closes map without opening pause menu underneath")
	key(KEY_M)
	game.world.seed_value += 1; game.restart(); key(KEY_M)
	require(map.last_seed == game.world.seed_value,"New maps refresh the displayed procedural terrain")
	var cell: Vector2i = game.world.props.keys()[0]
	game.world.props.erase(cell); map.refresh()
	require(map.last_props == game.world.props.size(),"Depleted resource obstacles refresh the map cache")
	game.world_map.hide()
	var panel := preload("res://scripts/settings_panel.gd").new()
	root.add_child(panel); panel.configure(game.gameplay_settings)
	require(panel.hud_slider.min_value == 1 and panel.hud_slider.max_value == 6 and panel.hud_slider.step == 1,"Juego slider exposes exactly six discrete positions")
	panel.hud_slider.value = 4
	require(panel.pending.hud_size == 4 and panel.hud_value.text.contains("64%"),"Slider explains the selected level's occupied area")
	game.gameplay_settings.values.hud_size = panel.pending.hud_size
	game.gameplay_settings.changed.emit()
	require(game.styled_hud.map_frame.scale.is_equal_approx(Vector2.ONE*Settings.hud_scale(4)),"Applied preferences resize the running game's HUD immediately")
	print("%s: %d HUD/map checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
