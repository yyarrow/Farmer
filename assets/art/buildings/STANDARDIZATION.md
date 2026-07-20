# Building atlas standard

Every release building atlas is an era-owned `768×768` PNG containing four
`384×384` stage frames in reading order. `footprint_templates.gd` is the sole
authoring-space geometry authority:

- 2:1 isometric camera and ground diamond;
- south/front corner is the explicit road entrance and render socket;
- a minimum four-pixel transparent frame margin;
- one uniform subject scale plus translation only — no per-axis or affine
  deformation;
- roofs may visually overhang the foundation, but ground-contact pixels remain
  within the canonical footprint.

`tools/standardize_all_building_assets.gd` recovers stage subjects from the old
2×2 sheets by connected component, preserving pixels that crossed an old
quadrant boundary. It repositions the recovered natural subject and ground
contact against the canonical socket without changing aspect ratio or adding a
second artificial base. `standardization_manifest.json` records the footprint,
socket and method for every era/type pair.

The eight files directly under `assets/art/buildings/` are deprecated legacy
fallbacks. Release code must resolve an explicit era asset through the manifest;
these files are retained temporarily only for migration comparison and should
be moved to a non-exported archive once all consumers use the manifest.

QA contacts are generated under `.qa/building_standardization/` and are not
shipped. Run the asset contract with:

```sh
godot --headless --path . --script tests/all_era_building_assets.gd
```
