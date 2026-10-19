"""Bake tangent-space surface data from the approved rock and its original maps.

Requires NumPy, Pillow and SciPy. Export UV frames with rock_material.gd first.
All fine detail is evaluated in metres on the mesh, avoiding UV noise seams.
No source image, geometry or UV is overwritten.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import distance_transform_edt, gaussian_filter

ROOT = Path(__file__).resolve().parents[2]
FOLDER = ROOT / "assets/models/meshy/rock1"


def smoothstep(lo, hi, values):
    t = np.clip((values - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)


def unit(v):
    return v / np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-8)


def noise_gradient(points, frequency, seed):
    """Continuous 3D value noise and analytic world-space height derivatives."""
    q = points * frequency
    cell = np.floor(q).astype(np.int64)
    t = q - cell
    fade = t * t * t * (t * (t * 6 - 15) + 10)
    derivative = 30 * t * t * (t - 1) * (t - 1)
    value = np.zeros(len(points), np.float32)
    gradient = np.zeros_like(points)
    for x in (0, 1):
        for y in (0, 1):
            for z in (0, 1):
                corner = np.array([x, y, z])
                c = cell + corner
                # Fixed integer hash; no random image noise or platform RNG state.
                h = (c[:, 0] * 73856093) ^ (c[:, 1] * 19349663) ^ (c[:, 2] * 83492791) ^ seed
                h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
                h = h ^ (h >> 16)
                sample = (h.astype(np.float64) / 4294967295 * 2 - 1).astype(np.float32)
                weight = np.where(corner, fade, 1 - fade)
                slope = np.where(corner, derivative, -derivative)
                value += sample * np.prod(weight, axis=1)
                for axis in range(3):
                    others = [i for i in range(3) if i != axis]
                    gradient[:, axis] += sample * slope[:, axis] * weight[:, others[0]] * weight[:, others[1]] * frequency
    return value, gradient


def raster_frames(mesh, size):
    points = np.asarray(mesh["positions"], np.float32)
    normals = np.asarray(mesh["normals"], np.float32)
    tangents = np.asarray(mesh["tangents"], np.float32)
    uvs = np.asarray(mesh["uvs"], np.float32) * size - 0.5
    positions = np.zeros((size, size, 3), np.float32)
    ts = np.zeros_like(positions)
    bs = np.zeros_like(positions)
    coverage = np.zeros((size, size), bool)
    for ids in np.asarray(mesh["indices"]).reshape(-1, 3):
        a, b, c = uvs[ids]
        lo = np.maximum(np.ceil(np.minimum(np.minimum(a, b), c)).astype(int), 0)
        hi = np.minimum(np.floor(np.maximum(np.maximum(a, b), c)).astype(int), size - 1)
        if np.any(hi < lo):
            continue
        ab, ac = b - a, c - a
        determinant = ab[0] * ac[1] - ab[1] * ac[0]
        if abs(determinant) < 1e-8:
            continue
        yy, xx = np.mgrid[lo[1]:hi[1]+1, lo[0]:hi[0]+1]
        dx, dy = xx - a[0], yy - a[1]
        v = (dx * ac[1] - dy * ac[0]) / determinant
        w = (ab[0] * dy - ab[1] * dx) / determinant
        u = 1 - v - w
        inside = (u >= -1e-6) & (v >= -1e-6) & (w >= -1e-6)
        if not inside.any():
            continue
        weights = np.stack([u[inside], v[inside], w[inside]], axis=-1).astype(np.float32)
        y, x = yy[inside], xx[inside]
        normal = unit(weights @ normals[ids])
        tangent = weights @ tangents[ids, :3]
        tangent = unit(tangent - normal * np.sum(normal * tangent, axis=1, keepdims=True))
        sign = np.where(weights @ tangents[ids, 3] >= 0, 1, -1)
        positions[y, x] = weights @ points[ids]
        ts[y, x] = tangent
        bs[y, x] = np.cross(normal, tangent) * sign[:, None]
        coverage[y, x] = True
    return positions[coverage], ts[coverage], bs[coverage], coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mesh_json", type=Path)
    args = parser.parse_args()
    profile = json.loads((FOLDER / "surface_profile.json").read_text())
    provenance = json.loads((FOLDER / "source.json").read_text())
    for name, expected in provenance["textures_sha256"].items():
        assert hashlib.sha256((FOLDER / (name + ".png")).read_bytes()).hexdigest() == expected, name + " source differs"
    albedo = Image.open(FOLDER / "albedo.png").convert("RGB")
    size = profile["resolution"]
    assert albedo.size == (size, size)
    hsv = np.asarray(albedo.convert("HSV"), np.float32) / 255
    h0, h1, h2, h3 = profile["moss_hue_degrees"]
    s0, s1 = profile["moss_saturation"]
    hue = hsv[..., 0] * 360
    moss = smoothstep(h0, h1, hue) * (1 - smoothstep(h2, h3, hue)) * smoothstep(s0, s1, hsv[..., 1])
    # Subpixel transitions; preserve small green patches instead of dilating them.
    moss = gaussian_filter(moss, 0.7)
    positions, tangents, bitangents, coverage = raster_frames(json.loads(args.mesh_json.read_text()), size)
    membership = moss[coverage]
    stone_noise, stone_gradient = noise_gradient(positions, profile["stone_detail"]["frequency_per_metre"], profile["seed"])
    moss_noise, moss_gradient = noise_gradient(positions, profile["moss_detail"]["frequency_per_metre"], profile["seed"] + 1)
    gradient = (stone_gradient * profile["stone_detail"]["height_metres"] * (1 - membership[:, None])
                + moss_gradient * profile["moss_detail"]["height_metres"] * membership[:, None])
    source = np.asarray(Image.open(FOLDER / "normal.png").convert("RGB"), np.float32) / 127.5 - 1
    n = unit(source[coverage])
    strength = profile["source_normal_strength"]
    scale = strength["stone"] * (1 - membership) + strength["moss"] * membership
    n[:, :2] *= scale[:, None]
    n[:, 0] -= np.sum(gradient * tangents, axis=1)
    n[:, 1] -= np.sum(gradient * bitangents, axis=1)
    n = unit(n)
    encoded = np.rint((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    normal_map = np.full((size, size, 3), [128, 128, 255], np.uint8)
    normal_map[coverage] = encoded
    source_roughness = np.asarray(Image.open(FOLDER / "roughness.png"), np.float32)[coverage] / 255
    # Retain the source's local variation while separating dry stone and soft moss.
    variation = np.clip((source_roughness - 0.73) * 0.65, -0.05, 0.05)
    stone = np.clip(0.78 + variation + stone_noise * 0.012, *profile["stone_roughness"])
    plant = np.clip(0.95 + variation * 0.3 + moss_noise * 0.018, *profile["moss_roughness"])
    roughness_map = np.full((size, size), 199, np.uint8)
    roughness_map[coverage] = np.rint((stone * (1 - membership) + plant * membership) * 255).astype(np.uint8)
    # Extend only into unused atlas texels. Adjacent UV islands keep their own data.
    distance, nearest = distance_transform_edt(~coverage, return_indices=True)
    padding = (~coverage) & (distance <= profile["padding_pixels"])
    for output, filename in [(normal_map, "surface_normal.png"), (roughness_map, "surface_roughness.png")]:
        output[padding] = output[nearest[0][padding], nearest[1][padding]]
        Image.fromarray(output).save(FOLDER / filename, optimize=True)
    provenance["surface_material"] = {
        "profile": profile["profile"],
        "configuration": "surface_profile.json",
        "material": "surface_material.tres",
        "normal": "surface_normal.png",
        "roughness": "surface_roughness.png",
        "bake_tool": "tools/meshy/bake_rock_surface.py",
        "derived_sha256": {
            name: hashlib.sha256((FOLDER / name).read_bytes()).hexdigest()
            for name in ("surface_normal.png", "surface_roughness.png")
        },
    }
    (FOLDER / "source.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print("Baked", coverage.sum(), "surface texels; original maps and mesh unchanged")


if __name__ == "__main__":
    main()
