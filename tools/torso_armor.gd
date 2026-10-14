extends RefCounted
## Reusable sleeveless torso shell, attached to the same transform as the skin.
## Normal armor designs change the texture and profile, never the torso motion.
const GUIDE = preload("res://assets/items/burdock_armor_guide.png")
const PROFILES := {
	&"burdock_armor": {"texture":GUIDE,"crop":Rect2(1080,290,368,634), "rings":[
		[24.5,7.5,4.0],[28.5,7.8,4.2],[34.0,7.1,4.2],[40.0,9.0,4.8],[44.2,8.2,4.3],[46.0,6.9,3.4]
	]}
}
static var textures: Dictionary = {}
static func texture_for(id: StringName) -> Texture2D:
	if not textures.has(id):
		var source := AtlasTexture.new()
		source.atlas = PROFILES[id].texture
		source.region = PROFILES[id].crop
		textures[id] = preload("res://scripts/leaf_armor_art.gd").texture(source,Vector2(30,44))
	return textures[id]

static func append(surface: SurfaceTool, torso: Transform3D, id: StringName) -> void:
	var rings: Array = PROFILES[id].rings
	for row in rings.size()-1:
		for column in 24:
			var points: Array[Vector3] = []
			var uv: Array[Vector2] = []
			for corner in [[row,column],[row+1,column],[row+1,column+1],[row,column+1]]:
				var ring: Array = rings[corner[0]]
				var angle: float = corner[1]*TAU/24
				var point := Vector3(sin(angle)*float(ring[1]),float(ring[0]),cos(angle)*float(ring[2]))
				points.append(torso*point)
				# Both sides receive the same leaf weave; side panels wrap continuously.
				uv.append(Vector2(0.5+sin(angle)*0.49,1-(point.y-24.5)/(46.0-24.5)))
			for corner in [0,1,2,0,2,3]:
				surface.set_uv(Vector2(5,0))
				surface.set_uv2(uv[corner])
				surface.set_color(Color.WHITE)
				surface.add_vertex(points[corner])
