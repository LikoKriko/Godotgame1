# Aren: editable head study

`authoring/aren_head_high.blend` is an independent high density likeness study.
It does not replace `aren_visual.glb` or any gameplay character. The visual
likeness remains in progress; polygon density is not an approval criterion.

The source separates facial anatomy, hair, eyes and a neutral portrait studio
into named collections. The facial shell includes connected eyelid and lip
surfaces, recessed oral and nasal cavities, and a neck continuation. Auricles,
ocular globes, curved irises, pupils and eyebrows remain separate editable
objects. Skin uses the `Tone` point color attribute. Hair paint is packed into
the Blender file.

The original `psnj1_3d_rigged.fbx` supplies a read-only facial volume reference
and layered hair geometry. Its imported reference collection is hidden. The
original FBX, rig, binds and animation clips are unchanged. The supplied Aren
character sheet determines the intended identity and silhouette.

Open the saved `ThreeQuarter` camera or select any `Head review` camera for
front, profiles, back, elevated, ear and eye views. For surface inspection,
use solid shading with a single studio material; the `Neutral clay inspection`
material is also available. The study contains no rig or animation.

The `primary_volumes_01` pass refines cheekbone planes, the mandibular border,
chin and the neck transition on the existing dense surface. It uses bounded,
feathered displacements with pinned nose, lip and orbital regions. Hair,
auricles and ocular meshes retain their coordinates and transforms. The pass
does not resample or reduce the mesh. Aperture rims follow the actual boundary
edge cycles with opposite winding so the facial shell has consistent normals.

Rebuild with Blender 4.3 or newer from the repository root:

```sh
blender -b --python tools/characters/sculpt_aren_head.py -- --no-render
```

Omit `--no-render` for eight rendered views in the ignored `work/aren-head/`
directory. `--quick` uses six views and fewer rendering samples. Rebuilding
overwrites the generated source: preserve manual sculpt edits separately.
The builder applies `tools/characters/aren_head_volumes.py` after constructing
the dense surface. That pass refuses repeated application to an already
refined source, preventing cumulative deformation.

To retain an existing studio and every nonfacial object exactly when updating
only the facial shell, open that baseline and transfer the rebuilt surface:

```sh
blender -b baseline.blend --python tools/characters/aren_head_volumes.py -- \
  --surface rebuilt-head.blend --output updated-head.blend
```

This transfers only the facial mesh, retains the baseline skin material and
checks the coordinates and transforms of all other meshes before saving.

No remesh or decimation has been applied. Retain this high density source
unchanged when making a later remesh copy, after the likeness is settled.
Check the nose, lip corners, eyelids, helix and hair silhouette against the
source before accepting any reduction. `source.json` records the stage and
per-collection polygon counts.
