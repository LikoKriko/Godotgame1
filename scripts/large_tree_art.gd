extends RefCounted
static var sizes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/imported/tree_sizes.json"))
static var textures: Array[Texture2D] = []
static func dimensions(design: int) -> Vector2:
 var scale := 67.2/float(sizes[5][1])
 return Vector2(sizes[design][0],sizes[design][1])*scale
static func texture(design: int) -> Texture2D:
 if textures.is_empty():
  for i in 9: textures.append(load("res://assets/environment/imported/tree_%02d.png" % (i+1)))
 return textures[design]
