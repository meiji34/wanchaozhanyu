# rts_environment_model_refs - Design Spec

> Human-readable design narrative. Machine-readable contract: spec_lock.md.

## I. Project Information

| Item | Value |
| ---- | ----- |
| **Project Name** | rts_environment_model_refs |
| **Canvas Size** | 512x512 per view |
| **Asset Count** | 4 modeled objects, 2 master sheets, 18 individual views |
| **Art Style** | High-Res Pixel / Outlined / Cel-shaded / Textured |
| **Target Platform** | Blender modeling reference; Godot 4.7.1 / Android / iOS |
| **Color Palette** | Three Kingdoms Natural Terrain 48 |
| **Created Date** | 2026-07-29 |

---

## II. Canvas Specification

| Property | Value |
| -------- | ----- |
| **Base sprite size** | 512x512 per view |
| **Tree master sheet** | 1536x1024, 3 columns x 2 rows |
| **Mountain master sheet** | 1536x2048, 3 columns x 4 rows |
| **Transparency** | Alpha channel (RGBA); only 0 or 255 alpha in final exports |

---

## III. Color Palette

### Palette Name: Three Kingdoms Natural Terrain 48

| Index | HEX | Role |
| ----- | --- | ---- |
| 0 | Transparent | Empty background |
| 1-4 | #17151A, #211C20, #2B2526, #332D2B | Outline and deepest shadow |
| 5-16 | #3A3A38, #454640, #51534B, #5E6055, #6B6D60, #797A6C, #888779, #979487, #A7A295, #B7B0A1, #C6BDAA, #D5CBB7 | Rock faces and stone highlights |
| 17-24 | #3A2A24, #4A3328, #5B3D2E, #6C4935, #7D563D, #906747, #A57955, #BA8E67 | Soil, exposed earth and warm rock |
| 25-32 | #2D1E1B, #3B261F, #4A2F24, #59382A, #684431, #795139, #8B6043, #A0714F | Tree trunk, branches and dry roots |
| 33-44 | #1F2B22, #293729, #344632, #40553B, #4D6545, #5B7650, #6A875D, #7A986B, #8CAA79, #9DBC88, #AFCB98, #C2D7AA | Pine needles, shrubs and mountain vegetation |
| 45-48 | #38443A, #536050, #707A64, #909879 | Moss, lichen and muted neutral accents |

### Palette Usage Rules

- All final pixels must use colors from this palette
- Per-object budget: no more than 40 opaque colors
- All three mountains share the same rock, soil and vegetation ramps
- The mountains differ through silhouette and massing, not unrelated hue changes
- Light source direction is fixed at top-left
- Use pale colors sparingly so silhouettes remain readable at RTS zoom

---

## IV. Art Style Definition

| Property | Value |
| -------- | ----- |
| **Sub-style** | Outlined / Cel-shaded / Textured |
| **Outline color** | #17151A |
| **Shading depth** | 3-tone hard-edged clusters with selective fourth-tone accents |
| **Dithering** | Selective on broad rock faces and bark only |
| **Light direction** | Top-left |
| **View consistency** | Orthographic modeling reference; constant scale and proportions |

---

## V. Asset List

### Characters

None.

### Tiles

None.

### Items

None.

### UI

None.

### Effects

None.

### Backgrounds

| Asset | Size | Colors | Animation | Description | Priority |
| ----- | ---- | ------ | --------- | ----------- | -------- |
| rts_ancient_pine_multiview | 1536x1024 | Wood + vegetation + shared outline | None | Six-view sheet of one mature ancient pine: front, right, rear, left, top and three-quarter isometric; thick readable trunk, layered asymmetric crown and visible root flare | High |
| rts_ancient_pine_view_* | 512x512 each | Same as tree sheet | None | Six individual crops matching the master sheet | High |
| rts_mountains_multiview | 1536x2048 | Rock + earth + vegetation + shared outline | None | Twelve-view sheet containing three mountains in columns: sharp peak, long ridge and rounded clustered peaks; rows are front, side, top and three-quarter isometric | High |
| rts_mountain_*_view_* | 512x512 each | Same shared mountain palette | None | Twelve individual mountain view crops matching the master sheet | High |

---

## VI. Animation Specification

No animation. All assets are static modeling references.

---

## VII. Technical Constraints

- No anti-aliasing
- No smooth gradient fills
- No partial opacity in final exports
- All colors from the declared palette after quantization
- Consistent top-left light direction
- Consistent orthographic proportions between views of the same object
- Hard pixel clusters and nearest-neighbor scaling only
- No text, labels, UI frames, people, buildings or modern objects
- No atmospheric perspective, cast shadow, ground plane or decorative background
- Complete silhouette must fit each cell with generous padding
- Tree branches and mountain ridges must remain identifiable across corresponding views

---

## VIII. Platform Export Notes

| Platform | Special Requirements |
| -------- | ------------------- |
| Blender | Use individual view PNGs as orthographic image references; align by shared cell center and scale |
| Godot 4.7.1 | Import final RGBA PNGs with nearest-neighbor filtering; use as reference or map entity source art |
| Android / iOS | Keep 512x512 masters; runtime assets may be reduced later after model and LOD decisions |
