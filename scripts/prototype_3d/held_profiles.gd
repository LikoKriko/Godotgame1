extends RefCounted
## Offsets are measured from the gripping palm, in model-authoring units.
const PROFILES := {
 &"axe":{"tip":Vector3(11,20,0),"two_hands":true,"support":8.25},
 &"pickaxe":{"tip":Vector3(12,21,0),"two_hands":true,"support":8.25},
 &"sword":{"tip":Vector3(0,29,0),"two_hands":false,"support":0.0},
 &"bow":{"tip":Vector3(0,0,20),"two_hands":false,"support":0.0},
 &"bottle":{"tip":Vector3(0,2.8,0),"two_hands":false,"support":0.0},
 &"food":{"tip":Vector3(0,2,0),"two_hands":false,"support":0.0},
 &"carried":{"tip":Vector3(0,0,7),"two_hands":true,"support":10.0}
}
static func profile(family: StringName) -> Dictionary:
 return PROFILES.get(family,{"tip":Vector3.ZERO,"two_hands":false,"support":0.0})
