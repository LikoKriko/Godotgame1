extends Node
var game
var ambient: CanvasModulate
var sun: DirectionalLight2D
var shadows: Node2D
var state: Dictionary = {}

func configure(owner_game) -> void:
	game = owner_game
	ambient = CanvasModulate.new()
	add_child(ambient)
	sun = DirectionalLight2D.new()
	sun.blend_mode = Light2D.BLEND_MODE_ADD
	sun.shadow_enabled = false
	# Ground-projected alpha silhouettes give finite, height-aware shadows.
	add_child(sun)
	shadows = preload("res://scripts/sun_shadows.gd").new()
	shadows.configure(game)
	game.add_child(shadows)
	update_light()

func update_light() -> void:
	state = game.day_cycle.sun_state()
	ambient.color = state["ambient"]
	game.world_view.ground_material.set_shader_parameter("ambient_tint",Vector3(ambient.color.r,ambient.color.g,ambient.color.b))
	if game.world_view.grass_floor != null:
		game.world_view.grass_floor.material.set_shader_parameter("ambient_tint",Vector3(ambient.color.r,ambient.color.g,ambient.color.b))
	sun.visible = state["visible"]
	sun.energy = state["energy"]
	sun.color = Color.WHITE.lerp(Color(1,0.76,0.52),state["warmth"])
	sun.rotation = state["direction"].angle()+PI/2
	shadows.update_sun(state)
