extends SceneTree
## Bake two reusable 512px pixel textures, using the uploaded tree's palette.
## Originals remain references; these are procedural surface maps, not cutouts.
func _initialize() -> void:
 var bark:=Image.create(512,512,false,Image.FORMAT_RGB8)
 var leaf:=Image.create(512,512,false,Image.FORMAT_RGB8)
 for y in 512:
  for x in 512:
   var u:=x/512.0;var v:=y/512.0
   var bend:=0.33*sin(v*TAU)+0.17*sin(v*TAU*3+u*TAU)
   var groove:=pow(0.5+0.5*sin((u*11+bend)*TAU),12)
   var fine:=0.5+0.5*sin((u*37+0.13*sin(v*TAU*7))*TAU)
   var grain:=sin((floor(u*256)*19+floor(v*256)*31))*0.018
   var value:=snappedf(0.93-groove*0.20+fine*0.035+grain,1.0/32)
   bark.set_pixel(x,y,Color(value,value,value))
   # A central midrib and staggered diagonal secondary veins, kept restrained.
   var midrib:=1-smoothstep(0.008,0.026,absf(u-.5))
   var path:=fposmod(v-absf(u-.5)*.72,0.18)
   var vein:float=(1-smoothstep(.005,.018,minf(path,.18-path)))*(1-smoothstep(.34,.49,absf(u-.5)))
   var shade:=0.90+0.045*sin(u*PI)+0.055*midrib+vein*.025+grain*.45
   value=snappedf(shade,1.0/48)
   leaf.set_pixel(x,y,Color(value,value,value))
 DirAccess.make_dir_recursive_absolute("res://assets/environment/prototype_3d")
 bark.save_png("res://assets/environment/prototype_3d/tree_bark.png")
 leaf.save_png("res://assets/environment/prototype_3d/tree_leaf.png")
 print("Baked shared 512x512 nearest-sampled tree surface maps")
 quit()
