# Ultimate Terrain Generator

A Transport Fever 3 mod by TangoEchoXray, published on mod.io (the game's Mod Hub). This repository holds its
released versions: `mod/` is the mod folder exactly as uploaded (release r3), `docs/` the
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
- **Lower tree density:** about half the trees in the same forests, for slower computers.
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
- **Finished by the game's own rules** on Temperate: forests, rock and snow at full 4 m detail.

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
1. **Map Editor** > **Create New Map**: **Temperate**, **Small** or larger, this mod on the **Add Mods** tab.
2. Click **UTG** (top left, next to the map layers button), pick a map type and a **Terrain** step (Gentle is the
   easiest), press **Preview**.
3. Read the **Report**; try **New seed** or other settings and Preview again.
4. Tick **Keep towns** / **Keep industries** if wanted, then **Apply to map**. Not happy? **Undo**.
5. Add towns and industries, save the map and play it from **New Game**.

## Limits
- Map editor only.
- Forests, rock and snow on **Temperate** only; other climates get the terrain shape for now.
- **Undo** restores the terrain only, not trees or removed towns and industries.
- Slower than the game's generator: about 12 s to preview, 3 s to apply on a 14 km map.
- Few or no rivers on maps under about 6 km.

**Guide:** what each setting and slider does to the terrain: `extended_readme.md` in the mod's folder (from mod.io:
`Users\Public\mod.io\10640\mods\6433560` on the system drive).

## Feedback
Post on the mod page what looked wrong (a screenshot helps), the map size and the Report's "For:" line. For files to
attach, turn on **Debug tools** in this mod's settings (where you add the mod), then press **Save log**, or **Run
test** on a spare Temperate map (it replaces the terrain); they go into the game's `heightmaps` folder.

## Changes in this version
**New**
- **Two map types:** **Alpine** (separate snow-capped massifs over hill country, with two long passes graded for
  railways) and **Sea Strait** (a sea channel splits the map from edge to edge: long sounds for ships and ferries, and
  a few narrows of about 350-400 m for big bridges; ships always get through). Twelve map types now.
- **No sea** where it fits: Sea side **None** on Mountain Range, Alpine and Highland Plateau, and a **Sea** box on
  Great River Valley (the big river leaves the map instead of reaching the sea).
- **Lower tree density** check box: about half the tree models for lower-spec computers; forests stay where they are.
- Tooltips on every Terrain parameter slider, in plain words.

**Improved**
- **Relief is now called Terrain**, Hilly is pre-selected, and flat land now shrinks in even steps from Gentle to
  Mountainous (the middle steps have much more flat land between the hills than before).
- **Mountain Range passes** meet their railway grade at every Terrain step (2.5 % at Gentle up to 6 % at
  Mountainous), and the rivers behind the range run straight to the far edge.
- **Apply to map** makes the preview first when you changed a setting, so it never applies an outdated map.
- Changing the map type keeps your choices where they still mean the same; Alpine pre-selects Sea side None.
- The window can be moved again, and generating no longer stalls the game for a tenth of a second at a time.
- The mod description and the in-mod guide are rewritten: what the Studio and the terrain engine give you, and what
  each setting does to the map.

**Fixed**
- **Apply with towns on the map and Keep towns off crashed the game** (Undo could too). Fixed.
- Short ship rivers could run in straight lines with sharp corners; they now bend like the others.
- With some GUI mods active (mods that replace the game's window component), opening the window could crash the
  game. The window now always builds on the game's own component.

## Planned
- Forests, rock and snow for Dry, Subarctic and Tropical maps, and map types made for them (Fjord Coast, Mesa
  Country, Volcanic Islands).
- Undo that also brings back the trees, and faster generation on the largest maps.

**AI Tool-Use**
