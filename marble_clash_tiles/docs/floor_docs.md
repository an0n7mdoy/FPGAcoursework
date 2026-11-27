# Marble Clash: arena tiles

This document describes the current cave arena design: how every tile is built, and how to draw it on the FPGA. File paths refer to the folders in `marble_clash_tiles.zip`.

## Contents
1. [Overview](#1-overview)
2. [Asset list](#2-asset-list)
3. [Floor](#3-floor)
4. [Lava](#4-lava)
5. [Water puddle](#5-water-puddle)
6. [Spike walls](#6-spike-walls)
7. [Edge walls](#7-edge-walls)
8. [Edge blending: crust, glow and charred corners](#8-edge-blending-crust-glow-and-charred-corners)
9. [Flipping whole tiles](#9-flipping-whole-tiles)
10. [Tile map](#10-tile-map)
11. [Drawing pipeline](#11-drawing-pipeline)
12. [PNG to COE converter and memory budget](#12-png-to-coe-converter-and-memory-budget)
13. [Still to decide](#13-still-to-decide)

---

## 1. Overview

- **Screen:** 1440×900. A 100-pixel information bar sits at the top; the arena fills the remaining 1440×800.
- **Grid:** the arena is 18×10 squares of 80×80 pixels. Columns (0–17) and rows (0–9) are counted from 0.
- **Arena coordinates:** measured from the top-left of the arena, so arena `ay = screen y − 100`. All coordinates below are arena coordinates unless stated.
- **Layers:** every square has a base layer (**floor** or **lava**) and may have one **overlay** on top (a **puddle**, a **spike wall** or an **edge wall**). After that, the FPGA applies **edge blending** colour changes near the lava, then draws the marbles on top.

The base layers hide repetition in two ways:
1. **Inside each tile**, the 80×80 image is a 5×5 grid of 16×16 blocks, each a randomly picked variant, flipped at random. This is done once, when the PNG is made.
2. **Across the arena**, whole floor and lava tiles are mirrored depending on their column and row ([section 9](#9-flipping-whole-tiles)). This is done live by the FPGA, at no memory cost.

Walls are never flipped, because their shapes must point the right way. Instead, each wall square uses a pre-built **variant** chosen for its position, and the variant number is stored in the tile map.

---

## 2. Asset list

Converter-ready images are the ones to load into Block Memory. Files in `combined/` folders show an overlay on the floor for viewing only; don't load them into the FPGA.

| Asset | Converter file | Size | Depth | Notes |
|---|---|---|---|---|
| Floor | `01_floor/floor_rock_80x80.png` | 80×80 | 6400 | 7 colours, no `000` |
| Lava (animated) | `02_lava/lava_anim_stack_80x320.png` | 80×320 | 25600 | 4 frames stacked; 4 colours, no `000` |
| Puddle | `03_puddle/overlay/puddle_20x20.png` | 20×20 | 400 | Drawn 4× size; `000` = transparent |
| Spike walls | `04_spike_walls/spike_walls_stack_80x400.png` | 80×400 | 32000 | 5 variants stacked; `000` = transparent |
| Edge walls | `05_edge_walls/edge_walls_stack_80x1280.png` | 80×1280 | 102400 | 16 variants stacked; `000` = transparent |

Each stacked file also has its individual images saved separately in the same folder (`frames/` or `overlay/`), in case you'd rather use one memory per image. For still lava, use `02_lava/frames/lava_frame0_80x80.png` (depth 6400) instead of the stack.

All colours are 12-bit (4 bits each for red, green and blue), written below as three hex digits, e.g. `F70`.

---

## 3. Floor

### What it looks like
Grey cobbled rock with a few specks of moss. It covers every square inside the lava ring.

### Source
`source_sheets/rock_floor_sheet.png`. The sheet is a grid of 16×16 blocks with a 2-pixel transparent gap, so block (column *c*, row *r*) starts at pixel (18*c*, 18*r*). Fourteen plain rock blocks are used:

```
(6,17) (7,17)
(6,18) (7,18) (8,18)
(6,19) (7,19) (8,19)
(6,20) (7,20) (8,20)
(6,21) (7,21) (8,21)
```

### How the tile is built
The 80×80 tile is a 5×5 grid of 16×16 blocks at their original size. For each of the 25 positions:

1. **Pick a variant** at random from the 14 blocks.
2. **Remove the corner moss.** Each block has moss specks in its corners, meant to join up with moss tiles. Side by side they form a regular grid of green dots, so any moss pixel (red and blue differ by more than 20) is replaced with a neighbouring grey. The blocks at positions (3,0) and (4,0) keep their moss, so a little green still shows.
3. **Flip at random:** left-to-right with a 50% chance, and separately top-to-bottom with a 50% chance.
4. **Place it** at (16 × block column, 16 × block row).

The random seed is fixed (5), so the same tile comes out every time. Colours are reduced to 12-bit by keeping the top 4 bits of each channel, giving 7 colours: `331 444 666 783 888 AAA CCC`.

### How to implement it
- **Memory:** one ROM, depth 6400, loaded from `01_floor/floor_rock_80x80.png`.
- **Address:** for a pixel at position (`u`, `v`) inside its square (0–79 each), with the square's flips from [section 9](#9-flipping-whole-tiles):
  ```
  u' = flip_x ? 79 - u : u
  v' = flip_y ? 79 - v : v
  addr_floor = v' * 80 + u'
  ```
- **Used on:** every square whose code is floor, puddle, spike wall or edge wall (the overlays sit on top of it).
- **Edge blending:** floor pixels near the lava are tinted ([section 8](#8-edge-blending-crust-glow-and-charred-corners)).

---

## 4. Lava

### What it looks like
Bubbling red-orange-yellow lava filling the outer ring of squares (row 0, row 9, column 0 and column 17). It animates through 4 frames.

### Source
`source_sheets/lava_sheet.png`, the same 16×16 grid layout. Only the 15 fully filled blocks are used:

```
(1,1) (2,1) (3,1)
(6,1) (7,1) (8,1)   (6,2) (7,2) (8,2)
(10,0) (11,0) (10,1) (11,1) (10,2) (11,2)
```

These 15 positions hold only **3 different patterns**, each repeated 5 times:

| Pattern | Positions |
|---|---|
| A | (1,1) (6,1) (6,2) (10,0) (11,0) |
| B | (2,1) (7,1) (7,2) (10,1) (11,1) |
| C | (3,1) (8,1) (8,2) (10,2) (11,2) |

The sheet repeats its layout four times, in rows 0–4, 5–9, 10–14 and 15–19. These are the **four animation frames**: the filled blocks are in the same places in every group, but the flames are drawn differently.

### How the tiles are built
1. **Choose a layout once:** for each of the 25 positions in a 5×5 grid, pick one of the 15 block positions at random and a random flip (left-to-right 50%, top-to-bottom 50%). The seed is 5.
2. **Build 4 frames from that one layout.** Frame *k* takes each block from rows `r + 5k` instead of `r`. Every frame uses the same positions and flips, so only the flames change and the lava bubbles in place.
3. **Reduce to 12-bit.** The lava uses 4 colours: `B31` (dark red), `F30` (red), `F70` (orange), `FD0` (yellow).
4. **Stack the frames** vertically into one 80×320 image: frame 0 in rows 0–79, frame 1 in 80–159, frame 2 in 160–239 and frame 3 in 240–319.

### How to implement it
- **Memory:** one ROM, depth 25600, loaded from `02_lava/lava_anim_stack_80x320.png`.
- **Address:** with the square's flips (as for the floor) and the current frame `f` (0–3):
  ```
  addr_lava = (v' + 80*f) * 80 + u'
  ```
- **Frame counter:** keep a 2-bit `f` and a counter of screen refreshes, and advance them once per refresh at vsync. Because `f` only changes at vsync, it never changes partway down the screen, so there is no tearing. All lava squares show the same frame at the same time.
  ```verilog
  reg [1:0] f = 0;
  reg [4:0] refresh_cnt = 0;
  // vsync_start: a 1-clock pulse at the start of each vsync, in the pixclk domain
  always @(posedge pixclk)
      if (vsync_start) begin
          if (refresh_cnt == N - 1) begin
              refresh_cnt <= 0;
              f <= f + 1;            // wraps 3 -> 0 by itself
          end else
              refresh_cnt <= refresh_cnt + 1;
      end
  ```

  | N | Frame changes per second | Feel |
  |---|---|---|
  | 6 | 10 | Fast bubbling |
  | 12 | 5 | Medium (as in the preview GIF) |
  | 20 | 3 | Slow and calm |

- **Still lava instead:** use `02_lava/frames/lava_frame0_80x80.png` (depth 6400) with `addr_lava = v' * 80 + u'`, and leave out the frame counter.
- **Edge blending:** lava near the arena darkens into a crust ([section 8](#8-edge-blending-crust-glow-and-charred-corners)).

---

## 5. Water puddle

### What it looks like
An irregular blue pool with a darker edge, a ripple and a small shine, sitting on the floor. The floor shows around it.

### Source
Drawn for this project, not taken from a sheet. It is a 20×20 image whose background is `000` (transparent). Its colours are `258` (edge), `269`, `37A`, `48B` and `9CF` (shine).

### How to implement it
- **Memory:** one ROM, depth 400, loaded from `03_puddle/overlay/puddle_20x20.png`.
- **Drawn 4× larger** to fill the 80×80 square, so divide the position by 4 (a 2-bit shift). It is not flipped:
  ```
  addr_puddle = (v >> 2) * 20 + (u >> 2)
  ```
- **Layering:** on puddle squares, if the puddle pixel isn't `000`, it replaces the floor pixel.
- `03_puddle/combined/` shows it on the floor, for viewing only.

---

## 6. Spike walls

### What it looks like
Dark rock blocks inside the arena, with spikes pointing outwards on every exposed side. The spike tips glow faintly red. Blocks that touch merge into one shape, for example the 2×2 centre pillar.

### Source
`source_sheets/spike_sheet.png`, the same 16×16 grid layout. It is a set of pieces designed to join up:

| Piece | Sheet positions (column, row) |
|---|---|
| Top-left corner (spike points up-left) | (0,3) (2,3) (4,3) |
| Top-right corner | (1,3) (3,3) (5,3) |
| Bottom-left corner | (0,4) (2,4) (4,4) |
| Bottom-right corner | (1,4) (3,4) (5,4) |
| Top edge (spike points up) | (1,0) (2,0) (3,0) |
| Bottom edge (spike points down) | (1,2) (2,2) (3,2) |
| Left edge (spike points left) | (0,0) (0,1) (0,2) |
| Right edge (spike points right) | (4,0) (4,1) (4,2) |
| Middle (no spikes) | (1,1) (2,1) (3,1) (6,1) (7,1) (8,1) (6,2) (7,2) (8,2) (10,0) (11,0) (10,1) (11,1) (10,2) (11,2) |

### How one block is built
A 5×5 grid of 16×16 pieces at their original size. Each position takes a piece that suits where it sits:

| Position in the 5×5 grid | Piece | Allowed random flips |
|---|---|---|
| Corners | Matching corner | None |
| Top / bottom edge (middle 3) | Top / bottom edge | Left-to-right only |
| Left / right edge (middle 3) | Left / right edge | Top-to-bottom only |
| Middle 3×3 | Any middle piece | Both |

The variant and flip are picked at random (seed 5), but only flips that keep the spikes pointing outwards are allowed.

### Red glow on the tips
| Pixels | Colour |
|---|---|
| White tip pixels in the sheet | `FCB` (pale pink) |
| Tan tip pixels in the sheet | `D86` (copper) |
| Transparent pixels within 1 px of a tip | `B22` (red) |
| Transparent pixels 2 px from a tip | `711` (dark red) |

The VGA output can't blend colours, so the glow is made of solid pixels painted next to each tip, 2 px wide. The rock colours are `111 332 333 444 666`.

### Joining neighbouring blocks
Each spike square looks at its four neighbours. On a side that touches another spike wall, the border pieces are replaced by middle pieces, so that side has no spikes and no glow. A corner position becomes an edge piece if one of its two sides is joined, and a middle piece if both are. Diagonal neighbours are ignored.

The joined sides form a 4-bit **mask**: N = 1, E = 2, S = 4, W = 8. Every variant uses the same random choices, so joined blocks line up seamlessly. Only the masks used by the map are built. The current map needs 5:

| Variant | Mask | Joined sides | Squares (col, row) |
|---|---|---|---|
| 0 | 0 | none | (3,2) (14,2) (5,7) (12,7) |
| 1 | 3 | N, E | (8,6) |
| 2 | 6 | E, S | (8,5) |
| 3 | 9 | N, W | (9,6) |
| 4 | 12 | S, W | (9,5) |

The variants are stacked vertically in variant order in `04_spike_walls/spike_walls_stack_80x400.png`: variant 0 in rows 0–79, variant 1 in 80–159, and so on.

### How to implement it
- **Memory:** one ROM, depth 32000, loaded from the stack.
- **Address:** drawn at full size and never flipped. `w` is the square's spike variant (0–4) from the tile map:
  ```
  addr_spike = (v + 80*w) * 80 + u
  ```
- **No neighbour checks in hardware:** the variant number is worked out in advance and stored in the tile map.
- **Layering:** on spike squares, if the spike pixel isn't `000`, it replaces the floor pixel.
- **If the map changes,** regenerate the variants, the stack and the variant numbers together.

---

## 7. Edge walls

### What it looks like
A low stone wall running along the lava side of some outer floor squares, made of rounded stone links. It has L-shaped corners and round end caps where it meets a gap. Gaps between wall sections let marbles roll into the lava. The wall band is 25 px thick, leaving 55 px of floor in each edge square.

### Source
`source_sheets/wall_sheet.png`, the same 16×16 grid layout. The artwork is drawn at 2×: every art pixel is a 2×2 block, so each piece is really an **8×8 drawing**. The pieces join up like pipe sections, and each one is open on some of its four sides:

| Open sides | Sheet positions | Used for |
|---|---|---|
| E, W | (6,4) (7,4) (8,4) | Horizontal straight |
| N, S | (5,0) (5,1) (5,2) | Vertical straight |
| E only | (9,0) (9,1) (9,2) | Round end cap, wall continues right |
| W only | (12,0) (12,1) (12,2) | Round end cap, wall continues left |
| S only | (6,0) (7,0) (8,0) | Round end cap, wall continues down |
| N only | (6,3) (7,3) (8,3) | Round end cap, wall continues up |
| E, S | (0,3) (2,3) (4,3) | Top-left corner |
| S, W | (1,3) (3,3) (5,3) | Top-right corner |
| N, E | (0,4) (2,4) (4,4) | Bottom-left corner |
| N, W | (1,4) (3,4) (5,4) | Bottom-right corner |

The first variant of each type is used. The sheet also has T-junctions, crosses and a single round block; the current layout doesn't need them.

### Layout
Edge walls sit only on the outer ring of floor squares (row 1, row 8, column 1 and column 16), on the side facing the lava. All four corners are walled. The other spike blocks on the outer ring were removed.

```
#  = edge wall      _ = gap (marble can fall into the lava)      L = lava
     col: 0         1
          012345678901234567
row 0:    LLLLLLLLLLLLLLLLLL
row 1:    L###__######__###L
row 2:    L#..............#L
row 3:    L#..............#L
row 4:    L_.............._L   <- spawn row
row 5:    L_.............._L
row 6:    L#..............#L
row 7:    L#..............#L
row 8:    L##__###__###__##L
row 9:    LLLLLLLLLLLLLLLLLL
```

### How the tiles are built
1. **Half-size pieces:** each 8×8 art piece is drawn with 5×5-pixel art pixels, so a piece is 40×40 px and an 80×80 edge square holds **2 pieces** along the wall. Corner squares hold an L of 3.
2. **40 px slots:** the wall is laid out on a grid of 40 px slots. Every wall slot picks the piece whose open sides match its neighbouring wall slots: straight between walls, an end cap next to a gap, and a corner piece at a corner.
3. **Pushed towards the lava:** in each piece, the horizontal band is art rows 2–6 and the vertical band is art columns 1–5. Each slot is shifted so the outer edge of the band touches the lava: top wall up 10 px, bottom wall down 5 px, left wall left 5 px, right wall right 10 px. Corner slots get both shifts.
4. **Breaks bridged:** at the corners, the shift leaves a small break (5 or 10 px) between the corner piece and its neighbours. It is filled with a slice from the middle of the straight piece.
5. **Clipped to the square:** anything pushed past the square's edge, such as the outer rim of an end cap or corner, is cut off. Colours are reduced to 12-bit, giving 5 colours: `222 333 444 666 888`. Everything else is `000`.

This gives 16 different edge squares. Squares of the same type are identical, so each type is stored once:

| Variant | Lava side | Wall continues | Squares (col, row) |
|---|---|---|---|
| 0 | N (top) | E | (6,1) (14,1) |
| 1 | N | E, W | (2,1) (7,1) (8,1) (9,1) (10,1) (15,1) |
| 2 | N | W | (3,1) (11,1) |
| 3 | S (bottom) | E | (5,8) (10,8) (15,8) |
| 4 | S | E, W | (6,8) (11,8) |
| 5 | S | W | (2,8) (7,8) (12,8) |
| 6 | W (left) | N | (1,3) |
| 7 | W | N, S | (1,2) (1,7) |
| 8 | W | S | (1,6) |
| 9 | E (right) | N | (16,3) |
| 10 | E | N, S | (16,2) (16,7) |
| 11 | E | S | (16,6) |
| 12 | N + W (top-left corner) | E, S | (1,1) |
| 13 | N + E (top-right corner) | S, W | (16,1) |
| 14 | S + W (bottom-left corner) | N, E | (1,8) |
| 15 | S + E (bottom-right corner) | N, W | (16,8) |

They are stacked in this order in `05_edge_walls/edge_walls_stack_80x1280.png`.

### How to implement it
- **Memory:** one ROM, depth 102400, loaded from the stack.
- **Address:** drawn at full size and never flipped. `e` is the square's edge variant (0–15) from the tile map:
  ```
  addr_edge = (v + 80*e) * 80 + u
  ```
- **Layering:** on edge-wall squares, if the edge pixel isn't `000`, it replaces the floor pixel.
- **Collision:** the wall's inner face is 25 px in from the lava side of the square. Your team is handling the physics: the marble can lose a life above a set speed, and bounces off at low speed.
- **If the layout changes,** regenerate the tiles, the stack and the variant numbers together.
- **Saving memory:** this stack is the largest memory in the design (about 35–40 block RAMs). A much smaller method is to store only the 8×8 art pieces (16 pieces × 64 entries = 1,024 entries, under one block RAM), then draw each 40 px slot from a small table of piece number and shift, dividing `u` and `v` by 5. The corner bridges make that logic fiddlier, so start with the stack and only switch if memory runs short.

---

## 8. Edge blending: crust, glow and charred corners

### What it looks like
The lava cools into a dark crust where it meets the arena, the stone glows red-orange at its base, and the four arena corners are darker: charred wall and a deeper crust. This is done entirely by the FPGA as colour changes, with **no extra memory and no extra images**.

### How it works
For each pixel, the FPGA knows how far it is from the arena edge, the rectangle `X0 = 80` to `X1 = 1359` and `Y0 = 80` to `Y1 = 719` in arena coordinates. That is the inner edge of the lava ring. Depending on that distance and on which layer the pixel came from, its colour is swapped using small lookup tables. A checkerboard bit, `chk = x[0] ^ y[0]`, applies the outermost step to every other pixel, so each effect fades out instead of ending in a hard line.

**Lava crust** (lava pixels):
```
dx = max(X0 - ax, ax - X1, 0)      dy = max(Y0 - ay, ay - Y1, 0)
d  = max(dx, dy)                  // 1 = touching the arena
steps = d<=3 ? 3 : d<=7 ? 2 : d<=12 ? 1 : (d<=16 ? chk : 0)
if (dx > 0 && dy > 0) begin       // diagonally off a corner: darker tip
    m = dx + dy
    steps += m<=14 ? 2 : m<=28 ? 1 : (m<=36 ? chk : 0)
end
```
Each step makes the colour one step cooler: `FD0 → F70 → F30 → B31 → 711 → 411 → 311`.

**Wall glow** (edge-wall overlay pixels) and **floor tint** (floor pixels, which only get near the lava at the gaps):
```
ex = min(ax - X0, X1 - ax)        ey = min(ay - Y0, Y1 - ay)
d  = min(ex, ey)                  // 0 = touching the lava
wall:  level = d<=3 ? 3 : d<=7 ? 2 : d<=11 ? 1 : (d<=14 ? chk : 0)
floor: level = d<=2 ? 3 : d<=5 ? 2 : d<=9  ? 1 : (d<=12 ? chk : 0)
```

| Colour | Level 1 | Level 2 | Level 3 (hottest) |
|---|---|---|---|
| `222` | `322` | `611` | `A21` |
| `333` | `533` | `822` | `C32` |
| `444` | `643` | `A42` | `E52` |
| `666` | `865` | `C63` | `F74` |
| `888` | `A86` | `E84` | `FA6` |
| `331` (floor) | `431` | `631` | `A21` |
| `783` (floor) | `873` | `A62` | `D52` |
| `AAA` (floor) | `CA9` | `EA7` | `FB7` |
| `CCC` (floor) | `DCB` | `EB9` | `FC9` |

**Charred wall corners** (edge-wall pixels near one of the four arena corners). These replace the glow:
```
m = ex + ey
if (m <= 30) charred = m<=8 ? 2 : m<=18 ? 1 : chk   // 0 = use the glow instead
```

| Colour | Charred 1 | Charred 2 (darkest) |
|---|---|---|
| `222` | `211` | `111` |
| `333` | `322` | `211` |
| `444` | `433` | `322` |
| `666` | `644` | `433` |
| `888` | `854` | `543` |

### How to implement it
- **Where:** after the layering step and before the marbles, so marbles are never tinted. It needs to know which layer each pixel came from: lava base, edge-wall overlay, or floor base with no overlay pixel.
- **Distances:** `dx`, `dy`, `ex` and `ey` are subtract-and-compare operations on the arena coordinates. The edges are constants, so this is small.
- **Tables:** the colour swaps are small `case` statements: the cooling chain for lava, one table with 9 colours × 3 levels for wall and floor, and one with 5 colours × 2 levels for the charred corners.
- **Cost:** no memory. A few dozen LUTs, and possibly one extra pipeline stage (if so, delay hsync, vsync and blanking by one more cycle).
- **Tuning:** every threshold above can be changed freely without touching any image.
- **Previews:** `previews/arena_final.png`, `previews/arena_final_animated.gif` and the close-ups show the result.

---

## 9. Flipping whole tiles

To stop the floor and lava visibly repeating every 80 px, the FPGA mirrors some whole squares based on their column `col` and row `row`:

```verilog
wire flip_x = col[0] ^ row[1] ^ col[2];   // mirror left-to-right
wire flip_y = row[0] ^ col[1] ^ row[2];   // mirror top-to-bottom
```

These XOR combinations give a mix of all four orientations with no obvious pattern, for a few logic gates and no memory. The same rule is used for floor and lava. Overlays (puddle, spike walls, edge walls) are **never** flipped.

---

## 10. Tile map

The tile map says what is in each of the 180 squares, indexed as `row * 18 + col`. Store it as a constant array in Verilog (a `case` statement or an initialised `reg` array), not block RAM, so it can be read in the same clock cycle. Each square needs a 3-bit **code** and a 4-bit **variant**:

| Code | Meaning | Base | Overlay | Variant |
|---|---|---|---|---|
| 0 | Floor | floor | none | – |
| 1 | Lava | lava | none | – |
| 2 | Puddle | floor | puddle | – |
| 3 | Spike wall | floor | spike wall | 0–4 |
| 4 | Edge wall | floor | edge wall | 0–15 |

**Map** (`L` lava, `.` floor, `W` puddle, `X` spike wall, `#` edge wall):
```
     col: 0         1
          012345678901234567
row 0:    LLLLLLLLLLLLLLLLLL
row 1:    L###..######..###L
row 2:    L#.X..W....W..X.#L
row 3:    L#.....W..W.....#L
row 4:    L................L   <- spawns at (4,4) and (13,4)
row 5:    L.......XX.......L
row 6:    L#W.....XX.....W#L
row 7:    L#.W.X......X.W.#L
row 8:    L##..###..###..##L
row 9:    LLLLLLLLLLLLLLLLLL
```

**Spike wall variants** (`.` = not a spike wall):
```
     col: 0         1
          012345678901234567
row 2:    ...0..........0...
row 5:    ........24........
row 6:    ........13........
row 7:    .....0......0.....
```

**Edge wall variants** (hex digit 0–F, `.` = not an edge wall):
```
     col: 0         1
          012345678901234567
row 1:    .C12..011112..01D.
row 2:    .7..............A.
row 3:    .6..............9.
row 6:    .8..............B.
row 7:    .7..............A.
row 8:    .E5..345..345..3F.
```

The map is mirror-symmetric left to right. The spawn squares are (col 4, row 4) and (col 13, row 4); their centres are at arena (360, 360) and (1080, 360), which is screen y = 460.

The game logic uses the same map: falling into lava, spike walls, edge walls and puddles.

---

## 11. Drawing pipeline

All of this runs in the pixel clock domain (`pixclk`, the clock driving the VGA module). The block RAMs should also be clocked by `pixclk`.

**Step 1: position.** For screen pixel (x, y) with y ≥ 100: `ax = x`, `ay = y − 100`. Then:
```
col = ax / 80     row = ay / 80      // which square
u   = ax % 80     v   = ay % 80      // position inside the square (0-79)
```
Don't divide by 80 in hardware. Keep counters instead: `u` counts up every pixel and wraps at 79, incrementing `col`; both reset at the start of each line. `v` counts up at the end of each arena line and wraps at 79, incrementing `row`; both reset when y reaches 100.

**Step 2: look up the square** in the tile map (code and variant) and work out `flip_x` and `flip_y`.

**Step 3: memory addresses.**

| Memory | Address |
|---|---|
| Floor | `v' * 80 + u'` |
| Lava | `(v' + 80*f) * 80 + u'` |
| Puddle | `(v >> 2) * 20 + (u >> 2)` |
| Spike walls | `(v + 80*w) * 80 + u` |
| Edge walls | `(v + 80*e) * 80 + u` |

Here `u'` and `v'` are the flipped positions, `f` is the lava frame, `w` is the spike variant and `e` is the edge variant. Multiplying by a constant doesn't need a multiplier:
- `× 80` = `(n << 6) + (n << 4)`
- `× 20` = `(n << 4) + (n << 2)`

**Step 4: layering.**
```
base    = (code == LAVA) ? lava_px : floor_px
overlay = (code == PUDDLE) ? puddle_px
        : (code == SPIKE)  ? spike_px
        : (code == EDGE)   ? edge_px
        : 12'h000
colour  = (overlay != 12'h000) ? overlay : base
```

**Step 5: edge blending** ([section 8](#8-edge-blending-crust-glow-and-charred-corners)), using which layer `colour` came from.

**Step 6: marbles,** then the information bar when y < 100.

**Memory delay:** block RAM returns data 1–2 clock cycles after the address is given, depending on whether the Block Memory Generator's output register is enabled. Use the same setting for every memory, and delay everything else that travels with the pixel by the same number of cycles through a shift register: the tile code, the edge-blend distances, the marble pixels, hsync, vsync and blanking. Otherwise the picture shifts sideways relative to the sync pulses, or the layers drift out of line.

---

## 12. PNG to COE converter and memory budget

### Converter steps
1. Drop the PNG onto the converter page.
2. Set the size to the image's width and height (see the asset list).
3. Check the preview, then save the `.coe` file.
4. In Vivado's **Block Memory Generator**, make a single-port ROM, 12 bits wide, with depth = width × height, and load the `.coe` file.
5. If the image or its size changes, regenerate the `.coe` and the Block Memory IP.

The converter treats `000` as transparent. That's why the floor and lava contain no `000` pixels, and every overlay uses `000` for its background.

**Assumptions to check:** the address formulas assume the converter writes pixels row by row, left to right, from the top-left, and that each entry is 12 bits (4 each for red, green and blue).

### Memory budget
The Nexys4 DDR's Artix-7 (XC7A100T) has 135 block RAMs of 36 Kb each. Vivado splits memories into fixed shapes, so real usage is above the raw bit count. Check the utilisation report after implementation.

| Memory | Depth × width | Bits | Expected block RAMs |
|---|---|---|---|
| Floor | 6400 × 12 | 76,800 | about 3 |
| Lava (animated) | 25600 × 12 | 307,200 | about 9–12 |
| Puddle | 400 × 12 | 4,800 | 1 (or half) |
| Spike walls | 32000 × 12 | 384,000 | about 11–12 |
| Edge walls | 102400 × 12 | 1,228,800 | about 35–40 |
| **Total** | | | **about 59–68 of 135** |

**If memory gets tight,** the biggest savings are:
1. **Edge walls:** store the 8×8 art pieces instead of whole squares, saving about 35 block RAMs ([section 7](#7-edge-walls)).
2. **Lava:** store only the 3 patterns per frame (4 × 3 × 256 = 3,072 entries) plus a table of pattern and flip for each of the 25 block positions, saving about 9 block RAMs.
3. **Still lava** instead of animated, saving about 7 block RAMs.

---

## 13. Still to decide
- What a puddle does to a marble.
- The speed above which hitting a spike wall or edge wall costs a life (the team is handling the physics).
