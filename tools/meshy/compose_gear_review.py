"""Compose actual Godot screenshots: python tools/meshy/compose_gear_review.py review_dir output.png."""
import sys
from PIL import Image, ImageDraw
from pathlib import Path
source=Path(sys.argv[1]);target=Path(sys.argv[2])
canvas=Image.new('RGB',(1600,1130),'#30383d');draw=ImageDraw.Draw(canvas)
for i,(name,label) in enumerate([('axe','Hacha'),('pickaxe','Pico'),('bow','Arco'),('leaf_armor','Armadura de hojas'),('rock1','Roca')]):
 image=Image.open(source/f'{name}_native.png').convert('RGB');image.thumbnail((310,310))
 canvas.paste(image,(i*320+(320-image.width)//2,35));draw.text((i*320+12,13),label,fill='white')
for i,(name,label) in enumerate([('axe_idle_worn','Hacha y armadura equipadas'),('pickaxe_action_worn','Pico: golpe'),('bow_action_worn','Arco: cuerda tensada')]):
 image=Image.open(source/f'{name}.png').convert('RGB');image.thumbnail((530,740))
 canvas.paste(image,(i*533+(533-image.width)//2,385));draw.text((i*533+12,360),label,fill='white')
target.parent.mkdir(parents=True,exist_ok=True);canvas.save(target)
