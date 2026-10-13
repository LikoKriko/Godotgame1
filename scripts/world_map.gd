extends Control
var game
var panel: Panel
var drawing: Control
var heading: Label
var close_button: Button

class TerrainView:
	extends Control
	var game
	var ground: ImageTexture
	var last_seed := -1
	var last_props := -1
	func refresh() -> void:
		if game == null: return
		if ground == null or last_seed != game.world.seed_value or last_props != game.world.props.size():
			last_seed = game.world.seed_value; last_props = game.world.props.size()
			var pixels := Image.create(game.world.SIZE.x,game.world.SIZE.y,false,Image.FORMAT_RGBA8)
			for cell in game.world.cells:
				var data: Dictionary = game.world.cells[cell]
				var color := Color("414a39")
				if data["road"]: color = Color("6a6351")
				if data["blocked"]: color = Color("737968")
				pixels.set_pixelv(cell-game.world.FIRST,color)
			ground = ImageTexture.create_from_image(pixels)
		queue_redraw()
	func world_to_map(point: Vector2) -> Vector2:
		return (point-game.world.bounds.position)/game.world.bounds.size*size
	func _draw() -> void:
		if ground == null: return
		draw_texture_rect(ground,Rect2(Vector2.ZERO,size),false)
		for patch in game.world.stone_patches:
			draw_rect(Rect2(world_to_map(patch.position),patch.size/game.world.bounds.size*size),Color(0.47,0.48,0.43,0.65))
		for puddle in game.world.puddles:
			var point := world_to_map(puddle["position"])
			draw_circle(point,2.5,Color("657b82"))
		var player := world_to_map(game.player)
		draw_circle(player,5,Color("292c22"))
		draw_circle(player,3.5,Color("ffe078"))
		draw_rect(Rect2(Vector2.ZERO,size),Color("8b896b"),false,1)

func configure(owner_game) -> void:
	game = owner_game
	theme = preload("res://scripts/ui_style.gd").theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0,0,0,0.7)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	panel = Panel.new(); add_child(panel)
	heading = Label.new(); heading.text = "MAPA · BOSQUE"
	preload("res://scripts/ui_style.gd").set_font_size(heading,22)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(heading)
	close_button = preload("res://scripts/menu_button.gd").new()
	close_button.text = "×"; close_button.size = Vector2(38,32)
	close_button.pressed.connect(hide); panel.add_child(close_button)
	drawing = TerrainView.new(); drawing.game = game
	drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drawing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(drawing)
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "● Tu posición    ·    Tierra: senderos    ·    Gris: obstáculos y piedra    ·    Azul: charcos"
	preload("res://scripts/ui_style.gd").set_font_size(legend,14)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(legend)
	get_viewport().size_changed.connect(fit)
	fit(); hide()
func fit() -> void:
	var viewport_size := get_viewport_rect().size
	panel.size = Vector2(minf(1100,viewport_size.x*0.9),minf(840,viewport_size.y*0.9))
	panel.position = (viewport_size-panel.size)/2
	heading.position = Vector2(24,16)
	close_button.position = Vector2(panel.size.x-56,12)
	var aspect: float = float(game.world.SIZE.x)/game.world.SIZE.y
	var available := panel.size-Vector2(48,108)
	drawing.size = Vector2(minf(available.x,available.y*aspect),minf(available.y,available.x/aspect))
	drawing.position = Vector2((panel.size.x-drawing.size.x)/2,64)
	panel.get_node("Legend").position = Vector2(24,panel.size.y-34)
	drawing.refresh()
func open_map() -> void:
	drawing.refresh(); show()
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_M,KEY_ESCAPE]:
		hide(); get_viewport().set_input_as_handled()
