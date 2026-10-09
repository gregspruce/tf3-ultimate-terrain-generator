# Changelog - Ultimate Terrain Generator

Format: [Keep a Changelog](https://keepachangelog.com/). Last Updated: 2026-10-09 (update prep: revision 2, shipped docs reviewed).

## [Released] revision 2 - 2026-10-09 - mod.io 6433560
- Uploaded to mod.io (mod file checked against the download); release tag `utg-r2`; public repository
  `tf3-ultimate-terrain-generator` (release r2, docs corrected the same day).

## [Unreleased] - 2026-10-09 - update prep (revision 2)
- Gallery (author): 1-8.png resized to 1920x1080 (1.7-3.5 MB each; originals in
  a backup, not shipped). publish_check: gallery images 1920x1080 and <= 8 MB too (FAIL).
- Cover (author: the 8 MB limit is real after all): new `_metadata/0.png` = the author's 1.png scaled to 1920x1080
  (2.4 MB; no old 0.png existed by then, the author had renamed it to 1.png). publish_check cover rule strict again
  (1920x1080, <= 8 MB); gallery images over 8 MB are a note (1, 2, 3, 4, 5, 6, 8.png are 8.8-14.3 MB).
- Mod Hub description: the numbered How to use steps ran together into one paragraph (author screenshot). Shared
  `tools/readme_to_html.py` now writes numbered steps as one paragraph each with a bold number; UTG and SIP
  description.html regenerated (SIP's had the same problem). Shared `tools/publish_check.py`: cover may be any 16:9
  >= 1920x1080 (the author's 3840x2160 screenshots work; never change them), over 8 MB is a note.
- `RELEASE_NOTES.md` (new, as SIP's): paste-ready mod.io Changelog text for revision 2 (author).
- **Alpine hints** (author: not clear which settings give a mountain/alpine region like vanilla): Relief tooltip names the
  snow line (Rugged and Mountainous reach ~350 m); Mountain Range description says it is the most alpine type (snow
  from Hilly up); readme map list and extended_readme Relief row say the same (vanilla alpine stamps peak ~460-520 m;
  our Mountain Range Hilly/Mountainous peaks 590-960 m, T1 run 6). Text only; baseline 40/40, studio 12/12.
- **Mod setting "Debug tools"** (author 2026-10-09: "whether the debug tools show should be a mod setting that defaults to
  off"): mod.json param `utg_debug_tools` (Button Off / On, default Off); the window shows the Debug row (Export,
  Test set, Run test, Save log) only when On (read once with getModParams, 1-based: 2 = On). strings.json has its
  texts; readme (Feedback, Changes) and extended_readme (Debug row) say where to turn it on. studio_check: fake
  getModParams (On for the existing scenarios) + new scenario "Debug tools Off: no Debug row": 12/12.
- **mod.io id restored:** the staged copy had lost `_metadata/mod.io_fileid.txt` (an upload would have created a NEW
  mod). The published mod is mod.io 6433560 (the installed copy: folder name, modId
  ultimate_terrain_generator, revision 1); the file is back in the project mod folder (digits + CRLF, as SIP's).
  publish_check: "uploads UPDATE mod.io mod 6433560".
- `mod.json` revision 1 -> 2 (publishing doc: increase on every published update).
- Shipped docs reviewed: readme (preview is coloured by biome and trees appear after Apply; "When applying" as the
  window says; Feedback leads with Run test; Changes list adds Run test and shorter window texts), extended_readme
  (readme.md name, preview colours, Debug row as a list incl. Run test). description.html regenerated.
- Independent fact-check (read-only review): no factual errors; applied: Several = up to 3, Run test = this mod's
  generator on Temperate, Test set = this mod's generator, readme trims (Preview step, Good to know merged, Improved list
  shortened), duplicate Limits bullets removed. publish_check (full, with tests) 9/9.

## [Unreleased] - 2026-10-08 - author's first look at the new build (wide screens, trees, one click, description)

Author (log, 5120 x 1440 screen): settings column fine, preview pane far too wide; "after a game update
UTG terrain doesn't get trees when applied"; why Generate and then Preview when other generators need one click; the
mod description needs a complete update with a changelog.

### Changed (GUI wording, 2026-10-09)
Author: the window is too wordy. Text only (no logic); studio_check 11/11.
- **Removed:** the "Not ticked: Apply removes them..." note under Keep towns / Keep industries (now in the two check
  boxes' tooltips), and the "Press Preview: the map is generated and shown on the right..." paragraph.
- **Shortened:** "Preview ready" status (the forests remark moved to the enabled Apply to map tooltip), game-generator
  help, "Map size:", stale-settings note, climate note (still says "terrain shape only"), small-map note, lakes note,
  Relief / Generator / side tooltips, Applied / Undo / finishing-pass / "Still generating." statuses, empty report and
  empty preview texts. Fixed "press Generate" in the generator-switch status (no such button any more).
- Unused stylesheet class `utg-page-group` removed; studio_check reads the removal warning from the tooltip.

### Changed
- **One click for this mod's generator:** the Generate button is gone; Preview generates (if there is no map for the
  current settings yet) and goes on to the finishing pass by itself one frame later. Time: the Lua generation itself
  (~8 s on 14 km in the author's log) is unchanged; the game's generators run natively in the engine (2.5-3 s).
- **Width caps for wide screens:** window <= 2600 px (Larger window 3000), preview pane <= 1880 px; no
  stylesheet unit ties width to the screen height (base CSS never uses vh in a width), so pixel caps; no effect on
  16:9 screens up to 2560 px.
- **Mod description rewritten** (reviewed): README / description.html (own window, any generator,
  preview on request, map editor only, no new-game mention, "Changes in this version" since the 2026-10-07 release),
  extended_readme.md (one-click Preview), modinfo description and summary.

### Run 13 (testscreenshots/13, 2026-10-09): preview colours fixed, Run test works
- **Run test** (one click) finished by itself in 22 s on 14 km (Coastal Region, Hilly): two previews, Apply, Export,
  log. collect_run judged the finished maps' biome rasters **varied** (b0 22 %, b1 30 %, b2 21 %, b3 24 %, b4 3 %), the
  same with one pass and with two; the placeholder raster stays uniform. Place assets 27-34 ms (trees); data maps after
  Apply follow the terrain (biome0 17 % at -17 m... biome4 6 % at 292 m, forest 33 %).
- Author: the one-pass preview is multicoloured (biome colours: water blue, lowland greens, hills brown, high ground
  pink/white), also when run by hand. So the pass's own `output_biomes` replaces the file's raster in ImportBiomesMode.

### Changed (run 13 follow-up, 2026-10-09)
- Removed the Debug choice One pass / Two passes and the two-pass code (not needed: same raster). Run test is now one
  preview, Apply, Export, Save log; its finished map is written as `utg_test_<id>` with biome masks. Strings,
  extended_readme, studio_check updated.

### Run 12 (testscreenshots/12): trees are back; the preview is blue
- Test C (our pass through ImportBiomesMode with a placeholder biome file): **trees and rocks on the map** (author:
  "TREES! They're back"); data maps after Apply follow our terrain (biome0 5 % at -7 m, biome1 35 % at 25 m, biome4
  11 % at 292 m, forest 38 %, river 1 %). Tree test: all four previews kept the heights.
- New problem: the whole preview is tinted blue (the game's Temperate generator in the same window is not).
  Cause (checked offline): the placeholder masks written from our heights map are uniform 0
  (`utg_biomes_..._biomes.png`, 3584 x 3584, one value; a vanilla export has 0/63/127/191/255), biome 0 is the water
  biome, coloured {0, 0.63, 0.9} in temperate.clima.lua, and our standard pass had no `output_biomes`, so the raster
  stayed the file's. Our window passes `showBiomesColors = false`, so the tint comes from the mode itself.

### Changed (run 12 follow-up)
- **The Import biomes route is the standard Preview** (the HeighmapGenerationMode + keepHeightmap route is gone: since
  the update it gives an import tree no heights). The placeholder biome file is written once as `utg_placeholder` and
  reused (also across sessions).
- **The standard finishing pass writes the biome raster and the rivers and mountains layers** (`output_biomes`, the
  former "Test A" variant, now built into `utg_finish_temperate`), so the preview should take its colours from our
  biomes. If it is still blue (the mode keeps its file's raster), Debug **Two passes (test)** exports the first
  pass's finished map with its biome data (`utg_twopass_<id>`) and runs the pass again with that file.
- Removed: the test variants `utg_finish_temperate_importbiomes` and `_normal` (files and builder options
  `import`/`passthrough`/`variants`), the Debug pass choice Standard/Test A/B/C, the Tree test, and the probes
  (heightmap import route, the game's Import biomes route with existing files); their strings.json keys. Recoverable
  from the temporary folder backup `utg_studio.before_run12fix.lua` and this changelog; no git in this workspace.
- Readme: "Fixed: trees are back" in Changes in this version; extended_readme: the files the tool writes, the Debug
  choice. description.html regenerated.
- Checks: studio_check 11/11 (new: Import biomes mode with the placeholder, placeholder written once, Two passes
  exports the first pass's map and Apply uses the second); run_checks 6/6; publish_check 9/9; baseline 40/40.

### Added (author 2026-10-08: "further testing as automated as possible, 1 button runs the tests start to
finish and exports the logs/heightmaps")
- **Debug "Run test"**: one button runs the in-game check by itself: Preview with two passes, Preview with one pass,
  each finished map written with its biome data (`utg_test_<id>_twopass` / `_onepass`), Apply of the one-pass map
  (data maps logged), Export of the world, log saved as `utg_log_test_<id>.lua`; restores the Debug choice; stops
  with the log saved if a stage gets no answer for 180 s. All buttons are disabled while it runs. studio_check covers
  it (both maps with biome data, one Apply, world export, log, choice restored).
- `tools/collect_run.py` also copies the utg_* biome masks (to `<run>/biomes/`, placeholder skipped) and judges each
  biome raster: UNIFORM (the placeholder's: blue preview) or varied with the share of each biome. Tried on the
  existing files: the author's vanilla export "varied (b0 16 %, b1 52 %,...)", run 12's mask "UNIFORM".
- the internal notes are now: press Run test, look at the preview once, say "run 13 done".

### Run 11 (testscreenshots/11): the Import biomes route works on our heights
- Test C (Import heightmap route, ImportExportHeightmapMode): heights only, no generator pass ("no data maps", no trees
  or rocks; textures default, "closer but not correct").
- Tree test: our pass 4.8 ms, + biome outputs 5.3, as a normal generator 5.2; the game's generator 25.1; **the game's
  Import biomes route (vanilla import generator, ImportBiomesMode, the author's vanilla biome files) on OUR heights:
  27.2 ms, heights kept**. So in ImportBiomesMode an import tree still gets the real heights and places trees.
- Next probe: OUR pass through ImportBiomesMode (it computes biomes, rivers and mountains from the heights; the mode's
  biome file only has to exist: written with app.writeHeightmap(..., biomesData = true), which puts
  <name>_biomes/_mountains/_rivers into the biomes folder). Debug "Test C: our pass via Import biomes" (Preview +
  Apply), Tree test steps 1 our pass, 2 our pass via Import biomes, 3 the game's Import biomes route, 4 the game's
  generator.

### Run 10 (testscreenshots/10): the root cause, and the import routes
- Window placement good (author).
- **After a standard Apply every data map is 0 % everywhere** (biome0-4, forest_mask, river_mask,...): the pass's
  height-based bands are empty although the heights arrive in the world. Since the game update `height_map_input`
  delivers no usable heights to an import-style pass run as HeighmapGenerationMode + keepHeightmap; everything built
  from it is empty: no trees AND wrong ground textures (author: Standard had wrong textures too).
- Test C (biome masks) never ran: `app.writeHeightmap` refuses paths ("Forbidden file name../biomes/..."); files go
  into the heightmaps folder by name only; with biomesData it writes <name>_biomes/_mountains/_rivers into the biomes
  folder by itself (the author's earlier vanilla export is listed there).
- New probes: Test C = the map editor's own "Import heightmap" route (our heights written as 16-bit PNG, imported with
  ImportExportHeightmapMode, generateAssets); Tree test step 5 = the same, step 6 = "Import biomes" route with the
  existing vanilla biome files (does that route still place trees). Statuses reworded: the preview shows the land only.

### Tree test run 9 (testscreenshots/9) and the biome-import probe
- Window: right width (36 % on 5120 x 1441, logged), centred horizontally but at the bottom: now centred vertically
  too (stylesheet gravity / anchorPoint 0.5, 0.5).
- Place assets: 1 our pass 4.9 ms, 2 + biome outputs 4.5 ms, 3 as a normal generator 4.4 ms, 4 the game's
  generator 30.7 ms. Not "import vs normal": the vanilla normal tree's forests use heights it computes itself, ours
  read `height_map_input`; suspect = what that node delivers since the update.
- The preview shows no trees and the tree test does not apply (author): so (a) a Debug choice "Finishing pass:
  Standard / Test A / Test B / Test C" used by Preview AND Apply, to look at trees in the world; (b) after every Apply
  the log lists each data map's share of the map and the mean ground height there (do the bands follow our heights?).
- **Biome import (author's idea; the supported import route):** Test C / Tree test step 5 write our biome, mountains
  (and empty rivers) masks into the userdata `biomes` folder with the game's exporter and run the game's own
  Temperate import generator through `ImportBiomesMode` on our heights (base "Import biomes" tab; wiki mask format).

### Tree test result (testscreenshots/8) and the next step
| Step | Place assets | Heights kept |
|---|---|---|
| 1 our pass (import-style, keepHeightmap) | 5.0 ms | yes |
| 2 our pass with the run-5 tree rules | 4.4 ms | yes |
| 3 our pass, keepBiomes | 4.5 ms | yes |
| 4 the game's Temperate generator with keepHeightmap on our heights | **23.5 ms** | **yes** |
- Our tree rules are not the cause (2 = 1). After the update a NORMAL generator keeps the heights with keepHeightmap
  (in probe run 1, before the update, it overwrote them) and places trees; import-style passes no longer get trees.
- A normal vanilla tree writes three `output_biomes` layers (biome raster, rivers, mountains: the layers an import
  tree reads from files); ours does not. New test variants (built by `tools/build_finish_tree.py`, lint 0 errors):
  `utg_finish_temperate_importbiomes` (our pass + the three outputs) and `utg_finish_temperate_normal` (the same as a
  NORMAL generator with our heights passed to a height output). The Tree test now runs: 1 our pass, 2 + biome
  outputs, 3 as a normal generator, 4 the game's generator. The run-5-rules variant and its check box are gone.
  Preview never uses a variant; the Generator list never shows our passes (a variant may be a normal generator).
- Window width, second attempt: the screen size was not readable in the stylesheet at load (window stayed 84vw).
  Now the window script reads it when the window opens (logged: "[UTG] Screen W x H: window N %...") and gives the
  window a width class; the stylesheet has one rule per even share 30-96 %. 5120 x 1440 -> 36 % (Larger 38 %).

### Fixed (author's second look, log + screenshot, 5120 x 1440)
- **The width caps did nothing in game** (the window ignored `maxSize`, still ~4300 px wide) and `initialX = 0.5` left
  the window at the screen's left edge under the game's tool strip. Now: the stylesheet reads the screen size
  (`api.util.getGraphicsPresetParam().screenExtent`, new with the game update) when it loads and makes the window
  "settings column + square preview" wide (5120 x 1440 -> 36vw; 1920 x 1080 -> 80vw; 3840 x 2160 -> 62vw; per text
  size; never above 84vw / Larger 96vw), and places it like the base Statistics window (centred, 64 px above the game
  bar, not movable). Without a screen size: the old shares.
- **Tree test hung at 1/4:** the native preview only runs when its inputs change, and step 1 equalled the preview just
  before it (log: no "Preview started" after the test began). Every request now gets its own preview component
  (`meta.localKey` per request) and the test a fresh map copy per step; a repeated Preview with unchanged settings
  also runs again now.
- The tree count is "not countable" from Lua (`#map.trees` unsupported); the engine's "Place assets" times in
  stdout.txt remain the measure.
- `README.md` renamed `readme.md` (workspace publishing rule of 2026-10-08: every published file name lowercase);
  description.html regenerated; publish_check 9/9.

### Investigating: no trees after Apply
- Author (later the same evening): a player on the ORIGINAL release (2026-10-07, which already had the run-6 tree
  rules) reports the same: the game update is the trigger. As the files did not change (below), the engine (exe)
  treats our route differently: an import-style pass run with keepHeightmap. `base/init.lua` gained
  `pairs_native_lua_table` (native tables handed to Lua differently), the only engine-API hint in the files.
- **Debug "Tree test"** (Studio): on the map in hand, four previews one after another, each logged with its tree count
  (where countable) and whether the heights were kept: 1 our pass, 2 without the newer tree rules, 3 our pass with
  keepBiomes, 4 the game's own generator with keepHeightmap on our heights (a way round if it keeps the heights); the
  log is saved as `utg_log_treetest_<id>.lua`; the engine's "Place assets" times are in stdout.txt.
- Not the game update, as far as the files show: the update (2026-10-08 local) changed the exe, gui.zip,
  game_mechanics.zip and others, but `climates.zip`, the vegetation/rock asset zips (contents identical) and the map
  editor's preview/apply code (one unrelated line) are unchanged.
- Evidence: the game logs "Place assets" per preview: our finishing pass now 3.8-4.7 ms vs 25-44 ms in run 5 (16 km)
  and 20-43 ms for the game's generators on the same 14 km map: our pass places very few trees, already in the preview.
  The pass changed after run 5 only by the run-6 vegetation edits (slope ramps, river-tree thinning), never seen in
  game until tonight.
- In-game A/B added (temporary): a second finishing pass `utg_finish_temperate_vanillaveg` = the same pass WITHOUT the
  run-6 vegetation edits (= run 5's), selectable with the Debug check box "Test: vanilla trees"; the log line "Preview
  ready" now names the pass and the tree count where the engine allows it. Builder: `variants` in `CLIMATES`.

## [Unreleased] - 2026-10-08 - any generator, buttons, keep towns/industries, feature side (work plan 2)

Author requests; plan and status: the internal notes.
All offline-checked; nothing of this seen in game yet (the internal notes steps 8-12, the internal notes).

### Added
- **Any terrain generator in the Studio** (DESIGN.md 15.5): a "Generator" choice (this mod's own, then every visible,
  non-import generator of the climate, vanilla and mods, in the game's order); a game generator's own parameters with
  the base widgets (`script_param_util.buildScriptParamComp`; combo boxes if that module cannot be loaded); its preview
  runs only on Preview and is the generation (no Generate step); a note when the settings changed since the preview;
  the Report measures the finished map (land, slope classes, heights; `engine_generators.measure`, over frames); Apply,
  Undo and Export work for it. New module `content/scripts/ultimate_terrain_generator/studio/engine_generators.lua`.
- **Keep towns / Keep industries** on Apply, like the vanilla generator window: unless kept, towns and then industries
  (with their roads) are removed before the terrain is replaced, in the base order; removals are not player-initiated
  (no cost, no reputation).
- **Feature side** (DESIGN.md 17): per map type, which map edge gets its main feature (Sea side / River comes from /
  Rivers flow towards; Random = the seed, as before). Core: `shapes.SIDES`, `TYPES[id].side`, `orientationFor`,
  pipeline setting `side`; the settings text names the side only when chosen (export_check parses it).
- `tools/settings_check.py` group `sides` (72 cases: the feature on the chosen edge); `tools/studio_check.py` 11 checks
  (new: two game-generator scenarios, a side scenario, Apply removal order, disabled Apply before the preview, primary
  Generate button).

### Changed
- **Buttons look like buttons** (players: "the buttons don't look like buttons"): the game's plain Button style is
  transparent with an outline only on hover; the Studio now uses the game's own "primary" (filled: Generate, Preview,
  Apply) and "secondary" (outlined: everything else) classes, greys out buttons that cannot act (`meta.enabled`), and
  gives them a common minimum width.
- README / description.html and extended_readme.md: generator choice, sides, keep options, buttons, Undo limits.
- Research: the internal notes correction (buttons CAN be disabled via meta.enabled) and the button
  classes.

### Fixed (second GUI evaluation, review; all in the Studio)
- **A failed or unanswered Apply/Undo could lock every button for good** (busy flag never cleared): removal and
  replacement are now pcall-guarded, and a watchdog releases the buttons after 90 s without an answer, with a status.
- Undo kept nothing to retry after a failure (its map was dropped first); the Undo map is now only replaced by a
  successful Apply and only cleared by a successful Undo.
- Closing and reopening the window re-ran the last preview (a full generator run): the request is dropped on close; the
  finished map stays ready for Apply, and Preview shows it again.
- Switching generator kept the old status and a running Generate; it now stops that Generate and sets a fitting hint.
  A finished older measurement could overwrite a newer preview's report; a failed measurement now says so.
- Game generator defaults are now the base game's rounded values (`getScriptParamDefaultValueIndex`).
- Map type change resets the side to Random ("Sea side" and "River comes from" name different edges).
- The game's own parameter widgets are styled inside our pages (the base styles them only in its own window): the same
  rules scoped to `!utg-page` (map_editor.css.lua:90-127, 164-169).
- Apply on a climate without a finishing pass recorded no height range for Export (regression from the morning's
  Apply rework, caught by studio_check).

### Changed (second GUI evaluation)
- Only the NEXT step is the filled button (Generate -> Preview -> Apply); Preview is greyed out where there is no
  finishing pass (Apply sets the heights directly); greyed buttons have a tooltip saying why.
- Keep towns / Keep industries: row "When applying", tooltips, and a visible note while one is unticked ("Apply removes
  them...; Undo does not bring them back"); the preview-ready status mentions the removal.
- Wider Generator combo (long generator names), wide label for the side choice, 16 px between field pairs (slack at
  medium text), Test set only for this mod's generator, "Steps: 1 Generate, 2 Preview, 3 Apply to map" hint, plainer
  status texts ("Adding forests, rock and biomes in the preview...").

### Not changed
- Terrain: 40/40 accepted maps identical (Random side = the seed's orientation).

## [Unreleased] - 2026-10-08 - work plan: GUI rework, settings audit (author request while run 7 waits)

Plan and status: the internal notes.

### Changed (Studio window, `utg_studio.script.lua` + `utg_studio.css.lua`)
- **Layout after the base map editor's generator window** (review 2026-10-08; the internal notes
  "Window layout that fits every screen"): the settings column has a fixed pixel width per text-size setting (650 /
  720 / 820 px for small / medium / large text: two label + field pairs side by side always fit, nothing floats on
  4K); the preview pane fills the rest of the window (was a fixed 30vw x 76vh portrait pane, about half empty); each
  tab page scrolls on its own and the tab headers stay (the whole TabWidget used to scroll); window 84vw x 80vh,
  Larger window 96vw x 88vh, centred at the top so the bottom stays clear of the game bar (was 72vw x 86vh, 93vh
  expanded: buttons behind the game bar below ~1000 px screen height, and the fixed 62vh tab area clipped the buttons
  below ~840 px). Labels have fixed widths (fields line up), sliders fill the row with the value right-aligned, help
  text wraps inside the column (its 36vw width overflowed the pane below 2600 px screens), the status keeps two lines
  (buttons no longer jump), text follows the game's text-size setting (`font-scale-body`, tab indicators
  `font-scale-tab-widget-indicator`).
- Settings tab: a one-line description of the chosen map type; tooltips on Relief, Water, Ship rivers and Seed; the
  map size of the editor map, and a note on maps under 6 km (most map types make few or no rivers there).
- Terrain parameters tab: sliders a map type has nothing for show "-" and a note names them (Island Chain: Rivers,
  Lakes, River bends, Valley width; Rolling Plains and Lake District: Coast roughness); a note that Lakes above 100 %
  can only use the natural lake sites.
- A note when the settings changed since the last Generate (Preview and Apply would use the older map).
- Generate during a Generate or a test set, and Preview or Apply during a Generate, now say why nothing happens
  (buttons cannot be disabled in a mod window); the Generate button keeps its label (no row jump).
- "Larger window" moved to the top of the preview pane; the debug row is labelled "Debug" (Export, Test set, Save
  log).
- Report: lines starting with "note:" are highlighted.

### Fixed (core; found by `tools/settings_check.py`; 40/40 baseline maps identical)
- **Valley width 0 %** skipped every valley side silently (and left a sea-level puddle beside a lake on Coastal
  Region): a 0 m side zone made `landform.valleyTarget` divide by zero (NaN). Zone 0 now means the limit slope starts
  at the floodplain edge.
- **Surface detail and Erosion at 200 % on Mountainous** dug up to 9 sea-level puddles into 15-25 m lowland: the
  detail term had no lower limit. `detail.DETAIL_FLOOR` (0.5 m): land that was above +3 m never ends below it
  (designed maps never get that low, so they stay identical).

### Changed (player docs)
- `README.md` (-> `_metadata/description.html`) rewritten for the new window: preview when you ask for it (and why),
  the window layout, notes in the Report, other climates (terrain shape only for now), small maps, towns and
  industries on Apply; "any generator" is not listed as planned (author decision pending, the internal notes).
- New `extended_readme.md` in the mod folder: how a map is made (stages), why the map editor and why rivers sit at
  sea level, every setting with its numbers, every Terrain parameter, the Report fields, the buttons, limits and
  their reasons. Shipped workspace references removed from code comments (publish rule).

### Added (other climates: framework; nothing shipped for them yet)
- `tools/build_finish_tree.py` is now one table `CLIMATES` (biome bands, which vanilla input gets which replacement:
  biome bands, rivers, open water, height ramp, zero; Temperate's vegetation tweaks). Temperate's output is byte for
  byte the same; Subarctic, Tropical and Dry are built as DRAFTS into `build/finish_drafts/<climate>/` (not in the mod;
  0 lint errors each) until an in-game probe checks them (`--ship <climate>` afterwards).
- `core/climate.lua`: climate profiles as data (snow and rock lines, map types that suit each climate, river and lake
  factors, planned climate map types). Not read by the generator yet (maps unchanged); the Studio uses it to tell
  players on Dry, Subarctic and Tropical maps that they get the terrain shape only, and which map types suit.
- Research: the internal notes.

### Added (testing)
- `tools/core_baseline.py` runs its 40 maps in parallel (`--jobs`; was ~4.5 min serially).
- `tools/collect_run.py <run> [--check --compare <run>]`: copies a run's utg_* files from the game's heightmaps folder
  into `testscreenshots/<run>/` (the game folder is only read; nothing overwritten) and runs export_check.
- `tools/run_checks.py`: every offline check in one command with one summary table.

### Added (design)
- DESIGN.md section 15: plan for any vanilla or mod terrain generator in the Studio (on-demand preview); section 16:
  settings audit (caught and fixed, explained to the player, settings to add or not). the internal notes.

### Added (core: text and report only; 40/40 baseline maps identical)
- `shapes.TYPES[id].description` and `.inactive` (sliders without effect per map type) as data for any host window.
- Report notes when the map could not give what the settings asked: Ship rivers One/Several with too few large
  rivers, fewer lakes than wanted (`report.shipsAsked`, `report.lakesWanted`, set by `pipeline.run`).
- `tools/settings_check.py`: every setting at its edges on every map type and odd map shapes (1.5 km squares, 1:5
  strips both ways, 1:3), all sliders at 0 % / maximum, Ship rivers x Water, odd seeds; parallel (24 processes: 424
  cases in 38 s at 4 km).
- `tools/studio_check.py`: new layout rules (fixed column per text size, filling panes), the new notes and guards,
  descriptions in the strings check; 23 new strings.json keys (3 unused removed).

## [Unreleased] - 2026-10-08 - playability numbers (TODO "Later"; run 7 material not yet in)

### Documentation (workspace)
- the internal notes: airport and airfield footprints from the game files
  (`stations/air.zip`): airfield flat field 400 x 110 m, airport 580 x 125 m (184 / 239 m with 2nd runway / terminal
  B), 500 m runway, approach zones 410-500 m past each end under rising planes (43 m and 134 m at the outer ends);
  the old guess "runways 1-2+ km" is corrected. W7.2: no file sets street `maxSlope*`; the street menu's Incline
  slider shows `maxSlopeBuild`, so the real grade can be read in game.
- Town slope limit: not in any file (native town placement; only `allowInRoughTerrain = false`). Stays open.

### Not changed
- Erosion speed (TODO "Later"): profiled at 16 km, erosion adds 3.5 s to a 10 s Generate (texture rows 1.6 s,
  interpolation 1.9 s). Left as is: the author found big-map generating time fine; revisit only if Generate feels
  slow.

## [Unreleased] - 2026-10-07 - release text, cover, lessons documented (author request during run 7)

### Changed
- **Mod description** (`README.md` -> `_metadata/description.html`) written for a first release: "Preview" dropped,
  Temperate stated as this release's climate, how-to for the new window (Relief steps, Terrain parameters, Larger
  window, Play map), Save log in Feedback, and a **Planned** list at the bottom (other climates' finishing pass,
  climate map types, new-game generator, Undo with trees, faster large maps). `modinfo.json` description and summary
  no longer claim all four climates.
- **Cover** `_metadata/0.png` (author: the old one looked computer-made): `tools/make_cover.py` now renders a real map from
  the mod's own core (Mountain Range with Passes, Hilly, seed itl4iveu59, 16 km, 8 m per pixel) as a topographic map:
  relief shading from the north-west, elevation tints, contour lines every 20 m (100 m bolder) traced on lightly
  smoothed heights, stepped water-depth bands with a crisp shoreline; no text. `--try <dir>` renders candidates.

### Documentation (workspace)
- New internal notes (logs and Save log, ids, Export/Test set, offline checks of
  the real Lua, frame budget and memory, the in-game run routine); the internal notes: checklist for a
  mod window; the internal notes: cover style; research README, the internal notes (index, fact:
  stdout.txt rewritten on start, writeHeightmap from a mod window).

## [Unreleased] - 2026-10-07 - run 6: erosion, Relief steps, Several ship rivers, trees, window, Save log

Run 6 (author, 16 km, the internal notes): scale better, but hills and mountains still "too smooth / blended"; Flat not
wanted; "Several" gave one ship river; striped forests on slopes and hard-edged river-tree lines; window cramped,
small and stacked; stdout.txt lost on restart.

### Added
- **Erosion texture** (`core/gullies.lua`, new): spurs and gullies running downhill on every slope, two octaves
  (300 m, side gullies 115 m following the main spurs' flanks), Gabor stripes from a jittered lattice aligned with the
  local slope, each cell's stripes flipped by a random sign (phase 0 or pi: a free phase drew dotted seams along every
  ridge, where the downhill direction flips); depth = K x slope x wavelength (flat land, floodplains and pass floors
  get none). Computed on a 16 m texture grid only where the land is rough, rows on demand, interpolated to 4 m by
  detail.lua; never cuts more than half the height above the detail floor (no puddles); yields to the frame budget
  while building its tables. 16 km, run 6 seed, hill-land curvature c8 / c32 / slope spread (vanilla 15.5 / 5.9 /
  0.09): Gentle types 4-5 / 2.1-2.4 / 0.05 -> 8-10 / 3.0-3.4 / 0.05-0.07; Mountain Range Hilly 7.3 / 3.3 / 0.07 ->
  14.8 / 5.3 / 0.10; Mountainous 17-21 / 6-8 / 0.12-0.14 (harder than vanilla, as intended). Flat land almost unchanged
  (Great River Valley Gentle 28.4 -> 27.7 %). Cost: about +3.7 s on a 16 km map (Generate ~10-12 s offline).
- Terrain parameter **Erosion** (`pipeline.TUNE` key `gullies`, 0-200 %).
- **Relief** levels as data in the core (`pipeline.RELIEF`): Gentle, Moderate, Hilly, Rugged, Mountainous.
- Studio **Save log** (debug): the session's `[UTG]` lines with UTC times into `<userdata>/heightmaps/
  utg_log_<id>.lua` (`app.saveUserdata`), next to the exports; the **Test set saves its log by itself** at the end.
- Studio **Larger window** / Smaller window: a second window size (the game has no free window resizing; the
  `expanded` window state, as the base Statistics window).
- Report: number of ship rivers (`ship rivers N, X km`).
- `scale_check.py` / `export_check.py`: texture metrics c8, c32, sdS (vanilla reference measured);
  `export_check.py` reads the saved logs (`utg_log_*.lua`) as well as stdout.txt and knows the new Relief names.
- `studio_check.py`: strings check (every window text has a strings.json key), Save log, Larger window, test set T2
  (19 cases, log saved): 9 checks.

### Changed
- **Relief:** Flat removed (author: too uninteresting); Moderate and Rugged added halfway. Gentle, Hilly and
  Mountainous keep their values exactly (proved: with Erosion at 0 % the new core reproduces all 40 accepted maps at
  Gentle and Mountainous except Delta Lowlands, whose change is the ship-river fix). All per-Relief tables have 5
  entries; settings `relief` is 1-5 (was 1-4 with Flat = 1).
- **Ship rivers "Several":** the two largest other rivers (other mouths and the trunk's tributaries, wherever they
  join; the trunk's ship reach extends to the junction) always become ship rivers, navigable for at least 4 km
  (`rivers.SHIP_MIN_LEN`), however small. Great River Valley, Hilly, run 6 seed: 1 -> 3 ship rivers (29 km).
- **Trees** (finishing pass, `build_finish_tree.py`): hill trees and conifers on smooth slope ramps instead of narrow
  slope bands (no contour stripes on even slopes); river trees thinned with distance from the water (70 % at 6 m,
  30 % at 50 m, none past 155 m, drawn with white noise) instead of a full-density band ending at ~46 m.
- **Studio window:** three tabs (Settings, Terrain parameters, Report); fields side by side (Map type + Relief,
  Water + Ship rivers, Seed); fixed-width labels, padding and spacing from the stylesheet; window sized to the screen
  (72 x 86 % of it; Larger window 96 x 93 %) with the preview pane always on the right (no jump when the preview
  appears; the preview centred and larger); tool buttons (Export, Test set, Save log, Larger window) on their own row.
- **Test set T2** (was T1): the five Relief levels, plus Great River Valley Hilly with Several ship rivers; 19 cases.
  Cases 1-10 have the same settings as T1's.
- `strings.json`: 94 keys (obsolete "Label: " variants, Flat and the old Advanced texts removed).
- Tools default to Relief 1 (Gentle); `core_baseline.py` cases are Gentle / Mountainous = Relief 1 / 5 (re-accepted
  with the erosion texture).

### Removed
- Generated previews made with the old Relief numbering or an older core: `previews/scale/*_r2*.png`,
  `*_r4*.png` (old Gentle / Mountainous; now `_r1` / `_r5`) and 34 `previews/m1/*.png` older than this change
  (regenerate any with `scale_check.py --png` / `core_check.py`). Nothing hand-made was removed.

## [Unreleased] - 2026-10-07 - Test set button and export_check.py (author request)

### Added
- **Test set** (debug) button: generates the fixed list `TEST_SET` (version T1: all ten map types at Gentle/Normal,
  Great River Valley at Flat/Hilly/Mountainous and Dry/Wet, Mountain Range at Hilly/Mountainous; 17 cases; seed
  `oeyrx62dl8`, the run 5 seed; Advanced at 100 %) on the current map size and exports each case straight from its
  generated heights (no Preview/Apply: the world is untouched). Names `utg_<batch id>_<NN>_<type>_<relief>_<water>_
  <seed>.png`; log lines name the set version, batch id and case number. Press again (Stop test set) to stop.
  Preview/Apply/Undo/Export wait while it runs. The last case stays ready for Preview/Apply.
- `tools/export_check.py`: reads a run folder (stdout.txt + utg_*.png), restores metres from the Export lines,
  measures every map like scale_check.py next to the vanilla reference, writes `export_metrics.md`; `--offline`
  regenerates each map with the current core (0.001 m on a synthetic run = same core); `--compare <run>` gives
  case-by-case changes between two runs.
- `studio_check.py`: test-set scenario (17 exports, names, log lines, world untouched, Stop): 8 checks. 8 new
  strings (84 keys).

## [Unreleased] - 2026-10-07 - Export button (author request)

### Added
- **Export** (debug) next to Generate / Preview / Apply to map / Undo: writes the world's heightmap as a 16-bit PNG
  with the editor's own exporter (`app.writeHeightmap(map, name, false, true, false)`, as
  `gui/map_editor/map_editor.tl` does). Name `utg_<Generate id>_<map type>_<relief>_<seed>.png` for a UTG Apply,
  `utg_<time>_world.png` otherwise (nothing applied yet, or after Undo).
- Every Generate gets an id (date and time, `20261007_042105`): `[UTG] Generate <id>: <settings>` and
  `[UTG] Generate <id> done...`. Export logs `[UTG] Export <file> (Generate <id>): <settings>; heights lo.. hi m =
  PNG 0.. 65535` (the export is normalised to the map's own range, so this restores metres).
- `studio_check.py`: export name, 16-bit, log line with settings and range, id matching a Generate line, `_world`
  after Undo. 4 new strings (76 keys).

## [Unreleased] - 2026-10-07 - run 5 feedback: game scale, Settings page, Advanced sliders

Run 5 (author, 16 km, the internal notes): the Studio works in game; the terrain was too flat and smooth for the game's scale.
Measured against a vanilla Temperate map of the same seed (new `tools/scale_check.py`).

### Added
- **Hill country** (landform step 3b): patches of hills on HILL_COVER of the land (Relief: 25/50/60/60 %), each a
  raised block (HILL_BLOCK 45 %) with 800 m hills on top (HILL_AMP 15/85/115/130 m), added after the ridge blur with
  its own slope limit, before the valleys are cut (floodplains stay flat, valley sides cut the hills). Per-type
  factor `preset.hills` (Delta 0.25, Rolling Plains 0.45, Island Chain 0.8, Highland Plateau 0.7).
- **Roughness field** (`landform.rough`): fine detail goes on hill country and steep ground only (never on plains,
  floodplains or pass floors); replaces the pass-only `calm` mask. DETAIL_AMP 1.5/5/6.5/8 m (was 0.6/1.4/3/6),
  fade-in 3..18 m (was 3..28).
- **Ragged coasts** on every map type (`shapes.COAST_RAG` 900 m: 6-octave edge noise, gain 0.62); eval-type maps now
  also turn slivers and enclosed sea specks into low land.
- **Advanced settings** (`pipeline.TUNE`, `settings.tune`): overall height, hill country, hill height, surface detail,
  coast roughness, rivers, lakes, river bends, valley width; multipliers, 1 = as designed.
- **Studio:** one Settings page (map type, seed, relief, water, ship rivers, then the 9 Advanced sliders and Reset
  advanced) and the Report tab, instead of four sparse tabs. 9 new strings (72 keys).
- `tools/scale_check.py`: slope classes, height, relief per wavelength band and shoreline next to the vanilla
  reference; previews in `previews/scale/` in the same palette as the vanilla image.

### Changed
- **Relief targets:** Hilly 340 -> 280 m, Mountainous 750 -> 420 m; Mountain Range relief factor 1.8 -> 1.5
  (Mountainous peaks ~1.4 km -> ~0.7 km). Gentle maps now carry 2-3x the relief at 100-1000 m wavelengths; Hilly is
  close to vanilla roughness with more flat valley land; Mountainous is harder than vanilla.
- **Meanders:** every half-bend now draws its own skew and flatness (one skew per river made all bends lean the same
  way), wider spread of bend lengths and swings, curvature noise between apexes, reach-scale strength
  0.5-1.2; the valley axis itself wanders on two scales (`rivers.wander`). Bend-length CV 0.3 -> 0.4-0.6.
- **Lake District:** ice-flow direction at a seed angle, milder stretch (1100 x 1900 m), more streams (rivers 0.75):
  lakes spread over the map instead of one edge.
- **Large Bays:** bays bend inland (lean) and swell and narrow (width noise 0.5), outlines warped more.
- **Lakes** are no longer placed on ship rivers (Delta Lowlands showed lake blobs on the main channel).
- Valley-side terraces removed (`landform.TERRACES = {}`): the same +4/+10/+18 m benches around every lake and stream
  read as ripple rings.

### Fixed
- Dark cliffs beside river mouths: the estuary lowering stopped at a fixed 600 m; it now uses the valley side profile
  out to where it meets the land.
- Hill-country loops yield every 2048 nodes (frame budget).

### Baseline
- `core_baseline.json` re-accepted (all 40 maps changed by design). Note: the compare run just before `--update`
  printed "40/40 identical", which cannot be right after these changes; change detection was then verified to work
  (same map = same hash; a changed setting = different hash). Cause not found.

## [docs] - 2026-10-06 - the internal notes

### Changed
- The author's open questions moved from the internal notes to the internal notes a questionnaire written to read well as raw text
  (short lines, one question per section, tick boxes, answer lines). the internal notes rewritten in the same plain style.
  New question B4: confirm the mod name and ID before any upload (was a TODO line).

## [Unreleased] - 2026-10-06 - run 5 fix: Studio tabs

### Fixed
- Opening the Studio failed in game: "TabWidgetChild item must not be a Layout". Each tab page is now a small
  recipe (`UtgTabPage`) that builds its layout, as the base game and the probe do. `studio_check.py` now enforces
  this engine rule in its stub (it passed the faulty window before).

## [docs] - 2026-10-06 - future host: Terrain Generator Window

### Added
- DESIGN.md section 12, the internal notes: a separate mod (Terrain Generator Window) may later load UTG as one more
  generator, if possible. UTG stays the primary goal; guidelines keep the door open only where it costs nothing.
  Review queue R11 answered. No code changed.

## [Unreleased] - 2026-10-06 - Studio strings; large-map speed and memory

### Added
- Studio window text goes through the game's translation function (`_`, English fallback when a mod script does not
  see it); `strings.json` has the 63 English keys (map type labels included). `studio_check.py`: a scenario with a
  translation function (7 checks).

### Changed
- Detail: the pass-floor calm factor is skipped on rows without pass floors (Mountain Range 28.7 km detail 8.1 ->
  6.6 s). Report: open-sea cells count as known big water in the puddle flood (no flooding the whole sea), slope
  statistics every 16 m on maps wider than ~12 km (report 2-3.3 -> 1.0-1.35 s). 28.7 km total 8.6-10.4 s
  (was 9.5-13.1 s). 11 km maps: heights and report numbers identical (baseline 40/40).
- Studio: heights are clamped in place and the Lua table is released once the engine map has them (no second
  51 M-entry table, about 800 MB less on 28.7 km maps).
- `core_baseline.py` also compares report numbers when the heights are identical.

## [Unreleased] - 2026-10-06 - four more map types (ten in all)

### Added
- Map types: **Peninsulas** (2-3 long peninsulas with bending axes, swelling widths, flared roots and rounded tips;
  ragged mainland coast), **Island Chain** (4-7 islands of 2-4 lobes each along a curve; low hills; short streams),
  **Coastal Region** (ragged coast with headlands and coves; a river from the hinterland, a ship river by default),
  **Highland Plateau** (coastal lowland, wavy escarpment, a raised flat plateau cut by river gorges).
- `shapes.build` two-pass mode for types with `sea()` + `land()`: land is shaped from the true distance to the open
  sea (`grid.nearestSeed`); sea slivers one cell wide are removed (`removeSeaSlivers`; they left sub-zero specks
  along ragged shores) and closed sea patches become land (`openSeaOnly`).
- Raised ground: two-pass types may return a lift; landform adds `LIFT x target x preset.lift` before the slope limit,
  never on rivers, so the limit cuts gorges down to them (the game has one water level).
- Relief capped by land size for two-pass types (`landform.LAND_SLOPE` x 99th-percentile distance to the sea):
  small islands stay low and playable.
- `preset.minRiver` (shortest kept river; islands 600 m, peninsulas 1000 m).
- README lists all ten types.

## [Unreleased] - 2026-10-06 - three more map types

### Added
- Map types (`shapes.lua`): **Rolling Plains** (inland, no sea; a big river enters at the far edge and leaves at the
  near edge, a ship river by default; side outlets), **Lake District** (basins stretched along the old ice flow
  give long, narrow lakes on the rivers; 3x lakes), **Large Bays** (2-3 deep bays, each with its own side widths,
  rounded heads and warped outlines; a valley inland from each bay head; coves along the coast). Each type has a
  display `label`; the Studio, core_check and the baseline take the type list from `shapes.ORDER`.
- README lists the new types (description.html regenerated).

### Changed
- Ship rivers may also be rivers that leave the map at an edge (inland maps); maps with a sea are unchanged (baseline:
  all 12 earlier maps identical). Baseline now covers all 6 types (24 maps).

## [Unreleased] - 2026-10-06 - checks; route G on hold

### Added
- `tools/publish_check.py` (thin wrapper around the shared `tools/publish_check.py`): 9 checks including
  `studio_check.py` and `core_check.py`; passes.
- `tools/core_baseline.py` + `core_baseline.json`: 12 accepted maps (3 types x seeds 1-2 x Gentle/Mountainous,
  11 km): height hash and report numbers; compare mode lists maps a change altered.

### Changed
- Author: route G (new-game generator, M4) is on hold; work stays on the map editor.

## [Unreleased] - 2026-10-06 - M2 Studio window

### Added
- `content/gui/ultimate_terrain_generator/utg_studio.script.lua` + `utg_studio.css.lua`: the Studio (map editor
  only). Tabs Map (type, seed) / Water (water, ship rivers) / Relief / Report; Generate runs `pipeline.job` from
  `react.onStep` with 25 ms of work per frame and a progress line (falls back to one go if `coroutine` is missing);
  Preview runs this climate's finishing pass (`utg_finish_*`, import-style, keepHeightmap always on) on the generated
  heights in the window; Apply sends the finished map (or the bare heights where a climate has no finishing pass);
  Undo restores the terrain from before the last Apply (trees are not restored). All steps logged with "[UTG]".
- `tools/studio_check.py`: fake engine + the real core on 4 km maps; drives Generate frame by frame, Preview,
  Apply, Undo; 4 editor scenarios + not-the-editor + stylesheet (6/6).
- the internal notes (author's in-game steps for M2).
- Mod `README.md` (preview build: what it does, map types, how to use, good to know, feedback) and the generated
  `_metadata/description.html`. Shipped files no longer name workspace documents (publishing rule).

### Changed
- Core yields more often for the frame budget: `grid.blur` / `grid.nearestSeed` take an optional ctx and tick per
  row; landform loops tick every 8192 nodes and per row; `noise.tile`, the detail shore guard, river carving (every
  64 segments) and the report's sea flood fill tick too. Longest stretch without a yield: 11 km 67 ms (was 286 ms),
  28.7 km about 150 ms (three stalls while Lua grows the 51 M-entry heightmap table; plain Lua cannot pre-size it).
- Report height quantiles come from a 0.25 m histogram instead of sorting every sample.
- `utg_button.res.lua` opens the Studio.

### Removed
- The diagnostic probe (`utg_probe.script.lua`, `utg_probe.css.lua`) moved from the mod folder to
  `archive/probe_v3/` (not shipped; recover by moving them back and pointing `utg_button.res.lua` at
  `utg_probe.script@UtgModButtonPlugin`). `tools/probe_check.py` now loads it from the archive.

## [Unreleased] - 2026-10-06 - M1 tuning

### Fixed (mouths and estuaries)
- Courses running into existing water (sea shelf, lake, estuary) no longer cut a trench: their bed follows the bottom
  there (`detail.carve`; ship reaches keep >= 2.6 m, `detail.SHIP_BED`).
- Ship channels continue straight out to sea until the shelf is as deep as they are, widening at the end
  (`rivers.extendMouths`); points already at sea are trimmed first, so the channel no longer ends in a hook.
- Estuary trumpet built around the river's own course with plain distance (smooth banks) instead of the valley
  axis with width-weighted seeds (one-sided bulge, jagged edges).
- Lakes keep 400 m from the sea (`landform.LAKE_SEA_GAP`); one had merged with a river mouth.
- Shore smoothing also covers seams between different water bodies (lake / estuary / sea).
- `core_check.py` previews grade water colour by depth; the former hard step at 2 m drew contour artefacts.

### Added
- Oxbow lakes (`rivers.oxbows`, run after landform, carved by `detail.carve` as courses of kind "oxbow"): at the
  tightest half-bends (turn >= 2 rad) of rivers >= 30 m wide, a horseshoe lake just outside the bend opening towards
  the channel; loop radius 1.8-3 river widths, drawn out along the valley (aspect 1-1.4), uneven radius, narrower and
  shallower silted ends; kept only on lowland (+0.3 m.. floodplain + 4 m) clear of other water (smaller loops
  retried); banks rise 1:4 to the local ground. Up to 1 / 3 / 5 per map (Water Dry / Normal / Wet). Report line
  "oxbow lakes N"; rivers count and length exclude them. Sweep (seeds 1-6, Water 1-3, Relief 1-4): no puddles.
- `passes.lua` and landform step 5b: legible mountain passes. Each pass is a winding valley axis (the drainage notch in
  `shapes.lua` follows it); its floor is graded to `passes.TARGET` (2 / 2.5 / 4 / 6 % by Relief, graded with a 15 %
  margin for 4 m roughness) and the hillsides rise from it like from any valley, so the pass reads as two valleys
  meeting at a broad col. Pass floors get no rock detail (`calm` mask in `detail.upsample`). Built after the river
  valleys, so floors descend gently into the valleys they cross.
- Report: "passes:" line (length, summit, steepest 100 m grade; water bridged level). `core_check.py` draws the
  routes on the overview, centres the Mountain close-up on the first col, fails if a pass route is missing and warns
  above 1.5 x target.
- Measured: Gentle 1.7-2.5 %, Mountainous 5.8-6.4 % (seeds 1-5, 11 km); 28.7 km 2.8-3.1 % at Gentle.

### Changed
- `chaikin` / `resample` moved from `rivers.lua` to `grid.lua` (shared polyline helpers).
- `shapes.build` returns `corridors` (pass axes in local metres); new `toLocal` helper.

### Rejected along the way
- Least-cost route (Dijkstra) plus a cut with the valley-side profile: on a range without valleys every route is
  equivalent, so routes came out straight, and the cut left terraced trench walls.
- Seeds weighted by floor height in `nearestSeed`: the sweep propagation is not exact for weighted seeds and left
  straight row-aligned creases; plain distance (as for river valleys) plus a local blur of the pass slopes is clean.

### Changed (flat land)
- Concave hillslopes on gentle map types (`landform.HILL_SHAPE` = {0.5, 0.5, 0.7, 0.85} per Relief, scaled by the new
  preset field `uplands`: 1 Great River Valley and Delta, 0 Mountain Range): hillsides steep near the valleys,
  flattening towards broad buildable tops. Great River Valley flat land at Gentle 29 % -> 38-43 % (seeds 1-6).
  Fine detail was measured and is not a factor (flat 28.6 % without it). Sweep seeds 2/4/6 x Relief 1-4: all pass.

## [Unreleased] - 2026-10-06 - M1 Lua core, first version

### Added
- `content/scripts/ultimate_terrain_generator/core/`: `noise.lua` (Park-Miller RNG, Perlin, fbm, tileable textures),
  `grid.lua`, `shapes.lua` (Great River Valley, Delta Lowlands, Mountain Range with Passes), `hydrology.lua`,
  `rivers.lua` (irregular Kinoshita-style meanders, ship reaches, deltas), `landform.lua` (stream-power channels +
  hillslopes, lakes, valley floors with terraces, estuaries, sea shelf, shore smoothing), `detail.lua` (cubic
  upsampling to 4 m, detail, channel carving), `report.lua`, `pipeline.lua` (run + frame-budget job).
- `tools/core_check.py`: offline Lua 5.2 check + previews (`previews/m1/`), determinism and job-runner check.
- DESIGN.md section 11 (the core as built).

### Changed (during M1 development, offline)
- Sea comes from each type's coastline, not from B < 0 (inland "sea" patches captured the rivers).
- Hillslopes as slopes from the nearest channel instead of per-node stream power (removed diagonal streaks).
- Valley floors follow the river centreline (no scalloped edges); one side profile per map (no cracks).
- Estuary = drowned valley axis (trumpet of water), replacing a drawn funnel that looked like a spike.
- Meanders: per-half-bend length and swing, skew/flatness (author: avoid regular periodic bends).

## [Unreleased] - 2026-10-06 - run 4: M0 finishing pass verified

### Verified
- Run 4 (author, in game): "UTG finishing pass (Temperate)" keeps Lua heights, draws forests, rock, snow and river
  trees from the heights, and creates all 9 data maps. Recorded in the internal notes DESIGN.md 8/10 and
  the internal notes extended.

## [Unreleased] - 2026-10-06 - author decisions, build plan, M0 finishing pass

### Added
- DESIGN.md: author answers (9a), how they are applied (9b: playability targets are soft and scale with Relief; no
  reserved sites; ship rivers from the setting with per-map-type defaults; full 4 m detail at the end), build plan
  M0-M5.
- M0: `tools/build_finish_tree.py` builds `content/climates/temperate/utg_finish_temperate.gen.lua` +
  `_gen.tree.lua` ("UTG finishing pass (Temperate)", editor only, import-style): the vanilla Temperate import tree with
  its imported biome, river and mountain inputs replaced by values computed from the heights. Lint 0 errors.
  the internal notes.

### Changed
- Workspace: the node-graph helper class moved to `tools/graph_builder.py` (Custom Terrain imports it; its
  build output verified byte-identical); `gen_graph.lint` accepts import-style generators (all four vanilla import
  trees now lint clean).

## [Unreleased] - 2026-10-06 - probe run 3

### Verified (author)
- Probe v3 window fits the screen (stylesheet sizing works); import generator with "Keep heightmap" unticked no
  longer crashes (forced keep; heights KEPT). Data maps after an import-style pass: still untested.

## [Unreleased] - 2026-10-06 - probe run 2 results, probe v3

### Fixed
- Crash in run 2: the import generator with "Keep heightmap" off (its tree has no height output). v3 always keeps
  the heightmap for import generators; the check box label says so.
- Window taller than the screen: tabs now in a fixed-size `ScrollArea`, smaller preview, "Show the preview image"
  toggle, sizes in the new `content/gui/ultimate_terrain_generator/utg_probe.css.lua`.

### Found (author's run 2)
- Import generator + keepHeightmap KEPT the Lua heights (preview and Apply): route S proven. No forests (the vanilla
  import tree needs an imported biome file): our own finishing tree must make biomes and forests from heights.
- E5b: ships need about 100 m water-line width (70 m = thin lane at >= 4 m depth; 40 m never). Height range -100..
  3176.75 m. Recorded in the research docs, the internal notes DESIGN.md. `probe_check.py`: stylesheet + 7 scenarios.

## [Unreleased] - 2026-10-06 - probe run 1 results, probe v2

### Added
- Probe v2: E5b (15 river-like channels with 1:4 banks, 40-200 m wide, 2-8 m deep, opening into a 10 m basin, for
  navigability and ship tests); E6 lists import generators and logs heights at test points (input, preview, world
  after Apply: KEPT/CHANGED); E1 logs the raw shape of `getMinMaxValidTerrainHeight`. `probe_check.py` 6/6.
- Run 1 results recorded: the internal notes (with a correction on keepHeightmap),
  the internal notes (navigability), the internal notes DESIGN.md sections 2 and 8.

### Found (author's run 1, 11 km flat temperate editor map)
- Lua height edits apply (whole-table assignment only); on-demand preview and Apply work; widgets work.
- keepHeightmap with the normal generator overwrote the E5 channels (normal trees write heights).
- Navigability: depth hardly matters (1 m is enough), width does (about 64 m minimum with steep banks).

## [Unreleased] - 2026-10-06 - probe fix: window failed to open

### Fixed
- Clicking UTG raised "Recipe child must be a layout" (recipe `UtgProbePanel` returned a TabWidget). The TabWidget
  is now wrapped in a BoxLayout, as vanilla does. `tools/probe_check.py` now enforces the rule (it catches the old
  code); 5/5 pass. Rule recorded in the internal notes.

## [Unreleased] - 2026-10-06 - P1 research, design proposal, diagnostic probe

### Added
- Research (by topic, in the internal notes): the internal notes map-editor window route added to
  the internal notes
- `DESIGN.md`: goals (playability first), engine facts, playability rules, water and geological-history design,
  routes G (generator) and S (map-editor Studio), settings, map types, author decisions.
- Diagnostic probe in the mod: `content/gui/ultimate_terrain_generator/utg_button.res.lua` +
  `utg_probe.script.lua` (editor-only UTG button; tests E1-E7: map facts, writing heights, Lua budget, data maps,
  navigability channels, on-demand generator preview with apply, widgets). the internal notes with the author's steps.
- `tools/probe_check.py` (offline Lua 5.2 check, 5/5 scenarios) and `tools/make_cover.py` (cover `_metadata/0.png`).

### Changed
- the internal notes: author's clarifications (window in the map editor; realistic water key;
  geological history bonus; playability first).

## [Unreleased] - 2026-10-06 - project set up

### Added
- Project folder with the internal notes this changelog; skeleton mod folder (`mod.json`,
  `_metadata/modinfo.json`, `strings.json`); the internal notes.
