extends StyleBox
## Separate source and destination corner sizes keep small text margins exact.
@export var rim: Texture2D
@export var fill: Texture2D
@export var filled_rim: Texture2D
@export var tint := Color.WHITE
@export var edge := 8.0
@export var button := false
func _get_draw_rect(rect: Rect2) -> Rect2: return rect
func _get_minimum_size() -> Vector2: return Vector2.ZERO
func _draw(canvas: RID, rect: Rect2) -> void:
	if rim == null: return
	var artwork: Texture2D = filled_rim if fill != null and filled_rim != null else rim
	var extent := artwork.get_size()
	var source_edge := Vector2(230,120) if button else Vector2(180,180)
	var target_edge := Vector2(minf(edge,rect.size.x/2),minf(edge,rect.size.y/2))
	var sx := [0.0,source_edge.x,extent.x-source_edge.x,extent.x]
	var sy := [0.0,source_edge.y,extent.y-source_edge.y,extent.y]
	var dx := [rect.position.x,rect.position.x+target_edge.x,rect.end.x-target_edge.x,rect.end.x]
	var dy := [rect.position.y,rect.position.y+target_edge.y,rect.end.y-target_edge.y,rect.end.y]
	for y in 3:
		for x in 3:
			if x == 1 and y == 1 and fill == null: continue
			var destination := Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y])
			var source := Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y])
			RenderingServer.canvas_item_add_texture_rect_region(canvas,destination,artwork.get_rid(),source,tint,false,false)

	# Reinforce the original contour inside the existing hit rectangle. Corner
	# artwork and text margins remain unchanged; no decoration is magnified.
	var width := minf(maxf(4.0,edge/2.0),minf(rect.size.x,rect.size.y)/2.0)
	var border := Color(0.08,0.09,0.075,tint.a)
	var middle_x := maxf(0,rect.size.x-2*target_edge.x)
	var middle_y := maxf(0,rect.size.y-2*target_edge.y)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position+Vector2(target_edge.x,0),Vector2(middle_x,width)),border)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(rect.position+Vector2(0,target_edge.y),Vector2(width,middle_y)),border)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(Vector2(rect.end.x-width,rect.position.y+target_edge.y),Vector2(width,middle_y)),border)
	RenderingServer.canvas_item_add_rect(canvas,Rect2(Vector2(rect.position.x+target_edge.x,rect.end.y-width),Vector2(middle_x,width)),border)
