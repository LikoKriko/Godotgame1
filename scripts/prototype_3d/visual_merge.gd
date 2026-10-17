extends RefCounted
## Bake static child transforms into one shared surface per original material.
static func merge(root:Node3D) -> ArrayMesh:
 var groups:Dictionary={}
 for node in root.find_children("*","MeshInstance3D",true,false):
  var transform:Transform3D=node.transform;var parent:Node=node.get_parent()
  while parent!=root:transform=parent.transform*transform;parent=parent.get_parent()
  var normal_basis:=transform.basis.inverse().transposed()
  for surface in node.mesh.get_surface_count():
   var paint:Material=node.get_active_material(surface)
   if not groups.has(paint):
    var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);groups[paint]=builder
   var builder:SurfaceTool=groups[paint];var arrays:Array=node.mesh.surface_get_arrays(surface)
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
   for i in (indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()):
    var index:int=indices[i] if not indices.is_empty() else i
    builder.set_normal((normal_basis*arrays[Mesh.ARRAY_NORMAL][index]).normalized())
    builder.set_uv(arrays[Mesh.ARRAY_TEX_UV][index] if arrays[Mesh.ARRAY_TEX_UV]!=null else Vector2.ZERO)
    builder.add_vertex(transform*arrays[Mesh.ARRAY_VERTEX][index])
 var result:=ArrayMesh.new()
 for paint in groups:
  groups[paint].set_material(paint);groups[paint].commit(result)
 return result
