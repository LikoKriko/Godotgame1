"""Compose untouched Godot review frames: input_folder output.png."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw
source=Path(sys.argv[1]);dest=Path(sys.argv[2]);canvas=Image.new('RGB',(1600,850),'#30383d');draw=ImageDraw.Draw(canvas)
rows=[('reference',0,'Referencia: 7340 triangulos'),('idle',1,'Reposo cuadrupedo'),('walk',1,'Marcha'),('attack',1,'Golpe izquierdo'),('boxing_guard',1,'Guardia de boxeo'),('hook',1,'Crochet izquierdo'),('hook',1,'Crochet derecho'),('corpse',1,'Cadaver y apoyo de cola')]
for i,(state,view,label) in enumerate(rows):
 image=Image.open(source/f'{state}_{1 if i==6 else 0}_{view}.png').convert('RGB');image.thumbnail((395,395))
 x=(i%4)*400;y=(i//4)*425;canvas.paste(image,(x,y+25));draw.text((x+10,y+8),label,fill='white')
dest.parent.mkdir(parents=True,exist_ok=True);canvas.save(dest)
