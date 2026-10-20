extends RefCounted
## Sweep the whole body up, forward and down at the actual frame displacement.
## A distant point ray can request a lift before the body has a valid landing.
const MAXIMUM:=.26

static func landing(body:CharacterBody3D,motion:Vector3,maximum:float=MAXIMUM) -> Dictionary:
 if not body.is_on_floor() or motion.length_squared()<.000001:return {}
 var wall:=KinematicCollision3D.new()
 if not body.test_move(body.global_transform,motion,wall):return {}
 if wall.get_normal().y>=cos(body.floor_max_angle):return {}
 if body.test_move(body.global_transform,Vector3.UP*maximum):return {}
 var raised:=body.global_transform;raised.origin.y+=maximum
 if body.test_move(raised,motion):return {}
 raised.origin+=motion
 var landing:=KinematicCollision3D.new()
 if not body.test_move(raised,Vector3.DOWN*maximum,landing):return {}
 var rounded_edge:bool=landing.get_normal().y<cos(body.floor_max_angle)
 var surface_y:float=raised.origin.y+landing.get_travel().y
 if rounded_edge:
  # A capsule can contact the rim of a flat step with a steep separation
  # normal. Verify the actual surface just inside that rim, not that normal.
  var at:Vector3=landing.get_position()+motion.normalized()*.003
  var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.01,at-Vector3.UP*.02,body.collision_mask,[body.get_rid()])
  var top:=body.get_world_3d().direct_space_state.intersect_ray(query)
  if top.is_empty() or top.normal.y<cos(body.floor_max_angle):return {}
  surface_y=top.position.y
  if surface_y-body.global_position.y>maximum+.005:return {}
 var lift:float=maximum+landing.get_travel().y
 if lift<=.005 or lift>maximum:return {}
 return {"transform":raised.translated(landing.get_travel()),"height":lift,"surface_y":surface_y,"rounded_edge":rounded_edge}

static func move(body:CharacterBody3D,motion:Vector3,maximum:float=MAXIMUM) -> bool:
 var preview:=landing(body,motion,maximum)
 if preview.is_empty():return false
 # Commit the complete landing, then refresh floor contacts without applying
 # the horizontal velocity twice or letting the previous floor undo the step.
 body.global_transform=preview.transform
 var velocity:=body.velocity
 body.velocity=Vector3.DOWN*.1
 var floor_angle:=body.floor_max_angle
 # The verified top is walkable; keep this short rim contact grounded while
 # refreshing contacts. Restore the usual slope limit immediately afterward.
 if preview.rounded_edge:body.floor_max_angle=PI*.5-.001
 body.move_and_slide()
 body.floor_max_angle=floor_angle
 body.velocity=Vector3(velocity.x,0,velocity.z)
 return true
