# Release notes - Ultimate Terrain Generator

Paste-ready changelog text for each upload. The game's Mod Hub upload form has one **Changelog** text field
(`base/content/gui/menu/mod_manager_react_util.tl` 1612-1632) and an **Update Metadata** checkbox (tick it so
mod.io gets the new description, summary and cover). The full player-facing list is in the mod readme section
"Changes in this version" (shown in game and on mod.io); developer history is in CHANGELOG.md.

mod.io version label: always "1.0" (the game's upload form has no version setting), so each changelog text starts
with the update's name.

## Revision 4 (update of revision 3; mod.io 6433560)
Paste into the Changelog field:

```
Update 4: All climates: the twelve map types now make finished maps on Dry, Subarctic and Tropical too, with each climate's own trees, rocks and ground (until now these climates got the terrain shape only), and Preview now shows the map in all four climates. Each climate draws snow at its own height: about 330 m on Temperate, about 210 m on Subarctic (snowy tops on most map types from Terrain Moderate), none on Dry and Tropical (Tropical shows bare rock from about 210 m instead). Lower tree density stays on Temperate for now. Run test (Debug tools) now works in all four climates, and the guide explains what each climate shows. Known issue: on Dry, all low land up to about 12 m (such as Great River Valley's valley floor and most of Delta Lowlands) is bright red sand, and farms find little land there; the next update tunes Dry's ground together with map types made for Dry, Subarctic and Tropical.
```

## Revision 3 (update of revision 2; mod.io 6433560)
Paste into the Changelog field:

```
Update 3: Two new map types: Alpine (snow-capped massifs with long railway-graded passes) and Sea Strait (a sea channel splits the map, with long sounds for ships and narrows of about 350-400 m for big bridges). No sea where it fits: Sea side None on Mountain Range, Alpine and Highland Plateau, and a Sea box on Great River Valley. New Lower tree density check box for lower-spec computers. Relief is now called Terrain, Hilly is pre-selected and flat land shrinks in even steps from Gentle to Mountainous. Mountain Range passes meet their railway grade at every step. Apply to map makes the preview first when settings changed; tooltips on every Terrain parameter; the window can be moved again; smoother generating. Fixed: Apply (or Undo) with towns on the map could crash the game; short ship rivers ran straight; some GUI mods could make the window crash the game. New description and guide.
```

## Revision 2 (update of the first release, revision 1; mod.io 6433560)
Paste into the Changelog field:

```
Update 2: Trees are back: since the October 2026 game update, applied maps came without forests, rocks and the right ground textures; fixed. The window can now run any terrain generator of your climate (the game's and other mods') with its own settings and preview on request. New: Keep towns / Keep industries when applying, choice of the side for the map type's main feature (sea, river source or outflow), one-click Preview (generates and finishes the map). Clearer buttons, a new layout with a large preview that adapts to your screen, shorter texts with hints, Report notes when a map cannot give what you asked for. New mod setting Debug tools (off by default) with a one-click Run test for bug reports. Several fixes (stuck buttons after a failed Apply, puddles at extreme settings).
```

## Revision 1 (first release, 2026-10-07)
Map editor window: rivers-first terrain for Temperate, ten map types, ship rivers, five Relief levels, terrain
parameters, preview on request.
