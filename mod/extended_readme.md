# Ultimate Terrain Generator - extended guide

The short guide is the mod description (`readme.md`). This file explains how the tool works, what every setting
does, what the Report means, and the limits and their reasons.

## 1. How a map is made
The tool works in the map editor, in Lua, on the whole map, in this order:

1. **Shape.** The map type lays out sea, coast and uplands (bays, peninsulas, a mountain belt, a plateau...). The
   seed picks one of eight orientations, so the sea is not always on the same side.
2. **Drainage.** Water is routed downhill over the whole map to the sea or the map edge. Where enough land drains
   into a line, there is a river. Small leaf streams are dropped; rivers grow wider downstream and join.
3. **Rivers.** Courses are smoothed and given irregular meanders (no repeating wiggles). Ship rivers are made
   120-180 m wide and 5 m deep all the way to the sea; other rivers stay 18-58 m wide, so they are easy to bridge.
   Oxbow lakes are left beside the tightest bends.
4. **Landform.** Valleys are cut around every river: a flat floodplain (+1 to +3 m) wide enough for the meanders,
   then valley sides rising into the hills. Lakes fill natural basins on the rivers. Mountain passes (Mountain Range)
   are winding valleys graded for railways. Hill country covers part of the land (more at higher Relief).
5. **Detail and erosion.** The map is refined to the game's 4 m grid. Hills and mountains get surface detail and an
   erosion texture: spurs and gullies running straight down the slopes, deeper where the slope is steeper. Flat land
   (floodplains, pass floors, beaches) gets none, so it stays buildable.
6. **Report.** The finished heights are measured (slopes, heights, rivers, ship rivers, lakes, passes).
7. **Preview / Apply.** The tool's own terrain pass (built from the game's official terrain logic for the climate)
   keeps these heights exactly and adds biomes, forests, rock, snow, river trees and the map data that towns and
   industries use. The preview shows the result coloured by biome; the trees appear on the map after Apply.

**Why the map editor:** only there can a mod write a whole heightmap and preview it in its own window, and run the
preview only when you ask for it.

**Why rivers sit at sea level:** the game has one water level for the whole map (0 m). Every river surface, lake
and sea is at 0 m, so rivers live in lowland valleys and lakes are basins dug below 0 m. There are no lakes up in
the hills and no waterfalls; the tool works with that rule instead of against it.

## 2. Settings tab
**Generator** (top of the tab): "Ultimate Terrain Generator (this mod)" or any terrain generator of the map's climate
that the game lists in its own generator window (the game's and other mods'). For another generator, its own settings
replace the ones below, its preview generates the whole map, the Terrain parameters tab is
hidden, and the Report shows land and slope numbers of the finished preview (rivers, lakes and passes are counted only
for this mod's maps). Seed, Keep towns / Keep industries, Apply and Undo work the same for every generator.

| Setting | Choices | What it does |
|---|---|---|
| Map type | ten types (list in readme.md) | The overall layout; the line under it describes the chosen type |
| Relief | Gentle, Moderate, Hilly, Rugged, Mountainous | How high and steep the land is. The highest 1 % of the land reaches about 140 / 210 / 280 / 350 / 420 m (times the map type's own factor); hill country covers 50-60 % of the land; mountain passes are graded to 2.5 / 3.25 / 4 / 5 / 6 %. Gentle suits most networks; Mountainous makes hard maps on purpose. Snow starts at about 330 m: Rugged and Mountainous reach it on most map types. **For an alpine region like the game's mountains:** Mountain Range with Passes at Hilly or higher (peaks about 600-950 m) |
| Water | Dry, Normal, Wet | How many rivers and lakes (Wet: smaller areas are enough to start a river) |
| Ship rivers | Map type default, None, One, Several | How many rivers become ship rivers (Several = up to 3, if the map has rivers big enough). Defaults: One on Great River Valley, Rolling Plains and Coastal Region; Several on Delta Lowlands; None on the others. A ship river needs a large river: if the map has none, the Report says so |
| Side (label per map type) | Random, North, East, South, West | Which map edge gets the map type's main feature. **River comes from** (Great River Valley, Rolling Plains): where the big river enters; the sea or the outflow lies opposite. **Sea side** (Delta Lowlands, Mountain Range, Large Bays, Peninsulas, Coastal Region, Highland Plateau): the edge with the sea; the mountain range runs parallel to it. **Rivers flow towards** (Lake District): where the rivers leave the map. Island Chain has none. Random: the seed decides, exactly as before |
| Seed | any text | Same settings + same seed = the same map. New seed picks a random one |
| When applying: Keep towns, Keep industries | ticked / not ticked | As in the game's own generator window: unless kept, towns and then industries (with their roads) are removed before the new terrain goes in |

The window also shows the editor map's size (set when you create the map in the editor) and notes when the map is
small or the climate is not finished yet.

## 3. Terrain parameters tab
Each slider multiplies a designed value: 100 % = as designed for the map type and Relief, 0 % = none, up to 200 %
(Lakes up to 300 %). Changes apply at the next Preview.

| Slider | What it changes |
|---|---|
| Overall height | The height target of the whole map (hills and mountains) |
| Hill country | How much of the land is raised hill country |
| Hill height | How high the hills rise |
| Surface detail | Rock-scale roughness on hills and slopes (never on flat land) |
| Erosion | Depth of the spurs and gullies down the slopes |
| Coast roughness | Coves and headlands along the coast (no effect on inland types: Rolling Plains, Lake District) |
| Rivers | How many rivers (above 100 %: smaller catchments start rivers) |
| Lakes | How many lakes. Lakes only form in natural basins on rivers, so above 100 % a map may have no more sites |
| River bends | How strongly rivers meander |
| Valley width | Width of the floodplains and valley sides (0 %: narrow valleys with steep sides) |

On Island Chain, Rivers, Lakes, River bends and Valley width do nothing (its islands are too small for rivers); the
window shows "-" for those.

## 4. Report tab
- **land / water:** share of the map above and below sea level.
- **land slope:** flat (< 3 %: towns, stations, airports), rail (3-8.5 %: the game's maximum build grade for track),
  steep (8.5-25 %), very steep.
- **land height:** median, 99th percentile and maximum.
- **rivers:** count, delta channels, total length; **ship rivers**: count, length, and the share of their course at
  least 2 m deep (should be 100 %).
- **lakes** and their area, **oxbow lakes**, **puddles** (small enclosed water on land; should be 0).
- **passes** (Mountain Range): length, summit height, steepest 100 m and the Relief's target grade.
- **note:** lines appear when the map could not give what the settings asked for (ship rivers, lakes), with what to
  try instead.

## 5. Buttons
- The next step (Preview, then Apply to map) is the filled button, the others are outlined; a button is greyed out
  while it cannot act (for example Apply before a preview is ready).
- **Preview:** for this mod's generator it generates the terrain (in the background, a little each frame, so the
  editor stays usable), then runs the terrain pass and shows the finished map, coloured by biome (blue water,
  greens and browns from lowland to hills, light colours on high ground; previews draw no trees); for another
  generator it runs that generator. Nothing changes on your map. Changing settings never starts a preview by itself; a note says when the
  shown map is older than the settings.
- **Apply to map:** replaces the editor map's terrain with the previewed one (on climates without a finishing pass:
  the heights only).
- **Undo:** puts back the terrain from before the last Apply (shape only; trees are not restored).
- **Larger window / Smaller window:** two window sizes (the game does not let mod windows be resized freely).
- **Debug row**, shown only when the mod setting **Debug tools** is On (Off by default; set it in the mod settings
  before the map editor loads). Files go to the game's `heightmaps` folder in the user data folder, biome masks to
  `biomes`:
  - **Export:** the current terrain as a 16-bit PNG.
  - **Test set** (this mod's generator): 19 fixed cases generated and exported without touching your map (about 4
    minutes on 16 km), so versions can be compared.
  - **Run test** (this mod's generator, Temperate): one click, about half a minute: Preview, Apply, export of the finished map (with its biome masks)
    and of the terrain, and the log. Everything a bug report needs; it replaces your terrain and removes towns and
    industries unless kept.
  - **Save log:** every line the tool logged this session (`utg_log_<id>.lua`).
- **Files the tool writes:** the terrain pass runs through the editor's "Import biomes" mode, which needs a biome file.
  The first Preview writes one set, `utg_placeholder` (a heightmap in `heightmaps`, three masks in `biomes`), and
  reuses it from then on; the pass computes the real biomes from your terrain. Deleting those files is safe: the tool
  writes them again.

## 6. Limits and their reasons
- **Temperate only, for now.** Each climate draws its forests, sand, rock and snow from height with its own rules; the
  finishing pass for Dry, Subarctic and Tropical is being prepared and tested. Until then those climates get the
  terrain shape only.
- **Snow on high hills (Temperate):** the game paints snow and rock from about 330-430 m up, whatever made the map;
  Hilly and higher Relief can reach it.
- **Small maps (under about 6 km):** rivers need catchment area; most map types make few or none there.
- **Large maps** (20-28 km) take up to about half a minute to generate and use a lot of memory while doing so.
- **Map size** comes from the editor map; create the map at the size you want first.
