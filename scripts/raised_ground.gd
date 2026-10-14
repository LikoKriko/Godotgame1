extends RefCounted
const HEIGHT := 9.6
static var textures: Array[Texture2D] = []
static var surfaces: Array[BitMap] = []
static func prepare() -> void:
 if not textures.is_empty(): return
 for i in 3:
  var source: Texture2D = load("res://assets/environment/imported/platform_%02d.png" % (i+1))
  var pixels := source.get_image()
  var mask := BitMap.new(); mask.create(pixels.get_size())
  for y in pixels.get_height():
   for x in pixels.get_width():
    var color := pixels.get_pixel(x,y)
    var maximum := maxf(color.r,maxf(color.g,color.b)); var minimum := minf(color.r,minf(color.g,color.b))
    mask.set_bit(x,y,color.a > 0.8 and maximum > 0.24 and maximum-minimum < maximum*0.30 and y < pixels.get_height()*0.87)
  # The stones form one raised surface; dark cracks and leaf decoration
  # must not drop the actor through the platform between adjacent slabs.
  for y in pixels.get_height():
   var first := -1; var last := -1
   for x in pixels.get_width():
    if mask.get_bit(x,y):
     if first == -1: first = x
     last = x
   if first >= 0:
    for x in range(first,last+1): mask.set_bit(x,y,true)
  textures.append(source); surfaces.append(mask)
static func contains(platform: Dictionary, point: Vector2) -> bool:
 prepare()
 var mask: BitMap = surfaces[platform.variant]
 var uv: Vector2 = (point-platform.rect.position)/platform.rect.size
 var pixel := Vector2i(uv*Vector2(mask.get_size()))
 return uv.x >= 0 and uv.y >= 0 and uv.x < 1 and uv.y < 1 and mask.get_bitv(pixel)
static func make_mesh(platform: Dictionary) -> ArrayMesh:
 # A dense strip raises the stone top while keeping the original soil at ground level.
 var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
 var vertices := PackedVector3Array(); var uvs := PackedVector2Array(); var indices := PackedInt32Array()
 for row in 33:
  var t := row/32.0
  var rise := HEIGHT*(1-smoothstep(0.87,1.0,t))
  for side in 2:
   vertices.append(Vector3(platform.rect.position.x+side*platform.rect.size.x,platform.rect.position.y+t*platform.rect.size.y+17-rise,0))
   uvs.append(Vector2(side,t))
 for row in 32:
  var a := row*2
  indices.append_array(PackedInt32Array([a,a+1,a+2,a+1,a+3,a+2]))
 arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = indices
 var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh

static var detail_cache: Dictionary = {}
static func detailed_texture(variant: int, dimensions: Vector2) -> Texture2D:
 prepare()
 var key := str(variant)+str(dimensions)
 if not detail_cache.has(key):
  if detail_cache.size() >= 64: detail_cache.clear()
  var style = preload("res://scripts/visual_style.gd")
  var raster: Texture2D = style.normalized(textures[variant],dimensions,true,false,2.0)
  # Twice the sampling density preserves the small soil marks; a second
  # contour raster keeps its physical width equal to other world drawings.
  detail_cache[key] = ImageTexture.create_from_image(style.outlined(raster.get_image()))
 return detail_cache[key]
