extends RefCounted
## Stable streams: channels do not consume each other's draws; no engine String.hash.
static func chunk_seed(seed_value:int,key:Vector2i,channel:String="") -> int:
 var result:=(seed_value ^ (key.x*73856093) ^ (key.y*19349663))&0xffffffff
 if channel.is_empty():return result # Existing resources and save IDs keep their layout.
 var salt:=2166136261
 for byte in channel.to_utf8_buffer():salt=((salt ^ byte)*16777619)&0xffffffff
 return (result ^ salt)&0xffffffff
