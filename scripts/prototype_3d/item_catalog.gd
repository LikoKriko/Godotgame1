extends "res://scripts/item_catalog.gd"
func configure(owner_game) -> void:
 icon_provider=preload("res://scripts/prototype_3d/item_icons.gd")
 super.configure(owner_game)
func open_catalog() -> void:
 show();fit();status.text="";spawn_button.disabled=false;search.grab_focus()
func spawn_enemy() -> void:
 status.text="Enemigo joven añadido." if game.spawn_enemy_near_player() else "No hay una posición libre cerca."
