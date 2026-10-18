extends PanelContainer
signal closed
const Style=preload("res://scripts/ui_style.gd")
var game
var hud_slider:HSlider
var auto_run:CheckButton
var size_label:Label
var tabs:TabContainer
func configure(owner_game) -> void:
 game=owner_game;theme=Style.theme(&"menu");custom_minimum_size=Vector2(490,360)
 var layout:=VBoxContainer.new();layout.add_theme_constant_override("separation",16);add_child(layout)
 var heading:=Label.new();heading.text="CONFIGURACIÓN";layout.add_child(heading)
 tabs=TabContainer.new();layout.add_child(tabs)
 var gameplay:=page("Juego");auto_run=check(gameplay,"Correr automáticamente",game.settings.values.auto_run,func(value):game.settings.values.auto_run=value;save())
 size_label=Label.new();gameplay.add_child(size_label)
 hud_slider=HSlider.new();hud_slider.min_value=1;hud_slider.max_value=5;hud_slider.step=1;hud_slider.value=game.settings.values.hud_size;hud_slider.custom_minimum_size=Vector2(360,28);gameplay.add_child(hud_slider)
 hud_slider.value_changed.connect(func(value):game.settings.values.hud_size=int(value);save())
 var graphics:=page("Gráficos")
 check(graphics,"Sincronización vertical",game.settings.values.vsync,func(value):game.settings.values.vsync=value;save())
 var show_fps:=check(graphics,"Mostrar FPS",game.settings.values.show_fps,func(value):game.settings.values.show_fps=value;save());show_fps.name="ShowFPS"
 var shadows:=check(graphics,"Sombras mejoradas (prueba)",game.settings.values.shadow_trial,func(value):game.settings.values.shadow_trial=value;save());shadows.name="ShadowTrial"
 shadows.tooltip_text="Mejora el contacto y la definición cercana. Desactiva para comparar con las sombras anteriores."
 var row:=HBoxContainer.new();graphics.add_child(row)
 var label:=Label.new();label.text="Límite de FPS";row.add_child(label)
 var fps:=OptionButton.new();fps.name="FPS";var limits:=[30,60,120,144,0]
 for value in limits:fps.add_item("Sin límite" if value==0 else str(value))
 fps.select(limits.find(int(game.settings.values.fps)));fps.item_selected.connect(func(index):game.settings.values.fps=limits[index];save());row.add_child(fps)
 row=HBoxContainer.new();graphics.add_child(row);label=Label.new();label.text="Antialiasing 3D";row.add_child(label)
 var aa:=OptionButton.new();aa.name="MSAA"
 for caption in ["Desactivado","2×","4×"]:aa.add_item(caption)
 aa.select(int(game.settings.values.msaa));aa.item_selected.connect(func(index):game.settings.values.msaa=index;save());row.add_child(aa)
 row=HBoxContainer.new();graphics.add_child(row);label=Label.new();label.text="Generación de mundo";row.add_child(label)
 var generation:=OptionButton.new();generation.name="WorldGeneration";var distances:=[100,200,400]
 for value in distances:generation.add_item("%d metros%s"%[value," (base)" if value==200 else ""])
 generation.select(distances.find(int(game.settings.values.world_generation)))
 generation.item_selected.connect(func(index):game.settings.values.world_generation=distances[index];save());row.add_child(generation)
 label=Label.new();label.text="Resolución y modo de pantalla: bloqueados temporalmente.";Style.set_font_size(label,13);graphics.add_child(label)
 var audio:=page("Audio")
 for key in ["master","music","effects"]:
  var caption:Dictionary={"master":"Volumen general","music":"Música","effects":"Efectos"}
  label=Label.new();label.text=caption[key];audio.add_child(label)
  var slider:=HSlider.new();slider.name=key;slider.min_value=0;slider.max_value=1;slider.step=0.01;slider.value=game.settings.values[key];slider.custom_minimum_size=Vector2(360,22);slider.value_changed.connect(set_volume.bind(key));audio.add_child(slider)
 check(audio,"Silenciar juego",game.settings.values.muted,func(value):game.settings.values.muted=value;save())
 var close:=preload("res://scripts/menu_button.gd").new();close.text="Volver";close.pressed.connect(func():closed.emit());layout.add_child(close);update_text()
func page(caption:String) -> VBoxContainer:
 var column:=VBoxContainer.new();column.name=caption;column.add_theme_constant_override("separation",12);tabs.add_child(column);return column
func check(parent:Control,caption:String,value:bool,callback:Callable) -> CheckButton:
 var control:=CheckButton.new();control.text=caption;control.button_pressed=value;control.toggled.connect(callback);parent.add_child(control);return control
func set_volume(value:float,key:String) -> void:game.settings.values[key]=value;save()
func save() -> void:
 var result:int=game.settings.save_settings()
 apply_runtime(game.settings,get_viewport());game.settings.changed.emit();update_text()
 if result!=OK:size_label.text="No se pudo guardar la configuración."
func update_text() -> void:size_label.text="Tamaño del HUD: %d / 5"%int(game.settings.values.hud_size)
static func apply_runtime(settings,viewport:Viewport) -> void:
 settings.values.hud_size=clampi(int(settings.values.hud_size),1,5)
 Engine.max_fps=int(settings.values.fps)
 viewport.msaa_3d=[Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][int(settings.values.msaa)]
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.values.vsync else DisplayServer.VSYNC_DISABLED)
 for key in ["master","music","effects"]:
  var bus_name:String={"master":"Master","music":"Music","effects":"Effects"}[key]
  var index:=AudioServer.get_bus_index(bus_name)
  if index<0:
   AudioServer.add_bus();index=AudioServer.bus_count-1;AudioServer.set_bus_name(index,bus_name);AudioServer.set_bus_send(index,"Master")
  var value:float=settings.values[key];AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,0.0001)));AudioServer.set_bus_mute(index,value<=0 or (key=="master" and settings.values.muted))

static func hud_scale(level:int) -> float:
 # New level 1 matches former level 3: 56% of original HUD surface.
 # Preserve the user-selected area metric; all increments refer to level 1.
 return sqrt(0.56*(1.0+0.1*(clampi(level,1,5)-1)))
