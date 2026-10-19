extends SceneTree
## Export the existing UV/tangent frame for baking, or attach the shared material.
const FOLDER := "res://assets/models/meshy/rock1/"

func _initialize() -> void:
 var args := OS.get_cmdline_user_args()
 var mesh: ArrayMesh = load(FOLDER + "model.res")
 assert(args.size() >= 1, "Use --export output.json or --apply")
 if args[0] == "--export":
  assert(args.size() == 2)
  var arrays := mesh.surface_get_arrays(0)
  var positions: Array = []; var normals: Array = []; var tangents: Array = []; var uvs: Array = []
  for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]: positions.append([p.x, p.y, p.z])
  for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]: normals.append([n.x, n.y, n.z])
  for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]: uvs.append([uv.x, uv.y])
  var raw: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
  for i in positions.size(): tangents.append([raw[i*4], raw[i*4+1], raw[i*4+2], raw[i*4+3]])
  var file := FileAccess.open(args[1], FileAccess.WRITE)
  assert(file != null)
  file.store_string(JSON.stringify({"positions": positions, "normals": normals, "tangents": tangents, "uvs": uvs, "indices": arrays[Mesh.ARRAY_INDEX]}))
 elif args[0] == "--apply":
  var material: StandardMaterial3D = load(FOLDER + "surface_material.tres")
  assert(material != null)
  mesh.surface_set_material(0, material)
  assert(ResourceSaver.save(mesh, FOLDER + "model.res", ResourceSaver.FLAG_COMPRESS) == OK)
 else:
  assert(false, "Use --export output.json or --apply")
 quit()
