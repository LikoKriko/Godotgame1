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

The `primary_volumes_02` pipeline refines cheekbone planes, the mandibular border,
chin and the neck transition on the existing dense surface. The zygomatic crest
is higher than the lower cheek hollow; the mandibular border ascends toward the
ear and the chin has a flatter mental plane. It uses bounded, feathered
displacements with pinned nose, lip, orbital and ear attachment regions. Hair,
auricles and ocular meshes retain their coordinates and transforms. The pass
does not resample or reduce the mesh. Aperture rims follow the actual boundary
edge cycles with opposite winding so the facial shell has consistent normals.

The separate `eye_likeness_03` stage is pending visual approval. It adjusts only
the orbital envelope, eyelids, brows and ocular components: a tapered almond
opening, closer eye centers, a slightly raised outer canthus, a hooded upper
lid and a recessed globe. Slate blue-gray irises, a transparent corneal surface
and a fine lower tear meniscus remain separate editable meshes. Hair, auricles,
the lower nose, lips, jaw and neck retain their existing geometry. The saved
`EyesFront` camera provides a bilateral close-up under the same studio lights.

The second eye pass redistributes vertices on the existing eyelid annuli with
pinned inner and outer loops, then fits a smooth local skin surface to remove
scalloped seam marks and duplicated folds. It preserves mesh connectivity,
polygon count, globe centers, irises and gaze. The eyebrow root is lowered
slightly and the outer arch is raised using the enlarged head reference.

The third pass reduces the canthal rise from 4.2 mm to 1.3 mm across the
opening and increases the upper lid arc. The morph fades within the immediate
lid envelope, retaining the clean outer orbital surface. Globe centers, eye
width, iris geometry and gaze stay fixed. Pupils are slightly smaller, paired
lacrimal caruncles are separate editable meshes, and brows sit closer to the
upper lids with a flatter, fuller silhouette.

Apply the complete eye pipeline once to a `primary_volumes_02` source without
an eye revision, or upgrade an existing `eye_likeness_01` or `eye_likeness_02` source:

```sh
blender -b baseline.blend --python tools/characters/aren_eye_likeness.py -- \
  --output eye-review.blend
```

A source already marked `eye_likeness_03` is refused to prevent cumulative edits.

Do not continue the general facial review or integrate this eye study into
gameplay until its visual approval is supplied.

Rebuild with Blender 4.3 or newer from the repository root:

```sh
blender -b --python tools/characters/sculpt_aren_head.py -- --no-render
```

Omit `--no-render` for nine rendered views in the ignored `work/aren-head/`
directory. `--quick` uses six views and fewer rendering samples. Rebuilding
overwrites the generated source: preserve manual sculpt edits separately.
The builder applies `tools/characters/aren_head_volumes.py` after constructing
the dense surface. An existing `primary_volumes_01` source can receive the plane
refinement directly with that script and `--output refined-head.blend`. A source
already carrying the current revision is refused, preventing cumulative deformation.

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
