extends Node2D
## This scene is instantiated on entry and freed on exit.
var host
func _draw() -> void:
 if host != null: host.draw_room(self)
