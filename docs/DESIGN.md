# DESIGN - Ultimate Terrain Generator

**Last Updated:** 2026-10-13 (23: author decisions B14-B16; earlier: section 24 review fixes: the wrapper record is checked and repaired, a plain
button when the window cannot open, five window scenarios; earlier: section 24: Studio window and other mods' GUI replacements; earlier: section 23 Sea Strait merged from its isolated build (built as section 21 there); earlier 2026-10-13: run 9 review fixes: 20: the factor remap reads from 0.5 so Normal is exactly
1.0 under both formulas that fit run 9, the formula wording, CheckBox wording, three more builder checks; 21: the
cancel note, Preview refused while Apply waits, the frame between Generate and the pass, more checks; earlier:
21: Apply to map makes the preview first; 22: Terrain parameter tooltips,
the internal notes 18, 19: Alpine pre-selects Sea side None, the internal notes earlier: 20: Forests becomes the "Lower tree density" check box, forest_mask the same
for both values, run 9 result; earlier: 19.1: Mountain Range gets Alpine's pass floors and far-edge outlets at every
Terrain step, the internal notes notes in 11, 14, 17, 19; earlier 2026-10-12: review fixes: 14: fresh-seed results and per-seed spread in "Known limits",
Overall height 0 % on the curved steps; 7: B12 note: help line, Report line "terrain"; earlier: 14: Relief
middle steps retuned so flat land steps evenly, the internal notes with notes in 3, 7, 11, 19; 7: label Terrain;
earlier: review fixes: 7: core_baseline at Hilly too; 20: Forests box only where the
pass declares it, failure modes told apart by the forest_mask line, checks; 16.3 item 2: correction as a quote; 17.2:
checks; earlier: 20: Forests Few /
Normal / Many; 16.3 item 2 corrected; 7: Forests in route S;
earlier: 17.2: Sea None on Great River Valley, notes in 17, 17.1, 18; earlier: 7: Relief pre-selected Hilly, notes in 3, 14, 18, 19; 2: street build grade 20 %; earlier 2026-10-11: 19 Alpine, with the review fixes; 18: map type changes; 17.1: Sea side None; earlier 2026-10-08: 15 any generator, 17 feature side, 16 settings audit; 14: run 6)
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
| Rail: 8.5 % maximum build grade; streets 20 % (Incline slider, read in game 2026-10-12); terraforming brush in game is small; town roads fail on rough terrain | The generator must supply the large flat areas and gentle corridors | the internal notes |
| Navigability (runs 1-2): depth hardly matters (2 m is enough), width does: river-like banks need >= 100 m at the water line (70 m = thin lane only at >= 4 m depth; 40 m never) | Ship rivers 100-200 m wide, 3-6 m deep; other rivers deliberately < 60 m | the internal notes |
| Mod windows have no size parameter and no screen-size query; a mod stylesheet (`*.css.lua`) sets sizes; the native preview is large | The Studio window fits 1920 x 1080 (fixed sizes + scroll area); the preview image is optional or in its own window | the internal notes |
| Map sizes reach 112 x 112 tiles (28.7 km, 51 M heights) | Full-resolution Lua passes are too heavy on the largest maps; work at 8-32 m there and add detail back (INFERENCE) | the internal notes |

## 3. Playability targets (soft; author decision 9a.4)
These are **targets, not limits**: they describe a good starting point at Relief = Gentle and loosen as Relief rises
(Hilly, Mountainous), so difficult maps are possible. The map report shows the numbers; nothing is forced or
"fixed" after the fact. Since 2026-10-12 the window opens at Hilly (author, the internal notes section 7); the targets still
describe Gentle (at Hilly, flat land is 8-36 % on most map types, Delta Lowlands 56 %; seed 1, 11 km; 4-24 % and 51 %
before the middle steps were retuned for flat land the same day, the internal notes section 14).
First values (to be tuned in game):
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
Export, Test set, Save log; Larger window. Forests (Few, Normal, Many) since 2026-10-12, a setting of the
finishing pass; since 2026-10-13 (author, run 9) the check box **Lower tree density** instead.
**Relief pre-selected: Hilly** (author 2026-10-12, the internal notes), the middle of the five steps; the core holds it as data
(`pipeline.DEFAULT_RELIEF`), the Studio starts with it and `pipeline.normalise` uses it when no Relief is given (was
Gentle). Being the most played step, it is in core_baseline since the same day (every map type and `/none` case at
Relief 3 next to 1 and 5: 90 maps; before, no check compared Hilly maps with accepted ones).
> **Note (2026-10-12, author, the internal notes):** the setting's player-visible label is **"Terrain"** (the game's own heading
> for its terrain settings on the new-game page; "relief" is not a word the game uses), in the Studio, strings.json and
> the readmes; the Terrain parameters help line reads "as designed for the map type and the Terrain setting", and the
> Report's "For:" line names the step "terrain Hilly" (`settingsText(cs, true)`; studio_check reads it). Internally it is
> still relief: the settings key, `pipeline.RELIEF` / `DEFAULT_RELIEF`, the settings line in the log (Generate, Apply,
> Export, Test set: "relief Hilly", parsed by `export_check.py`, so older logs read the same), export file names, tools
> and this document's technical text.

> **Note (2026-10-12, author, the internal notes): middle steps retuned so flat land steps evenly too.** Heights and pass grades
> already stepped evenly from Gentle to Mountainous, but flat land (< 3 % slope) was mostly gone at Moderate: at Hilly
> it sat 0.76-0.92 of the way from Gentle to Mountainous (Great River Valley 28.0 / 20.4 / 19.1 / 18.6 / 18.3 %). Now
> Moderate, Hilly and Rugged put it at about 0.25 / 0.5 / 0.75 of the way (mean per type within +-0.08 on 31 of the 33
> type-steps on seeds 7-14, on 27 on seeds 21-30, which no tuning used; single seeds vary, Island Chain most; Great
> River Valley 28.0 / 25.4 / 23.1 / 20.7 / 18.3 %), with the heights still even and Mountain Range's passes on their
> targets. Limits: section 14, "Known limits".
> **Gentle and Mountainous maps are unchanged** (byte-identical; core_baseline: every `/r1` and `/r5` key the same,
> only the 30 `/r3` keys updated). Every Hilly map, the default, changed. Tables, per-type numbers and the method:
> section 14, "Middle steps retuned for flat land".

**Map types (confirmed 9a.2; more may be added). First three: Great River Valley, Delta Lowlands, Mountain Range with
Passes.** Built since (2026-10-06, map editor): Rolling plains, Lake district, Large bays, Peninsulas, Island chain, Coastal
region, Highland plateau (all Temperate list types; the climate-specific ones wait for other climates); since
2026-10-11 Alpine, since 2026-10-12 Sea Strait (section 23; the author may ask for a flowing "Giant River"
later). Full list: Large bays · Peninsulas · Island chain (archipelago) · Coastal region ·
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
| Passes | `passes.lua` | Map types with corridors (Mountain Range, Alpine): each pass is a winding valley axis (the drainage notch follows it); its floor is graded to the Relief's target (2.5 / 3.25 / 4 / 5 / 6 % from Gentle to Mountainous, with a 15 % margin for 4 m roughness) and the hillsides rise from it like from any valley: two valleys meeting at a broad col. Floors get no rock detail (`calm` mask). Every floor is graded on the lowest ground across its width: Alpine from the start (2026-10-11, then the opt-in `preset.passFloorMin`), Mountain Range at Moderate, Hilly and Rugged since 2026-10-12, where the height curve applies, and at every Terrain step since 2026-10-13, when the opt-in was dropped |
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
(`pipeline.RELIEF`, section 12 guideline 3). Hilly is pre-selected since 2026-10-12 (`pipeline.DEFAULT_RELIEF`,
section 7). The middle steps were retuned for flat land on 2026-10-12 (next paragraph).

**Middle steps retuned for flat land (author 2026-10-12, the internal notes: "Yes, retune Moderate to Rugged for flat
land").** Heights (99th percentile, `RELIEF_P99` times the type's factor) and pass grades (`passes.TARGET`) stepped
evenly from Gentle to Mountainous, flat land (< 3 % slope, as `report.lua` measures it) did not: most of it was gone at
Moderate. Gentle's plains lie just under the 3 % line (Great River Valley: half of them at 2-4.4 %), so scaling every
slope with the height (1.5 x at Moderate) pushed them over it at the first step; interpolating the other relief tables
(`HILL_COVER`, `HILL_SHAPE`, `SIDE_SLOPE`,...) could not bring it back while heights stayed even (tested the same day).
**Gentle and Mountainous maps are byte-identical:** only index 2-4 of the relief tables changed, and the two new
per-step numbers are neutral at steps 1 and 5 (core_baseline: all 60 `/r1` and `/r5` keys identical, the `/none` ones
included; the 30 `/r3` keys updated with `--update`).

| Core table (`landform.lua` unless named) | Gentle / Moderate / Hilly / Rugged / Mountainous | Before |
|---|---|---|
| `LAND_SLOPE` (relief cap on small land, mean slope from the coast: Island Chain) | 0.05 / 0.088 / 0.125 / 0.16 / 0.18 | 0.075 / 0.1 / 0.14 in the middle |
| `HILL_AMP` (m, hill height in the hill country) | 85 / 96.25 / 107.5 / 118.75 / 130 (linear) | 100 / 115 / 122.5 in the middle |
| `PLAINS_RELIEF` (new): share of the landform's relief kept by the plains outside the hill-country patches (the patches keep all of it); only on types with `preset.uplands > 0`, so mountain types keep their massifs and belts whole | 1 / 0.67 / 0.6 / 0.6 / 1 | - |
| `RELIEF_BEND` (new): the height scale is curved, x = landform height / its 99th percentile becomes (1 - a) x + a x^2 (tangent above x = 1): low ground rises less steeply, high ground more | 0 / 0.37 / 0.55 / 0.5 / 0 | - |
| Alpine `reliefP99` (m, `shapes.lua`) | 200 / 232 / 255 / 300 / 330 | 240 / 280 / 310 in the middle (put its P99 at 0.37 / 0.70 / 0.90 of the way) |
| `preset.flatKeep` (new, `shapes.lua`): scales `PLAINS_RELIEF` and `RELIEF_BEND` for a type whose flat land answers more strongly | Alpine 0.6, Peninsulas 0.85, others 1 | - |

Unchanged: `RELIEF_P99`, `SLOPE_LIMIT`, `SIDE_SLOPE`, `CHANNEL_AREA`, `HILL_SHAPE`, `HILL_COVER`, `detail.DETAIL_AMP`,
`passes.TARGET`. With the plains factor, the relief scale comes from the geometric mean of the landform's 99th
percentile before and after it, so the height step stays the step's on every type. The hill-country patch mask is made
once in step 2 (it was made in step 3b; same noise and threshold). Pass seeds and hillsides follow the curve and the
plains factor, and at the curved steps every pass floor is graded on the lowest ground across its width, as Alpine's
`passFloorMin`: the curve lowers low ground beside a pass axis more than the axis, and a side valley then
undercut a floor graded on the axis (Mountain Range seed 3: 4.5 / 5.0 / 6.5 % on the 3.25 / 4 / 5 % passes). (Since
2026-10-13 every pass at every step, section 19.1; Mountain Range's maps changed at every step then, the internal notes.)
With Overall height at 0 % (no relief, the map flat at about 1 m) the curve has no inverse: the pass slopes then lie
at the beach level (`unrise` returns 0; it divided by the zero target, and the NaN made every pass-slope comparison
fail, review the same day). The straight path of Gentle and Mountainous still divides by the zero scale there (the
same flat map; left unchanged so those maps stay byte-identical).

**How it was chosen.** Three candidates were tuned, each in its own copy of the core (the chosen one on all 11 types,
11 km, seeds 1-10), then judged on fresh seeds 7-14 (seeds 11-14 new to every tuner) for flat-land evenness, the
other slope classes, P99, passes, look (previews, close-ups) and puddles: (a) relief tables only (`HILL_COVER` /
`HILL_SHAPE`): mesa-like blocks, and flat land still uneven (4 of 88 seed series not monotone); (b) "slopes": Gentle's
heights kept in a fixed share of the land: the best slope-class numbers, but where that share crossed high ground it
cut craters, cones in hollows and quarry-like rims (Mountain Range seed 7, Great River Valley seed 8; 2.5-4.9 % of
Mountain Range land added over 25 % slope), and it missed Delta Lowlands and Alpine; (c) the change above, chosen: it
follows the existing hill-country edges and leaves mountain massifs whole.

**Measured (offline, 11 km, mean of seeds 7-14; position = where the mean sits between Gentle 0 and Mountainous 1,
target 0.25 / 0.5 / 0.75):**

| Map type | Flat % G / Mo / Hi / Ru / Mt, before | Position before | Flat %, after | Position after |
|---|---|---|---|---|
| Great River Valley | 28.0 / 20.4 / 19.1 / 18.6 / 18.3 | 0.78 / 0.92 / 0.97 | 28.0 / 25.4 / 23.1 / 20.7 / 18.3 | 0.27 / 0.50 / 0.75 |
| Delta Lowlands | 68.9 / 57.3 / 50.7 / 48.0 / 45.1 | 0.49 / 0.76 / 0.88 | 68.9 / 61.7 / 56.1 / 52.3 / 45.1 | 0.30 / 0.54 / 0.69 |
| Mountain Range with Passes | 18.8 / 10.1 / 6.5 / 4.9 / 4.0 | 0.59 / 0.83 / 0.94 | 18.8 / 15.6 / 12.7 / 8.5 / 4.0 | 0.21 / 0.41 / 0.70 |
| Alpine | 11.6 / 8.6 / 6.3 / 5.8 / 5.5 | 0.48 / 0.86 / 0.95 | 11.6 / 10.1 / 8.3 / 6.9 / 5.5 | 0.24 / 0.54 / 0.77 |
| Rolling Plains | 51.7 / 33.8 / 23.8 / 21.0 / 19.5 | 0.56 / 0.87 / 0.95 | 51.7 / 44.5 / 35.7 / 28.9 / 19.5 | 0.22 / 0.50 / 0.71 |
| Lake District | 18.3 / 11.1 / 9.2 / 8.1 / 7.4 | 0.66 / 0.84 / 0.94 | 18.3 / 16.9 / 13.0 / 9.6 / 7.4 | 0.13 / 0.49 / 0.80 |
| Large Bays | 17.1 / 6.9 / 4.2 / 3.4 / 2.9 | 0.72 / 0.91 / 0.97 | 17.1 / 13.2 / 10.6 / 6.9 / 2.9 | 0.27 / 0.46 / 0.72 |
| Peninsulas | 17.3 / 6.9 / 4.2 / 3.4 / 2.9 | 0.72 / 0.91 / 0.97 | 17.3 / 14.4 / 10.9 / 6.3 / 2.9 | 0.20 / 0.44 / 0.76 |
| Island Chain | 15.9 / 6.3 / 3.6 / 1.9 / 1.3 | 0.66 / 0.84 / 0.95 | 15.9 / 11.2 / 8.6 / 3.9 / 1.3 | 0.32 / 0.50 / 0.82 |
| Coastal Region | 29.2 / 21.5 / 19.8 / 19.2 / 18.8 | 0.74 / 0.91 / 0.96 | 29.2 / 26.5 / 24.3 / 21.2 / 18.8 | 0.26 / 0.47 / 0.77 |
| Highland Plateau | 24.3 / 11.7 / 8.7 / 7.5 / 6.8 | 0.72 / 0.89 / 0.96 | 24.3 / 20.5 / 15.8 / 10.9 / 6.8 | 0.22 / 0.48 / 0.77 |

Flat land within +-0.08 of the target on 31 of 33 type-steps (before: 0 of 33); on seeds 11-14 alone 28 of 33. On
seeds 21-30, which no tuning used (review the same day, 110 seed series), 27 of 33, and on seeds 21-23 alone 22 (the
old core 0): the misses are Coastal Region 0.40, Island Chain 0.37, Large Bays 0.38 and Peninsulas 0.39 at Hilly, Lake
District 0.10 and Peninsulas 0.15 at Moderate. P99 positions 0.46-0.56 at Hilly on every type (before 0.41-0.68; Alpine's own heights were the outlier). Mountain Range's
passes now meet their targets at the middle steps (steepest 100 m / target 0.98 / 0.98 / 0.97, worst 1.04; before
1.08 / 1.09 / 1.09, worst 1.37); Alpine's stay at 0.99. Land under 8.5 %, very steep land and P99 are monotone over the
steps on every seed series (88 of seeds 7-14, 110 of seeds 21-30); flat land on all 88, but on 105 of the 110 (Known
limits). Ship rivers stay in >= 2 m water on every map; at Relief 2-4 lakes 552
(unchanged), oxbow lakes 340. Checks after the change: core_check, settings_check (4 km all groups and 11 km tune / extremes /
ships: 0 FAIL, the same WARN lines as before, line for line), run_checks 7/7.

**Known limits.** Lake District at Moderate (0.13; 0.10 on seeds 21-30) and Mountain Range at Hilly lie outside
the +-0.08 band; Island Chain and Delta Lowlands at Rugged are borderline; on seeds 21-30 the coastal
types sit low at Hilly (0.37-0.40, see above). **Single seeds vary more than the means show.** On seeds 21-30, 5 of 110
seed series keep slightly more flat land at Moderate than at Gentle (Island Chain seeds 21, 22, 26: 20.5 -> 20.9,
18.27 -> 18.34, 20.4 -> 22.2 %; Lake District seeds 23, 27: +0.2 and +0.3 points; the old core was monotone on all 33
series of seeds 21-23). Island Chain's Hilly position spreads widest (standard deviation 0.24 over the 10 seeds; every
other type 0.15 or less): 0.05-0.23 on seeds 21, 22, 25 and 26, where nearly all flat land goes between Hilly and
Mountainous (seed 21: 20.5 / 20.9 / 19.6 / 9.3 / 1.5 %), and 0.82 on seed 28. The cause is probably the small-land height
cap (`LAND_SLOPE` x reach) together with the plains factor (INFERENCE, not traced). `flatKeep` 0.8 on Island Chain and
Lake District removes the 5 inversions but overshoots (review experiment, seeds 21-30: Island Chain 0.46 / 0.69 / 0.86,
Lake District 0.36 / 0.66 / 0.86), so it was not adopted; a later retune should be judged on the spread per seed as
well as on the mean. Steepness comes late: very steep land sits at 0.57-0.72 of the way at Rugged, so Rugged to Mountainous is the largest step in steepness (everything still monotone).
The middle steps look different: broad plains beside the hill country, coastal lowland flatter than on Gentle, the
highest points of some types higher (the curve steepens high ground; Lake District 14 km Hilly seed `k9oeo2v9g2`: max
395 -> 448 m), and less snow at Hilly (Alpine 5.2 -> 3.1 %, Mountain Range 5.9 -> 3.7 %, Great River Valley 2.0 -> 1.2 %
of land; mean of 10 maps). A rare tiny puddle at the coast is an existing weakness, not new (1 of 396 extra maps at
Moderate to Rugged, seeds 4 and 15-25: Peninsulas seed 4 Hilly after the change, Island Chain seed 24 Moderate
before); a pocket guard limited to the middle steps only moved it and was not adopted. Another one sits on the test
seed at Hilly: Highland Plateau, seed `oeyrx62dl8`, 11 km, one puddle at (`core_check --relief 3`; the old
core has the same one). No routine check covers the middle steps on that seed (run_checks runs core_check at Gentle,
settings_check's shape, extreme and Sea None groups run at Gentle and Mountainous). In game: run 9 (TESTING).

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
2. **Forests** (Few / Normal / Many): already in the approved new-game list (section 7, 9a.3). BUILT 2026-10-12
   (author, the internal notes section 20) as the finishing pass's own parameter `utg_forests`, which scales the tree-density
   curves. Replaced on 2026-10-13 (author, run 9) by the check box **Lower tree density**.

   > **Correction:** the earlier plan here, declaring the vanilla `forest` number
   > (`temperate_import_gen.tree.lua:1016`, feeds "Humidity"), would not work as a Forests setting: it moves one
   > permeability factor of the plains forests by at most 10 % with an unknown sign, its runtime value is unknown, and
   > `forest_mask` does not follow it. The in-game probe it needed (how a gen.lua parameter reaches
   > `param_number`: index or number) is still open: the internal notes.
   > **Answered:** the pass receives its declared parameter as the normalised position.
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
| Great River Valley, Rolling Plains | River comes from | where the big river enters the map (sea / outflow opposite; Great River Valley's sea can be switched off in its own Sea box, 17.2) | high |
| Delta Lowlands, Mountain Range with Passes, Large Bays, Peninsulas, Coastal Region, Highland Plateau | Sea side | the edge with the sea (the range, bays, plateau lie inland from it) | low |
| Lake District | Rivers flow towards | where the rivers leave the map (the fells lie opposite) | low |
| Island Chain | (none) | islands across the whole sea | - |
| Sea Strait | Strait runs | which way the water runs: East-West, North-South, Diagonal SW-NE or NW-SE (no None) | axis |
Mountain Range: the range runs parallel to the sea side (a range "starting" at one edge would cut the passes' design);
its rivers leave the map on the opposite side (anywhere along it since 2026-10-13, section 19.1; at two points before). Code: `shapes.SIDES`, `shapes.TYPES[id].side`, `shapes.orientationFor`;
`pipeline` setting `side` 0..4; the settings text names it only when chosen (export_check parses it). Check:
`tools/settings_check.py` group `sides` (each type x side x 2 seeds at 8 km: the sea, the trunk source or the river
mouths on the chosen edge): 72/72.

### 17.1 Sea side None (author 2026-10-11)
The author asked for a "None" choice of Sea side where it makes sense, particularly on Mountain Range with Passes.
- **Where:** Mountain Range with Passes, Alpine and Highland Plateau (`side.none = true`): their sea is a setting
  around a feature that stands on its own (a range, massifs, a plateau over a lowland). Not on Delta Lowlands, Large
  Bays, Peninsulas or Coastal Region, whose sea IS the feature, nor on the types whose side is not a sea. Great River
  Valley (whose side names where the river comes from) got its own Sea box with None on 2026-10-12.
- **Meaning:** no sea at all. The sea's strip becomes land that keeps the type's fall towards that edge (one-pass
  types: eval skips the sea test; two-pass types: the land function gets the signed distance, negative where the sea
  would be), every node of that edge is an outlet, so the rivers leave the map there as they would have reached the
  sea. The layout is the one with a sea (setup draws the same numbers: range, massifs, passes, plateau and
  escarpment), but rivers, valleys and heights can differ: the new land drains to the edge and joins the relief
  scaling and the hill-cover percentile. Measured on the same seed at 8 km: Mountain Range and Alpine mostly move by a
  few metres (median under 3 m; more where a river takes another course, as at Mountainous on one seed), Highland
  Plateau a lot (most of its land by more than 5 m), since its land is shaped by the distance to the sea. The edge
  comes from the seed (there is no sea to place).
- **Coast roughness** has nothing to roughen without a sea: the coast line is used without its ragged noise
  (`ragScale` 0) and the window shows the slider as "-" (`shapes.inactiveFor`). No relief cap from the coast
  distance (`coastDist` nil), as on the inland types.
- **Values:** pipeline `side` 5 = `shapes.SIDE_NONE`, only where offered (`normalise` turns it into 0 elsewhere); the
  window's sixth Sea side choice; the settings text says `side none` (export_check reads it).
- **Checks:** core_baseline keys `<type>/s<seed>/r<relief>/none` (Mountain Range, Highland Plateau and Alpine, 4 maps
  each, accepted 2026-10-11 after the previews; the 40 earlier maps unchanged); settings_check group `sides`: no sea
  node at Gentle and Mountainous on 2 seeds, and Coast roughness 0 % / 200 % gives the identical map. Both checks fail
  on a core copy where None keeps its sea or keeps the ragged coast (tried 2026-10-11).

### 17.2 Sea None on Great River Valley (author 2026-10-12, the internal notes)
Author: "Also on Great River Valley (the big river leaves the map instead of reaching the sea)."
- **Its own "Sea" box**, directly under "River comes from" and only on Great River Valley (`side.seaChoice = true`):
  "At the river mouth" (pre-selected) or "None"; None shows the no-sea note of 17.1. Why not a sixth "None" in the side
  box, as on Mountain Range: there the box names where the river ENTERS (canonical edge "high"), so "River comes from:
  None" would read as "no river", and None inside the side box would leave the direction to the seed, losing the type's
  main choice. With its own box, "river from the North, no sea" is possible; Random, North, East, South and West keep
  their meaning, and for the same seed and choice the orientation is the one of the map with sea (the seed's roll is
  unchanged), so it is the same layout without the sea. Rejected: moving the None of all four types into a separate
  box (rewrites the 17.1 interface and the log format for no gain to the player). Not chosen (author may ask): carrying
  "no sea" across map type changes (Mountain Range None to Great River Valley Sea None): it would couple two different
  boxes.
- **Meaning:** as 17.1. The sea's strip becomes valley (eval skips the sea test, `s.noSea`): the type's organisation
  field already falls steadily to the low edge and no term depends on the coastline, so the valley simply continues to
  the edge, every node of which is an outlet (`edgeOutlets`, the edge opposite the river's source). The trunk enters
  on the chosen edge as before and leaves the map on the opposite one. Coast roughness has no effect (`ragScale` 0; the
  slider shows "-", "No effect without sea"). The code that assumes a sea does nothing without one (checked in the
  prototype): estuary and `extendMouths` only for sea mouths (the trunk's mouth is about 180 m wide at the edge instead
  of the 288 m flare into the sea; no estuary nodes), the delta only on Delta Lowlands, no shelf, no lake-sea gap; the
  ship river runs to the edge 180 m wide and 5 m deep, as on Rolling Plains.
- **Measured** (offline prototype, the same seed with and without sea, 14 maps at 11 and 16 km): the map changes more
  than on Mountain Range None. Median height change on land 0.4-3.3 m, P90 9.7-47.5 m, 15-32 % of the land moves by
  more than 5 m; the trunk's bends differ along its whole length (INFERENCE: the meander random stream is shared by all
  rivers and the trunk is now longer; the old sea strip joins the relief P99 and the hill-cover percentile; streams near
  the old coast reorganise). More lakes (7 against 3 per 10 maps at Normal, 21 against 15 at Wet), and 3 of the 7 touch
  the map edge (1 of 3 with sea); accepted maps already have such lakes (Mountain Range None 15 of 20, Rolling Plains 4
  of 15), and a gap between lakes and outlet edges would change accepted maps, so that is an author decision, not part of
  this. It stays distinct from Rolling Plains (P99 180-191 m against 73-91 m at Gentle; flat land 29-30 % against
  50-53 %). Generation time -1 % to +22 %. Previews (same seed, with and without sea): `previews/grv_sea_none/`.
- **Values:** pipeline setting `sea` = false (nil = the sea); `normalise` keeps false only on a type with
  `side.seaChoice` and passes nil everywhere else, so no other map can change. It uses an explicit `if`: the idiom
  `cond and false or nil` can never give false (the first prototype did that and kept the sea). `shapes.noSea(type, side,
  sea)`, `shapes.inactiveFor(type, side, sea)`, `shapes.build(..., side, sea)`. Window: `S.settings.sea` 1 (sea) or 2
  (None), sent through `seaSetting` (false or nil, again an explicit `if`); box key `utg-sea-<type>`; every map type
  change resets it to the sea (no other type has the box, so it is never revived on coming back, like the side after
  Island Chain); the settings text adds `, sea none` (logs of every other map read as before; the stale-preview note
  compares these texts, so without it a change of the box would not mark the preview stale; export_check reads it).
  Side 5 remains Sea side None of 17.1 and means nothing on Great River Valley (`normalise` turns it into 0).
- **Checks:** core_baseline keys `great_river_valley/s<seed>/r<relief>/none` (4 maps at Gentle and Mountainous, added
  2026-10-12 with `--add-new` after the 56 earlier maps compared identical; 2 at Hilly the same day, when the baseline
  got Relief 3); settings_check group `sides`: Sea None x River comes from North, East,
  South, West x 2 seeds (no sea node, the trunk's source on the chosen edge and its end on the opposite edge), from the
  seed at Gentle and Mountainous (its end opposite its source: checked since the review of 2026-10-12), Coast roughness 0 % / 200 % identical (the group: 112 cases, 0 FAIL, 0 WARN); a core
  copy where Great River Valley keeps its sea (the idiom in `normalise`) fails all 14 Sea None cases (tried 2026-10-12). studio_check: the scenario "Great
  River Valley, river from the west, Sea None" (report says `sea none`, the no-sea note, Coast roughness without
  effect) and Sea box steps in "map type changes" (box count, choices, key, value after every change, the notes, "-",
  and the core's settings line after Generate on Great River Valley North + None, then Rolling Plains). Seven
  deliberately broken copies (no reset on a type change, no key, no `sea none` in the text, inactive list without the
  sea, the box on every type with a side, the idiom in the window, the idiom in the core) all fail it.

## 18. Map type changes: every control shows what is used (author 2026-10-11)
Author: "When a user changes the map type, ensure all the drop downs and sliders will be used with their current shown
status/choice."
- **One source of truth:** every box and slider is drawn from the window's settings, and what Preview sends to the
  core is built from the same settings (`coreSettings`; the core's `normalise` changes nothing the window shows).
- **Feature side:** an edge the player chose (North, East, South, West or None) is kept across a map type change when
  it names the same edge on the new type (same label and edge, e.g. Sea side on both) and the new type offers the
  choice (None only where offered); otherwise the box shows the new type's **pre-selection**, which the core then gets.
  A type without a side (Island Chain) shows no box and uses none, and the choice is not revived when leaving it.
- **Pre-selected side (author 2026-10-13, the internal notes: "Sea-side option should default to 'None' when Alpine is
  chosen"):** data in the core's side table, `shapes.TYPES[id].side.default` (a setting value; Alpine `SIDE_NONE`, the
  others none = Random), read only by the window: `pipeline.normalise` ignores it, so a request without a side still
  means "from the seed" and every accepted map stays identical (core_baseline unchanged). The window keeps
  `S.settings.side = nil` until the player picks a side, and `sideIndex` shows and sends the current type's
  pre-selection meanwhile, so the window can open on any type and coming back to Alpine shows None again. **Random is
  not carried** (it names no edge), **nor is a pre-selection**: from Random, from River comes from or from Island
  Chain, Alpine shows None; Alpine's pre-selected None does not follow the player to Mountain Range (Random there),
  while a None the player picked on Mountain Range does carry to Alpine and back. Why nil rather than storing the
  default: a stored value cannot tell "chosen" from "pre-selected", so Alpine's None would leak into Mountain Range and
  Highland Plateau and change their default with the order in which the player looked at the types. (INFERENCE:
  picking the None that Alpine already shows may not reach the window, if the game's combo box reports changes only;
  then that None counts as pre-selected, which shows only on the way to Mountain Range or Highland Plateau: they show
  their own Random, and the player picks None there.)
- **Sea (Great River Valley only, 2026-10-12, 17.2):** every map type change puts it back to "At the river mouth", so a
  None is never carried to another type nor revived on coming back; "River comes from" keeps its choice across Great
  River Valley and Rolling Plains (same label and edge) whatever the Sea box shows.
- **Boxes whose choices depend on the map type are keyed by it** (`meta.localKey`, `utg-side-<type>` and
  `utg-ships-<type>`; the Sea box `utg-sea-<type>` too, although its choices are the same, like the others). The game's react layer keys a node by `localKey` (`gui/main/react.lua`: `makeNodeWithProps(recipeId,
  localKey, props)`, honoured for ComboBox and Slider, which are not layout children); the base game keys its own
  parameter widgets the same way (`gui/construction/construction.tl`: uiType + name). A new key makes the engine build
  a new box that shows the current choice, so a box can never keep the previous type's choice or item list on
  screen (the key reaching the engine is in the files; that the engine then builds a new widget is an inference, and run
  7 checks it in game). The base editor's own generator window redraws its parameter boxes from
  its state without keys when the generator changes (`gui/map_editor/map_editor.tl`), so a box's value follows the
  state anyway; the key is the extra guarantee for boxes whose list of choices changes (5 or 6 sides, the default's
  name).
- **Ship rivers:** the first choice names the type's default ("Map type default (One)"), so the box shows what
  "default" gives on this type.
- **Terrain parameters:** values never change with the map type; "-" marks exactly the sliders without effect on
  this type with this side and Sea choice (`shapes.inactiveFor`: the type's list, plus Coast roughness without sea), and
  the notes name the cause ("No effect on this map type" for the type's own list, "No effect without sea" for Coast
  roughness under None, since it works on these types when they have a sea).
- **Check:** `tools/studio_check.py` scenario "map type changes" walks through changes that keep, drop and reset the side
  and through every map type, checks every box and slider against the core's data, generates three times and compares
  the Report's settings line (what the core got) with what was shown. Five deliberately broken copies of the window
  script (side always reset, no keys, inactive list without the side, None everywhere, plain default label) all fail
  it (tried on 2026-10-11). Since 2026-10-13 its expectation model knows chosen versus pre-selected sides,
  and it adds Lake District -> Alpine (None, and the core gets `side none`), Alpine's None -> Mountain Range (Random),
  Random chosen on Mountain Range -> Alpine (None), Island Chain -> Alpine (None), South chosen on Alpine kept through
  Highland Plateau (generated: `side south`); the main scenario checks the side box shows the type's pre-selection as
  soon as the type is chosen (Alpine None). Planted faults that all fail it: the core data without the pre-selection,
  the window ignoring it, Random carried, the pre-selection stored as a choice (and carried to Mountain Range), a chosen
  edge no longer carried.
- **Relief tooltip:** says where snow starts for which types (Alpine's peaks from Gentle, the highest hills of most
  others from Hilly), so the hint is true whatever map type is chosen. 2026-10-12: it also names Hilly as the middle
  step (pre-selected, section 7) and Gentle as the one with the most flat land; the snow wording was corrected at the
  same time (highest point above 330 m on seed 1, 11 km: 1 of 11 types at Gentle, 3 at Moderate, 8 at Hilly).

## 19. Alpine (author 2026-10-09; built 2026-10-11)
**Request:** a map type for an alpine region like the game's own: start from Mountain Range with Passes (graded passes,
rivers in valleys, Sea side, playability first) and tune it towards a vanilla Temperate map: broken-up massifs and
peaks over high ground instead of one belt, more mountain area, snow on the peaks at Gentle (the default Relief then;
Hilly since 2026-10-12), slope mix and height near vanilla's (medium 16 km map: flat 11.4 %, rail 28 %, steep 36.1 %,
very steep 24.5 %, P99 333 m, r256 41 m, b384 36 m; `tools/scale_check.py`). Vanilla is mostly low hill country
(median 27 m, P90 109 m) with a few massifs: 1 % of its land is at or above 330 m, the highest point 471 m.

**How it was chosen.** Three concepts were each tuned in its own copy of the core against those numbers (offline,
16 km, three seeds), then judged by three independent reviewers who re-measured everything on fresh seeds:
| Concept | Idea | Gentle distance to vanilla | Weak point found by the review |
|---|---|---|---|
| A massif field | explicit massifs (count by map area, warped elliptic cones in B, high uplift, lifted aprons), a loose chain of them as the main divide, passes from the coastal plain to the far edge | 0.084 | passes over target on some fresh seeds (Gentle up to 4 %, Mountainous up to 8.9 %); 15 km routes nearly straight |
| B broken range | Mountain Range's belt cut into 3-7 massifs plus outliers, domes by lift | 0.080 | still reads as the old range line; fewer town sites reachable by rail |
| C percentile mask | a slow noise field cut at percentiles (fixed massif and upland shares), passes at the lowest col | 0.067 | pass outliers (Gentle 4.4 %, Mountainous 9.3 %); 2 of 12 seeds without snow; star summits, crater-like basins |
The look and playability reviews chose A (most distinct massifs, closest to vanilla's separate alpine massifs; the
largest share of land and town sites a railway can reach from the passes); the numbers review chose B (the only one
inside every limit, thanks to its pass-floor fix). All three recommended the same grafts.

**As built = A + three grafts:**
1. **Pass floors on the lowest ground** (`preset.passFloorMin`, from B; `passes.lua` window, `landform.lua` passes it):
   a floor graded on the ground of its axis alone ran on the rim of a side valley inside its width, up to 4 % at Gentle
   and 9 % at Mountainous on some seeds. Opt-in at first, so every accepted map stayed identical. Mountain Range had
   the same flaw (4.0 % at Gentle, 8.4 % at Mountainous on some 16 km seeds); it got the rule at its curved middle
   steps on 2026-10-12 and at every step on 2026-10-13, when the rule became every pass's and the
   opt-in was dropped.
2. **Far-edge outlets** (`s.farOutlets`, from C; `shapes.build` makes every node of the far edge an outlet, as for the
   Sea side None edge): rivers beyond the divide leave wherever they reach the far edge instead of running along it to
   two points (far-edge water 4-13 % -> about 1 %). It also removed A's last pass outlier. Mountain Range too since
   2026-10-13.
3. **Long routes that bend:** the passes keep running from the coastal plain to the far edge (they join coast and
   hinterland into one rail network; shorter, Mountain Range-length routes cut that reach from 38 % to 27 % of the
   land and ended in dead-end cuttings on some seeds), but bend like valleys (bends of ~4 km, up to a tenth of the map
   width) instead of wandering +-250 m.

After an independent review of the finished work two more fixes followed: the pass foot stays at least 200 m above
the last sea point on its axis (the eval's own sea test, so the ragged shore counts; a foot in the sea graded its
first 100 m over target on small maps and at high Coast roughness, 2.7-3.0 % at Gentle, now 2.2-2.5 %), and a
massif keeps a smaller clearance from the passes on maps under 7.5 km across (600 m or 8 % of the width), so narrow
maps still get massifs.

**Numbers (offline, 16 km; `scale_check`, plus pass scans on 12 Gentle and 9 Mountainous seeds):**
| | Gentle (3 seeds) | Mountainous (3 seeds) | vanilla |
|---|---|---|---|
| flat / rail / steep / very steep % | 11.1 / 30.9 / 36.1 / 22.0 | 5.7 / 13.8 / 33.9 / 46.6 | 11.4 / 28.0 / 36.1 / 24.5 |
| P99 / max m | 334 / 482, range 464-497 | 541 / 802, range 785-827 | 333 / 471 |
| land >= 330 m (snow) | 1.1 % | 8.6 % | 1.05 % |
| distance to vanilla | 0.09 (Mountain Range 0.34) | - | 0 |
| steepest pass, 12 / 9 seeds | 2.57 % (target 2.5 %) | 6.14 % (target 6 %) | - |
Sea side None gives about the same numbers on the default seed (P99 314 m, max 490 m, passes 2.6 %); Hilly passes
4.1 % (target 4 %). Rail reach from the passes at a 4 % limit: 38 % of the land and 84 % of town sites at Gentle
(Mountain Range 43 % / 85 %), 12 % / 74 % at Mountainous (Mountain Range 2.5 % / 39 %). Generation time about
Mountain Range's (1.05-1.1x).

**Settings:** relief 1.5 with per-step heights `reliefP99` 200 / 232 / 255 / 300 / 330 (the lift and hills come on
top; the middle steps were 240 / 280 / 310 until 2026-10-12, when they were set so the height and the flat land step
evenly, with `flatKeep` 0.6, section 14, the internal notes), `slope` 2.1, about twice the base slope limit for the steep massif flanks (capped at 1.0 from Hilly up, so the
higher steps gain less), dense channels 0.18, rivers 0.6, lakes 0.6, valley 0.9, lift 0.9. Every Terrain parameter
acts on Alpine (settings_check 11 km); Coast roughness only with a sea. **Sea side None is pre-selected** in the
window (author 2026-10-13, the internal notes `side.default`, section 18): an alpine region stands on its own, and a chosen
North / East / South / West still works as before; the core's default (no side = from the seed) and every accepted
Alpine map are unchanged.

**Known limits (offline; in game: run 7):** median and P90 heights stay above vanilla's (63 / 186 m against 27 / 109 m):
our lowland rises on gentle valley sides instead of vanilla's 0-4 m plains, and lowering it cost flat land or the
slope mix; relief at 256 m and 0.4-1 km is 15-16 % under vanilla; summits show radial ridges (the hillslope model, as on
Mountain Range); the long routes cross more rivers and now and then a lake (bridged in the report); on maps under
about 4 km across the massifs are small and the peaks may stay below the snow line, and tiny maps (4 km) have no
rivers, as on Mountain Range.

**Core changes this needed (all default-preserving, the 48 other accepted maps identical):** eval's 4th value = lift;
preset `reliefP99`, `slope`, `passFloorMin` (dropped 2026-10-13: every pass's rule, 19.1); setup flag `s.farOutlets`;
setup gets the coast roughness as a 5th argument. Checks: core_baseline keys `alpine/...` (8 maps), core_check expects two passes on Alpine, settings_check
`sides` covers Alpine and its None.

### 19.1 Mountain Range gets Alpine's pass floors and far-edge outlets (author 2026-10-13, run 9, the internal notes)
**Decision:** "Yes, use both on Mountain Range", at every Terrain step. Before, Mountain Range's passes ran over their
target at Gentle and Mountainous (the floor graded on the ground of its axis alone ran on the rim of a side valley; the
middle steps had the fix since 2026-10-12, section 14), and the rivers beyond the range ran along the far edge to two
outlet points.

**What changed (core):**
1. **Every pass floor is graded on the lowest ground across its width** (+-70 m, half of `landform.PASS_FLOOR`;
   `passes.profile`): `landform.lua` always passes the window. The opt-in `preset.passFloorMin` (Alpine) and the
   curved-step condition are gone, since every map type with passes now uses it. Only Mountain Range at Gentle and
   Mountainous changes from this: Alpine always had it, Mountain Range's middle steps since 2026-10-12.
2. **Far-edge outlets on Mountain Range** (`s.farOutlets`, as Alpine): every node of the far edge is an outlet, so
   rivers leave wherever they reach it. The two random draws for the old outlet points were the last of setup and
   nothing draws from that stream afterwards, so the range, the passes and the coast are where they were; the
   drainage beyond the range changes at every step.

**Numbers (offline, 16 km, seeds 11, 22,..., 88; 8 maps and 16 passes per step; the steepest 100 m of each pass from
the report, the land numbers from `scale_check.metrics`):**
| Terrain (target) | Mean pass grade % | Steepest pass % | Passes over target (by more than 2 %), of 16 | Highest col, mean |
|---|---|---|---|---|
| Gentle (2.5 %) | 2.70 -> 2.47 | 3.07 -> 2.63 | 12 -> 3 | 80 -> 76 m |
| Moderate (3.25 %) | 3.19 -> 3.19 | 3.27 -> 3.27 | 2 -> 2 | 90 -> 90 m |
| Hilly (4 %) | 3.92 -> 3.92 | 4.03 -> 4.03 | 2 -> 2 | 102 -> 101 m |
| Rugged (5 %) | 4.91 -> 4.91 | 5.03 -> 5.03 | 3 -> 3 | 121 -> 120 m |
| Mountainous (6 %) | 6.34 -> 5.90 | 6.81 -> 6.04 | 12 -> 3 | 171 -> 165 m |

| Terrain | Flat / rail / steep / very steep % | P90 / P99 / max m |
|---|---|---|
| Gentle | 19.4 / 29.9 / 40.6 / 10.1 -> 19.0 / 30.2 / 40.7 / 10.0 | 148 / 247 / 326, unchanged |
| Moderate | 15.8 / 24.8 / 37.4 / 22.0 -> 15.3 / 25.0 / 37.9 / 21.8 | 184 / 355 / 519 -> 183 / 355 / 519 |
| Hilly | 12.8 / 21.4 / 35.5 / 30.3 -> 12.2 / 21.6 / 36.1 / 30.1 | 218 / 458 / 689 -> 217 / 458 / 687 |
| Rugged | 9.1 / 20.5 / 33.1 / 37.4 -> 8.4 / 21.0 / 33.6 / 37.1 | 266 / 563 / 847, unchanged |
| Mountainous | 4.9 / 12.4 / 33.3 / 49.3 -> 4.2 / 12.7 / 34.0 / 49.0 | 385 / 687 / 963 -> 384 / 687 / 963 |
Snow (land at or above 330 m) unchanged: 0.01 / 1.6 / 4.0 / 6.7 / 13.2 %. Far edge (the same at every step: the
drainage does not depend on it): water in the 300 m band along the far edge 8.0 -> 0.6 % (single maps 1.9-18.7 %
before), separate water crossings of the edge 5.8 -> 2.4, river course within 250 m of the edge 3.7 -> 0.8 km, trunk
rivers leaving there 1.5 -> 2.4, rivers per map 6.9 -> 6.4. **Sea side None** gives the same picture: passes at
Gentle 2.72 -> 2.47 % (steepest 3.10 -> 2.60 %, 13 -> 3 over target) and Mountainous 6.33 -> 5.89 % (6.85 -> 6.05 %,
12 -> 3), the middle steps unchanged; flat land 20.0 / 16.4 / 13.4 / 9.8 / 5.6 -> 19.5 / 15.7 / 12.7 / 8.9 / 4.7 %;
far-edge band water 8.2 -> 0.6 %. No puddles before or after.

**Side effects (accepted with the decision):**
- **Flat land 0.4-0.9 points lower at every step:** the rivers that ran along the far edge had floodplains; the short
  rivers that now leave straight across it have less. The steps stay even: 0.25 / 0.46 / 0.72 of the way from Gentle to
  Mountainous (before 0.25 / 0.46 / 0.71; section 14; the same with Sea side None).
- **Fewer, shorter rivers on some seeds:** small catchments beyond the range now leave the map one by one instead of
  joining along the edge (11 km accepted map seed 2: rivers 3 -> 2, river length 11.6 -> 5.1 km, flat land at
  Mountainous 4.7 -> 2.9 %, and its second pass's col 67 -> 81 m at Gentle, still on target).
- **Small maps:** at 4 km, 1 of 16 seeds had a river before (seed 3), none now, as on Alpine (section 19, "Known
  limits"). settings_check (4 km) has 25 new WARN lines, all on that one map (tune group, seed 3, Hilly: "no rivers" and
  the river sliders without effect there); every other line is the same, and at 11 km all are identical.
- **Left over target:** 3 of 16 passes at Gentle and at Mountainous, all within 0.05 points of the target but one:
  Gentle seed 11, 2.63 % (2.60 % with Sea side None), where the floor itself is graded to 2.1 % and a 0.5 m notch at
  the bottom of a valley crossing (the final map's 4 m roughness, which `passes.MARGIN` covers elsewhere) steepens the
  100 m around it.

**Checks:** core_baseline: exactly the 12 Mountain Range keys changed (seeds 1 and 2 x Gentle / Hilly / Mountainous,
with and without `/none`; updated with `--update`, JSON diff against the previous commit: no other key changed, the 8
Alpine keys identical); settings_check as above; core_check; run_checks 7/7. In game: not yet seen.

## 20. Lower tree density (author 2026-10-13, run 9; first built as Forests Few / Normal / Many, the internal notes 2026-10-12)
**Request:** "The forest option appears to change the density of the trees, which might help players with
lower-spec computers. For now, change the forest drop down to a checkbox that is 'Lower Tree Density', with a tooltip
on hover saying that the forest mask is identical, but tree asset density is reduced for lower-spec systems." Forests
are drawn by the finishing pass (the game's own Temperate tree logic, `tools/build_finish_tree.py`), not by the terrain
core, so the setting belongs to the pass.

**The first version, Forests, and what run 9 showed.** The pass declared `utg_forests` (ComboBox Few /
Normal / Many) and multiplied the tree-density curves by 0.5 / 1 / 2 (river trees: Few half the density, Many a band
twice as wide). In game (run 9, one Great River Valley Hilly map, river from the West, Sea None, seed `u5pip6mqlu`):
- **The Import biomes mode hands the pass its declared parameter, normalised:** `forest_mask` covered 24 % (Few), 39 %
  (Normal) and 44 % (Many) of the map, mean height there 63 / 104 / 113 m (the conifer terms on high ground followed
  the setting). A raw index (0 / 1 / 2 or 1 / 2 / 3) would have given Normal and Many the same factor 2 through the two
  clamped remaps, so the value is not a raw index. Which normalisation is not shown by this run (review 2026-10-13):
  it is consistent with (index - 1) / (count - 1), the design rule (inferred from generator files read for the
  research notes), but index / count gives three ordered values too.
- **Trees cost time:** Apply took 1.8 / 2.8 / 4.4 s. Hence the author's request: a lower density for slower computers,
  with the forests where they are.
- **Why `forest_mask` moved:** the hill-tree and conifer curves also feed `forest_mask` (hill trees through `New
  Normalize maps #288`, conifers through the clamped remaps `New Remap map #4`, 0..0.15, and `#309`, 0..0.08), so
  scaling the curves scaled it too.

**Why not the vanilla `forest` number** (corrects 16.3 item 2): the import tree reads `param_number "forest"` (dummy 1)
into "Humidity", but no gen.lua of the game declares it, so its value at runtime is unknown (the dummy, or 0). Traced
through the graph it only moves the y-scale of the plains-forest permeability curve from 0.320 to 0.353 (+10 %) and the
percolation seed density by -0.3 % over its whole range, and whether a percolation cluster becomes forest or clearing is
unknown, so even the direction of the effect is unknown. It stays untouched and undeclared.

**Design (built 2026-10-13):**
- **Parameter:** `utg_forests` (key kept) in the pass's gen.lua, values Normal / Lower, `defaultIndex` 1 (1-based); by
  the design rule the pass gets 0 (Normal) or 1 (Lower). One clamped `remap_number` from to gives the
  factor (the vanilla slider idiom; vanilla "Mountain input range #0" maps 0..1 to 1..0.5 too): exactly 1.0 and 0.5 by
  `mathutil.mapClamp` (`clamp(c + (d - c) * ((x - a) / (b - a)), min, max)`; Normal's 0 is clamped to the bound 1.0,
  Lower's fraction is exactly 1). It reads from 0.5, not 0 (review 2026-10-13), so that Normal is exactly 1.0 under
  index / count too (0.5 / 1): from that formula would have thinned every map's trees to 0.75 at Normal without
  anyone seeing it. Under the third formula run 9 leaves open, (index - 1) / count (0 / 0.5), Lower would stay at 1.0:
  a visible failure (the internal notes step 1c), never a change of the approved Normal pass. The `param_number` dummy is
  0, so the node editor shows Normal. `uiType` stays ComboBox: the game never draws this parameter (the base Import
  biomes tab shows no widgets for an import generator's parameters; the Studio draws its own check box), and ComboBox
  is the type this gen.lua loaded with in run 9. CheckBox is a `ScriptParamType` too, and the base GUI draws it as two
  states, index 1 unticked and 2 ticked (`gui/main/script_param_util.tl` 208-212, 515-541), but no game data file
  declares one, so it is not used before it is seen loading: a pass that failed to load would leave Temperate without
  trees.
- **Only the tree assets thin out:**

| Trees | Scaled where | Normal / Lower |
|---|---|---|
| Hill trees | density map `New Multiply map #289`, for its asset reader `compare_map0` only | x 1 / x 0.5 |
| Conifers (by height and on lake cliffs) | density map `add coast cliff trees` (the MAX of both), for its asset reader `dithering` only | x 1 / x 0.5 |
| Plains trees | curve `plain trees density` (x: the dithering threshold 0.1) | 10 / 5 % of the cells |
| Single trees | `single tree density` (`to` point, 0.0007 per cell) | 0.0007 / 0.00035 |
| River trees | curve `utg river tree falloff steps` (y: density; x, the band, unchanged) | x 1 / x 0.5, same band |

- **`forest_mask` is the same for both values.** The two densities that also feed it are scaled as MAPS where the asset
  path leaves the `forest_mask` path: a `map_clamp_map` from to (0, factor), unclamped (its `to` point wired, as
  for single trees), read only by the asset-path reader; the `forest_mask` branch keeps the unscaled map. `compare_map`
  GREATER gives 1 where the density beats the dithering noise, so half the map gives half the trees, as half the
  curves did (MAX(k a, k b) = k MAX(a, b)). Plains, single and river trees feed only the assets, so their curves stay
  scaled (`scale_pointcloud`, both factor sockets wired). The same holds for every other data map and the biome raster:
  none of them has the parameter upstream.
- **Normal is exactly the approved pass** (runs 4-6, 9, 12-13): every factor is exactly 1.0, and with the exact x1
  scales taken out, the graph feeding every output (the tree assets and all 12 data-map and biome outputs) equals the
  Forests pass at Normal node for node (offline comparison, 2026-10-13).
- **Studio:** a check box **Lower tree density** in a row labelled **Trees** (key `utg-lower-trees`) where the Forests
  box was (after the side and Sea boxes), only for this mod's generator on a climate whose finishing pass declares
  `utg_forests` (read from the generator rep as the base editor reads a generator's parameters; a draft pass shipped as
  built declares none, so its climate gets no box and nothing is sent). Tooltip: "Fewer tree models for lower-spec
  computers (about half). Where forests grow stays the same; only how many trees are placed changes."
  `S.settings.trees` is the pass's 1-based index (1 unticked, 2 ticked), sent as `params = { utg_forests = 1 | 2 }`. It
  is not part of `settingsText`, so heights, their logs, export names and the baselines do not depend on it, and a
  change alone makes Preview run only the finishing pass again (no Generate); the stale-preview note compares the
  state of the pass in hand (`S.requestTrees`, kept when the window closes). The Preview, Apply and Run test log lines
  name it ("trees normal" / "trees lower"); Apply names the state the ready map was finished with (since section 21
  Apply first re-runs the pass when the box changed, so that state is always the box's).
- **Checks:** `tools/build_finish_tree.py --check` (run_checks "finish"): the shipped tree, gen.lua and strings.json
  equal the build; lint clean (shipped pass and the three drafts); (a) none of the 12 data-map and biome outputs
  (`forest_mask`, `biome0..4`, `biome4_mountains`, `biome4_no_mountains`, `river_mask`, the three `output_biomes`) has
  the parameter upstream, while the tree assets do (graph reachability); (b) every scale point is wired where designed
  and every factor is exactly 1.0 at Normal and 0.5 at Lower, under both (index - 1) / (count - 1) and index / count;
  since the run 9 review (c) every kind of tree the assets output places (the combine_map / add_map chain into
  `assets_output.forest`: 6 kinds; rocks are not trees) has the parameter upstream of its own inputs, so a density
  left out of the builder's lists cannot pass, and (d) every declared `uiType` is a `ScriptParamType` (case-insensitive,
  vanilla writes "SLIDER" and "Slider"; `gen_graph.lint` checks only `defaultIndex`), the tree density's is ComboBox,
  and the gen.lua default and the node's dummy both give the factor 1.0. Broken copies (the hill curve scaled as before,
  `forest_mask`'s reader on the scaled conifers, a factor of 1.0000001 or 0.999 at Normal or 0.6 at Lower, a clamped
  scaler, the asset reader bypassing it, single or river trees unscaled; since the review also the remap from,
  the default or the dummy at Lower, a misspelt uiType, CheckBox, hill trees, conifers, plains or river trees left out
  of the lists, three values) all fail it. studio_check: the box (unticked, its label
  and tooltip; only where a pass declares the parameter: not on Dry, not for a game generator, not for a pass without
  it; kept through map type changes), `utg_forests = 1` in the first preview; ticked: the stale note, then Preview runs
  only the pass, with `utg_forests = 2`; the log lines; the note after reopening the window; Apply naming the ready
  map's state. Broken copies of the window script (0 / 1 sent instead of 1 / 2, the parameter always sent, the box on
  every climate, no stale note, ticked by default, Apply naming the box, the box inverted, reset by a map type change,
  the wrong state shown, no tooltip) all fail it.
- **In game: the internal notes ** (the same map unticked and ticked: equal `data map forest_mask` lines, visibly fewer
  trees, a shorter Apply).
- **Limits:** "about half" is statistical (each tree is placed with half the probability, still spread evenly by the
  dithering); the plains-forest patches (percolation) are the forest areas and stay as they are.

## 21. Apply to map makes the preview first (author 2026-10-13, run 9)
**Request:** "changing the forest option and hitting apply to map produces no change, contrary to the tooltip
when hovered over apply-to-map button. Should 'Apply to map' button also run the preview button task silently?" -
answered yes. Before, Apply put in the ready preview whatever the settings had become since (only the note "Settings
changed since the last Preview" said so), and it was greyed out until a preview was ready.

**Design (built 2026-10-13, window only; the core and the finishing pass are unchanged):**
- **One notion of "the map in hand is current"** for the stale note, the filled button and Apply: `settingsChanged()`
  (this mod's generator: the terrain settings against the result, the tree density against the finishing pass in hand;
  a game generator: its settings against the last request's) and `applyReadyNow()` (not changed, and a ready preview, or
  the result on a climate without a finishing pass). The old render-only stale code moved into `settingsChanged`.
- **Apply when the map is current:** as before (immediately). **Otherwise** `startApplyAfterPreview` runs exactly what
  Preview runs (`previewClicked`: Generate when the terrain settings changed, else only the finishing pass, e.g. after
  Lower tree density; a game generator's preview), unless a preview of these settings is already being made
  (`previewRunning`: Generate, the frame before the pass when the settings still match the result just generated, the
  pass or a game generator's preview), then sets
  `S.applyAfter = { text, since }` with the settings line it waits for, and the status reads "Making the preview, then
  applying..."; the note line under the tabs says "Apply to map waits for this preview, then applies it."
- **The step function** (`stepApplyAfter`, every frame after Generate / pass steps) cancels the wait when the current
  settings line (`currentSettingsLine`: the terrain settings plus the tree density, or the generator's settings) differs
  from the one clicked, or `settingsChanged()` - so a change even during Generate cancels it, and the preview of the
  older settings is never applied; it calls the ordinary `apply()` as soon as `applyReadyNow()` holds, so the existing
  guards, the Undo snapshot of the world as it is at that moment, and Keep towns / Keep industries as ticked then all
  hold; it cancels when nothing makes that map any more (Generate or the preview failed: "Nothing applied." plus the
  reason) or after 180 s without the preview (Generate not counted), so the buttons cannot stay locked. Closing the
  window (its preview stops with it; a closed window must not change the map later) and switching the generator cancel
  it too.
- **A cancel by a settings change stays on the note line** (run 9 review): "Settings changed while the preview was being
  made: nothing applied. Press Apply to map again." replaces the stale note until the next Preview or Apply click
  (`S.applyCancelled`). On the status line alone it lasted one frame: Generate's progress and then the preview's own
  "Preview ready. Apply to map..." replaced it, which read as if Apply would now put that older preview in.
- **The frame between a Preview's Generate and its pass** (run 9 review): that pass is for the result just generated,
  so `previewRunning` counts it only while the settings still match that result; Apply clicked in that frame after a
  change during the Generate generates again instead of waiting for the older pass and cancelling itself. A new
  Generate also drops a pass still due for the result it replaces (`startGenerate`; without coroutines that pass
  would otherwise run once more).
- **Buttons:** Apply is enabled whenever Preview is; a waiting Apply counts as busy, like Run test, so Preview, Apply,
  Undo, Test set and Run test wait (their handlers refuse as well; Preview's since the run 9 review: a pass it started
  would be the one the wait applies). The filled button is Apply only when
  `applyReadyNow()`. Tooltip: "Makes the preview for the current settings first (as Preview does), then puts that map
  on your map." when it would refresh, "Puts the previewed map on your map. Forests and biomes are added now; the
  preview shows the land only." when current (on a climate without a finishing pass: the heights), "Wait for the
  current work to finish." while busy.
- **Run test** (debug) applies only the map it previewed (`apply(..., noRefresh)`): when a setting changed during the
  test it stops ("Run test stopped: the settings changed during the test") instead of applying an outdated map, as it
  did before, or starting another preview.
- **Rejected:** applying the outdated ready map with a warning (the author's complaint); cancelling Apply on a Preview
  click (Preview is greyed out while Apply waits and its handler refuses, so the question does not arise); restarting
  the wait after a settings change (the player changed something after deciding: they press Apply again).
- **Checks:** `tools/studio_check.py` two scenarios "Apply without a preview or after a change" (Temperate with the
  finishing pass, Dry with heights only): Apply without a preview (enabled, tooltip, status, note, Generate, the pass, the
  applied map is that preview's; a second click starts nothing; Apply and Preview greyed out while it waits; then Apply
  is the filled button with the "Puts the previewed map" tooltip; Undo restores the world as it was when the map went
  in), after a seed change
  (generates again; the new map goes in, never the ready older one: tag, heights, Report, export name), after a
  tree-density-only change (no Generate, the pass again with Lower, its map applied, "trees lower"), a map type change
  and a tree density change while it waits (cancelled; the outdated preview never goes in), Undo and Run test refused
  while it waits, closing the window cancels it, a setting changed during Run test stops the test (nothing applied,
  nothing generated). The main scenario: Apply during the preview waits for that preview (no new Generate or preview)
  and applies it on the next frame; after Run test, unticking Lower tree density and Apply re-runs the pass with
  Normal and applies that map. The game generator scenario: Apply after a parameter change previews again and applies
  the new map. Planted faults (2026-10-13, scratch copies of the window script): the old behaviour (Apply applies the
  ready map whatever the settings, refuses without one, greyed out until a preview), readiness ignoring a settings
  change, no cancel on a settings change, closing the window keeping the wait, the wait not counted as busy, Undo
  allowed while waiting, a new preview instead of waiting for the running one, Run test refreshing, the tree density
  missing from the waited-for line all fail it. One planted fault does not: removing the refusal of a second Apply click
  while waiting, which changes nothing a player can see (during Generate the old "Still generating." guard refuses the
  click; during the pass it would re-arm the same wait).
  **Since the run 9 review** the Temperate scenario also checks: the world edited and Keep towns ticked while Apply
  waits (Undo restores the edited world, the towns stay: the snapshot and the boxes are taken when the map goes in, not
  at the click), Preview refused while Apply waits, the box changed while a Preview's pass runs and then Apply (the pass
  again with Lower, applied, nothing cancelled), the cancel note kept after the preview is made and cleared by the next
  Apply click, a pass that cannot start while Apply waits (no biome file: the wait ends at once with the reason, the
  buttons free), the 180 s timeout on a faked wall clock (studio_check `FAKE_TIME`: Generate frames "take" 500 s and
  do not count; 90 s into the pass it still waits, at 190 s it gives up; the pass answering later applies nothing),
  and Apply in the frame between a Preview's Generate and its pass after a seed change (a new Generate, the new map
  applied). Planted faults that now fail it: readiness trusting a running pass after a change, the Undo snapshot or
  Keep boxes taken at the click, the timeout counting Generate or never firing, no cancel when the pass cannot start,
  the cancel note not set or never cleared, Preview's refusal removed, the frame-between race. Not caught: a Generate
  keeping a pass due for the replaced result (an extra pass without coroutines, nothing applied wrongly).
- **In game: the internal notes.**

## 22. Terrain parameter tooltips (author 2026-10-13, the internal notes)
**Request:** "'Hill Country' and 'Hill Height' need at least a tooltip explaining what they do." All ten sliders got
one, on the slider and on its name (the base game puts tooltips on sliders too: `gui/music_player/music_player.tl`),
written for players with no terrain-generation background: what the slider does on the map, which way helps building
(railways, towns), and what 0 % or the maximum gives where that is useful. Each follows the core's real use of the
multiplier (`pipeline.TUNE`): Overall height = the Terrain step's height target, with the hills and raised ground
(0 %: almost flat); Hill country = the share of the land in hill-country patches (`landform.HILL_COVER`, 50-60 % at
100 %, all of it at 200 %) and not their height; Hill height = how tall those hills are (`HILL_AMP`), not where;
Surface detail = metre-scale bumps on hill country and steep ground (none on plains, floodplains, beaches, pass
floors); Erosion = gullies deeper on steeper slopes, 0 % off; Coast roughness = the ragged coast noise, none without
sea; Rivers = the drained area a river needs (more streams reaching further up); Lakes = lakes wanted on the rivers,
natural basins only (0 %: none apart from oxbow lakes, which this slider does not control); River bends = meander
strength (0 %: only the valley's gentle curve); Valley width = floodplain and valley-side width. Texts in `TUNE_TIPS`
(window script), keys in strings.json; studio_check's strings check reads `TUNE_TIPS` like `TUNE_LABELS`, and the main
scenario checks that every slider and its name carry a tooltip and that Hill country and Hill height name each other
(planted faults: no tooltips; Hill height not naming Hill country: both fail it). The extended guide's slider table
says the same in more words.

## 23. Sea Strait (author 2026-10-12, the internal notes built offline the same day)
**Request:** a player asked for a map split in half by a giant river or strait, east-west first (1:3 maps and longer),
also north-south or diagonal. Three concepts were prototyped and judged (Giant River, Sea Strait, Rift Sound;
the internal notes); the proposal: **Sea Strait**, built on the Strait prototype with
the Giant River's banks, bends and islands and the Rift's cell-aware narrows. **Author decisions:** narrows at
least 300 m wide, so only the player bridges the strait (the game's own road links between towns stop at 250 m,
`mod.script.tl:113`; that a low bridge would block ships is an inference); East-West means the water runs from the
west edge to the east edge, land north and south, plus North-South and two diagonals; a flowing "Giant River" type
may follow later, not now.

**What the player gets** (INFO line): "A sea strait splits the map from edge to edge: wide sounds for ships and ferries,
a few narrows for bridges, flat shores on both sides." Map type id `sea_strait`, label "Sea Strait", the twelfth entry,
at the END of `shapes.ORDER` (every other type keeps its place in the Map type box). The side box is **Strait runs**:
Random, East-West, North-South, Diagonal SW-NE, Diagonal NW-SE (pipeline `side` 0-4; `side.edge = "axis"`,
`side.choices`, `side.names` = `ew`, `ns`, `swne`, `nwse` for the settings text, `shapes.sideName`). No None: the sea is
the type. Ship rivers default None (the strait is the ship water, as on Large Bays). Every Terrain parameter acts on it
(settings_check at 11 km: no dead slider).

**Review (2026-10-12, after the first build):** two evaluations (fresh seeds and look/integration) found the narrows
man-made (each an exact X of two headlands with straight 2-2.5 km flanks, right-angled tips, box basins joined by
canal stubs) and cliffs of 9-17 m at every bridge abutment (the lane's 6 m banks cut the bluff's foot); pointed capes
with low banks and short landings on 28.7 km squares and 16 km diagonals; islands on 4 of 800 maps; the smaller bank's
median share at 0.343-0.350 on some 8 km maps; no harbour coast on 1.5 km crossings. The narrows were redesigned (one
broad headland per narrows, the banks taking turns, rounded tips, bowed and wandering flanks, roughness across the
shore), the lane's banks raised to 24 m, the bends centred on the median, the land zones of short crossings shrunk,
islands allowed closer to the narrows; strait_check gained the landing, cliff, straight-shore and island targets that
would have caught it. Every other accepted map is unchanged (core_baseline 90/90).

**Review round 2 (2026-10-12, after the fixes):** the look evaluation found the diagonals drawn as square ponds joined
by straight canals (BLOCKER): the bank rule (each bank at least 0.33 D, measured from the map edge along the section)
held 21-45 % of a 16 km diagonal's outline, and a shore held there runs parallel to that map edge; a 16 km diagonal got
3 narrows only 4.7-5.1 km apart (round(L / 7 km)), so its basins were as long as wide; and a headland's flanks, 51-68
degrees to the strait, lie north-south or east-west on a 25-35 degree diagonal. The targets evaluation found the
generation time at 1.17-1.33 x Coastal Region (the builder's measure shared one Lua state), sounds of 0.13-0.15 D on
some 16 km diagonals, a thin cape at the narrowest crossing at Coast roughness 200 %, and the small-map exemption hiding
12-24 % straight shore on the editor's 1:3 and 1:5 Small strips; nits: islets 23-240 m off the shore, river mouths at
the map edge beside the strait's ends, lakes cut by the map edge, a finger cove on a short crossing. The fixes:
narrows counted over the strait's middle, at least 1.5 sound widths apart; bank limits relative to each side's own
room with a wander of their own; on a diagonal longer rising walls, half the bends, less asymmetric headlands and
1.2 x wider sounds; the roughness held off around each channel by distance; sounds 0.25 D on maps up to 4 km across
and stronger closing there; short crossings' sounds at most 0.4 x their length; stray land, land slivers and lakes on
the map border removed; a bump along the edges the strait meets; the shape stage reuses each node's frame. strait_check
gained an island-channel target, the narrowest line's own bank height, timing in fresh Lua states, the coast extremes
on every shape, fresh 16 km diagonals and the small strips (288 maps).

**Review round 3 (2026-10-13, after the round-2 fixes):** the look evaluation still found round or boxy basins joined
by canals (BLOCKER): inner sounds about as wide as long (a 16 km diagonal's middle sound a rounded square 5 km across
with north-south walls of 1-1.6 km, on the map the internal notes step 3 names), every 28.7 km diagonal a chain of compact
basins, and the narrows themselves 1.0-2.35 km of even, straight water under 600 m wide. Its causes: inner sounds free
to swell to 1.6 x the design between narrows only 1.5 sound widths apart; the map-angle limit on one kind of wall only;
smoothstep walls, flat at the tip, so the channel stayed narrow for a kilometre or more. It also found the docs
overstating the look and the four directions testing two shapes per seed. The targets evaluation found rivers running
along and beyond the map edge into the strait's mouth on short crossings (and a cliff there), the bluff at a narrows
flattened to 1-2 m by a ship river's valley on 2 km strips (Water Wet, Ship rivers Several), diagonals on 1:3 and 1:5
maps only 1-8 degrees off the long side, generation time up to 1.17 x Coastal Region on some seeds; nits: a 314 m
crossing beside a narrows on 64 m cells (the lane a fairway there), water pockets cut off at the map edge, an oval
plateau with a scarp rim beside short crossings' narrows, 4 narrows never made, long frames from the lane carve, an
islet beside an estuary. The fixes: inner sounds at most 0.42 x the way between their narrows wide with a
swell of 0.85-1.15, the narrows spread evenly over the whole strait; walls that leave the channel at an angle from a
rounded tip (a pinch, not a canal), bowed less and wandering more; a slope limit on every wall (58 degrees to the
strait; on a diagonal 72 degrees to the map's x axis); the swell and the bank limits' wander as logistic curves of
their noise, never held at a bound (held, they drew straight shores), the corner wedge's limit wandering too; coves and
capes allowed closer to a channel; the channel placed by the design's sound; the lane at
the channel's full width wherever the strait is within a coarse cell of it; only the main sea body kept; on short
crossings the drainage bump shorter and the bank's fade gentler along the strait; river meanders 150 m inside the two
edges the strait meets; in a narrows' graded banks river floodplains narrowed (never off the channel) with the bank
rising beside them; faster shape, bank and lane-carve steps. strait_check gained inner-sound, river-mouth and
axis-parallel-shore measures, the narrowest line in the narrows' width, both channels across an island in the sound
width, Water and Ship rivers fields, seeds per direction and 12 new random seeds per full run (312 maps);
settings_check judges the bluff.

### 23.1 Geometry as built (`shapes.lua`: `M.STRAIT`, `soundAt`, `M.straitAt`, `straitSetup`, `straitFrame`, `straitSea`, `straitLand`)
- **Frame and directions.** `u` along the strait's axis (0 at the map centre), `v` across. `M.axisOrientation` replaces
  the seed's rotation (the roll is still drawn): East-West keeps the axis on local x, North-South swaps; both keep the
  seed's two mirrors. The diagonals put the long side on canonical X; the canonical diagonal rises from low Y at X = 0
  to high Y at X = cw, so it runs SW-NE exactly when flipX and flipY agree: the seed keeps flipX, the choice sets flipY.
  Random has its own draw (`derive(seed, "straitkind")`, uniform over the four). A diagonal enters the short edge at
  15-20 % of it, or higher where the corner's land wedge would stay under 1.5 km (the water there is 1.15 x the sound
  wide): on a 16 km square it enters at about 24 % and crosses at about 28 degrees; on maps only 2-3 km across it is
  nearly straight (no room for corner wedges; the direction box's tooltip says so since review round 2). On maps three
  or more times as long as wide the wedge holds the entry at 41-45 % of the short edge, so a diagonal runs only a few
  degrees off the long side (review round 3: 5.8-7.7 on 24.6 x 8.2 km, 2.4-2.6 on 13.8 x 4.6, 1.8-2.8 on 28.7 x 5.6,
  0.8-1.8 on 17.9 x 3.6; 19-21 on 8 km, 27-29 on 16 km and 33 on 28.7 km squares); the tooltip and the extended guide
  say so since round 3. A real diagonal there would have to enter and leave by the long edges near the corners (about
  20-25 degrees on a 1:3 map): a decision for the author, not built.
- **Sounds** (`soundAt`). Half-width `hb` = 0.1 x the cross distance D (sound width 0.2 D, clamped 700-4800 m; under
  7 km across the share grows to 0.25 D by 4 km, review round 2: sounds of 0.2 D, 700-900 m there, were barely twice a
  narrows wide, so the strait read as an even river with straight shores; on maps under ~2.5 km across at most 0.28 D,
  so each bank keeps 35 %), x 1.2 on a diagonal (its flanks are longer, so less of each sound keeps its full width: 16 km
  diagonals measured 0.13-0.14 D), and on a **short crossing** at most 0.2 x the strait's length L (round 2: 4.8 km sounds on
  an 8.2 km strait left it all hourglass, its channel a straight canal 3 km long). Each shore swells on its own (two
  noises, at most +60 % and -15 %; -25 % drew sounds of 0.14-0.15 D on some 16 km diagonals), so a sound is no mirror
  image about its middle; 1.4 x wider at both ends (open sea; the diagonals 1.15 x and held by the corner wedge).
  Beyond the strait's ends (a diagonal's corners) the room, end widening and bends keep their end values but the
  shores keep swelling. **Funnel:** towards a narrows a shore swells at most 10 % beyond the design, over 1.3 x the
  longer wall there (at most 45 % of the way to the next narrows; round 2: funnels over 45 % of the way held the sounds
  at their design width almost everywhere). A sound keeps at least 350 m half-width (0.85 hb on narrow maps).
  **Inner sounds** (review round 3, BLOCKER: inner sounds as wide as long, 4.5-5.5 km between narrows 6-7 km apart, read
  as round ponds joined by canals): between two narrows the design half-width is at most `basinShare` / 2 = 0.21 x the
  way between their channels (a smooth minimum with a knee of a tenth of hb, its limit faded in over 600 m either side
  of a narrows, so an outer sound, open to the sea, keeps the design), and the swell stays within 0.85-1.15 there: an
  inner sound is about twice as long (between the channels) as its widest, or longer (0.44, tried first, left a few
  just under 2; 0.40 would bring the 28.7 km squares' sounds under the 3.6 km target, their three narrows 9.6 km
  apart). The bends are clamped by the design's shores, and each shore then closes in on the bend line (clamped by the
  inner sound's narrower shores, the centre jumped 1 km sideways within 600 m of a narrows and the channel turned
  across the strait). **The swell is a logistic curve of its noise** (kMin + (kMax - kMin) / (1 + exp(-(7 f + b))), b
  so that f = 0 gives the design; round 3): the noise stays within about +-0.6, so neither bound is held for long. The
  hard clamp of 1 + 1.5 f held a shore at its bound wherever the noise ran past it (the -15 % bound wherever f < -0.1, a
  third of the strait), and with the inner sounds' close bounds that drew straight shores (11.5 % of a 16 km diagonal's
  shore within 40 m of a line over 1.5 km, at 0.92-1.15); a tanh bound, tried, still held it near -15 % for f < -0.15,
  and a gentler curve (4 f) left a third of the clamp's variation near the design and straight shores on long strips
  (10.3-13.5 % on three maps). On a diagonal
  the corner wedge's limit on the water wanders down by up to 15 % of its width with the swell, so a shore held by it
  does not run straight into the corner.
- **Bank limits** (review round 2, BLOCKER: the first rule, each bank at least 0.33 D measured from the map edge,
  held 21-45 % of a diagonal's outline as straight shores parallel to that edge). The water takes at most (1 - keep) of
  the room on its side of the axis, keep = 2 x 0.33 raised by a slow wander of each bank's own (0-15 %, wavelength 4 sound
  half-widths, at least 2.5 km), held at its value inside a narrows' funnel (wandering there, a held limit set the
  sounds either side at different heights and the channel between them ran obliquely: an oblique crossing at a
  headland's tip, round 2). On a straight strait (room D / 2 either side) each bank keeps 0.33-0.38 of D, as before; on
  a diagonal the limit follows each side's own room, so it runs with the strait, not with a map edge. The wander is a
  logistic curve of its noise too (round 3: clamped, it sat at 0 or 1 wherever the noise ran past +-0.31, and a shore
  held at its limit ran straight for 2 km beside a diagonal's corner, where the room is constant). Each half-width
  is capped softly (a smooth min with a knee of a tenth of the cap) at its bank's limit, so a swollen shore bends onto
  the limit instead of meeting it at a corner; the bends are clamped softly between the two limits. `strait_check`
  reports how much of the strait holds at a limit ("bank limit holds", info).
- **Bends:** amplitude 8-12 % of D, wavelength 10-14 sound widths within 0.6-2 x the strait's length, at most 6 % of the
  wavelength; **half on a diagonal** (round 2: a 28.7 km diagonal swung 2.4 km across over 2.1 km along, a stretch
  running north-south). Centred so that both banks' MEDIAN room (shore to map edge, over 200 sections) is equal (3 steps,
  once the funnels are final): centring the mean left the smaller bank's median share at 0.343-0.350 on 8 km maps
  (review round 1, S3). The strait is centred across the map.
- **Narrows** (review round 1, BLOCKER 1: the first build's hourglass of two headlands drew an exact X, straight
  flanks for 2-2.5 km and right-angled tips; S1: pointed capes with low banks). **One per ~7 km of the strait's middle
  76 %** (round(0.76 L / 7 km), 1-4; round 2: counted over the whole length, as first built, a 16 km diagonal got 3
  narrows 4.7-5.1 km apart, basins as long as wide), **at least 1.5 sound widths apart** (fewer where the sounds are
  wide: 3 instead of 4 on a 28.7 km diagonal), **spread evenly over the whole strait**, each outer sound half as long as
  an inner one, at most +-5 % off (round 3; spread over the middle 76 %, the inner sounds were 6.2 km long on 16 km
  squares, too short to be twice as long as wide at 0.15 D; +-20 % drew inner sounds 4.5 km long, +-10 % a 16 km
  diagonal's inner sound of 0.139 D). So 1 on 8 km
  squares, 2 on 16 km squares (about 8.2 km apart) and diagonals (9.3 km), 3 on 28.7 km squares (9.6 km) and the
  editor's 1:3 and 1:5 Large strips (8.2 and 9.6 km). 4 would need a strait over 32 km long, which no editor size gives
  with the sound-width rule (review round 3 found none: the documents now say 1-3). Each is **a broad headland from one bank**, doing 65-82 % of the closing
  (down to 60 % where the room is short; on a diagonal 59-70 %, x 0.6 of the excess: round 2, the water swings towards
  the channel and back, and at 25-35 degrees to the map edges a full swing turned a stretch of it north-south), **the
  banks alternating** from one narrows to the next (the first from the seed), so the water winds round the capes; the
  other shore makes a gentler bulge (its flanks 0.9-1.2 x the headland's). The channel between them is 355-390 m across
  its course (never under 5 coarse cells): its half-width in v is t / cos of its course, since where the sound's centre
  or width changes along it the channel runs obliquely (370 m in v came out 288 m across on an 8 km diagonal); its
  place and width come from the design's sound, without the inner sounds' limit (round 3: by the limited sound, which
  narrows across a narrows, the channel ran obliquely and came out 1.7 x as wide). Each wall keeps its full reach over
  the channel's core (60-120 m half-length, at least 1.5 cells), then falls back to the sound's shore over its own
  length on either side as **(1 - xs)^2**, xs a soft |x| (sqrt(x^2 + e^2) - e, scaled to 1 at the wall's end;
  `wallF`): a rounded tip of about 200 m radius (e = 2 x 200 m x reach / length^2, at most 0.35), the wall leaving it at
  2 x reach / length and curving into the sound's shore, no corner at either end. (Round 3, BLOCKER: the plain
  smoothstep built before is flat at the tip, so the channel ran on at nearly its full narrowness for 1.0-2.35 km, an
  even, straight canal; this wall opens the water within a few hundred metres: a pinch.) The headland's flank is
  max(1.4-1.9 x its reach, sqrt(2 x 200 m x reach / 0.35)) long (it leaves the tip at 46-55 degrees to the strait), up
  to 62 % of the way to the next narrows (whose main headland stands on the other bank); the other shore's bulge and
  the funnel take at most 45 %; each wall's reach is that of the sound on its own side (an inner sound is narrower than
  an outer one). **On a diagonal** (axis th above the map's x axis) a wall that rises towards the channel (the lower one
  before the narrows, the upper one after it) lies at th + its own angle to the map's x axis: at 51-68 degrees it ran
  north-south on a square map, with the falling wall east-west (square basins, round 2). That wall is made longer, so
  that on average it lies no steeper than 64 degrees to the map's x axis (never asked to be flatter than 34 degrees to
  the strait; as far as the room allows); its tip, steeper, is held to 72 degrees by the wall slope limit (below). (Made
  as long as the smoothstep's steepest part needed, 2 x reach / tan, round 3's first try, the two long rising walls in
  one inner sound left it 0.137 D wide.) The falling one keeps its length, so the water still opens quickly beyond the
  channel. Each wall also **bows out** a little (0.02-0.07 x its reach for the headland, 0.02-0.05 for the other shore,
  x sin^2 over its length; round 3: the 0.06-0.2 and 0.05-0.14 set for the smoothstep's straight middle cancelled the
  new wall's own curve and drew flanks within 40 m of a line over 1.5 km) and **wanders** (1.2-2.2 waves along its flank, at least one per 1.8 km (a
  diagonal's lengthened wall, 4-5 km, ran straight with fewer), none shorter than 700 m, 5-8 %
  of the headland's reach (taken as at least 1.2 km; 3.5-6 % before round 3, which left the new walls straight over
  1.5-1.8 km beside the channel) but at most a tenth of the flank, x sin^2: nothing at the channel),
  so no flank is the straight middle of a formula. (Tried in round 2 and dropped: a hyperbolic wall with a set tip
  radius of 200-420 m and flanks 0.7-1.05 x the reach. It shortened the channel's narrow stretch (half-width under
  300 m) from 1.0-1.4 km to 0.8-0.9 km only with tips under ~280 m, and then a crossing at the tip, oblique to the
  strait, met the headland's other flank within 400-800 m: no solid landing. Round 3's wall leaves the tip at 46-55
  degrees, so the headland is a broad wedge: the land 150 m behind each landing at least 600 m wide.)
- **Wall slope limit** (round 3, `s.lim`, applied in `M.straitAt`): no shore of the outline steeper than 58 degrees to
  the strait (`wallMax`), and on a diagonal no rising wall steeper than 72 degrees to the map's x axis
  (`flankMapLim`): each shore becomes the nearest outline within those slopes that holds at least as much land (a cone
  envelope in two passes over the 8 m steps), so the limit only ever narrows the water, and never under the narrowest
  channel plus 40 m across the water's course (three rounds: limited on one shore alone, a crossing beside a channel
  came out 224 m). The walls' own lengths keep it mostly idle (it adds 50-300 m of land over 0.5-1.4 km of a few walls).
- **The channel's width is set at 4 m resolution.** The coarse sea at the throat comes out 14-58 m narrower than
  designed (the edge moves by up to a cell with the grid, and the shore smoothing lifts the water's edge; measured at
  16, 32 and 64 m cells), more than the target window allows. So the lane carves the channel at its designed width in
  the core and 150 m on (tapering to the fairway by 300 m), across the water's course (x the cosine of the axis's angle
  to the frame), with banks rising 1:4 to 24 m (`laneBank`, above the 18-23 m bank top, along the whole lane: the first
  build's 6 m banks cut the bluff's foot into 9-17 m steps right at the bridge abutments, review BLOCKER 2). Since
  round 3 also wherever the design half-width is within a coarse cell of the narrowest channel's (375 m beyond a core
  the lane was a 222 m fairway, and the coarse water's edge set a 314 m crossing on 64 m cells).
- **Coast roughness and shore noise** act **across the shore**: the shift in v is x the shore's stretch sqrt(1 +
  slope^2) (at most 3), the slope dv/du of that shore from the table, since a shift in v alone slid along a headland's
  flank, which runs nearly across the strait. Besides the Coast roughness the type has its own **shore noise** (fBm,
  wavelength 0.6 hb, at least 800 m; amplitude 0.35 hb at Coast roughness 100 % and above, rising to 0.7 hb at 0 %, at
  least 250 m: the roughness's own 1.2 km octave shapes the shores otherwise, and at 0 % the flanks ran straight for
  1.5-2 km). (Scaling it by an inner sound's share of the design, tried in round 3 to keep a cove from setting a sound's
  widest, made the inner sounds' shores straighter: dropped.) **Around each narrows' channel** (by the distance to its centre, review round 2; first built by the place
  along the strait, which held a steep flank smooth for its whole height): no coves within 550 m, all beyond 1000 m (coves
  there made thin spits and fingers of the landings), no capes within 300 m, all beyond 600 m (one beside the channel
  became the narrowest crossing; round 3: 650-1150 and 350-700 m, as before, held the narrows' flanks smooth for 1.3-2.3
  km, look review; 450-850 m, tried, let a cove come within 560 m behind a landing at Coast roughness 0 %); both
  distances grow with how far the shore can move (`fadeK`, the coast roughness and
  the shore noise against Coast roughness 100 %, never below 1: at 200 % a cape beside the channel became a thin finger
  at the narrowest crossing, round 2). Beside an island only the capes are damped (0.8; coves only widen its channel;
  both damped, the shores ran straight for 2-4 km beside an island). **Closing** is a smooth tanh limit of a quarter of
  the half-width (x the stretch), but at least 200 m (at most 45 % of the half-width) on maps up to 4.5 km across (round
  2: a quarter saturated on sounds 600-900 m wide, so wherever the noise ran negative the shore lay within 60 m of a line
  for 2-5 km; none from 5 km across, where it drew unplanned narrows under 600 m at 200 %). The water never gets narrower
  than the narrowest channel + 10 m + a coarse cell per side **across its course** (the floor in v divided by the cosine
  of the course; a floor in v alone left 256-296 m crossings past a headland's tip on 64 m cells). The middle half of the
  strait is always water, so it can never close.
- **Outline warp.** The sounds are drawn through a smooth 2D warp (along the strait 0.25 x hb, across 0.1 x hb,
  wavelength one sound width), faded out within 600-1600 m of a channel centre and where the half-width is under 600-900
  m, so the channel keeps its width and the lane always runs in water, and over 1 km beyond the furthest the water can
  reach (round 3: it shapes only the outline; the land's frame there costs less without it). The axis that the report
  measures along follows the warped water (each point solved by fixed-point steps).
- **Islands** (Giant River rules, tightened): at most one per 5 km, only where the sound is at least 1.4 km wide over
  the island's length, the island's ends at least 1.5 km beyond a narrows' channel core; 150 m+ wide, 1.8-3.5 x as long
  (the proposal's 2.5-5 x drew thin smooth fingers), its shore moved across it by half the coast roughness and a noise
  of its own, at most 120 m either way; off the axis (the lane passes on the inner side); the outer channel at least
  300 m plus those 120 m: never a cheaper crossing than a narrows. **Any other land the water cuts off becomes water**
  (`M.dropStrayLand`, 4 neighbours: land touching another piece only diagonally is cut off once upsampled), and so do
  **land slivers one cell wide** (`M.removeLandSlivers`: the shore smoothing lowered a thin cape's tip below the water
  and left islets 100-200 m off the shore; round 2, islets 23-240 m off the shore and a 0.25 km^2 block 222 m off a
  bank). **Only the largest sea body stays sea** (`M.keepMainSea`, round 3: the shore noise beside a strait's mouth cut
  pockets of water off it at the map edge, up to 2800 m^2, which count as open sea and no puddle).
- **Lane** (`out.lanes`, carved after the rivers by `pipeline.lua`; not in `paths`, so it is no river): wherever the
  half-width is under 600 m (and 300 m on), 6 m deep; in a channel's core and 150 m on its full width (above), beyond
  300 m a 200 m fairway (at most 70 % of the strait, inside whatever the roughness leaves, so it never cuts a cape
  straight). `detail.carve` only lowers and follows deeper water; the lane is carved in chords of up to 120 m and 0.6 x its
  width (`p.step`; 40 m and a quarter of the width for rivers), and the carve ticks the frame budget by the cells it
  visits (round 3: the lane's wide segments held the Studio window for 64-100 ms between ticks).

### 23.2 Banks (`straitLand`'s 4th and 5th values; `landform.lua` step 3c, after the hill country, before lakes and valleys)
- **Drainage.** B = coast-distance field (every river drains to the strait; no outlets) plus a bump of 150 within
  1-3 km of each channel centre (the land rises by at most ~60 in B), so no river ends at a bridge site, and a bump of 40
  along the two edges the strait meets (full at the edge, none 1.5 km in; review round 2: on 25 of 72 maps a river ran
  along such an edge into the strait's mouth, Coastal Region 4 of 24). Round 3 (on short crossings rivers still ran
  along and beyond the edge into the strait's mouth: a trunk 2.66 km within 60 m of the edge, 1.65 km of it outside the
  map, and a cliff where it left a half-channel): the edge bump reaches at most 0.2 x the strait's length in; the bump
  around a narrows reaches along the strait at most 70 % of the way to its end (`s.kb`; on a 2 km crossing it reached
  the map edge, so the edge was the lowest way to the water); and the rivers' meanders stay 150 m inside the two edges
  the strait meets (`shape.riverBounds`, rivers.lua; the inflows enter by the other two edges, which keep the old
  bound). On every other map type the meanders may still run up to a coarse cell beyond the edge (Coastal Region 8 km
  seed 97: 0.65 km of river outside the map); keeping them inside everywhere would change accepted maps: the author's
  decision. One inflow per bank from beyond its far edge (0.3
  x the map area), at 25-75 % of that edge (on a diagonal 50-85 % or 15-50 %, away from the corner the strait enters by;
  20-80 % before: an estuary beside the strait's mouth reached the map edge on its own, review N1), its mouth away from
  the narrows where possible: that bank's main valley and estuary (1200 m).
- **Shore plain:** a cap like a floodplain: +1 m at the water rising 2.5 m to its width (400-1200 m per bank, at most
  40 % of the bank, none within 1.7 km of a channel, full beyond 3 km), then a valley side; no rock texture on it.
- **Bluffs:** within 1.55 km of a channel centre (blended out by 2.3 km) the land is a set ramp: from +1 m at the water
  to the bank top (18-23 m per map) 100 m inland, then rising at the Relief's pass grade x 0.85 (2.1 % at Gentle.. 5.1 %
  at Mountainous). Beyond the bank top the ramp follows a **smoothed** coast distance (one 5x5 box as running sums along
  rows and columns since round 3, three 3x3 passes before: the same smoothing at half the cost; exact within a cell of
  the top): the distance field's crease along a headland's middle drew a straight ridge line (review nit). No extra
  uplift (the prototype's raised the banks to 164-242 m at Mountainous).
- **Rivers in the graded banks** (round 3: on 2 km strips crossed the short way with Water Wet and Ship rivers One or
  Several, a ship river's floodplain, 400-500 m either side, lowered the bluff 150 m behind the water from 20 m to
  1-4 m): in the valley pass (landform step 5) a floodplain inside a narrows' graded banks is at most a fifth as wide
  (weighted by the bluff weight; never off the river's own channel, whose distance is measured apart there) and beside
  it the land rises to the bank as from the strait's own water, over 250 m (`RIVER_BANK_AT`; over the strait's 100 m it
  left 6 m steps where a ship river's bend met the graded bank); the same beside an estuary. Floodplains and estuaries
  elsewhere, and on every other map type, are unchanged.
- **Short crossings** (a strait under 6 km long, e.g. 1.5 km across a 1:5 strip): the bluff, plain and drainage zones
  shrink along the strait by L / 6 km (not across it, where the approach runs), so the shores keep harbour room (the
  first build's 1.55 km bluff zone covered every shore of a 1.5 km strait: 0.1-0.2 km of harbour coast per bank, review
  S4; strait_check: on such a short crossing a ferry harbour per bank, at least one site and 0.3 km). The bluff zone
  fades over at least 600 m along the strait (`bluffBlendMin`, round 3: shrunk with the zone, the fade drew an oval
  plateau with a scarp rim beside a 2 km crossing's narrows, 30-70 % over 100 m on the approach lines).
- **Harbour shelf:** slope 0.06 (Coastal Region 0.012) and `shelf.steep` 3: after the shore smoothing the sea's edge
  is made 3 x deeper, at most as deep as the shelf there (the water line stays where the smoothing put it). Only at the
  sea's edge: deepening a lake's smoothed edge left one-node puddles.
- **Lakes:** `lakeOpen` removes lake tails one or two nodes wide (a morphological opening): the shore smoothing lifted
  such a tail to 0 m and cut a pond off its end (8 km maps, 12 of 204 measured maps had a puddle; not caused by this
  type's banks, but its B field made such pits). `lakeInland` (review round 2): no lake on the map border, where the
  edge would cut it off (the banks have no edge outlets, so dips against an inland edge or at an inflow became lakes:
  a 1.3 km lake on the west edge of a 4.6 x 13.8 km map, a 1.2 km lake at an inflow). Both opt-in, so accepted maps keep
  their lakes; whether to switch them on for every type is a question for the author (it would change accepted maps).

### 23.3 Report and tools
- **Report** (`report.lua`, `straitStats`): a section every 25 m along the axis on the final heights; each narrows is the
  narrowest section within 1 km of it, refined by oblique lines (+-30 degrees, +-200 m along the axis, 2 m steps on
  interpolated heights: the sections alone overstated a curving channel by up to 9 m, review N2); the narrowest crossing
  anywhere; "ships pass end to end" (every section's axis point at least 2 m deep with at least 100 m of such water
  around it). Line: `strait: 2 narrows (372 m, 356 m across at the water line), narrowest crossing 356 m; ships pass end
  to end: yes`. The strait counts as neither river nor ship river. Result: `result.strait` (axis, half-width, narrows
  weight, narrows indices, D, L, sound width), `result.lanes`.
- **Speed:** the outline, both shores' slopes and the roughness damping are tabulated along u every 8 m (`straitTable`,
  over the strait and beyond its ends). Review round 2 (1.17-1.33 x Coastal Region, measured in fresh Lua states): the
  sea pass first tests each node's unwarped frame against the furthest the water can reach around its u (the outline
  plus the most both noises can move it, over the warp's reach; tabulated too) and leaves the frame of a node beyond it
  to the land pass; it keeps each other node's frame (u, v, throat distance) for the land pass, which no longer computes
  it again (`build` passes the node index to `sea` and `land`; the other types ignore it). The same map, a faster stage.
  Round 3 (up to 1.17 x Coastal Region on some seeds): the land function skips the zones' terms beyond their reach and
  computes both of a short crossing's scaled throat distances in one loop; the warp fades out beyond the water's reach;
  the channels' own distance (landform step 5) is measured only where a river runs through the graded banks (a full
  grid pass otherwise); the bank top's smoothing is one running 5x5 box; the lane is carved in longer chords.
- **`tools/strait_check.py`** measures every target per map (sections in Lua at 4 m, areas on an 8 m grid, each
  narrows' crossing lines on its own 4 m window); since review round 1 also: the **landing** at each narrows (the
  narrowest crossing line; per bank the land run behind the water >= 1 km or to the map edge, and >= 300 m of land
  across it 150 m behind the water), the **bluff** on the crossing lines through the channel (the middle half of the
  lines within 16 m of the narrowest; the sections across a curving axis met the headland's shoulder) and, since round
  2, on the narrowest line itself (it can land beside a cove), **cliffs** (4 m neighbours more than 4 m apart within
  40 m of water: 0), **straight shore** (share of the strait's shore, rivers and the narrows' channels (500 m around
  their centres, smooth on purpose) left out, on runs straight within 60 m over 2 km or 40 m over 1.5 km: FAIL above
  10 % or a 3.5 km run (2 km measure), WARN above 5 % or 2.5 km; on maps 3-5 km across (the editor's 1:3 and 1:5 Small
  strips, sounds 0.9-1.2 km wide) FAIL above 15 % or 4 km (round 2: they were WARN only, which hid 12-24 %); WARN only on
  maps under 3 km across, on a short crossing and at Coast roughness 0 % under 6 km) and **islands** (no route over an
  island under 300 m; since round 2 also **both channels** at least 300 m for every island in the strait of 0.02 km^2 or
  more (within 300 m of the designed outline and with at least 60 % of the water around it the strait's wide water:
  land cut off by a river's branches at its mouth or beside a lake is no stepping stone; smaller islets are counted
  apart); sections whose water run ends at an island leave the sound statistics). **Bank limit holds** (info, round 2):
  the share of the sound sections whose shore lies at its bank's limit. **Timing** (`--timing`, round 2): CPU seconds,
  each run in a fresh Lua state, best of two alternating (one shared state charged each run for clearing up the one
  before: 1.02 x measured that way where fresh states gave 1.33 x). The approach reads "unmeasurable" when the land
  behind the water ends within about 550 m. A Lua error in one map is that map's FAIL, not a broken run. `--set quick` (6
  small maps; in `run_checks.py` as "strait"), `--set full` (312 maps since round 3: every shape and direction at
  three Reliefs and three seeds, each direction with its own seeds (North-South is East-West transposed and NW-SE is
  SW-NE mirrored, so one seed for all four measured two shapes, look review round 3), Coast roughness 0 % and 200 % on
  every shape and direction, more 16 km diagonals, the 1:3 and 1:5 Small strips, Water Dry and Wet with Ship rivers
  Several on short crossings and 8 km squares, and 12 maps with new random text seeds on 16 and 28.7 km diagonals,
  printed so a failure can be re-run; `--fresh N`), `--maps` (text seeds, and since round 3 the Water and Ship rivers
  fields: `size:side:relief:seed[:coast %][:water][:ships]`), `--timing`, `--png`, `--out`, `--json`. Round 3 added:
  **inner sounds** (the way between two narrows' channels along the axis / the sound's widest: the diameter of the
  largest circle in its water, islands counted as water, over the water whose nearest axis point lies between the two;
  FAIL under 1.8, WARN under 2, at Coast roughness 0 % and 200 % WARN only, where the shore noise is strongest by
  design. The widest water run through the axis, tried first, cut a sound obliquely where the axis turns towards a
  channel off the sound's middle: a sound about 4 km wide measured 7.1 km; the reviewers' own width tool used the
  inscribed circle too), **shore along a map axis** on diagonals of maps under 2.5:1 (share of the shoreline on
  straight 1 km runs within 10 degrees of a map axis, WARN above 12 % or 2.2 km: Coastal Region scores 5.8 % / 1.2 km on
  it, and with chords of 0.85 x the window, as first tried, 48 %, since a natural coast turns through every direction;
  shown, not failed), **river mouths** (the nearest trunk mouth at least 300 m from the map edge and no river within
  60 m of the two edges the strait meets; WARN only on maps under 3 km across), the narrows' water line and 2 m depth
  on the narrower of the section and the narrowest crossing line (the reviewer's 314 m crossing beside a 320 m
  section), the sound width across an island as both channels (walked on the 8 m grid from bank to bank; left out, the
  island's sections took a sound's widest part out of its median), and the landing run on a short crossing at least a
  quarter of the strait's length (400 m+) instead of 1 km (the river that enters a 2 km strait lies within about a
  kilometre of its narrows). `settings_check` (group strait) judges the bank 150 m behind the water at each narrows on
  its sections (`strait_check.section_bluffs`, 12-30 m: FAIL).

### 23.4 Numbers (offline, after review round 3: `strait_check --set full`, 312 maps: 8, 16 and 28.7 km squares in every direction (28.7 km: East-West and SW-NE), 1:3 and 1:5 strips both ways (East-West and North-South), 2 x 10 km in both diagonals; Gentle, Hilly, Mountainous; 3 seeds, each direction its own; Coast roughness 0 % and 200 % on every shape and direction (2 seeds); 12 more 16 km diagonals; the editor's 1:3 and 1:5 Small strips both ways; Water Dry / Wet with Ship rivers Several on short crossings and 8 km squares; 12 maps with new random seeds on 16 and 28.7 km diagonals; 545 narrows)
| Target (proposal; reviews) | Measured (312 maps) | |
|---|---|---|
| Narrows water line 300-420 m, >= 250 m at >= 2 m deep, count as designed (also 64 m cells) | sections 356-404 m (median 376), the narrowest crossing lines 355-398 m; 336-372 m deep enough on both; count 312/312 (1 narrows on 150 maps, 2 on 91, 3 on 71, never 4) | pass |
| Bank to bank (+3 m contours) <= 500 m | at most 444 m | pass |
| Landing: land run behind each landing >= 1 km or to the map edge (short crossings: a quarter of the strait, 400 m+), >= 300 m of land 150 m behind the water | shortest run that ends in water 850 m (a 2 km crossing), narrowest landing 542 m | pass |
| Bluff 150 m from the water on the channel's crossing lines and on the narrowest line, every Relief, Water and Ship rivers: 12-30 m | 15.8-25.6 m | pass |
| Cliffs: steps over 4 m between 4 m neighbours within 40 m of water | 0 (largest step 2.6 m) | pass |
| Navigable: every 25 m section >= 100 m at >= 2 m, connected end to end | 100 % on every map (narrowest 2 m deep water through a section 332 m); connected 312/312; report "yes" on all | pass |
| Inner sounds (round 3, look review): the way between two narrows' channels / the widest (inscribed circle) >= 2 | 233 inner sounds 2.24-8.7 (median 2.95); none under 2 | pass |
| Sound width median >= 0.15 D (or >= 3.6 km where the 4.8 km cap applies) | long straight straits 0.127-0.248 (the low end 28.7 km squares at 3.75 km+); diagonals on squares 0.130-0.331 (the low end a 28.7 km diagonal at 3.9 km); short crossings and maps under 5 km shown only (49 WARN) | pass |
| Each bank >= 35 % of D; banks within 60/40 | long straight straits: median share at least 0.357; diagonals 0.306-0.428 (shown); area split at least 46 % | pass |
| Flat land (< 3 %) per bank, Gentle: >= 20 % at 16 km, >= 15 % on strips | smaller bank at least 26.0 % on 12 km+ squares, 25.7 % on strips | pass |
| Harbour coast per bank: >= 3 km and 3 sites at 16 km, >= 1.5 km on strips | at least 11.2 km and 6 sites at 16 km+, at least 5.6 km on strips; short crossings at least 0.5 km and a site per bank | pass |
| Harbour shelf: 2 m deep within 60 m on >= 85 % of the sounds' shore | at least 85 % | pass |
| Straight shore (Coastal Region 0 %) | maps 8 km+ at default roughness: none on 81 of 154, at most 9.5 % (median 0), longest straight run (2 km windows) 2.98 km; maps 3-5 km across at most 5.8 %; 2 km strips up to 79 % (shown); FAIL on one map at Coast roughness 0 % (28.7 km East-West: 11.6 % on the 1.5 km / 40 m measure, the walls beside a narrows, held smooth for the landings); WARN on 65 maps | 1 FAIL |
| Shore along a map axis, diagonals on squares (round 3; Coastal Region 5.8 %, 1.2 km) | median 4.6 %, 90th percentile 11.5 %, longest run 2.9 km (WARN on 14) | shown |
| River mouths off the map edge (round 3): >= 300 m, none along the strait's edges | at least 560 m on maps 3 km+; 300-316 m on 2 km crossings (WARN); no river within 60 m of the strait's two edges | pass |
| Islands: no route over one cheaper than a narrows; both channels >= 300 m | shortest span over any island 496 m; nearest bank to an island in the strait 352 m; islets of 0.02-0.1 km^2 or cut off by an estuary 64-115 m off a shore on 4 maps (WARN) | pass |
| Puddles 0; ship water check | 0 on all | pass |
| Generation time <= 1.1 x Coastal Region | CPU time, each run in a fresh Lua state, best of 3 alternating (the review's method), 10 maps: 0.93-1.14 x, median 1.065 (8 km 1.05-1.09, 13.8 x 4.6 km 0.93, 16 km 1.05-1.14, 24.6 x 8.2 km 1.07-1.14, 28.7 x 5.6 km 1.01, 28.7 km 1.05); the same map measured 1.14 and 1.00 in two sessions, the other work on the machine moves single values by up to 0.15 | median pass |
| Other map types identical | core_baseline: 90 of 90 accepted maps identical; the 30 Sea Strait maps re-added (`--add-new`) | pass |
The look (round 3, BLOCKER): 16 km diagonals (the reviews' seeds 41, 61-64, 101-108, `bw2r`, `strait2`) and 28.7 km
squares now run as a chain of long sounds, lens-shaped, joined at short pinches: inner sounds 2.2-3.7 x as long as their
widest by the reviewers' own width tool (`x/e4w.py`: the widest inscribed circle, its length between the narrow
stretches; 1.2-1.6 before), and the water under 600 m wide 0.8-1.3 km long at a 16 km diagonal's narrows (median 1.0
km; 1.2-2.35 km before), 0.9-1.6 km on 28.7 km squares. The reviewers' independent measure (`x/ev4_ind.py`, 30 maps
with seeds of their own kind): narrows 355-396 m at the water line, the narrowest crossing anywhere 355-387 m, 339-399
m of it 2 m deep, a 2 m deep channel at least 335 m wide end to end, flat land on the smaller bank at Gentle at least
25.4 %.
Game scale (scale_check, 16 km, Gentle): East-West flat 26.2 %, rail 32.5 %, P99 189 m; SW-NE 30.2 % / 32.2 % / 199 m;
Coastal Region 30.2 % / 32.4 % / 195 m.

### 23.5 Known limits (offline)
- **Diagonals on long maps** (round 3, a decision for the author): on maps three or more times as long as wide the corner
  wedges hold a diagonal 1-8 degrees off the long side; the tooltip and the extended guide say so. A real
  diagonal there would enter and leave by the long edges near the corners (about 20-25 degrees on a 1:3 map): not built.
- **Generation time:** about 1.07 x Coastal Region (median of 10 maps; single maps 0.93-1.14, as noisy as the machine).
  The extra is the strait's frame per node in the shape stage (the land function costs about twice Coastal Region's,
  some 0.3-0.4 s per 260,000 nodes), the stray-land and sliver passes, the graded banks and the lane carve, and the
  detail stage on more land than Coastal Region's. Judging the target as the median over seeds is the author's call.
- **Narrows count:** counted over the strait's middle 76 % (round 2) and now spread over the whole strait (round 3): 1
  on 8 km squares, 2 on 16 km maps (8.2-9.3 km apart), 3 on 28.7 km squares and the 1:3 and 1:5 Large strips (8.2-9.6
  km apart); the proposal's "every ~7 km, 1-4" would give 2-4 there. Fewer, longer sounds keep each about twice as long
  as wide at the sound width the proposal asks for.
- **Straight shore:** at Coast roughness 0 % a 28.7 km map can still exceed 10 % on the 1.5 km / 40 m measure (11.6 % on
  one of the 312): the walls beside a narrows are held smooth for 0.55-1 km so the landings stay whole, and at 0 % only
  the type's own shore noise roughens the rest. Earlier full runs of round 3 had one to three maps just over 10 % before
  the wall wander was raised; this is the tail of a statistical measure (the median is 0 at 8 km+).
- **Short crossings** (a strait shorter than three sound widths, e.g. East-West on a tall 1:3 or 1:5 map): one or two
  narrows between two bays, the sounds at most 0.4 x the strait's length; sound width / D, bank share and straight
  shore are shown, not judged; on a 1.5 km crossing each bank keeps a ferry harbour. On 2 km crossings the rivers enter
  the strait 300-316 m from the map edge (WARN): the strait is only 2 km long, and the drainage bump around its narrows
  leaves 0.3-0.6 km either end; with Water Wet and Ship rivers Several their mouths lie 0.6-0.8 km from the narrows, and
  the land run behind a landing measures at least 850 m (a quarter of the strait counts there, 23.3).
- **Maps under 5 km across:** sounds 0.25 D (0.9-1.2 km), about 2.5-3 x a narrows; roughness can make a stretch of a
  sound read as narrows (27 WARN; on 2 km strips spots of 430 m, 3 km from the narrows, read as narrows by the review's
  measure, with low banks: they are sounds); under ~1.5 km and on thin diagonal strips there are no rivers.
- **Water at the map edge:** the inflow rivers enter from beyond the far edges, so each map has two river channels on
  its border; the review's measure counts the water where they enter as small patches on the edge (18-95 nodes). The
  pockets cut off the strait's mouth are gone.
- **Approach** (WARN on 2 of 545 narrows): the steepest 100 m within 1.25 km behind a narrows above 1.2 x the pass grade,
  at most 8.7 % (a 28.7 km map at Coast roughness 0 % and a 3.6 x 17.9 km strip: a valley side behind the ramp); the
  landing and the bank height pass there.
- **Islets of 0.02-0.1 km^2, and land an estuary cut off** (WARN, 4 of 312 maps, 64-115 m off a shore): where the estuary
  carve or the shore smoothing at full resolution cuts a cape's tip or a headland's neck. Land the shape stage cuts off
  is removed; these form later. No route over them is cheaper than a narrows.
- **A band of narrow ridges at the edge of the graded zone** (round 1 look review nit, traced, not changed): on 8 km maps
  land more than 6 m above its 100 m neighbourhood is 2.4 x as common 1.7-2.1 km from a narrows as elsewhere. The set
  ramp beyond the bank top (rising at the pass grade) is blended into the hill country over 1.55-2.3 km; where it stands
  above the natural land the blend leaves a raised band. A fix changes every Sea Strait map's banks and needs the
  approach targets re-measured: left for a later step.
- **Water Dry + Ship rivers One/Several:** the inflow rivers stay too small to become ship rivers (the Report's note).
- **Not yet seen in game**.

### 23.6 Core changes this needed (all opt-in: every other accepted map identical)
`shapes.lua`: the type, `M.STRAIT`, `soundAt`, `M.straitAt`, `M.axisOrientation`, `M.sideName`, `M.AXIS_CHOICES` /
`AXIS_NAMES`; `build` computes the map size before the roll, passes setup a 6th and 7th argument (variant, coarse cell;
the other types ignore them), passes the node index to the two-pass types' `sea` and `land` (review round 2: the strait
keeps each node's frame; the other types ignore it), runs `M.removeLandSlivers` and `M.dropStrayLand` when setup asks
(`s.dropStrayLand`, Sea Strait only), collects the land function's 4th and 5th values (`out.plain`, `out.bluff`) and
the type's `out.strait` (with `hold`, round 2), `out.lanes`, `out.bluffTop`; `orientationFor` ignores "axis" sides.
`landform.lua`: step 3c (only with `shape.plain` / `shape.bluff`, the ramp beyond the bank top on a smoothed coast
distance), `preset.shelf.steep`, `preset.lakeOpen`, `preset.lakeInland` (round 2). `pipeline.lua`: carves
`shape.lanes`, passes `shape.strait` to the report, returns `strait` and `lanes`. `report.lua`: `straitStats` (narrows
refined by oblique lines) and its line. Window: the direction box from `side.choices` with its own tooltip (round 2:
it says a diagonal runs nearly straight on a map under about 3 km across; round 3: also on maps three or more times as
long as wide), `settingsText` through `shapes.sideName`; a map type change resets it (its label differs from every
other side box).
Round 3, all opt-in as well: `shapes.lua` `M.keepMainSea` (when setup sets `s.mainSeaOnly`), `out.riverBounds` (Sea
Strait); `rivers.lua` reads `shape.riverBounds` (else the old bound, a cell beyond the map); `detail.lua` `carve`
takes a path's `step` (the lane only) and ticks the frame budget by the cells it visits (no effect on the heights);
`landform.lua` keeps `bluffT` / `bluffW` from step 3c (only with `shape.bluff`) and step 5 reads them (the floodplains
and estuaries in a narrows' graded banks, `RIVER_BANK_AT`), measuring the channels apart only where a river runs
through them; step 3c's smoothing is one running 5x5 box. Every accepted map of the other types is identical
(core_baseline, 90 of 90).

### 23.7 Checks
`strait_check` (above; full set 312 maps: 1 FAIL, the straight shore of one 28.7 km map at Coast roughness 0 %);
settings_check: `sides` covers the four directions (the strait's two ends on the edges or corners they name; FAIL
otherwise) and a group `strait` (every direction on 1.5 km squares, 4 km, 1:3 and 1:5 strips both ways at Gentle and
Mountainous, Coast roughness 0 % / 200 %, Water Dry / Wet x Ship rivers None / One / Several): FAIL when ships cannot
pass, there is no narrows, a crossing is under 300 m, the direction is wrong or (round 3) the bank 150 m behind the
water at a narrows is outside 12-30 m on its sections; WARN when a narrows is outside 300-420 m (round 3: 178 cases, 0
FAIL, 9 WARN: no rivers on 1.5 km squares, Water Dry with Ship rivers One); studio_check: a Sea Strait scenario
(Diagonal NW-SE: the Report names `side nwse` and says ships pass; the Strait runs box's tooltip says what East-West
means; its longest frame 54 ms, round 3) and steps in "map type changes" (the box, its five choices in the core's order,
keyed by type, reset by every type change, `side swne` / `side ew` reaching the core, the strait line); core_baseline 30
maps (re-added in round 3: every other map identical); export_check reads `side ew`.. `side nwse` (the names from the
core's `AXIS_NAMES`); scale_check `--types sea_strait --side 1-4`.

**Author decisions after building:** the narrows as built (spread evenly: 2 on
16 km maps, 3 on 28.7 km maps and long strips), diagonals on maps 3:1 and longer as built (nearly along the long
side; the tooltip says so), the lake rules (no lake tails, no lake on the map border) only on the Sea Strait.
Run 11 passed in game: narrows 360-366 m, ships pass end to end.

### 23.8 In game
Bridges over a narrows at the bluff height (road and rail), ships under them (the Navigable Waters layer), a harbour
on a sound shore, the editor's Main Connections tool not linking towns across the strait, the direction box and the
Report line.

## 24. Studio window and other mods' GUI replacements (2026-10-13; offline-checked, in game: the internal notes)
**Problem.** Opening the Studio killed the game when a certain other mod was active (`NodeStorage.cpp:51` assertion
"While transforming... WindowContainer"). Some mods replace the game's window component `builtin.Window` with a Lua
function of their own (a wrapper that passes every call on) when their script loads; the GUI module table is shared,
so every later reader gets their function. A window recipe must be a wrapper of the game's Window (the engine's window
container finds the window node through `_react.recipeMetas[<window recipe id>].innerRecipeId`), and
`react.RegisterWrapperRecipe(name, builtin.Window, fn)` looks the wrapped recipe up by FUNCTION identity
(`recipeFnToRecipeId`, local to base `gui/main/react.lua`, which knows only functions react registered). Registered
after such a mod, the Studio was "a wrapper around nil" (verbose log), and opening it crashed. Whether it happens
depended on which script loaded first, and on whether a mod that also replaces react's own registration functions
was active: such a mod can make a replaced `builtin.Window` register as the game's Window (review 2026-10-13).

**Fix (`utg_studio.script.lua`, "The window recipe").** The game keeps its own Window recipe in the global tables
of `base/init.lua`: its id in `_react.builtin.Window` (builtin.lua declares it with that id) and its node constructor
in `_react.originalRecipeFn[id]` (react.lua 380). `registerWindowRecipe`:
- react reports `builtin.Window` as the game's Window (`react.GetRecipeId(builtin.Window)` is the game's id): the
  normal wrapper, and the window body builds its node with that function, captured at load, so a mod that replaces
  `builtin.Window` later cannot reach this window either. Then the record `RegisterWrapperRecipe` wrote is CHECKED,
  not assumed: a mod can replace react's `GetRecipeId` too, and a lookup that names the game's Window while the
  registration records nothing would bring the crash back. A record that does not name the game's Window is repaired
  as in the next case (same recipe, record overwritten). Without the game's tables there is nothing to check against:
  the normal wrapper as before.
- Replaced (or the record wrong): `react.RegisterRecipe(name, fn)` (or the recipe just registered) and
  `_react.recipeMetas[our id] = { innerRecipeId = <game's id> }`, exactly the record `RegisterWrapperRecipe` writes
  for a wrapper of the game's Window; the body builds its node as the game's registered function does (an official
  recipe replacement `_react.recipeReplace[id]` first, else the constructor; react.lua 382-388), never through the
  other mod's function. One `[UTG]` line says so and why. (React's per-render child check, `checkRecipeMatch`, only
  writes a verbose line on a mismatch; the child is the game's Window by construction.)
- Neither possible (the game's tables not as expected, e.g. after a game update): no window recipe at all; the UTG
  mod button stays as a plain button (no on/off state a refused click could leave pressed), its tooltip says the
  window cannot open safely and why to disable mods that change game windows, a click opens nothing and is logged.
  Never a crash.

Considered and not taken: refusing to open whenever `builtin.Window` is replaced (safe, but the Studio would be lost
with common, harmless mods); finding the original function among the replacement's upvalues with the `debug` library
(depends on how each other mod wrote its replacement, and on `debug.getupvalue` being available to mods); registering
"as early as possible" (a mod cannot choose its script load order). The engine reads `recipeMetas` and
`innerRecipeId` by name (both strings are in `TransportFever3.exe`); that it reads the record after registration is
inferred (react.lua itself writes it only after the engine handed out the recipe id) and is what run 12 confirms.

**Checks.** `studio_check`: the fake react keeps recipe ids by function identity and records wrappers in
`_react.recipeMetas`; the fake window container crashes on any window recipe that is not a wrapper of the game's
Window (every scenario). Five scenarios change `builtin.Window`: replaced before the Studio loads with the game's
Window still findable (the window wraps it, its node comes from the game's constructor and not the other mod's
function, it opens, generates and closes) and not findable (no window, no crash, a plain button with the tooltip, the
click logged); replaced together with react's id lookup (the record is checked and repaired); replaced by another
recipe while the game has an official Window replacement (that replacement builds the node); replaced with an
unrelated function after the Studio loaded (the window is still a game Window). A planted-fault check runs the first
on the old registration and must see the crash; a Lua error in a scenario fails that scenario. Planted faults checked
in a scratch script (review fixes 2026-10-13): each of the 11 (the body built through `builtin.Window`, `builtin.Window`
looked up at render time, the record check left out, the record left out or naming the other recipe, the official
replacement ignored, the button without its guard or as a toggle, each of the three log lines left out) fails at least
one scenario.

**In game:** with a mod that replaces `builtin.Window` active, the Studio opens and works, and the
log has the `[UTG] Another mod replaced the game's window component` line. Mods that also replace react's registration
functions must be off for that run: with them the Studio takes the normal path and the guard is not exercised.

## 25. All climates: the map types in Subarctic, Tropical and Dry (author 2026-10-14; revision 4)

**Decision (author, 2026-10-14):** players asked to use the Studio and the terrain engine in every climate. Revision 4
lets the twelve map types (designed for Temperate) run in Subarctic, Tropical and Dry, each with its climate's own
finishing pass (trees, rocks, ground, biomes, data maps). Map types made for those climates (Fjord Coast, Mesa
Country, Volcanic Islands; `core/climate.lua` `newTypes`) come in the next update. The core is unchanged: a seed gives
the same heights in every climate, and every accepted map stays identical (`core_baseline`). The Temperate pass is
unchanged byte for byte.

**Finishing passes (`tools/build_finish_tree.py`, table `CLIMATES`).** Each climate's pass is its vanilla import tree
with every imported input replaced by a recipe computed from the heights (built 2026-10-08 as drafts, research
the internal notes). Changes for shipping:
- **Biome outputs per climate.** A pass writes the biome raster and every layer its climate imports (`output_biomes`;
  a climate's normal generator writes exactly the layer keys its import tree reads, checked in the files for all four),
  each from the recipe that replaced the import: Subarctic `lakes` (open water), `swamps`, `mountains` (100 -> 170
  m); Tropical `volcano`, `mountains` (120 -> 250 m), `islands`; Dry `rivers`, `mountains` (120 -> 250 m),
  `monument_valley`, `coast_hills`, `mesas`. Without the raster the Import biomes mode would show the placeholder
  file's all-biome-0 blue preview. Temperate's three outputs come out as before.
- **Shipping by status.** `status: "shipped"` puts a pass into the mod folder and makes `--check` compare it byte for
  byte; the old `--ship` option shipped for one build only, so a shipped copy could go stale unseen. It is gone.
- **Dry river guard.** Vanilla Dry multiplies both of its asset inputs (rocks and plants) by a factor that is 0 within
  1 m of the blurred river core, computed from a distance map of the river layer (on narrow channels the core can
  vanish and nothing is cleared). On a map without river cells that distance map has no source pixel (an engine case
  vanilla never meets: its river amount is at least 0.001); if the engine gives 0 there, the map would get no plants and
  no rocks. The factor now comes straight from the river mask: 0 on exactly the river water, 1 elsewhere. UTG needs it
  anyway: river water is biome index 0, which Dry's class-1 mask counts as its own, so only this factor keeps shrubs out
  of the rivers. On wide rivers shrubs and rocks may now reach the waterline (vanilla left about 1 m): judged in run 14.
  Dry's river shrubs and river stones still read the vanilla distance; without river cells they place nothing whatever
  it returns.
- **Empty layers are not normalised.** UTG gives Dry's monument valley and coast hills and Tropical's islands no content. Vanilla normalises the heights they make (`normalize_map` of a constant map, never seen in game: min = max) and
  feeds the result into shrub, cactus, stone and hill-tree densities through arithmetic only. With an empty layer each
  of those nodes means exactly 0 ("no feature"), so the pass replaces them by 0 (Dry `height range`, `New Normalize Map
  #311`; Tropical `island heights`). The constant-map case of the Temperate pass (its mountains chain on maps without
  land above 250 m) reaches the trees only through distance thresholds and is left as it is. Normalisations that still
  see a zero layer MAX it with a real density first (Subarctic plains trees, two Tropical forest_mask maps).
- **Biome bands** stay the first values of 2026-10-08 (band 4 from 130 m Subarctic, 120 m Tropical; Dry 0-2-1-4-3
  from 0 / 12 / 80 / 170 m); run 14 reads the land shares per biome and they move only if one band dominates (the
  biome masks steer where the game places industries).
- **Lower tree density** stays Temperate only (DESIGN 20): each climate wires its tree kinds differently (Subarctic
  `combine_map` stacks, Tropical about nine kinds MAXed, Dry about twelve shrub and cactus kinds), so the scaling and its
  checks are per climate work for a later update. The Studio shows the box only where the climate's pass declares it.

**What the climates paint on these map types** (snow and rock lines from the climate trees and `core/climate.lua`; the
heights are the same in every climate). Which Terrain step reaches a line was measured on 2026-10-14 on the accepted
core maps (`tools/core_baseline.json` at Gentle, Hilly and Mountainous, probes of the same core at Moderate and Rugged;
11 km, seeds 1 and 2, sliders 100 %, land P99 and highest point). The readme, the guide and the Studio's Terrain
tooltip use these words. They replace a first estimate (P99 140 / 210 / 280 / 350 / 420 m times a factor per map type)
that the measured maps disprove (Great River Valley P99 180-190 m at Gentle, 470-500 m at Mountainous).
- Temperate: rock from about 280 m, snow from about 330 m.
- Subarctic: rock from about 130 m, snow from about 210 m. Alpine, Mountain Range and Highland Plateau reach the snow
  from Gentle (P99 305-345, 224-243 and about 220 m), most other map types from Moderate (P99 about 230-300 m); Island
  Chain and Rolling Plains only a few peaks from Rugged (highest point 211-269 m); Delta Lowlands hardly ever (at most
  a spot at Mountainous: highest point 192 / 252 m). The sea counts as open water for the lake-shore tree band
  (vanilla's lakes layer is inland lakes only): judged in run 14.
- Tropical: no snow; bare rock from about 210 m, reached by the same map types at the same steps as Subarctic's snow.
  Its hill trees and palms read a slope band (0.15-0.75 in the import tree); that this leaves few trees on Gentle and
  Moderate hills is inferred only (the band's slope unit is not verified), so the player text does not say it.
- Dry: no snow; rocky ground on high land (the `mountains` map from 120 m); no forest_mask (Dry has none).

**Studio.** The climate note on the Settings tab follows the pass, not `climate.lua`'s `finished` (data only,
unchanged), and whether `climate.lua` knows the climate (the Studio's `climateProfile()`, read as `profile()` does):
- a climate `climate.lua` does not know (another mod's) and no pass -> "This climate gets the terrain shape only (no
  forests or biomes)." (no climate name: `profile()` would say Temperate);
- a known climate whose pass is missing (failed to load) -> "Climate: X. Gets the terrain shape only (no forests or
  biomes). Best map types:...";
- a known climate with a pass whose map types are not its own -> "Climate: X. The map types are made for Temperate; map
  types for this climate come later. Suits best:..." (`climate.lua` `fits`);
- Temperate -> no note.
The Terrain tooltip (`TERRAIN_TIPS`) names the climate's own snow or bare-rock line and which map types reach it; the
Overall height tooltip (`HEIGHT_TIPS`) says what higher land brings in that climate (more snow on Temperate and
Subarctic, more bare rock on Tropical, neither on Dry). Temperate's texts are unchanged; a climate `climate.lua` does
not know gets Temperate's tooltips (open: a neutral text). The Run test and Apply log lines end with "climate <climate>,
finishing pass <name>" ("none" for bare heights), so run material shows which climate it came from.

**Checks.** `build_finish_tree --check` (17 rows): the mod holds exactly the shipped climates' passes; each shipped pass
equals the build, writes the biome raster and its climate's layers, and names its climate in the canonical form the
game's lists compare (`::/climates/<c>/<c>.clima`); lint; Temperate's four tree density rows. `studio_check` (30
checks): the fake engine builds its list of finishing passes from the mod's files; main flows on the Dry pass (with Run
test), Subarctic Lake District and Tropical Coastal Region (Preview runs the climate's pass by name), an Apply-refresh on
the Tropical pass; the no-pass path kept by a flag (Dry, Temperate) and a climate another mod adds; the climate note,
Terrain and Overall height tooltips checked per climate as soon as the window opens; planted faults each caught.

**In game:** each climate's pass loads and runs through the Import biomes mode (coloured preview,
trees, rocks, data maps), Apply without a crash, the climate strings, land shares per biome, Subarctic coasts and a map
without open water, Dry on a low map.
