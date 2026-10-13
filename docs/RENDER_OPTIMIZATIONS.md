# Reuse of unchanged presentation data

The HUD retains the previous displayed strings, item identities/quantities and
rounded cooldowns. Events and the existing 0.1-second timer still refresh it;
only identical widget assignments and identical minimap redraws are skipped.

Visible resource silhouettes use 128-unit spatial buckets as a broad phase.
The original alpha bitmap test determines the hit, with the same depth and
insertion-order tie rules. Moving/rotating resource surfaces and transformed
parents rebuild their index. No hitbox or interaction distance changed.

Trees cache their rest rectangle, trunk anchor and base tint. An unchanged
player skips settled trees; fading/impacted trees retain their original
per-frame interpolation and geometry. The last impact frame restores the rest
transform. Movement and resource removal invalidate the relevant state.

## Measurement

Seed 73129, 117 resources including 58 trees, Godot 4.6.3 on the cloud Linux
runner. Median of seven rounds after warmup; times below are microseconds for
batches, not frame times or a prediction of FPS on another computer.

| Batch | Before | After |
| --- | ---: | ---: |
| 300 identical HUD refreshes | 7136 | 2527 |
| 1000 deterministic cursor queries | 97831 | 1221 |
| 300 settled-tree updates | 51774 | 295 |

Native rendered comparisons at 1280×720 for idle, behind-tree transparency and
an impact had **zero differing pixels**. The spatial regression test compares
12,000 queries with the old full silhouette scan, including parent transforms,
rotations, negative scales, removal and insertion-order ties. Existing
interaction, ground-cover, combat and render-reuse checks passed.
