extends RefCounted
## Sweep the whole body up, forward and down at the actual frame displacement.
## A distant point ray can request a lift before the body has a valid landing.
static func move(body:CharacterBody3D,motion:Vector3,maximum:float=.26) -> bool:
 if not body.is_on_floor() or motion.length_squared()<.000001:return false
 var wall:=KinematicCollision3D.new()
 if not body.test_move(body.global_transform,motion,wall):return false
 if wall.get_normal().y>=cos(body.floor_max_angle):return false
 if body.test_move(body.global_transform,Vector3.UP*maximum):return false
 var raised:=body.global_transform;raised.origin.y+=maximum
 if body.test_move(raised,motion):return false
 raised.origin+=motion
 var landing:=KinematicCollision3D.new()
 if not body.test_move(raised,Vector3.DOWN*maximum,landing):return false
 if landing.get_normal().y<cos(body.floor_max_angle):return false
 var lift:float=maximum+landing.get_travel().y
 if lift<=.005 or lift>maximum:return false
 # Commit the complete landing, then refresh floor contacts without applying
 # the horizontal velocity twice or letting the previous floor undo the step.
 raised.origin+=landing.get_travel()
 body.global_transform=raised
 var velocity:=body.velocity
 body.velocity=Vector3.DOWN*.1
 body.move_and_slide()
 body.velocity=Vector3(velocity.x,0,velocity.z)
 return true
