# rts_city - Design Spec

> Human-readable design narrative. Machine-readable contract: spec_lock.md.

## I. Project Information

| Item | Value |
| ---- | ----- |
| **Project Name** | rts_city |
| **Canvas Size** | 512x512 |
| **Asset Count** | 8 |
| **Art Style** | High-Res Pixel / Outlined / Cel-shaded / Textured |
| **Target Platform** | Godot 4.7.1 / Android / iOS |
| **Color Palette** | Three Kingdoms Fortress 48 |
| **Created Date** | 2026-07-28 |

---

## II. Canvas Specification

| Property | Value |
| -------- | ----- |
| **Base sprite size** | 512x512 |
| **Tile size** | N/A |
| **Background size** | 512x512 |
| **Transparency** | Alpha channel (RGBA); only 0 or 255 alpha |

---

## III. Color Palette

### Palette Name: Three Kingdoms Fortress 48

| Index | HEX | Role |
| ----- | --- | ---- |
| 0 | Transparent | Empty background |
| 1-4 | #17151A, #211C20, #2B2526, #332D2B | Outline and deepest shadow |
| 5-12 | #403A36, #4C4540, #5A514A, #685E55, #776B5E, #897A6B, #9A8A79, #ADA08E | Stone walls and masonry |
| 13-20 | #3A2A24, #51372B, #684433, #7B523B, #906345, #A87854, #C09163, #D2AA78 | Earth, roads and warm highlights |
| 21-26 | #2D1E1B, #442921, #5C3527, #75442F, #8E5738, #A96D45 | Timber structures |
| 27-32 | #4A1F25, #67252B, #842C30, #A03937, #BC4A40, #D3634D | Lacquer red roofs and banners |
| 33-38 | #5B4727, #746037, #8D7947, #AA955A, #C7B370, #E2CF8A | Bronze and muted gold |
| 39-43 | #263B3A, #31504C, #3F655E, #547B6E, #6F9381 | Blue-green roof patina |
| 44-48 | #273624, #35482D, #465B38, #5A7046, #72885B | Desaturated vegetation |

### Palette Usage Rules

- All sprite pixels must use colors from this palette after post-processing
- Per-sprite color budget: 48 colors (excluding transparency)
- Light source direction: top-left
- Bright gold is reserved for roof ridges, command flags and focal highlights
- Red is used sparingly to preserve military readability

---

## IV. Art Style Definition

| Property | Value |
| -------- | ----- |
| **Sub-style** | Outlined / Cel-shaded / Textured |
| **Outline color** | #17151A |
| **Shading depth** | 3-tone hard-edged clusters |
| **Dithering** | Selective, only on large stone and earth surfaces |
| **Light direction** | Top-left |
| **View** | Three-quarter isometric top-down |

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
| ----- | ---- | ------- | --------- | ----------- | -------- |
| rts_city | 512x512 | All 48 | None | Isolated Three Kingdoms RTS fortified city with square outer wall, four corner towers, monumental gatehouse, central palace compound, barracks, command flags, courtyards and readable roads; transparent background | High |
| rts_city_multiview | 1536x1024 | All 48 | None | Six-view modeling reference sheet: front, right, rear, left, top and three-quarter isometric views in a fixed 3x2 grid, consistent scale and architecture, transparent background | High |
| rts_city_view_front | 512x512 | All 48 | None | Front orthographic modeling view | High |
| rts_city_view_right | 512x512 | All 48 | None | Right orthographic modeling view | High |
| rts_city_view_rear | 512x512 | All 48 | None | Rear orthographic modeling view | High |
| rts_city_view_left | 512x512 | All 48 | None | Left orthographic modeling view | High |
| rts_city_view_top | 512x512 | All 48 | None | Top-down modeling plan view | High |
| rts_city_view_isometric | 512x512 | All 48 | None | Three-quarter isometric modeling view | High |

---

## VI. Animation Specification

No animation. Both assets are static PNG files.

---

## VII. Technical Constraints

- No anti-aliasing
- No smooth gradient fills
- No partial opacity
- All colors from the declared palette after quantization
- Consistent top-left light direction
- Hard pixel clusters and nearest-neighbor scaling only
- No text, labels, UI frames, people, armies or modern objects
- Complete silhouette must fit the canvas with generous transparent padding

---

## VIII. Platform Export Notes

| Platform | Special Requirements |
| -------- | ------------------- |
| Godot 4.7.1 | Import as RGBA PNG; nearest-neighbor filtering; use as map city entity texture |
| Android / iOS | Keep 512x512 master; engine may scale down while preserving nearest-neighbor filtering |
