# DESIGN - Ultimate Terrain Generator

**Last Updated:** 2026-10-08 afternoon (15 built: any generator; 17: feature side; 16: settings audit; 14: run 6)
**Status:** DECIDED (author, 2026-10-06; section 9a). Building per section 10: M0 done; M1 Lua core first version works offline, tuning. Facts link to the research
docs; anything not proven is marked (INFERENCE) or names the probe that will decide it.

## 1. Goals, in priority order
1. **Playable first.** Players must be able to build good rail, road, ship and air networks without ugly
   terraforming. Realism that blocks building is a failure (author, 2026-10-06).
2. **Realistic water.** Meanders, tributaries, deltas and estuaries, lakes that rivers feed and drain,
   river width growing downstream, and some rivers big enough for large ships.
3. **Terrain that shows its history.** Valleys carved by the rivers that are there today, floodplains,
   terraces, oxbow lakes, alluvial fans, glacial valleys and fjords where the climate fits (bonus).
4. **Variety through map types:** bays, peninsulas, island chains, coastal regions, rolling plains and more.
5. **Easy settings:** few controls, and preview only when the player asks for it.
6. **Works in all four climates and with Smart Industry Placement (SIP).**

## 2. Engine facts that shape the design (with sources)
| Fact | Consequence | Source |
|---|---|---|
| **One water level for the whole map, fixed at 0 m for generated maps.** Water = any terrain below 0 | No lakes above sea level, no waterfalls, no visible river gradient. Every river surface is at 0 m, so rivers live in lowland valleys and lakes are basins dug below 0 | the internal notes (verified in `api/tealdef/api/engine.d.tl:1232`) |
| Rivers are carved natively by `river_map` from script-made polylines with per-point width and depth | Width growth, tributaries, deltas and estuaries can be built. How overlapping channels merge is unknown | same doc 1.2 |
| Script nodes in the graph run Lua but can only output numbers and points; they can sample maps | Drainage networks can be computed in a script node (coarse grid). Full erosion of the heightmap cannot | same doc 2.2 |
| No usable native erosion or flow node (`erosion_map` exists but is unused and undocumented) | Erosion inside the graph is unproven | same doc 2.1 |
| **In the map editor, Lua can rewrite the whole heightmap and apply it** (verified in game, run 1): assign the whole `heightmap` table, `makeWorldReplaceTerrainCmd`; a mod window runs a generator preview only on its own button; 11 km map: full generation 1.6 s, apply 1.3 s, 3 x 3 blur in Lua 1.4 s, 32 m drainage 0.12 s | **Route S is proven:** an import-style tree (reads `height_map_input`, no height output) with keepHeightmap kept our Lua heights in preview and Apply. We must ship our own finishing tree that derives biomes, forests, assets and data maps from the heights (the vanilla import tree takes biomes from an imported file, so it drew no forests). keepHeightmap must always be on for such a tree (off crashed the game) | the internal notes |
| New-game page: every setting change regenerates the full map at once, and mods cannot add windows there | Keep the new-game settings list short | the internal notes 3 |
| Each climate needs its own gen.lua; the climate trees read different data-map keys | A builder emits four trees from one source; output the union of keys | the internal notes 5 |
| Rail: 8.5 % maximum build grade; terraforming brush in game is small; town roads fail on rough terrain | The generator must supply the large flat areas and gentle corridors | the internal notes |
| Navigability (runs 1-2): depth hardly matters (2 m is enough), width does: river-like banks need >= 100 m at the water line (70 m = thin lane only at >= 4 m depth; 40 m never) | Ship rivers 100-200 m wide, 3-6 m deep; other rivers deliberately < 60 m | the internal notes |
| Mod windows have no size parameter and no screen-size query; a mod stylesheet (`*.css.lua`) sets sizes; the native preview is large | The Studio window fits 1920 x 1080 (fixed sizes + scroll area); the preview image is optional or in its own window | the internal notes |
| Map sizes reach 112 x 112 tiles (28.7 km, 51 M heights) | Full-resolution Lua passes are too heavy on the largest maps; work at 8-32 m there and add detail back (INFERENCE) | the internal notes |

## 3. Playability targets (soft; author decision 9a.4)
These are **targets, not limits**: they describe a good starting point at Relief = Gentle and loosen as Relief rises
(Hilly, Mountainous), so difficult maps are possible. The map report shows the numbers; nothing is forced or
"fixed" after the fact. First values (to be tuned in game):
| Rule | First target | Why |
|---|---|---|
| Flat land for towns and stations | >= 35 % of land under 3 % slope (plains presets more, mountain presets less but never < 15 %) | Towns need flat land (`allowInRoughTerrain = false`) |
| Rail corridors | At Flat/Gentle relief, neighbouring lowland regions are usually linked by a corridor under about 2.5 % (valleys, passes, coastal strips); at Hilly/Mountainous, corridors may be steep or missing | 8.5 % is the game's build limit; 2-3 % plays well; hard maps are allowed |
| River crossings | Big rivers have crossing spots (narrower reaches, islands, firm banks) at least every 5-8 km; bank tops above the floodplain so bridges clear ships | Bridges must clear navigable water |
| Ship routes | At least one navigable route of real length when the preset includes water (trunk river to the sea, lake chains, bays). Width and depth come from E5 | Ships need a connected navigable grid |
| Harbour coasts | Long coast stretches shelve gently (no cliff along the whole coast) | Landings in navigable water, street access on land |
| Airport sites | No dedicated sites (author 9a.5): flat land arises from the terrain itself; players choose and terraform | Players must keep freedom of placement |
| No ugly artefacts | No 4 m spikes, no terraces of 1-2 m that roads cannot follow, no sea-level puddles on floodplains (floodplain at +1 to +3 m) | 0.05 m height steps; puddles read as water |

Rule of thumb for realism vs play: valleys are wider and flatter than in nature, mountains are concentrated in
belts with passes, and gorges appear only where a preset asks for them.

## 4. Water design
- **Hydrology first.** Build land and uplift, then the drainage network from the sea and lakes upstream, then
  carve the terrain so every valley belongs to a river. River order (Strahler) sets width, depth and valley size.
- **Rivers at 0 m (engine).** Trunk rivers run through broad lowlands that rise gently away from them.
  Headwaters in uplands become dry valleys above a set height, so small streams do not become absurd gorges.
- **Meanders** whose wavelength scales with width; tighter in floodplains, straighter in valleys. **Oxbow lakes**
  from cut-off loops (small basins below 0 beside the trunk).
- **Tributaries** join at realistic angles, and widths add up downstream. **Confluences** widen slightly.
- **Deltas** where a big river meets a shallow, sheltered sea (bays, delta presets): 2-4 distributaries over a
  shelf. **Estuaries and rias** where the coast has sunk: the valley continues below sea level and widens.
- **Lakes** as basins below 0: chains of lakes along a river (fed and drained), terminal lakes in dry climates,
  glacial finger lakes in subarctic. All lakes are at sea level by engine rule, so their surroundings rise only
  gently, otherwise they look like holes.
- **Ships.** The "Ship rivers" setting (None / One / Several) decides how many rivers reach the navigable size
  (>= 100 m wide, 3-6 m deep; E5/E5b); its default comes from the map type (Great River Valley: One; Delta Lowlands:
  Several; Mountain Range with Passes: None). Other rivers stay under about 60 m. Nothing else is placed for the
  player: no reserved harbour, station or airport sites (author 9a.5).

## 5. Geological history (bonus) - cheap cues first
Valleys whose width follows river size; floodplain benches at +1 to +3 m; river terraces at about +4, +10 and +18 m;
oxbows; alluvial fans where streams leave the hills; U-shaped glacial valleys and fjords (subarctic); drowned river
mouths; mesas and canyons (dry); volcanic cones and eroded calderas (tropical). In the editor tool (route S below),
a few iterations of real stream-power or hydraulic erosion can add the realistic texture (INFERENCE, E3 times it).

## 6. Two delivery routes
| | **Route G: generator** (node trees) | **Route S: "Studio" in the map editor** (mod button + window) |
|---|---|---|
| Where | New game and map editor (generator list) | Map editor only; the player saves the map and starts a game from it ("Play Map") |
| How | Our own node trees, one per climate, from one builder. A hydrology script node computes the drainage network on a coarse grid and feeds `river_map`; native nodes shape valleys, terraces and coasts | Lua works on the whole heightmap: base shape (from our route G trees, run on demand in the window), then hydrology, erosion, carving and playability fixes in Lua, then **our own finishing tree** (import-style: reads the heights, no height output, keepHeightmap always on) adds biomes, forests, assets and data maps, then Apply |
| Realism | Good (network-consistent valleys, no true erosion) | Best (real erosion and exact river profiles) |
| UI | 4-6 settings on the new-game page; preview on every change | Unlimited, tabbed, preview only on Preview, undo, map report |
| Offline testing | Approximate (native nodes are evaluated only in game; workspace `preview.py` approximations) | Exact for the Lua part (same code runs offline in Lua 5.2 via lupa) |
| Risk | Unknown `river_map` merging and cross-section; script-node speed | E2/E6 must pass; memory on the largest maps |

**Shared core:** the hydrology and river-shaping code is plain Lua on grids, written once and used by both the
script node (coarse, outputs polylines) and the Studio (full resolution, writes heights). Whether a script node
can `require` a module from our mod is to be tested; otherwise the builder copies the module into the node script.

## 7. Settings
**Route G (new game), about 5 controls:** Map type (ComboBox with a tooltip per type) · Relief (Gentle, Moderate,
Hilly, Rugged, Mountainous; run 6: Flat dropped) · Water (Dry, Normal, Wet: river density and lakes) · Ship rivers (None, One, Several) ·
Forests (Few, Normal, Many). Everything else is set by the map type preset.
**Route S (editor window):** as built after run 6: tabs Settings (map type, Relief, water, ship rivers, seed) /
Terrain parameters (one slider per `pipeline.TUNE` entry) / Report; Generate, Preview, Apply, Undo; debug tools
Export, Test set, Save log; Larger window.

**Map types (confirmed 9a.2; more may be added). First three: Great River Valley, Delta Lowlands, Mountain Range with
Passes.** Built since (2026-10-06, map editor): Rolling plains, Lake district, Large bays, Peninsulas, Island chain, Coastal
region, Highland plateau (all Temperate list types; the climate-specific ones wait for other climates). Full list: Large bays · Peninsulas · Island chain (archipelago) · Coastal region ·
Rolling plains · Great river valley (one big navigable river) · Lake district · Mountain range with passes · Delta
lowlands · Highland plateau · Fjord coast (subarctic) · Mesa country (dry) · Volcanic islands (tropical).

## 8. Diagnostic probe (built 2026-10-06, `content/gui/ultimate_terrain_generator/utg_probe.script.lua`)
Map-editor-only "UTG" button and window; every result is a `[UTG]` line in stdout.txt. Steps in the internal notes.
| Test | Question | Decides |
|---|---|---|
| E1 | Map facts; generator names, params and flags of this climate | How the Studio names and runs generators |
| E2 | Can Lua write heights into a map copy, and which way works? | Whether route S is possible at all |
| E3 | Lua cost of a full-resolution pass and of a 32 m drainage network | Route S resolution and speed budget |
| E4 | Data maps (keys, sizes, means) and water level, before and after changes; per-tile water mesh levels | What survives a terrain replacement; final check on "one water level" |
| E5 | Navigability: 63 channels (depth 1-12 m by width 8-128 m) carved by Lua into a flat editor map | Navigable width and depth for small and large ships |
| E6 | Preview a generator **on demand inside our window** with our own params, optionally keeping our heights, then Apply | The Studio workflow end to end |
| E7 | Tabs, combo box, check box and slider work in a mod window | The Studio UI |
| E5b (v2) | River-like channels (1:4 banks, 40-200 m, 2-8 m) branching off a deep basin; navigable layer and ship lines | Trunk-river cross-section for ships |

**Run 1 results:** E2 yes (whole-table assignment only); E3 budget as in section 2; E4 a new editor map has
no data maps, a generator Apply creates 9, all water meshes at 0 m; E5 see section 2; E6 on-demand preview and Apply
work, but `keepHeightmap` with the normal generator overwrote the channels; E7 all widgets work. **Run 2** (v2) tests
the import generator as a height-keeping finishing pass (logged heights KEPT/CHANGED) and E5b.
**Run 2 results:** import generator + keepHeightmap KEPT the Lua heights (4 test points, preview and
world); no forests (no biome file); import generator without keepHeightmap crashed the game (v3 forces it on); E5b
navigability as in section 2; height range -100.. 3176.75 m; the window was taller than a 1440 px screen (v3: scroll
area, smaller preview, preview on/off, `utg_probe.css.lua`).
**Run 4 results:** our finishing pass kept the heights, drew forests, rock, snow and river trees from the
heights alone, and created all 9 data maps (forest_mask, river_mask, biome masks), so Studio maps work with SIP.
Offline check: `python tools/probe_check.py` (stylesheet + 7 scenarios, fake engine).

## 9. Decisions for the author
1. **Routes:** build route G only, route S only, or both? **Recommendation: both, sharing one Lua core; start
   with the core plus route S if E2 and E6 pass** (exact offline testing and the best realism), then route G for
   new games. If E2 or E6 fails, route G only.
2. **Map types:** confirm, cut or add to the list in section 7. Which three first?
3. **New-game settings:** is the five-control list in section 7 right?
4. **Playability targets** in section 3: agree as starting values?
5. **Ships:** how many navigable rivers by default (one trunk per map, or none unless the player asks)?
6. **Climate order:** temperate first, then the other three?
7. **Large maps:** is it acceptable for the Studio to work at reduced detail (8-32 m) on maps above about 16 km?


### 9a. Answers (author, 2026-10-06)
1. Both
2. Confirm, but we might add to these later. These 3 first: Great River Valley, Delta Lowlands, Mountain Range with Passes
3. Yes
4. The grade limit shouldn't be a hard maximum. We must also allow for generation of maps that are more "difficult" from a gameplay-perspective.
5. Similar to #4, we don't want to generate terrain that forces a player to put airports in certain locations. The player must have freedom to play as they desire, we're just crafting a good starting point for their game map. Terraforming and making hard decisions about infrastructure placement is a game-mechanic.
6. Temperate first
7. Acceptable if required, as long as the final product is generated at full detail.

### 9b. How the answers are applied (the author, 2026-10-06; author may correct)
- 1: both routes; route S (editor Studio) and the shared Lua core first, then route G (new-game generator).
- 4: section 3 values are soft targets scaled by the Relief setting; no hard grade limit; challenging maps allowed.
- 5: read as "no forced placements": the generator never reserves sites for airports, harbours or stations, and
  ship rivers come only from the "Ship rivers" setting with a per-map-type default.
- 7: large maps may be processed at 8-32 m internally, but the final heightmap always gets full 4 m detail
  (coarse shapes upsampled + a full-resolution detail and carving pass).

## 10. Build plan (milestones)
| # | Milestone | Content | Done when |
|---|---|---|---|
| M0 | **Finishing pass (Temperate)** - DONE | `tools/build_finish_tree.py` turns the vanilla Temperate import tree into ours: biome index, rivers and mountains layers computed from the heights (no imported files). Editor only, import-style, keepHeightmap always on | In game: heights KEPT, forests and biomes drawn, data maps created |
| M1 | **Lua core** (offline first) - FIRST VERSION WORKS, tuning | `content/scripts/ultimate_terrain_generator/core/`: grids and seeded noise; map-type shapes (the first three); hydrology (depression filling, flow accumulation, Strahler order, river polylines, meanders, tributaries, deltas, lakes as basins below 0); carving (channels at 0 m, valley, floodplain, terraces); coarse erosion; coarse-to-full-resolution detail; map report (section 3 numbers). Offline tests in Lua 5.2 (lupa) with PNG previews | The three map types look right in previews; report numbers sane; 11 km map in a few seconds of Lua |
| M2 | **Studio window** (replaces the probe) - BUILT, offline check passes; waits for run 5 | Tabs (Shape / Water / Relief / Report), Generate (Lua core, spread over frames with a progress line so the game does not freeze), finishing-pass preview, Apply, Undo; sizes via stylesheet | Works end to end in the editor; Play Map from the saved map |
| M3 | **Tune in game** | Temperate, three map types, then the rest of the list | Author satisfied with look and playability |
| M4 | **Route G** - ON HOLD (author 2026-10-06: map editor only for now) | New-game generator: node trees from a builder, the core's drainage in a script node, about five settings | Generates in the new-game screen |
| M5 | **Other climates** | Finishing trees and assets for Dry, Subarctic, Tropical; climate features (fjords, mesas, volcanoes) | All four climates |

Modules are loaded the way Smart Industry Placement does it: `require "ultimate_terrain_generator::/scripts/
ultimate_terrain_generator/core/<name>.lua"` from the window script (proven pattern).

## 11. M1 Lua core as built
`content/scripts/ultimate_terrain_generator/core/`, pure Lua 5.2, same code in game and offline
(`tools/core_check.py`). Every module header explains its WHY; summary:
| Stage | Module | What it does |
|---|---|---|
| Shape | `shapes.lua` | Map type in a canonical frame (one of 8 orientations by seed): sea/coast, organisation field B (drainage order, lake pits), uplift U, inflow and outlet points, per-type preset (relief factor, ships, shelf, lakes, river density, meander, valley width, estuary, channel density, delta) |
| Drainage | `hydrology.lua` | Priority flood from the sea/outlets (receivers, order, filled), D8 accumulation (+ inflow catchments), pits as lake sites, water network as a river tree (mouth to source, short leaves pruned), Strahler |
| Rivers | `rivers.lua` | Smoothed courses, irregular meanders (per half-bend length and swing, Kinoshita skew/flatness, near-straight and near-cut-off bends; author: no periodic bends), ship reaches (120-180 m, 5 m) by the Ship rivers setting, small rivers 18-58 m, floodplain level +1..+2.8 m, delta channels, oxbow lakes beside the tightest bends (after landform; 1 / 3 / 5 per map by Water) |
| Landform | `landform.lua` | Channels by stream power, hillslopes as slopes from the nearest channel (no D8 streaks; concave on gentle types via `preset.uplands`, so tops are broad and buildable), relief scaling, lakes (deepest part, fragments dropped), valley floors along the centreline (belt-wide, gentle undulation, one side profile per map, terraces +4/+10 m), drowned-valley estuaries, pass valleys, sea shelf, shore smoothing |
| Passes | `passes.lua` | Map types with corridors (Mountain Range): each pass is a winding valley axis (the drainage notch follows it); its floor is graded to the Relief's target (2 / 2.5 / 4 / 6 %, with a 15 % margin for 4 m roughness) and the hillsides rise from it like from any valley: two valleys meeting at a broad col. Floors get no rock detail (`calm` mask) |
| Detail | `detail.lua` | Catmull-Rom upsampling to 4 m, tileable detail above +3 m, puddle guard, channels carved at 4 m (bed -d, 1:4 banks) |
| Erosion | `gullies.lua` | Spurs and gullies running downhill: Gabor stripes aligned with the slope, two octaves, depth = K x slope x wavelength, on a 16 m texture grid read by detail.lua |
| Report | `report.lua` | Section 3 numbers: slope classes, heights, rivers/ship length/ship depth check, lakes, puddles (confirmed at full resolution), passes (summit, steepest 100 m grade with bridges level) |
| Run | `pipeline.lua` | `run(settings, map)` and `job`: a coroutine runner with a per-frame time budget for the editor window |

Coarse grid 16/32/64 m (<= 300k nodes). Water threshold scales with map area. Offline timings (Lua 5.2): 4 km 1 s,
11 km 2.5 s, 16 km 5 s, 28.7 km 9 s. First report numbers (seed 1, Gentle, Normal): Great River Valley 29 % flat /
63 % railable; Delta Lowlands 90 % flat; Mountain Range with Passes 28 % flat; no puddles; ship courses 100 % in
>= 2 m water. Open tuning points are in the internal notes (M1/M3).
Tuning: Great River Valley 38-43 % flat at Gentle (concave hillslopes); Mountain Range passes measure
1.7-2.5 % at Gentle, 5.8-6.4 % at Mountainous (seeds 1-5), cols 42-50 m at Gentle; 28.7 km maps 10-12.6 s.

## 12. Future: UTG loaded by the Terrain Generator Window (author, 2026-10-06)
The author decided to build a separate mod, **Terrain Generator Window** (``): a
map-editor window for any built-in or mod terrain generator, with Preview on demand. **If possible**, that window
should one day be able to load UTG as one more generator.

**Priority rule (author):** getting UTG working properly is the primary goal. Considerations for the separate window
must never compromise it: when they conflict, UTG wins, and nothing in UTG is changed now for this purpose. Future
UTG work should only *keep the door open* where that costs nothing or is good design anyway.

What already fits (as built, no change needed):
- The terrain core (`content/scripts/ultimate_terrain_generator/core/`) is pure Lua with no GUI or engine calls; its
  single entry is `pipeline.run(settings, map, hooks)` / `pipeline.job` (frame-budget runner), which is what a
  host window needs. Results are plain data (`heights`, `report` + `report.format`, `paths`, `lakes`, `corridors`).
- Map types come from the core (`shapes.ORDER`, each with a `label`), not from the Studio.
- The finishing pass is an ordinary import-style generator per climate (`utg_finish_<climate>.gen.lua`), which a
  generic generator window can list and run like any other.

Guidelines for future UTG work (soft; skip any that would cost UTG quality or time):
1. Keep the core free of GUI and engine (`api.*`) calls; the Studio window stays the only engine-facing part.
2. Keep `pipeline.run` / `pipeline.job` the one entry point; note any change of their settings or result fields in
   CHANGELOG.md (a host may depend on them).
3. When settings change, prefer describing them in the core as data (key, label, choices, default), as map types
   already are, rather than only in the Studio script.
4. Keep the report as data plus a formatter, and logging prefixed (`[UTG]`), so a host can show or forward it.

Not yet known (verify when the window project starts, not before):
- Whether one mod's GUI script can `require` another mod's script by its `<modId>::/` path (works within a mod,
  INFERENCE across mods), and how the window would discover UTG (an optional `pcall(require,...)`).
- UTG is not a `gen.lua` generator (route S runs in Lua), so the window would need a small "Lua generator" interface
  next to the engine's generator list; its shape is to be designed in the window project.

## 13. Game scale (run 5 feedback, 2026-10-07)
The author's verdict on run 5: realistic, but too flat and smooth for the game; mountains too big; coasts too smooth.
Vanilla Temperate is sized right for the game but too noisy for building. Target: between the two, with UTG's
playability. Measured with `tools/scale_check.py` (16 km, seed oeyrx62dl8; RMS relief per wavelength band):

| Map | flat % | steep+ % | P99 m | 48-128 m | 128-384 m | 384-1024 m |
|---|---|---|---|---|---|---|
| Vanilla Temperate medium | 11 | 61 | 333 | 8.5 | 24.8 | 35.9 |
| Great River Valley, Gentle, run 5 | 43 | 5 | 138 | 1.3 | 3.7 | 8.0 |
| Great River Valley, Gentle, now | 28 | 37 | 195 | 3.2 | 9.3 | 13.1 |
| Great River Valley, Hilly, now | 17 | 67 | 351 | 5.4 | 16.0 | 23.7 |

How: hill country, patches of raised hills on a share of the land set by Relief (vanilla's plains/hills
patchwork, not its noise level); fine detail only where the land is hilly or steep (`rough`); lower relief
targets at Hilly/Mountainous; ragged coasts; irregular meanders on a wandering valley axis. The drainage model
(valleys, floodplains, passes) is unchanged and still cuts through everything, so corridors stay buildable.
Players tune all of it with the Advanced sliders (`pipeline.TUNE`). Open: the author's check in game.

## 14. Run 6: erosion texture, Relief steps, ships, trees, window
The author's run 6 verdict: better scale, but hills and mountains still "too smooth / blended".
Relief per wavelength band already matched vanilla at Hilly and above; what was missing is texture. Vanilla hill land
has 2-3 times our curvature (scale_check keys c8, c32, sdS; the internal notes): its slopes
are cut into spurs and gullies that run straight downhill and branch, the look of water erosion.

**Erosion texture (`gullies.lua`).** Real erosion is too slow in Lua at 4 m on a 16 km map, so the core draws its
result: cosine stripes from the 3 x 3 nearest cells of a jittered lattice (Gabor noise), each cell with its own sign
(phase 0 or pi, so the stripes stay continuous across ridges where the downhill direction flips), crests aligned with
the local downhill direction; where cells disagree the stripes fade, merge or end, which reads as branching. Two octaves (300 m and 115 m); the second follows the slope of land plus first octave, so side gullies
run down the flanks of the main spurs. Depth = K x slope x wavelength: steep mountainsides are deeply dissected,
gentle slopes barely, flat land not at all, so playability (flat land for towns and stations, graded pass floors,
floodplains) is untouched. A 16 m texture grid (>= 7 samples per wavelength), rows computed on demand only where the
land is rough, interpolated to 4 m with the same cubic weights as the heights. Players scale it with Erosion (0-200 %).

**Relief steps.** Flat dropped (author); Gentle, Moderate, Hilly, Rugged, Mountainous. Gentle, Hilly and Mountainous
keep their exact values; Moderate and Rugged are midpoints (CHANNEL_AREA geometric). The list lives in the core
(`pipeline.RELIEF`, section 12 guideline 3).

**Several ship rivers.** On maps with one dominant trunk (Great River Valley), no other river passed a size test
relative to the trunk. Several now always widens the two largest other rivers (other mouths or the trunk's
tributaries; the trunk's ship reach extends to the junction) for at least 4 km. Open for the author: widen small
rivers (now) or grow bigger rivers instead.

**Trees.** Vanilla's forest rules (kept in our finishing pass) grow hill trees and conifers in narrow slope bands and
river trees in a hard-edged band: on our even slopes those became contour stripes and dense lines. The finishing pass
now uses smooth slope ramps and thins river trees with distance. Snow and rock above ~330-430 m come from the
climate itself (not the generator); hilltops near 400 m at Hilly get snow patches.

**Window.** The game has no free window resizing (WindowParam); the Studio uses screen-relative sizes, a second size
via `expanded` (Larger window), a fixed two-pane layout (settings left, preview right), fields side by side, and
stylesheet spacing (the internal notes "Window size, layout spacing and files").


## 15. Any terrain generator in the Studio window (designed 2026-10-08; BUILT the same afternoon, offline-checked; 15.5)
Author request: a plan for loading **any terrain generator, vanilla or mod**, in our window, using its
space and **on-demand preview**. Earlier decision: this was to be a separate mod, Terrain Generator
Window (TGW, on hold; section 12). The plan below works for both; where it lives is the author's choice.

### 15.1 What the game files give us (verified in files, `base/content/gui/`)
| Need | Base game mechanism | Source |
|---|---|---|
| List the generators of this climate, in order | `app.res.terrainGeneratorRep.getAll()`, `get(k)` (desc: `climate`, `visible`, `isImportGenerator`, `order`, `params`, `desc.name`), `getName(k)`; filter `gen.climate == baseConfig.climate and gen.visible` (+ not import for the generate tab), sort by `order` | `map_editor/map_editor.tl:509-527` (`getPossibleGenerators`) |
| Default parameter values | `script_param_util.getScriptParamDefaultValueIndex(param.numbers, param.defaultIndex)`; existing values clamped with `clampScriptParamValueIndex` | `map_editor.tl:529-539` (`addMissingGeneratorParams`) |
| A widget for every parameter type (combo, slider, check box, buttons, toggle buttons) | `script_param_util.buildScriptParamComp(scriptParam, index, onValueChange)` (label + control in the base "script-param-wrap" layout) | `main/script_param_util.tl:546-570`; used `map_editor.tl:655, 677` |
| Generator choice as a combo | a `api.type.ScriptParam.new()` with `key = "generator"`, `uiType = ComboBox`, `values` = `gen.desc.name` | `map_editor.tl:640-670` |
| Preview inputs | `HeighmapGenerationMode` (`terrainGenerator`, `generateTowns/Industries = false`, `generateAssets`, `keepHeightmap`, `keepBiomes`), `inputMap = makeMapFromGame(withHeightmap, withTowns, withIndustries, withAssets)` with `waterLevel = 0`, `params` = { key = 1-based value INDEX }, `seed` string | `map_editor.tl:541-556, 584-592, 298-330, 2670-2685` |
| Apply | remove towns (`makeTownDestroyCmd`) and industries (`industry_util.removeIndustries`) unless "Keep towns / Keep industries", then `makeWorldReplaceTerrainCmd(Map.new(readyMap), baseConfig.terrain, seed, world, keepAssets)`, `setMapSeedText(seed)`, `reloadMaterialIndexManagerPipeline()` | `map_editor.tl:749-830` |
The base window re-runs the preview on EVERY change (its `MapPreviewComp` inputs change with each parameter). Our
window already proves the on-demand alternative: the preview's inputs change only when Preview is pressed (runs 1-6).
Import-style generators need `keepHeightmap = true` (without it the game crashed, probe run 2) and an imported file;
they are left out of the list, as the base generate tab does.

### 15.2 Design
**One window, two kinds of generator ("sources").** A `Generator` combo at the top of the Settings tab lists
"Ultimate Terrain Generator" first, then every visible, non-import generator of the current climate (vanilla and
mods), in the game's order. The rest of the window follows the chosen source:

| | UTG (Lua core, as now) | Any engine generator |
|---|---|---|
| Settings tab | Map type, Relief, Water, Ship rivers, Seed | the generator's own parameters (base widgets from `buildScriptParamComp`), Seed |
| Terrain parameters tab | UTG sliders | hidden (the generator's parameters are all on Settings; a generator with many parameters scrolls) |
| Generate | Lua core over frames | not needed: the native preview IS the generation (button hidden) |
| Preview | finishing pass on our heights | the generator itself (`mode.terrainGenerator = name`, `keepHeightmap = false`, params as indices) |
| Apply / Undo | as now | the same code (Undo = the world map saved before Apply) |
| Report tab | UTG report | the same numbers measured on the ready preview map's heights (slope classes, heights, land/water) by `report.lua` functions that need only heights (no rivers or passes): a neutral way to compare generators |
| Keep towns / industries | new options for both | as the base window |

**On demand:** parameter changes only edit the pending settings; the preview runs when Preview is pressed, and a note
says when the shown preview no longer matches the settings (as the UTG note "Settings changed since the last
Generate"). This is the author's point for slower computers: several changes, one preview.

**Code shape (so TGW or UTG can host it):** a GUI-side module `content/gui/ultimate_terrain_generator/sources.lua`
(plain Lua, no core changes) with two source objects sharing one interface: `label`, `buildSettings(state, changed)`,
`hasGenerate`, `startGenerate/step`, `makePreviewRequest(state)`, `reportFromReadyMap(map)`. The Studio holds the
current source; Apply, Undo, Export, Save log and the layout stay common. The UTG source wraps today's code; the
engine source is new (~250 lines). The core (`pipeline.lua`) stays untouched (section 12 guidelines).

### 15.3 Settings this adds (and what must be caught)
- **Keep towns / Keep industries** (check boxes, both sources; default off = remove them, as the base window). UTG's
  Apply today leaves existing towns and industries standing on the new terrain (README says "place them after
  applying"); with these options the player chooses, and the order is the base game's (towns, then industries, then
  terrain, each step in the previous step's callback).
- **Keep assets** (engine source): `mode.generateAssets = not keepAssets`, `keepAssets` passed to Apply (base).
- Catch: a generator that throws or produces no map (`onReady` never fires) -> status after a time-out, Apply refuses;
  a generator removed between sessions (stored name not in the list) -> fall back to UTG; parameters of a mod
  generator with `values` but no `numbers` (index used, as the base does); generators of another climate never listed;
  import generators never listed; Apply while a preview runs refused (as now).

### 15.4 Steps, checks and the in-game proof
1. `sources.lua` + Studio wiring, UTG source first (no behaviour change: studio_check 9/9, baseline 40/40).
2. Engine source with a fake `terrainGeneratorRep` in `studio_check.py` (three generators: vanilla-like with combo +
   slider params, a mod-like one with `values` only, an import generator that must not be listed); scenarios: list
   and order, defaults, a parameter change does NOT start a preview, Preview builds one request with index params,
   Apply with and without Keep towns/industries (fake town and industry removal), Undo.
3. In game (one short run): pick the vanilla Temperate generator, change three parameters, Preview once, Apply, Undo;
   then a mod generator if installed. Unknowns this run settles: `require "::/gui/main/script_param_util.tl"` from a
   mod script (other `.tl` modules load fine: `game_react_globals.tl`, `main_mod_button_area.tl`, runs 5-6); the
   base widgets inside our column; preview time of vanilla generators at 16 km; `generateTowns` in the preview.
Estimated size: 1 session to build and check offline, 1 in-game run.

### 15.5 As built (2026-10-08 afternoon; offline-checked, not yet seen in game)
- `content/scripts/ultimate_terrain_generator/studio/engine_generators.lua` (engine-facing, not core): `list()`,
  parameter values (`valueOf` / `indexOf` / `defaultValue`, the base rules), `makeRequest` (keepHeightmap off, inputs as
  the base `makeMap`), `removeTownsAndIndustries` (base order; industries counted by the constructions found; proposals
  not player-initiated), `measure` (land, slope classes, heights of a finished map, the UTG report's definitions).
- Studio: "Generator" combo (UTG first); a game generator's parameters through the base `buildScriptParamComp`
  (pcall-required; fallback combo boxes); Terrain parameters tab only for UTG; no Generate button for a game generator
  (its preview is the generation); a stale-preview note; the Report measures the finished preview over frames; Apply,
  Undo, Export (named `utg_<id>_engine_<generator>`) shared; Keep towns / Keep industries for both.
- Deviation from 15.2: one script file (no separate `sources.lua` GUI module): the UTG and engine paths share most of
  the window code and the module with the engine calls is `engine_generators.lua`.
- Checks: `tools/studio_check.py` scenarios "game generator (fallback widgets)" and "(base parameter widgets)": list
  (hidden and import-style generators excluded), defaults (index and number values), no preview before Preview, request
  params, stale note, measured report, Keep towns on / industries off (command order industry, segments, terrain),
  Export name, Undo, switching back.

## 16. Settings audit: what players get, what they should not, and what was caught
Author request: decide which additional settings should or should not be given to players, and catch
combinations or implementations of settings that misbehave. Tool: `tools/settings_check.py` (every setting at its
edges, all map types, odd map shapes, parallel); results in the work plan notes (W4) and CHANGELOG 2026-10-08.

### 16.1 Caught and fixed (core; 40/40 accepted maps unchanged)
| Combination | What went wrong | Root cause | Fix |
|---|---|---|---|
| Valley width 0 % (any type) | valley sides were silently skipped (1 puddle on Coastal Region, Hilly) | zone width 0 -> `k = 1/0`, `k * e * e` = NaN, `NaN < h` false | `landform.valleyTarget`: zone 0 = limit slope from the floodplain edge |
| Surface detail + Erosion at 200 % on Mountainous | 9 sea-level puddles in 15-25 m lowland | the detail term (up to ~36 m) had no limit; only gullies were limited | `detail.DETAIL_FLOOR`: land that was above +3 m never ends below +0.5 m |

### 16.2 Behaviour that surprised, now explained to the player (no terrain change)
| Combination | Behaviour (by design) | What the player now sees |
|---|---|---|
| Ship rivers One/Several on maps with no or few large rivers (small maps, Water Dry, Rivers 0 %, coastal types) | no ship river can be made | Report note: asked vs made, with what to try |
| Lakes above 100 % (most types), Lakes 0 % where there are none | lakes form only in natural basins on rivers; the count is capped by the sites | slider note + Report note: wanted vs made |
| Coast roughness on Rolling Plains / Lake District; Rivers, Lakes, River bends, Valley width on Island Chain | the map type has no sea / no rivers | slider shows "-", a note names them (`shapes.TYPES[id].inactive`) |
| Maps under ~6 km (editor allows 1.5 km) | most map types make few or no rivers (river size scales with area) | Settings note on small maps; README "Limits" |
| 1:5 strips, 1.5 km squares | all valid (no failures) | none needed |
| Any seed text (empty, spaces, 600 characters, non-ASCII, digits) | valid and deterministic | none needed |

### 16.3 Settings to ADD (recommendations)
1. **Keep towns / Keep industries** on Apply (the internal notes author: yes, like vanilla; BUILT 2026-10-08): the base editor removes towns and industries before
   replacing the terrain unless these are ticked; UTG leaves them standing on the new terrain. Two check boxes,
   default off (remove), the base order of commands (DESIGN 15.1). Clear benefit, small, safe.
2. **Forests** (Few / Normal / Many): already in the approved new-game list (section 7, 9a.3). The finishing pass's
   vanilla logic reads a `forest` number (`param_number`, default 1, `temperate_import_gen.tree.lua:1016`, feeds
   "Humidity") that no vanilla gen.lua declares; our finishing gen.lua could declare it and the Studio pass it to the
   preview. Needs one in-game probe (how a gen.lua param reaches `param_number`: index or number; TGW open question).
3. **Any generator** (the internal notes author: in UTG's window; BUILT 2026-10-08, section 15.5).
4. **Feature side** (author 2026-10-08: generalised from "coast side"; BUILT, section 17): was **Coast side** (Random / North / East / South / West) for map types with a sea.
   Today the seed picks one of 8 orientations; a player who wants "sea in the south" must try seeds.

### 16.4 Settings NOT to add (and why)
- Sea level / water level: one engine water level at 0 m; a setting would only shift
  the whole map.
- River width / depth per river, ship-river count above "Several": ship rivers need >= 100 m width (probe E5b), the
  three-step setting already covers it; more freedom would produce rivers ships cannot use, or wide rivers that block
  every crossing (playability first).
- Exact mountain heights / a height slider in metres: the Relief steps + Overall height already scale heights, and the
  game paints snow and rock by absolute height (C1); metres invite unplayable maps without adding control.
- Map size: set by the editor map (the Studio shows it); changing it is the editor's job.
- Separate grade / pass-steepness sliders: passes follow Relief (2-6 %, section 11); the internal notes asks only about pass
  height. A free grade slider would let players break the rail-friendly corridors silently.
- More advanced sliders: ten are enough to tune every stage; B2 asks the author whether any are missing or unneeded.

### 16.5 Checks that keep this true
`tools/settings_check.py` (FAIL: errors, invalid heights, puddles, ship courses dry, job runner differs; WARN: settings
the map cannot satisfy, dead sliders, slow cases) runs in `tools/run_checks.py` at 4 km (all groups) and 11 km
(Terrain parameters, extremes, ships). Any new setting gets its edge cases added there.

## 17. Feature side (author 2026-10-08)
The author asked for a choice of which side (North, East, South, West) gets a map type's defining feature. Every map type
is written in a canonical frame whose low edge is the sea or the "near" side; the seed picks one of 8 orientations
(rotate / mirror). A chosen side fixes the rotation (`swap`, `flipY`); the mirror along that edge stays the seed's, so
seeds still differ; the seed's roll is always drawn, so "Random" reproduces every earlier map (baseline 40/40).
| Map type | Setting label | Means | Canonical edge |
|---|---|---|---|
| Great River Valley, Rolling Plains | River comes from | where the big river enters the map (sea / outflow opposite) | high |
| Delta Lowlands, Mountain Range with Passes, Large Bays, Peninsulas, Coastal Region, Highland Plateau | Sea side | the edge with the sea (the range, bays, plateau lie inland from it) | low |
| Lake District | Rivers flow towards | where the rivers leave the map (the fells lie opposite) | low |
| Island Chain | (none) | islands across the whole sea | - |
Mountain Range: the range runs parallel to the sea side (a range "starting" at one edge would cut the passes' design);
its rivers leave the map on the opposite side. Code: `shapes.SIDES`, `shapes.TYPES[id].side`, `shapes.orientationFor`;
`pipeline` setting `side` 0..4; the settings text names it only when chosen (export_check parses it). Check:
`tools/settings_check.py` group `sides` (each type x side x 2 seeds at 8 km: the sea, the trunk source or the river
mouths on the chosen edge): 72/72.
