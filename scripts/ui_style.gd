extends RefCounted
static var shared: Theme
static var display_font: Font
const SMALL_TEXT_MAX := 14
static func menu_font() -> Font:
	if display_font == null:
		display_font = preload("res://assets/ui/pause_font.fnt").duplicate()
		display_font.fallbacks = [ThemeDB.fallback_font]
	return display_font

static func set_font_size(control: Control, size: int) -> void:
	control.add_theme_font_size_override("font_size",size)
	control.add_theme_font_override("font",ThemeDB.fallback_font if size <= SMALL_TEXT_MAX else menu_font())

static var menu_theme: Theme
static func frame(scope: StringName = &"game", button: bool = false, padding: float = 8.0, state: String = "normal") -> StyleBox:
	var box = preload("res://scripts/ui_frame.gd").new()
	box.rim = load("res://assets/ui/styles/%s_%s.png" % ["menu" if scope == &"menu" else "game","button" if button else "frame"])
	box.fill = null if state == "focus" else preload("res://assets/ui/styles/fill.png")
	box.edge = padding; box.button = button
	box.tint = Color(1.22,1.22,1.12) if state in ["hover","focus"] else (Color(0.55,0.55,0.55) if state == "disabled" else (Color(0.8,0.8,0.8) if state == "pressed" else Color.WHITE))
	for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: box.set_content_margin(side,padding)
	return box

static func skin_button(control: Button, scope: StringName = &"game") -> void:
	var font := control.get_theme_font("font")
	var height := font.get_height(control.get_theme_font_size("font_size"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		control.add_theme_stylebox_override(state,frame(scope,true,height*0.15,state))

static func theme(scope: StringName = &"game") -> Theme:
	if scope == &"menu" and menu_theme != null: return menu_theme
	if scope != &"menu" and shared != null: return shared
	var result := Theme.new()
	result.default_font = menu_font(); result.default_font_size = 16
	for type in ["Button","OptionButton","CheckButton","CheckBox"]:
		for state in ["normal","hover","pressed","disabled","focus","normal_pressed","hover_pressed","disabled_pressed"]:
			var appearance: String = "pressed" if state.ends_with("_pressed") else state
			if state == "disabled_pressed": appearance = "disabled"
			result.set_stylebox(state,type,frame(scope,true,menu_font().get_height(16)*0.15,appearance))
	for type in ["Panel","PanelContainer","TabContainer","PopupMenu"]: result.set_stylebox("panel",type,frame(scope))
	for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:
		for type in ["TabContainer","TabBar"]: result.set_stylebox(state,type,frame(scope,true,menu_font().get_height(16)*0.15,"hover" if state == "tab_selected" else "normal"))
	if scope == &"menu": menu_theme = result
	else: shared = result
	return result
