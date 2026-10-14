extends SceneTree
const Ground = preload("res://scripts/ground_contact_shadow.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
	checks += 1
	if not ok: failures += 1; push_error(message)
func run():
	var pixels := Image.create(80,80,false,Image.FORMAT_RGBA8)
	var feet := PackedVector2Array([Vector2(0.1,0.6),Vector2(0.3,0.4),Vector2(0.6,0.9),Vector2(0.9,0.7)])
	for foot in feet: pixels.fill_rect(Rect2i(Vector2i(foot*80)-Vector2i(1,4),Vector2i(3,4)),Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var data := Ground.geometry(texture,feet)
	require(data.contacts.size() == 4,"Four independent leg contacts are preserved")
	for contact in data.contacts:
		var point: Vector2 = contact*80
		require(pixels.get_pixelv(Vector2i(point-Vector2(0,1))).a > 0.5,"Contact sits on a visible foot rather than transparent padding")
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2(0.6,0.8)]:
			for stretch in [0.4,2.0,4.0]:
				require(Ground.projected(point,point,direction,stretch).is_equal_approx(point),"Every leg remains attached at every light angle")
	require(Ground.geometry(texture,feet).mesh == data.mesh,"Meshes are reused across changes of sun direction")
	var art = preload("res://scripts/workbench_art.gd")
	var table := Ground.geometry(art.texture(),art.SHADOW_CONTACTS)
	require(table.contacts.size() == 4,"Actual table uses four contacts")
	print("%s: %d ground contact checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); quit(1 if failures else 0)
