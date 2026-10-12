extends RefCounted
static var shared: Theme
static func theme() -> Theme:
	if shared != null: return shared
	shared = Theme.new()
	for type in ["Button","OptionButton","CheckButton","CheckBox"]:
		for state in ["normal","hover","pressed","disabled","focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("222820") if state == "normal" else Color("353d2d")
			box.border_color = Color("676952") if state == "normal" else Color("aaa681")
			box.set_border_width_all(1)
			box.set_corner_radius_all(2)
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			if state == "focus": box.bg_color = Color.TRANSPARENT
			shared.set_stylebox(state,type,box)
	for type in ["Panel","PanelContainer","TabContainer","PopupMenu"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("20251f")
		box.border_color = Color("676952")
		box.set_border_width_all(1)
		shared.set_stylebox("panel",type,box)
	for state in ["tab_selected","tab_unselected","tab_hovered","tab_disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("353d2d") if state == "tab_selected" else Color("222820")
		box.border_color = Color("676952")
		box.set_border_width_all(1)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		shared.set_stylebox(state,"TabContainer",box)
		shared.set_stylebox(state,"TabBar",box)
	return shared
