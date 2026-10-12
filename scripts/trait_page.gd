extends Control
var game
var ability := true
var selected: StringName
var points: Label
var title: Label
var description: Label
var rank: Label
var message: Label
var purchase_button: Button
var activate_button: Button
var entries: Dictionary = {}
var refresh_time := 0.0
const Progression = preload("res://scripts/progression.gd")

func configure(owner_game, is_ability: bool) -> void:
	game = owner_game
	ability = is_ability
	size = Vector2(568,480)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	points = label(Vector2.ZERO,Vector2(568,32),18)
	var definitions: Dictionary = Progression.SKILLS if ability else Progression.PERKS
	var index := 0
	for id in definitions:
		var button := preload("res://scripts/menu_button.gd").new()
		button.position = Vector2(0,48+index*60)
		button.size = Vector2(186,48)
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(select.bind(id))
		add_child(button)
		entries[id] = button
		index += 1
	title = label(Vector2(206,48),Vector2(354,40),20)
	description = label(Vector2(206,100),Vector2(354,142),16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rank = label(Vector2(206,258),Vector2(354,70),16)
	purchase_button = preload("res://scripts/menu_button.gd").new()
	purchase_button.position = Vector2(206,340)
	purchase_button.size = Vector2(354,42)
	purchase_button.pressed.connect(purchase)
	add_child(purchase_button)
	activate_button = preload("res://scripts/menu_button.gd").new()
	activate_button.position = Vector2(206,392)
	activate_button.size = Vector2(354,42)
	activate_button.pressed.connect(activate)
	add_child(activate_button)
	activate_button.visible = ability
	message = label(Vector2(0,448),Vector2(568,32),14)
	select(definitions.keys()[0])
func label(point: Vector2, extent: Vector2, font_size: int) -> Label:
	var node := Label.new()
	node.position = point; node.size = extent
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size)
	add_child(node)
	return node
func select(id: StringName) -> void:
	selected = id
	message.text = ""
	refresh()
func refresh() -> void:
	var definitions: Dictionary = Progression.SKILLS if ability else Progression.PERKS
	title.text = definitions[selected].name
	description.text = definitions[selected].description
	if game == null:
		points.text = "Puntos de mejora: 0"
		purchase_button.disabled = true; activate_button.disabled = true
		for id in entries: entries[id].text = definitions[id].name
		return
	var progress = game.progression
	var ranks: Dictionary = progress.skills if ability else progress.perks
	var limit := Progression.SKILL_LIMIT if ability else Progression.PERK_LIMIT
	points.text = "Puntos de mejora compartidos: %d" % game.skill_points
	for id in entries:
		entries[id].text = "%s\n%s %d/%d" % [definitions[id].name,"Nivel" if ability else "Fase",ranks[id],limit]
	rank.text = "%s %d/%d\n%s" % ["Nivel" if ability else "Fase",ranks[selected],limit,"Máximo disponible alcanzado" if ranks[selected] == limit else "Coste: %d puntos" % progress.cost(selected,ability)]
	purchase_button.text = "Máximo disponible" if ranks[selected] == limit else ("Desbloquear" if ranks[selected] == 0 else "Mejorar")
	purchase_button.disabled = not progress.can_buy(selected,ability,game.skill_points)
	if ability:
		var remaining: float = progress.cooldowns[selected]
		activate_button.text = "Activar" if remaining <= 0 else "Espera: %.1f s" % remaining
		activate_button.disabled = ranks[selected] == 0 or remaining > 0 or progress.health <= 0
		if progress.active[selected] > 0: rank.text += "\nActivo: %.1f s" % progress.active[selected]
func purchase() -> void:
	if game != null and game.buy_improvement(selected,ability): message.text = "Mejora adquirida."
	refresh()
func activate() -> void:
	if game != null and game.activate_skill(selected): message.text = "Habilidad lista. Cierra el inventario para continuar."
	refresh()
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	refresh_time += delta
	if refresh_time >= 0.1: refresh_time = 0; refresh()
