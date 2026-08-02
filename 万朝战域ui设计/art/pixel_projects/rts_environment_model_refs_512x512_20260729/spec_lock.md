# Execution Lock

## canvas
- base_size: 512x512
- tree_sheet_size: 1536x1024
- tree_layout: 3 columns x 2 rows
- tree_view_order: front, right, rear, left, top, three-quarter isometric
- mountain_sheet_size: 1536x2048
- mountain_layout: 3 columns x 4 rows
- mountain_column_order: sharp_peak, long_ridge, rounded_cluster
- mountain_row_order: front, side, top, three-quarter isometric
- format: RGBA PNG
- alpha: binary only (0 or 255)

## palette
- name: Three Kingdoms Natural Terrain 48
- colors:
  - #17151A
  - #211C20
  - #2B2526
  - #332D2B
  - #3A3A38
  - #454640
  - #51534B
  - #5E6055
  - #6B6D60
  - #797A6C
  - #888779
  - #979487
  - #A7A295
  - #B7B0A1
  - #C6BDAA
  - #D5CBB7
  - #3A2A24
  - #4A3328
  - #5B3D2E
  - #6C4935
  - #7D563D
  - #906747
  - #A57955
  - #BA8E67
  - #2D1E1B
  - #3B261F
  - #4A2F24
  - #59382A
  - #684431
  - #795139
  - #8B6043
  - #A0714F
  - #1F2B22
  - #293729
  - #344632
  - #40553B
  - #4D6545
  - #5B7650
  - #6A875D
  - #7A986B
  - #8CAA79
  - #9DBC88
  - #AFCB98
  - #C2D7AA
  - #38443A
  - #536050
  - #707A64
  - #909879

## style
- tier: High-Res Pixel
- sub_style: outlined, cel-shaded, textured
- outline_color: "#17151A"
- shading: 3-tone hard-edged clusters with selective fourth-tone accents
- dithering: selective
- light_direction: top-left
- view: orthographic modeling reference multiview
- scale_consistency: strict within each object
- background_generation: flat solid #FF00FF chroma key
- final_background: transparent

## per_sprite_budget
- max_colors: 40

## assets
- characters: []
- tiles: []
- items: []
- ui: []
- effects: []
- backgrounds:
  - name: rts_ancient_pine_multiview
    size: 1536x1024
    cell_size: 512x512
    layout: 3 columns x 2 rows
    views: front, right, rear, left, top, three-quarter isometric
    colors: outline, wood, vegetation, moss accents
    animations: none
    alpha: transparent final background
    description: one mature ancient pine with thick trunk, root flare, layered asymmetric crown and consistent structure across six views
  - name: rts_ancient_pine_view_front
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_ancient_pine_view_right
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_ancient_pine_view_rear
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_ancient_pine_view_left
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_ancient_pine_view_top
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_ancient_pine_view_isometric
    size: 512x512
    colors: tree subset
    animations: none
  - name: rts_mountains_multiview
    size: 1536x2048
    cell_size: 512x512
    layout: 3 columns x 4 rows
    columns: sharp_peak, long_ridge, rounded_cluster
    rows: front, side, top, three-quarter isometric
    colors: outline, rock, earth, vegetation, moss accents
    animations: none
    alpha: transparent final background
    description: three distinct mountain masses with the same palette and four orthographic modeling views each
  - name: rts_mountain_sharp_peak_view_front
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_sharp_peak_view_side
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_sharp_peak_view_top
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_sharp_peak_view_isometric
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_long_ridge_view_front
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_long_ridge_view_side
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_long_ridge_view_top
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_long_ridge_view_isometric
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_rounded_cluster_view_front
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_rounded_cluster_view_side
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_rounded_cluster_view_top
    size: 512x512
    colors: mountain subset
    animations: none
  - name: rts_mountain_rounded_cluster_view_isometric
    size: 512x512
    colors: mountain subset
    animations: none

## forbidden
- Anti-aliasing
- Smooth gradient fills
- Partial opacity (1-254 alpha)
- Colors outside declared palette in final exports
- Sub-pixel rendering
- Blurred edges
- Cropped silhouette
- Text or labels
- UI frames
- Decorative background
- Ground plane
- Cast shadow
- Atmospheric perspective
- Inconsistent topology between views
