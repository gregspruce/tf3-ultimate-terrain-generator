# Ultimate Terrain Generator

A Transport Fever 3 mod by TangoEchoXray, published on mod.io (the game's Mod Hub). This repository holds its
released versions: `mod/` is the mod folder exactly as uploaded (release r4), `docs/` the
development history (CHANGELOG, DESIGN, RELEASE_NOTES). To play, install the mod from the Mod Hub in game.

---

**Terrain built for transport, and a studio to shape it.**

A map-editor window with its own terrain engine, that can also load any vanilla or mod terrain generator. Rivers wind
through broad, flat valleys to the sea, mountain ranges have passes a train can climb, and big rivers carry ships
while small ones stay easy to bridge.

## The Studio
What it does that the game's own generator window cannot:
- **Preview on demand:** set everything first, then preview once; the game's window rebuilds after every change.
  **Apply to map** always uses the settings you see.
- **A Report before you apply:** flat land, rail-grade land, rivers, ship rivers, lakes, pass grades, strait narrows
  and what to try when a map falls short.
- **Undo** puts the previous terrain back.
- **More control than the game's three sliders:** twelve map types, five Terrain steps, the edge the sea, big river
  or strait is on (or no sea), and ten sliders with tooltips.
- **Lower tree density:** about half the trees in the same forests, for slower computers (Temperate maps, for now).
- **Any generator of your map's climate,** the game's own included, runs here too with Preview, Undo and the
  Report's land and slope numbers to compare them.

## The terrain engine
- **Rivers first:** the land is shaped around the rivers, so every valley has its river and every river reaches the
  sea or the map edge.
- **Ship rivers on request:** 120-180 m wide and 5 m deep all the way out. Other rivers stay 18-58 m wide, cheap to
  bridge.
- **Passes a railway can climb** on Mountain Range and Alpine: 2.5 % on Gentle up to 6 % on Mountainous, under the
  game's 8.5 % railway limit (4.0-4.1 % in game on Alpine, for a 4 % target).
- **Room to build:** Great River Valley at Hilly had 27 % flat land (under 3 % slope) in game, against 11 % on a
  game-generated map. Rolling Plains and Delta Lowlands are flatter still.
- **Natural detail:** spurs and gullies on the hillsides, smooth plains and valley floors, lakes on the rivers, oxbow
  lakes, deltas and estuaries.
- **Finished by the game's own rules** in all four climates: that climate's own trees, rocks and ground at full 4 m
  detail, and snow where the climate has it.

## Map types
- **Great River Valley:** a ship river down a broad valley to the sea.
- **Delta Lowlands:** the flattest map, the river split into channels.
- **Mountain Range with Passes:** one long range, two railway passes.
- **Alpine:** snow-capped massifs over hill country, two long passes.
- **Rolling Plains:** gentle inland country and a ship river.
- **Lake District:** hills with long lakes along the rivers.
- **Large Bays:** deep bays where ships cross and trains go round.
- **Peninsulas:** short sea routes, long land routes.
- **Island Chain:** islands of all sizes, for ships and ferries.
- **Coastal Region:** a ragged coast, a coastal plain, hills inland.
- **Highland Plateau:** a lowland, an escarpment, a high plateau.
- **Sea Strait:** a channel from edge to edge; its narrows (350-400 m) are too wide for the game's automatic town
  roads, so the big bridges are yours.

## How to use
1. **Map Editor** > **Create New Map**: any climate (Temperate, Dry, Subarctic or Tropical), **Small** or larger,
   this mod on the **Add Mods** tab.
2. Click **UTG** (top left, next to the map layers button), pick a map type and a **Terrain** step (Gentle is the
   easiest), press **Preview**.
3. Read the **Report**; try **New seed** or other settings and Preview again.
4. Tick **Keep towns** / **Keep industries** if wanted, then **Apply to map**. Not happy? **Undo**.
5. Add towns and industries, save the map and play it from **New Game**.

## Limits
- Map editor only.
- The map types are made for **Temperate**. On Dry, Subarctic and Tropical they keep their shape and get that
  climate's own trees, rocks and ground.
- Each climate draws snow at its own height: about 330 m on Temperate, about 210 m on Subarctic, none on Dry and
  Tropical (Tropical shows bare rock from about 210 m). On Subarctic and Tropical, Alpine, Mountain Range and Highland
  Plateau reach that line from Terrain **Gentle**, most other map types from **Moderate**; Island Chain and Rolling
  Plains only a few peaks from **Rugged**; Delta Lowlands hardly ever.
- **Undo** restores the terrain only, not trees or removed towns and industries.
- Slower than the game's generator: about 12 s to preview, 3 s to apply on a 14 km map.
- Few or no rivers on maps under about 6 km.

**Guide:** what each setting and slider does to the terrain: `extended_readme.md` in the mod's folder (from mod.io:
`Users\Public\mod.io\10640\mods\6433560` on the system drive).

## Feedback
Post on the mod page what looked wrong (a screenshot helps), the map size and the Report's "For:" line. For files to
attach, turn on **Debug tools** in this mod's settings (where you add the mod), then press **Save log**, or **Run
test** on a spare map (it replaces the terrain); they go into the game's `heightmaps` folder.

## Changes in this version
**New**
- **All four climates:** the twelve map types now make finished maps on Dry, Subarctic and Tropical too, with that
  climate's own trees, rocks and ground (until now these climates got the terrain shape only). **Lower tree
  density** stays on Temperate for now. Map types made for these climates come in a later update.

**Improved**
- **Preview** now shows the map in all four climates (until now only on Temperate).
- **Run test** (Debug tools) now works in all four climates.
- The guide explains what each climate shows on these map types (section 3, "Climates").

**Known issue**
- **Dry:** all low land up to about 12 m above the water, such as Great River Valley's valley floor and most of
  Delta Lowlands, is bright red sand, and farms find little land there. The next update tunes Dry's ground together
  with the new map types for Dry.

## Planned
- Map types made for Dry, Subarctic and Tropical (for example canyons and mesas for Dry, fjords for Subarctic,
  volcanic islands for Tropical), with heights and rivers suited to each climate, and Dry's ground retuned.
- Island Chain rebuilt: more land, more and larger islands, and a choice of layouts.
- Undo that also brings back the trees, and faster generation on the largest maps.
