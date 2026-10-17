extends "res://scripts/item_catalog.gd"
var sprout_button:Button
func configure(owner_game) -> void:
 icon_provider=preload("res://scripts/prototype_3d/item_icons.gd")
 super.configure(owner_game)
 sprout_button=preload("res://scripts/menu_button.gd").new();sprout_button.name="SpawnEnemy3";sprout_button.text="Añadir enemigo3"
 spawn_button.get_parent().add_child(sprout_button);sprout_button.pressed.connect(spawn_sprout)
func open_catalog() -> void:
 show();fit();status.text="";spawn_button.disabled=false;search.grab_focus()
func spawn_enemy() -> void:
 status.text="Enemigo joven añadido." if game.spawn_enemy_near_player() else "No hay una posición libre cerca."

func spawn_sprout() -> void:
 status.text="Enemigo3 añadido: recorrido de 10 metros." if game.spawn_sprout_near_player() else "No hay un recorrido libre de 10 metros cerca."
