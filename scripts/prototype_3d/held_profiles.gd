extends RefCounted
## Offsets are measured from the gripping palm, in model-authoring units.
const Axe=preload("res://assets/models/meshy/axe/anchors.gd")
const Pickaxe=preload("res://assets/models/meshy/pickaxe/anchors.gd")
const PROFILES := {
 &"axe":{"tip":Axe.TIP,"two_hands":true,"support":Axe.SUPPORT,"model_scale":Axe.MODEL_SCALE,"shaft_range":Vector2(Axe.SHAFT_BOTTOM,Axe.SHAFT_TOP)},
 &"pickaxe":{"tip":Pickaxe.TIP,"two_hands":true,"support":Pickaxe.SUPPORT,"model_scale":Pickaxe.MODEL_SCALE,"shaft_range":Vector2(Pickaxe.SHAFT_BOTTOM,Pickaxe.SHAFT_TOP)},
 &"sword":{"tip":Vector3(0,29,0),"two_hands":false,"support":0.0},
 &"bow":{"tip":Vector3(0,0,20),"two_hands":false,"support":0.0},
 &"bottle":{"tip":Vector3(0,2.8,0),"two_hands":false,"support":0.0},
 &"food":{"tip":Vector3(0,2,0),"two_hands":false,"support":0.0},
 &"carried":{"tip":Vector3(0,0,7),"two_hands":true,"support":10.0}
}
static func profile(family: StringName) -> Dictionary:
 return PROFILES.get(family,{"tip":Vector3.ZERO,"two_hands":false,"support":0.0})
