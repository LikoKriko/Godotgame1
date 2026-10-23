extends Node3D
## Isolated visual inspection; never instantiates the playable actor or animation driver.
const VISUAL := preload("res://assets/characters/aren_v2/aren_visual.glb")
const VIEWS := ["Frontal", "Lateral izquierdo", "Lateral derecho", "Trasera", "Tres cuartos", "Superior", "Rostro"]
const ANGLES := [0.0, 90.0, -90.0, 180.0, 30.0, 30.0, 0.0]
var camera: Camera3D
var yaw := 30.0
var pitch := 5.0
var distance := 3.2
var target := Vector3(0, 0.88, 0)
var dragging := false
var status: Label

func _ready() -> void:
	add_child(VISUAL.instantiate())
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("303641")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d2d9e2")
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	for data in [[Vector3(-2, 3, 3), 1.1], [Vector3(3, 2, 1), 0.6], [Vector3(0, 3, -3), 0.8]]:
		var light := DirectionalLight3D.new()
		add_child(light)
		light.position = data[0]
		light.look_at(Vector3(0, 0.9, 0))
		light.light_energy = data[1]
		light.shadow_enabled = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.005
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("444b57")
	material.roughness = 1.0
	floor_mesh.material_override = material
	add_child(floor_mesh)
	camera = Camera3D.new()
	camera.near = 0.01
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.05
	add_child(camera)
	camera.make_current()
	_build_ui()
	_set_view(4)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "AREN · ESTUDIO VISUAL"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	var stage := Label.new()
	stage.text = "Primera versión · pendiente de aprobación"
	box.add_child(stage)
	for i in VIEWS.size():
		var button := Button.new()
		button.text = "%d · %s" % [i + 1, VIEWS[i]]
		button.pressed.connect(_set_view.bind(i))
		box.add_child(button)
	status = Label.new()
	box.add_child(status)
	var help := Label.new()
	help.text = "Arrastrar botón derecho: girar\nRueda: acercar / alejar\n1–7: vistas · R: restablecer"
	box.add_child(help)

func _set_view(index: int) -> void:
	yaw = ANGLES[index]
	pitch = 24.0 if index == 5 else 5.0
	target = Vector3(0, 1.55 if index == 6 else 0.88, 0)
	camera.size = 0.42 if index == 6 else 2.05
	status.text = VIEWS[index]
	_update_camera()

func _update_camera() -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	camera.position = target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size * 0.9, 0.2, 3.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size / 0.9, 0.2, 3.5)
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.35
		pitch = clampf(pitch + event.relative.y * 0.25, -15.0, 70.0)
		_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			_set_view(event.keycode - KEY_1)
		elif event.keycode == KEY_R:
			_set_view(4)
