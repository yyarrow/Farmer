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

The eight files directly under `assets/art/buildings/` and the unstandardized
era sheets are deprecated legacy fallbacks. They remain in the repository for
authoring comparison, but every Android export excludes them. All 112 release
atlases resolve through the era-specific standardized paths and manifest.

QA contacts are generated under `.qa/building_standardization/` and are not
shipped. Run the asset contract with:

```sh
godot --headless --path . --script tests/all_era_building_assets.gd
```
