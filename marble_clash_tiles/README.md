# Marble Clash: arena tiles

Current cave arena design. Converter-ready images use 12-bit colour; `000` is transparent in overlays. For how each tile is built and how to draw it, read `docs/floor_docs.md`.

Edge blending (lava crust, wall glow, floor tint, charred corners) is done live by the FPGA, so it isn't in any tile image, only in `previews/`.

## Folders

- **`01_floor/`**: Floor tile: grey cobbled rock, 25 mixed and flipped blocks.
- **`02_lava/`**: Animated lava: 4 frames, stacked for one memory and also as single frames.
- **`03_puddle/`**: Water puddle overlay (drawn 4x), plus a view-only version on the floor.
- **`04_spike_walls/`**: Spike wall variants for the current map (joined where blocks touch), stacked and single, plus view-only versions on the floor.
- **`05_edge_walls/`**: Half-wall edge tiles (wall on the lava side), 16 variants stacked and single, plus view-only versions on the floor.
- **`previews/`**: Final arena (still and animated) with edge blending, and close-ups. For viewing only.
- **`source_sheets/`**: The original sprite sheets the tiles were built from.
- **`docs/`**: floor_docs.md: how every tile is built and how to implement it on the FPGA.

## Files for the PNG-to-COE converter

Load these into Block Memory Generator (single-port ROM, 12 bits wide, depth as listed).

| File | Size | Depth | What it is |
|---|---|---|---|
| `01_floor/floor_rock_80x80.png` | 80x80 | 6400 | Floor tile (converter). 25 rock blocks, mixed + flipped. |
| `02_lava/frames/lava_frame0_80x80.png` | 80x80 | 6400 | Lava frame 0 on its own (also the still-lava tile). |
| `02_lava/frames/lava_frame1_80x80.png` | 80x80 | 6400 | Lava frame 1 on its own. |
| `02_lava/frames/lava_frame2_80x80.png` | 80x80 | 6400 | Lava frame 2 on its own. |
| `02_lava/frames/lava_frame3_80x80.png` | 80x80 | 6400 | Lava frame 3 on its own. |
| `02_lava/lava_anim_stack_80x320.png` | 80x320 | 25600 | All 4 lava frames stacked (converter, one memory). |
| `03_puddle/overlay/puddle_20x20.png` | 20x20 | 400 | Puddle overlay (converter), drawn 4x; 000 = transparent. |
| `04_spike_walls/overlay/spike_v0_mask00_none_80x80.png` | 80x80 | 6400 | Spike wall variant 0, joined none. 000 = transparent. |
| `04_spike_walls/overlay/spike_v1_mask03_NE_80x80.png` | 80x80 | 6400 | Spike wall variant 1, joined NE. 000 = transparent. |
| `04_spike_walls/overlay/spike_v2_mask06_ES_80x80.png` | 80x80 | 6400 | Spike wall variant 2, joined ES. 000 = transparent. |
| `04_spike_walls/overlay/spike_v3_mask09_NW_80x80.png` | 80x80 | 6400 | Spike wall variant 3, joined NW. 000 = transparent. |
| `04_spike_walls/overlay/spike_v4_mask12_SW_80x80.png` | 80x80 | 6400 | Spike wall variant 4, joined SW. 000 = transparent. |
| `04_spike_walls/spike_walls_stack_80x400.png` | 80x400 | 32000 | All 5 spike-wall variants stacked (converter, one memory). |
| `05_edge_walls/edge_walls_stack_80x1280.png` | 80x1280 | 102400 | All 16 edge-wall variants stacked (converter, one memory). |
| `05_edge_walls/overlay/edge_v00_lavaN_connE_80x80.png` | 80x80 | 6400 | Edge wall variant 0: lava side N, wall continues E. 000 = transparent. |
| `05_edge_walls/overlay/edge_v01_lavaN_connEW_80x80.png` | 80x80 | 6400 | Edge wall variant 1: lava side N, wall continues EW. 000 = transparent. |
| `05_edge_walls/overlay/edge_v02_lavaN_connW_80x80.png` | 80x80 | 6400 | Edge wall variant 2: lava side N, wall continues W. 000 = transparent. |
| `05_edge_walls/overlay/edge_v03_lavaS_connE_80x80.png` | 80x80 | 6400 | Edge wall variant 3: lava side S, wall continues E. 000 = transparent. |
| `05_edge_walls/overlay/edge_v04_lavaS_connEW_80x80.png` | 80x80 | 6400 | Edge wall variant 4: lava side S, wall continues EW. 000 = transparent. |
| `05_edge_walls/overlay/edge_v05_lavaS_connW_80x80.png` | 80x80 | 6400 | Edge wall variant 5: lava side S, wall continues W. 000 = transparent. |
| `05_edge_walls/overlay/edge_v06_lavaW_connN_80x80.png` | 80x80 | 6400 | Edge wall variant 6: lava side W, wall continues N. 000 = transparent. |
| `05_edge_walls/overlay/edge_v07_lavaW_connNS_80x80.png` | 80x80 | 6400 | Edge wall variant 7: lava side W, wall continues NS. 000 = transparent. |
| `05_edge_walls/overlay/edge_v08_lavaW_connS_80x80.png` | 80x80 | 6400 | Edge wall variant 8: lava side W, wall continues S. 000 = transparent. |
| `05_edge_walls/overlay/edge_v09_lavaE_connN_80x80.png` | 80x80 | 6400 | Edge wall variant 9: lava side E, wall continues N. 000 = transparent. |
| `05_edge_walls/overlay/edge_v10_lavaE_connNS_80x80.png` | 80x80 | 6400 | Edge wall variant 10: lava side E, wall continues NS. 000 = transparent. |
| `05_edge_walls/overlay/edge_v11_lavaE_connS_80x80.png` | 80x80 | 6400 | Edge wall variant 11: lava side E, wall continues S. 000 = transparent. |
| `05_edge_walls/overlay/edge_v12_lavaNW_connES_80x80.png` | 80x80 | 6400 | Edge wall variant 12: lava side NW, wall continues ES. 000 = transparent. |
| `05_edge_walls/overlay/edge_v13_lavaNE_connSW_80x80.png` | 80x80 | 6400 | Edge wall variant 13: lava side NE, wall continues SW. 000 = transparent. |
| `05_edge_walls/overlay/edge_v14_lavaSW_connNE_80x80.png` | 80x80 | 6400 | Edge wall variant 14: lava side SW, wall continues NE. 000 = transparent. |
| `05_edge_walls/overlay/edge_v15_lavaSE_connNW_80x80.png` | 80x80 | 6400 | Edge wall variant 15: lava side SE, wall continues NW. 000 = transparent. |

**Use the stacked files** (`*_stack_*.png`) for one memory per asset, as the docs describe. The single images are the same content split up, in case you prefer separate memories.

## View-only files

These show overlays on the floor. Don't load them into the FPGA.

| File | What it is |
|---|---|
| `03_puddle/combined/floor_with_puddle_80x80.png` | View only: puddle on the floor. |
| `04_spike_walls/combined/floor_with_spike_v0_none_80x80.png` | View only: spike variant 0 on the floor. |
| `04_spike_walls/combined/floor_with_spike_v1_NE_80x80.png` | View only: spike variant 1 on the floor. |
| `04_spike_walls/combined/floor_with_spike_v2_ES_80x80.png` | View only: spike variant 2 on the floor. |
| `04_spike_walls/combined/floor_with_spike_v3_NW_80x80.png` | View only: spike variant 3 on the floor. |
| `04_spike_walls/combined/floor_with_spike_v4_SW_80x80.png` | View only: spike variant 4 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v00_lavaN_connE_80x80.png` | View only: edge wall variant 0 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v01_lavaN_connEW_80x80.png` | View only: edge wall variant 1 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v02_lavaN_connW_80x80.png` | View only: edge wall variant 2 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v03_lavaS_connE_80x80.png` | View only: edge wall variant 3 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v04_lavaS_connEW_80x80.png` | View only: edge wall variant 4 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v05_lavaS_connW_80x80.png` | View only: edge wall variant 5 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v06_lavaW_connN_80x80.png` | View only: edge wall variant 6 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v07_lavaW_connNS_80x80.png` | View only: edge wall variant 7 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v08_lavaW_connS_80x80.png` | View only: edge wall variant 8 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v09_lavaE_connN_80x80.png` | View only: edge wall variant 9 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v10_lavaE_connNS_80x80.png` | View only: edge wall variant 10 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v11_lavaE_connS_80x80.png` | View only: edge wall variant 11 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v12_lavaNW_connES_80x80.png` | View only: edge wall variant 12 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v13_lavaNE_connSW_80x80.png` | View only: edge wall variant 13 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v14_lavaSW_connNE_80x80.png` | View only: edge wall variant 14 on the floor. |
| `05_edge_walls/combined/floor_with_edge_v15_lavaSE_connNW_80x80.png` | View only: edge wall variant 15 on the floor. |
| `previews/*` | Arena and close-up previews. |

## Source sheets

| File | Used for |
|---|---|
| `source_sheets/rock_floor_sheet.png` | Floor |
| `source_sheets/lava_sheet.png` | Lava (4 animation frames) |
| `source_sheets/spike_sheet.png` | Spike walls |
| `source_sheets/wall_sheet.png` | Edge walls |

The puddle wasn't taken from a sheet; it was drawn for this project.
