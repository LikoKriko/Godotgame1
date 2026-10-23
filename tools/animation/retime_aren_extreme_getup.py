"""Blender time edit only: extend the existing 4-second getup to 8 seconds.
Run on aren_extreme.blend. Poses, paths, rig and the first four phases stay fixed.
The retained d69986ad action makes reruns idempotent. Use --bake-only for manual edits.
"""
import bpy, json, sys
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent))
from blender_native_export import export_native
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/prototype_3d/generated/aren_extreme_blender_v1'
rig=bpy.data.objects['Aren_Native_66_Authoring'];scene=bpy.context.scene
BASE='ArenExtreme_GetupTimingBase_d69986ad'
ACTIVE='ArenExtreme_SlowGetup_WholeBodyPoses'
FACTOR=2.0
base=bpy.data.actions.get(BASE)
if base is None:
 base=rig.animation_data.action
 assert base.name=='ArenExtreme_ShoulderCircles_WholeBodyPoses', 'Open the d69986ad authoring source'
 base.name=BASE
 rig['getup_base_timing']=json.dumps(json.loads((OUT/'timing.json').read_text()))
 rig['getup_base_markers']=json.dumps([(m.name,m.frame) for m in scene.timeline_markers])
base.use_fake_user=True
source=json.loads(rig['getup_base_timing'])
fps=source['fps'];cut=round(source['getup']*fps)+1
assert len(rig.data.bones)==66 and source['frames']==385 and cut==145

def warp(frame):return frame if frame<=cut else cut+(frame-cut)*FACTOR

def retime(action):
 for curve in action.fcurves:
  original=[(k.co.copy(),k.handle_left.copy(),k.handle_right.copy()) for k in curve.keyframe_points]
  for key,(co,left,right) in zip(curve.keyframe_points,original):
   key.co.x=warp(co.x);key.handle_left.x=warp(left.x);key.handle_right.x=warp(right.x)
   assert key.co.y==co.y, 'A time edit must never change a keyed pose value'
  curve.update()

def copy_retimed(action,name):
 old=bpy.data.actions.get(name)
 if old:bpy.data.actions.remove(old)
 result=action.copy();result.name=name;result.use_fake_user=False
 retime(result)
 return result
rig.animation_data.action=copy_retimed(base,ACTIVE)
# Keep the existing editable contact targets on the same revised timeline.
for name in ['Foot_R','Foot_L','Palm_R','Hand_L','Knee_R','Knee_L','Elbow_R','Elbow_L']:
 obj=bpy.data.objects.get(name)
 if not obj or not obj.animation_data or not obj.animation_data.action:continue
 base_name='ExtremeGetupTimingBase_'+name
 control_base=bpy.data.actions.get(base_name)
 if control_base is None:control_base=obj.animation_data.action;control_base.name=base_name
 control_base.use_fake_user=True
 obj.animation_data.action=copy_retimed(control_base,'ExtremeSlowGetup_'+name)
for marker in list(scene.timeline_markers):scene.timeline_markers.remove(marker)
for name,frame in json.loads(rig['getup_base_markers']):scene.timeline_markers.new(name,frame=round(warp(frame)))
end=round(warp(source['frames']))
scene.frame_start=1;scene.frame_end=end;scene.render.fps=fps
rig['whole_body_keys']=[round(warp(f)) for f in source['keys']]
rig['phase_frames']=[1,34,78,109,cut,end]
rig['refinement']='Timing only: original getup 4 s -> 8 s; unchanged complete poses and first four phases'
# Update absolute event times; the first four phases and shoulder timing stay fixed.
timing=dict(source)
for name in ['palms','feet','leg_load','right_foot_start','left_foot_start','left_palm','torso_align','torso_forward','end']:
 if name in timing:timing[name]=(warp(timing[name]*fps+1)-1)/fps
previous=source['end']-source['getup']
timing.update(frames=end,keys=rig['whole_body_keys'].to_list(),getup_previous_duration=previous,getup_duration=previous*FACTOR,getup_time_scale=FACTOR)
(OUT/'timing.json').write_text(json.dumps(timing,indent=2)+'\n')
for old in list(bpy.data.actions):
 if old.name.startswith('ArenExtreme_Baked'):bpy.data.actions.remove(old)
baked=export_native(rig,OUT,'extreme',end,'ArenExtreme_Baked')
for old in list(bpy.data.actions):
 if old.users==0 and old not in [base,rig.animation_data.action,baked.animation_data.action]:bpy.data.actions.remove(old)
scene.frame_set(round(warp(190)))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='DESELECT');rig.hide_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'authoring/aren_extreme.blend'),compress=True)
print('GETUP RETIMED',previous,'->',previous*FACTOR,'seconds;',end,'frames; keyed poses unchanged')
