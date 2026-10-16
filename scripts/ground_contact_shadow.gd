extends RefCounted
## Cached silhouettes with multiple ground contacts. Author explicit contacts
## for legs/buildings; alpha-contour fallback handles roots and solid stones.
static var cache: Dictionary = {}
static func contacts(pixels: Image, explicit: PackedVector2Array = PackedVector2Array()) -> PackedVector2Array:
	if not explicit.is_empty():
		var snapped := PackedVector2Array()
		var size := pixels.get_size()
		for contact in explicit:
			var target := Vector2i(contact*Vector2(size))
			var chosen := target; var found := false
			for y in range(mini(size.y-1,target.y+2),maxi(-1,target.y-3),-1):
				for x in range(maxi(0,target.x-1),mini(size.x,target.x+2)):
					if pixels.get_pixel(x,y).a > 0.5:
						chosen = Vector2i(x,y); found = true; break
				if found: break
			snapped.append(Vector2((chosen.x+0.5)/size.x,float(chosen.y+1)/size.y))
		return snapped
	var size := pixels.get_size()
	var bottom := pixels.get_used_rect().end.y
	var points := PackedVector2Array()
	for x in size.x:
		for y in range(bottom-1,maxi(0,bottom-ceili(size.y*0.18)),-1):
			if pixels.get_pixel(x,y).a > 0.5:
				points.append(Vector2((x+0.5)/size.x,float(y+1)/size.y)); break
	if points.is_empty(): points.append(Vector2(0.5,float(bottom)/size.y))
	return points
static func contact_at(x: float, points: PackedVector2Array) -> float:
	if x <= points[0].x: return points[0].y
	for i in range(1,points.size()):
		if x <= points[i].x:
			return lerpf(points[i-1].y,points[i].y,inverse_lerp(points[i-1].x,points[i].x,x))
	return points[-1].y
static func geometry(texture: Texture2D, explicit: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var key := str(texture.get_instance_id())+str(explicit)
	if cache.has(key): return cache[key]
	var points := contacts(texture.get_image(),explicit)
	var average := 0.0
	for point in points: average += point.y/points.size()
	var columns: Array[float] = [0.0,1.0]
	for point in points: columns.append(point.x)
	for i in range(1,33): columns.append(i/33.0)
	columns.sort()
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(columns.size()-1):
		var a := columns[i]; var b := columns[i+1]
		if is_equal_approx(a,b): continue
		# A common upper plane avoids projecting the tabletop four times.
		# Each lower column still lands on its individual ground contact.
		var rows: Array[float] = [0.0,0.2,0.4,0.6,0.8,1.0,contact_at(a,points),contact_at(b,points)]
		rows.sort()
		for band in range(rows.size()-1):
			for vertex in [Vector2(a,rows[band]),Vector2(b,rows[band]),Vector2(a,rows[band+1]),Vector2(a,rows[band+1]),Vector2(b,rows[band]),Vector2(b,rows[band+1])]:
				surface.set_color(Color(contact_at(vertex.x,points),average,0,1))
				surface.set_uv(vertex); surface.add_vertex(Vector3(vertex.x,vertex.y,0))

	var result := {"mesh":surface.commit(),"contacts":points}
	if cache.size() >= 512: cache.clear()
	cache[key] = result
	return result
static func projected(point: Vector2, contact: Vector2, direction: Vector2, length: float) -> Vector2:
	return Vector2(point.x,contact.y)+direction*length*maxf(0,contact.y-point.y)
