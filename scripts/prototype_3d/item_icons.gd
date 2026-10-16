extends RefCounted
## 256px assets are baked from original artwork, never from the old tiny icons.
const ROOT:="res://assets/items/prototype_3d/icons/"
static var cache:Dictionary={}
static func for_item(item:Dictionary) -> Texture2D:
 return get_icon(&"botella_full" if item.get("id")==&"botella" and item.get("water_ml",0)>0 else item.get("id",&""))
static func get_icon(id:StringName) -> Texture2D:
 if id==&"":return null
 if not cache.has(id):
  var path:=ROOT+String(id)+".png"
  cache[id]=load(path) if ResourceLoader.exists(path) else load(ROOT+"_placeholder.png")
 return cache[id]
