extends StyleBox
## Separate source and destination corner sizes keep small text margins exact.
@export var rim: Texture2D
@export var fill: Texture2D
@export var tint := Color.WHITE
@export var edge := 8.0
@export var button := false
func _get_draw_rect(rect: Rect2) -> Rect2: return rect
func _get_minimum_size() -> Vector2: return Vector2.ZERO
func _draw(canvas: RID, rect: Rect2) -> void:
	if fill != null:
		RenderingServer.canvas_item_add_texture_rect(canvas,rect.grow(-edge*0.5),fill.get_rid(),false,Color(0.80,0.80,0.80,1))
	if rim == null: return
	var extent := rim.get_size()
	var source_edge := Vector2(230,120) if button else Vector2(180,180)
	var target_edge := Vector2(minf(edge,rect.size.x/2),minf(edge,rect.size.y/2))
	var sx := [0.0,source_edge.x,extent.x-source_edge.x,extent.x]
	var sy := [0.0,source_edge.y,extent.y-source_edge.y,extent.y]
	var dx := [rect.position.x,rect.position.x+target_edge.x,rect.end.x-target_edge.x,rect.end.x]
	var dy := [rect.position.y,rect.position.y+target_edge.y,rect.end.y-target_edge.y,rect.end.y]
	for y in 3:
		for x in 3:
			if x == 1 and y == 1: continue
			var destination := Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y])
			var source := Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y])
			RenderingServer.canvas_item_add_texture_rect_region(canvas,destination,rim.get_rid(),source,tint,false,false)
