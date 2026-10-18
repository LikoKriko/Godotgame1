extends RefCounted
## Original release artwork. Whole frames keep their proportions; quick slots share an atlas.
const TEXTURES={
 &"life":preload("res://assets/ui/hud/Vida.png"),
 &"food":preload("res://assets/ui/hud/Kcal.png"),
 &"water":preload("res://assets/ui/hud/Agua.png"),
 &"weight":preload("res://assets/ui/hud/Peso.png"),
 &"clock":preload("res://assets/ui/hud/DiayHora.png"),
 &"level":preload("res://assets/ui/hud/Nivel.png"),
 &"settings":preload("res://assets/ui/hud/Configuración.png"),
 &"pause":preload("res://assets/ui/hud/Pausa.png"),
 &"map":preload("res://assets/ui/hud/Mapa.png"),
 &"skills":preload("res://assets/ui/hud/Habilidades.png"),
 &"quick":preload("res://assets/ui/hud/Inventario.png")
}
static func dimensions(kind:StringName,width:float) -> Vector2:
 var source:Vector2=TEXTURES[kind].get_size()
 return Vector2(width,width*source.y/source.x)
static func frame(kind:StringName,state:String="normal") -> StyleBoxTexture:
 return texture_frame(TEXTURES[kind],state)
static func texture_frame(texture:Texture2D,state:String="normal") -> StyleBoxTexture:
 var result:=StyleBoxTexture.new();result.texture=texture
 result.modulate_color=Color(1.15,1.15,1.10) if state in ["hover","focus"] else (Color(.8,.8,.8) if state=="pressed" else (Color(.6,.6,.6) if state=="disabled" else Color.WHITE))
 for side in [SIDE_LEFT,SIDE_RIGHT]:result.set_content_margin(side,12)
 for side in [SIDE_TOP,SIDE_BOTTOM]:result.set_content_margin(side,6)
 return result
static func quick_slot(index:int) -> StyleBoxTexture:
 var source:Texture2D=TEXTURES[&"quick"];var atlas:=AtlasTexture.new();atlas.atlas=source
 var cell:=source.get_width()/6.0;atlas.region=Rect2(index*cell,0,cell,source.get_height());atlas.filter_clip=true
 return texture_frame(atlas)
static func skin_button(button:Button,kind:StringName) -> void:
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box:=frame(kind,state)
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_content_margin(side,6)
  button.add_theme_stylebox_override(state,box)
static func transparent_button(button:Button) -> void:
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box:=StyleBoxFlat.new()
  box.bg_color=Color(1,1,.85,.08) if state in ["hover","focus"] else (Color(0,0,0,.14) if state=="pressed" else Color.TRANSPARENT)
  button.add_theme_stylebox_override(state,box)
