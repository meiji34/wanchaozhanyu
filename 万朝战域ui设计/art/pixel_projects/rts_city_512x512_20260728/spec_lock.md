# Execution Lock

## canvas
- base_size: 512x512
- tile_size: N/A
- format: RGBA PNG
- alpha: binary only (0 or 255)

## palette
- name: Three Kingdoms Fortress 48
- colors:
  - #17151A
  - #211C20
  - #2B2526
  - #332D2B
  - #403A36
  - #4C4540
  - #5A514A
  - #685E55
  - #776B5E
  - #897A6B
  - #9A8A79
  - #ADA08E
  - #3A2A24
  - #51372B
  - #684433
  - #7B523B
  - #906345
  - #A87854
  - #C09163
  - #D2AA78
  - #2D1E1B
  - #442921
  - #5C3527
  - #75442F
  - #8E5738
  - #A96D45
  - #4A1F25
  - #67252B
  - #842C30
  - #A03937
  - #BC4A40
  - #D3634D
  - #5B4727
  - #746037
  - #8D7947
  - #AA955A
  - #C7B370
  - #E2CF8A
  - #263B3A
  - #31504C
  - #3F655E
  - #547B6E
  - #6F9381
  - #273624
  - #35482D
  - #465B38
  - #5A7046
  - #72885B

## style
- tier: High-Res Pixel
- sub_style: outlined, cel-shaded, textured
- outline_color: "#17151A"
- shading: 3-tone hard-edged clusters
- dithering: selective
- light_direction: top-left
- view: three-quarter isometric top-down

## per_sprite_budget
- max_colors: 48

## assets
- characters: []
- tiles: []
- items: []
- ui: []
- effects: []
- backgrounds:
  - name: rts_city
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
    description: fortified Three Kingdoms RTS city with outer walls, four corner towers, gatehouse, central palace, barracks, courtyards, roads and command flags
  - name: rts_city_multiview
    size: 1536x1024
    cell_size: 512x512
    layout: 3 columns x 2 rows
    view_order: front, right, rear, left, top, three-quarter isometric
    colors: all
    animations: none
    alpha: transparent background
    description: orthographic modeling turnaround sheet matching rts_city structure and proportions
  - name: rts_city_view_front
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
  - name: rts_city_view_right
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
  - name: rts_city_view_rear
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
  - name: rts_city_view_left
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
  - name: rts_city_view_top
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background
  - name: rts_city_view_isometric
    size: 512x512
    colors: all
    animations: none
    alpha: transparent background

## forbidden
- Anti-aliasing
- Smooth gradient fills
- Partial opacity (1-254 alpha)
- Colors outside declared palette
- Sub-pixel rendering
- Blurred edges
- Text or labels
- UI frames
- Modern objects
- Cropped silhouette
