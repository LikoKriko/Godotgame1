extends RefCounted
static var sizes: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/imported/tree_sizes.json"))
static func dimensions(design: int) -> Vector2:
 var scale := 67.2/float(sizes[5][1])
 return Vector2(sizes[design][0],sizes[design][1])*scale
