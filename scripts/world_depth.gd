extends RefCounted
## Ground planes stay below zero; all living beings and tall props sort by feet.
static func layer(ground_y: float) -> int:
 return clampi(roundi(ground_y)+1800,16,4000)
static func opacity(game, rect: Rect2, base_y: float, actors = null, player_point := Vector2.INF) -> float:
 var player: Vector2 = game.player if not player_point.is_finite() else player_point
 var player_body := Rect2(player+Vector2(-15,-53-game.ground_height),Vector2(30,70))
 if player.y+17 < base_y and rect.intersects(player_body): return 0.35
 if game.is_inside_tree():
  var creatures: Array = game.get_tree().get_nodes_in_group("creatures") if actors == null else actors
  for creature in creatures:
   if not creature.visible: continue
   if creature.position.y+17 < base_y and rect.intersects(Rect2(creature.position+Vector2(-15,-15-creature.ground_height),Vector2(30,32))): return 0.75
 return 1.0
