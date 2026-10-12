extends RefCounted
const PATH := "user://day_zero_settings.cfg"
const DEFAULTS := {"master": 0.8, "music": 0.6, "effects": 0.8, "vsync": true, "fps": 60, "msaa": 0, "window_mode": 0, "resolution": Vector2i(1920,1080)}
var values: Dictionary = DEFAULTS.duplicate()

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in DEFAULTS:
			values[key] = config.get_value("settings",key,DEFAULTS[key])
	for key in ["master","music","effects"]:
		values[key] = clampf(float(values[key]),0,1)
	values["fps"] = int(values["fps"]) if int(values["fps"]) in [0,30,60,120,144] else 60
	values["msaa"] = clampi(int(values["msaa"]),0,2)
	values["window_mode"] = clampi(int(values["window_mode"]),0,2)
	if not values["resolution"] is Vector2i or values["resolution"].x < 800 or values["resolution"].y < 600:
		values["resolution"] = DEFAULTS["resolution"]

func save_settings() -> Error:
	var config := ConfigFile.new()
	for key in values:
		config.set_value("settings",key,values[key])
	return config.save(PATH)

func apply(viewport: Viewport) -> void:
	for pair in [["Master","master"],["Music","music"],["Effects","effects"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,pair[0])
			AudioServer.set_bus_send(index,"Master")
		var volume: float = values[pair[1]]
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume,0.0001)))
		AudioServer.set_bus_mute(index,volume == 0)
	Engine.max_fps = values["fps"]
	viewport.msaa_2d = values["msaa"]
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,values["window_mode"] == 2)
	DisplayServer.window_set_size(values["resolution"])
	if values["window_mode"] == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif values["window_mode"] == 2:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(screen.position+(screen.size-values["resolution"])/2)
