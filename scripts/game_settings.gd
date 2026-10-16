extends RefCounted
signal changed
const PATH := "user://day_zero_settings.cfg"
const DEFAULTS := {"auto_run": false,"sharp_camera": false,"hud_size": 1,"muted": false,"master": 0.8, "music": 0.6, "effects": 0.8, "vsync": true, "fps": 60, "msaa": 0, "window_mode": 0, "resolution": Vector2i(1920,1080)}
var values: Dictionary = DEFAULTS.duplicate()
var applied_display: Array = []
var resolution_locked := OS.get_name() == "Windows"
var startup_resolution := Vector2i.ZERO

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in DEFAULTS:
			values[key] = config.get_value("settings",key,DEFAULTS[key])
	values["auto_run"] = bool(values["auto_run"])
	values["muted"] = bool(values["muted"])
	values["sharp_camera"] = bool(values["sharp_camera"])
	values["hud_size"] = clampi(int(values["hud_size"]),1,6)
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

static func supports_msaa_2d() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"

static func hud_scale(level: int) -> float:
	# Area is width × height. Equal scaling on both axes uses its square root.
	return sqrt(0.4*(1+0.2*(clampi(level,1,6)-1)))

func apply(viewport: Viewport) -> void:
	# Temporary Windows safeguard: keep the resolution that worked at startup.
	# Enforce this here too, so stale UI values cannot resize the render viewport.
	if resolution_locked:
		if startup_resolution == Vector2i.ZERO: startup_resolution = values["resolution"]
		values["resolution"] = startup_resolution
	for pair in [["Master","master"],["Music","music"],["Effects","effects"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,pair[0])
			AudioServer.set_bus_send(index,"Master")
		var volume: float = values[pair[1]]
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volume,0.0001)))
		AudioServer.set_bus_mute(index,volume == 0 or (pair[0] == "Master" and values["muted"]))
	Engine.max_fps = values["fps"]
	if not supports_msaa_2d(): values["msaa"] = 0
	viewport.msaa_2d = values["msaa"]
	if DisplayServer.get_name() == "headless":
		changed.emit()
		return
	# Use one explicit render resolution in every screen mode. Fullscreen and
	# borderless otherwise ignore window_set_size and render at desktop size.
	var window := viewport.get_window()
	var display_state := [window.get_window_id(),values["resolution"],values["window_mode"]]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED,window.get_window_id())
	if applied_display == display_state:
		changed.emit(); return
	applied_display = display_state.duplicate()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_size = values["resolution"]
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_factor = 1.0
	# Update the Window node as well as the native window. Direct DisplayServer
	# calls leave its position/size cached, desynchronizing render and UI input.
	window.mode = Window.MODE_WINDOWED
	window.borderless = values["window_mode"] == 2
	window.size = values["resolution"]
	if values["window_mode"] == 1:
		window.size = DisplayServer.screen_get_size(window.current_screen)
		window.position = DisplayServer.screen_get_position(window.current_screen)
		window.mode = Window.MODE_FULLSCREEN
	elif values["window_mode"] == 2:
		window.size = DisplayServer.screen_get_size(window.current_screen)
		window.position = DisplayServer.screen_get_position(window.current_screen)
	else:
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = screen.position+Vector2i(Vector2(screen.size-window.size)/2.0)
	var cursor := window.get_tree().root.get_node_or_null("GameCursor")
	if cursor != null: cursor.resync_after_display_change()
	changed.emit()
