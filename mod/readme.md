# Ultimate Terrain Generator

A map editor tool with its own window. It builds whole maps the way nature does, with players in mind: rivers first,
then the valleys they carved, then the hills and mountains around them, worn down by erosion. The same window can
also run any other terrain generator of your map's climate, the game's own or from other mods, with that generator's
own settings. You set everything first and the preview runs only when you press **Preview**; nothing touches your map
until you press **Apply to map**.

**Map editor only.** This release makes full maps (forests, rock, snow) for the Temperate climate; other climates
get the terrain shape only for now. Feedback is very welcome.

## What it does
- **Real drainage:** every valley belongs to a river. Rivers grow downstream, join, meander irregularly and reach the
  sea or the map edge. Lakes sit on the rivers that feed and drain them.
- **Water for every transport mode:** small rivers stay easy to bridge; "ship rivers" are wide and deep enough for
  ships all the way to the sea. River mouths open into estuaries or deltas, and coasts shelve gently for harbours.
- **Terrain that tells its history:** wide floodplains, oxbow lakes, drowned river mouths, and hills and mountains cut
  by spurs and gullies running down their slopes.
- **Playable by default, hard if you want:** at Gentle relief most land is buildable and rail-friendly, and flat land
  stays flat; mountain passes are graded valleys a railway can climb. Mountainous makes steeper, harder maps.
- **No forced placements:** the tool never reserves sites for airports, harbours or stations.
- **Full detail:** the final map has the game's full 4 m resolution, with forests, rock and snow drawn by the game's
  own terrain pass, including the data that town and industry placement uses.
- **Preview when you ask for it:** the game's own generator window recomputes after every change. Here you set
  everything first, which saves a lot of waiting on large maps and slower computers.
- **Any terrain generator in the same window,** with a Report of land and slope numbers to compare them.

## Map types
- **Great River Valley:** one big river crosses the map in a broad valley and reaches the sea.
- **Delta Lowlands:** a wide, flat coastal plain; the river splits into several channels across a delta.
- **Mountain Range with Passes:** the most alpine type: a snow-capped mountain belt (from Hilly up) with two graded
  passes, foothills on both sides.
- **Rolling Plains:** inland, gentle swells and a big navigable river.
- **Lake District:** inland hill country with long, narrow lakes strung along the rivers.
- **Large Bays:** a coast cut by two or three deep, sheltered bays with rivers at their heads.
- **Peninsulas:** a mainland with two or three long peninsulas reaching into the sea.
- **Island Chain:** islands of different sizes with sounds between them; rivers are rare.
- **Coastal Region:** a ragged coast with headlands and coves, a coastal plain and hills inland.
- **Highland Plateau:** a lowland by the sea, an escarpment and a high plateau cut by river gorges.

## How to use
1. Open the map editor with a **Temperate** map of the size you want (the terrain will be replaced).
2. Click the **UTG** button in the mod button strip. The window opens with the settings on the left and the preview on
   the right. **Larger window** switches to a bigger size and back. The window adapts to your screen and the game's
   text size; on very wide screens the preview stays roughly square.
3. **Settings** tab: **Generator** (this mod's own, or another one), **Map type**, **Relief** (Gentle, Moderate,
   Hilly, Rugged, Mountainous), **Water** (Dry, Normal, Wet), **Ship rivers** (map type default, None, One, Several),
   the **side** for the map type's main feature (**Sea side**, **River comes from** or **Rivers flow towards**:
   Random, North, East, South or West) and **Seed** (same settings and seed give the same map).
4. Optional: **Terrain parameters** tab: ten sliders to fine-tune height, hills, surface detail, erosion, coast,
   rivers, lakes, river bends and valley width (100 % = as designed; **Reset all to 100 %**).
5. **Preview** generates the terrain and shows the finished map, coloured by biome (trees and rock appear on the
   map after Apply). The editor stays usable meanwhile; large maps take up to about half a minute. The **Report** tab lists buildable land, rivers, ship rivers, lakes and
   passes, with a note if the map could not give what you asked for.
6. **When applying: Keep towns / Keep industries,** as in the game's own generator window. Not ticked means they
   are removed before the new terrain goes in.
7. **Apply to map** puts the terrain on the map; **Undo** puts the previous terrain back. Then place towns and
   industries, save the map and start it with **Play map**.

**Another generator:** choose it under **Generator**. Its own settings appear; change them, press **Preview**, then
**Apply to map**. The Report shows the finished map's land and slope numbers so you can compare generators.

The next step is the filled button; greyed-out buttons cannot act yet. Details on every setting:
`extended_readme.md` in the mod's folder.

## Good to know
- Map editor only. The button is hidden in normal games.
- **Other climates:** on Dry, Subarctic and Tropical maps this mod's generator makes the terrain shape only, without
  forests and biomes (the window says so).
- **Undo** restores the terrain shape of the last Apply only: not the trees, and not removed towns or industries.
- **Small maps** (under about 6 km), Dry water and coastal types may give fewer rivers, ship rivers or lakes than
  asked; the Report says so and suggests what to change.
- Large maps take longer to generate and may stutter briefly.

## Feedback
Thank you for trying it! If something looks wrong or fails, please post on the mod page what looked wrong (a
screenshot helps), the map size and the settings (they are on the Report tab). If you can, add the tool's files:
turn on the mod setting **Debug tools** (in the mod settings before the map editor loads) for a Debug row in the
window, then:
- **Run test** (Debug row; this mod's generator on Temperate maps) does everything in about half a minute:
  preview, Apply, export of the map and the log, into the game's `heightmaps` folder (in the user data folder). It
  replaces your terrain, so use a spare map.
- Or just **Save log**: everything the tool logged this session, as `utg_log_<id>.lua` in the same folder.

## Changes in this version
**New**
- Your own window can now run **any terrain generator** of the map's climate, the game's and other mods', with that
  generator's own settings, preview on request, Apply, Undo and a Report of land and slope numbers.
- **Keep towns / Keep industries** when applying, like the game's own generator window.
- **Choose the side** of the map type's main feature: sea, river source or river outflow.
- Preview now generates and shows the finished map in one step: Preview, then Apply to map.
- **Run test**: one click collects everything a bug report needs (Debug row, shown with the new mod setting
  **Debug tools**; Off by default).

**Improved**
- Clearer buttons (next step filled, unavailable ones greyed out) and a new layout with a large preview that adapts
  to screen and text size.
- A short description under each map type, hints on the settings, shorter texts.
- The Report notes when a map cannot give what you asked for and what to try.

**Fixed**
- **Trees are back.** Since a game update in October 2026, maps applied with this tool came without forests, rocks
  and the right ground textures. The tool now finishes the map the way the editor's own "Import biomes" does, which
  the update did not affect.
- Valley width at 0 % no longer skips the valley sides or leaves a stray puddle beside a lake.
- Surface detail and Erosion at maximum on Mountainous no longer dig puddles into low land.
- A failed Apply or Undo could leave the buttons stuck; they now recover, and a failed Undo can be retried.
- Closing and reopening the window no longer re-runs the last preview.
- Switching generator no longer keeps an old status or a running generation.

## Planned
- **Other climates:** the finishing pass (forests, biomes, rock and snow) for Dry, Subarctic and Tropical maps.
- **Climate map types:** Fjord Coast (Subarctic), Mesa Country (Dry), Volcanic Islands (Tropical).
- **Undo with trees,** and faster generation on the largest maps.
