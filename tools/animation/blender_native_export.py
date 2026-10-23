"""Shared native 66-joint Blender bake/glTF export, preserving fixed normalization."""
import bpy, json, struct
def export_native(rig, output, stem, frame_end=156, action_name="ArenLanding3m_Baked"):
 for name in ["Aren_Baked_66","ExportSkin"]:
  old=bpy.data.objects.get(name)
  if old:bpy.data.objects.remove(old,do_unlink=True)
 # Keep the editable original and bake a separate copy for the game.
 baked=rig.copy();baked.data=rig.data.copy();bpy.context.collection.objects.link(baked);baked.name='Aren_Baked_66'
 baked.animation_data.action=rig.animation_data.action.copy()
 bpy.ops.object.select_all(action='DESELECT');baked.select_set(True);bpy.context.view_layer.objects.active=baked
 bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.select_all(action='SELECT')
 bpy.ops.nla.bake(frame_start=1,frame_end=frame_end,step=1,only_selected=False,visual_keying=True,clear_constraints=True,use_current_action=False,bake_types={'POSE'},clean_curves=False)
 bpy.ops.object.mode_set(mode='OBJECT');baked.animation_data.action.name=action_name;baked.animation_data.action.use_fake_user=True
 # A tiny hidden skin ensures glTF retains all 66 native joints without duplicating the character asset.
 mesh=bpy.data.meshes.new('ExportSkin');mesh.from_pydata([(0,0,0),(.001,0,0),(0,.001,0)],[],[(0,1,2)])
 proxy=bpy.data.objects.new('ExportSkin',mesh);bpy.context.collection.objects.link(proxy);proxy.matrix_world=baked.matrix_world.copy();proxy.parent=baked
 vg=proxy.vertex_groups.new(name='smartrig:Hips');vg.add([0,1,2],1,'REPLACE');mod=proxy.modifiers.new('NativeSkin','ARMATURE');mod.object=baked
 bpy.ops.object.select_all(action='DESELECT');baked.select_set(True);proxy.select_set(True);bpy.context.view_layer.objects.active=baked
 bpy.ops.export_scene.gltf(filepath=str(output/(stem+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_anim_single_armature=False,export_frame_range=True,export_force_sampling=True,export_def_bones=False,export_materials='NONE',export_yup=True)
 # Blender's active-action exporter emits identity object tracks for this pose bake.
 # Keep the armature's fixed native normalization in the node, animate bones only.
 path=output/(stem+'.glb');raw=path.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
 gltf=json.loads(raw[20:20+length]);binary=raw[20+length:]
 for animation in gltf['animations']:
  animation['name']=action_name
  animation['channels']=[channel for channel in animation['channels'] if gltf['nodes'][channel['target']['node']].get('name')!='Aren_Baked_66']
 encoded=json.dumps(gltf,separators=(',',':')).encode();encoded+=b' '*((-len(encoded))%4)
 path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(encoded)+len(binary))+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+binary)
 baked.hide_render=True;baked.hide_set(True);proxy.hide_render=True;proxy.hide_set(True)
 return baked
