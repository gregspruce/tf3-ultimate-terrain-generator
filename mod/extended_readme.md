# Ultimate Terrain Generator - guide

The mod page (`readme.md`) says what the tool is for. This guide explains what every setting and slider does to the
land, with numbers where they help you choose, and how to read the Report. Section 1 gets you to a first map in a few
minutes; sections 4 to 7 are the reference.

**How to read the numbers.** Unless a line says otherwise, they come from test maps of the game's Medium square size
(11.3 km) at Terrain Hilly, Water Normal and every slider at 100 %, averaged over two seeds. Your maps will differ a
little with the seed, and larger maps have more and longer rivers. Words used throughout:
- **Flat land:** slope under 3 %, where towns, stations and airports fit. Shares are of the land, not of the map.
- **Land a railway can use:** slope under 8.5 % (the game's limit for track), flat land included.
- **Very steep:** slope over 25 % (the street tool stops at 20 %).
- **Tops:** the height that only 1 % of the land rises above (the Report's "99 %"): about the height of the highest
  hills.
- **Snow:** about 330 m on Temperate, about 210 m on Subarctic; Dry and Tropical have none (Tropical shows bare rock
  from about 210 m). Everything this guide says about snow is for Temperate (section 3, "Climates").
- For comparison, a map from the game's own Temperate generator has about 11 % flat land, 39 % of its land under
  8.5 % and tops of about 330 m.

## 1. Make your first map
1. In the main menu choose **Map Editor** > **Create New Map**. Pick a climate (Temperate, Dry, Subarctic or
   Tropical) and a size of **Small** or larger, add this mod on the **Add Mods** tab, then **Start Map Editor**.
2. In the editor, click **UTG** in the top-left corner of the screen, next to the map layers button. The window opens:
   settings on the left, the preview on the right.
3. On the **Settings** tab keep Map type **Great River Valley** and set **Terrain** to **Gentle** (the most flat land).
4. Press **Preview**. After some seconds the map appears; your own map has not changed yet.
5. Open the **Report** tab: how much flat land, how many rivers, how long the ship river is (section 7).
6. Not quite right? Press **New seed** for another map with the same settings, or change a setting, then Preview again.
7. Press **Apply to map**. The new terrain goes in with the climate's trees, rocks and ground. Towns and industries
   already there are removed unless **Keep towns** / **Keep industries** is ticked. Not happy? **Undo**.
8. Add towns and industries with the editor's **Towns / Industries** button, then save the map. To play it: main menu
   > **New Game**, choose your map, **Play Map**.

## 2. Preview, Apply to map, Undo
The window has three tabs (Settings, Terrain parameters, Report); under them are a note line, the status line and the
buttons. The **filled button** is the next step; a **greyed-out** one cannot act right now, for example while a map
is being made. Hover over a setting, a slider or Apply to map for a short explanation. **Larger window** switches to
a bigger window and back; the window can be moved.

**Preview** makes the map for the current settings and shows it. Your own map does not change.
- It runs only when you press it, so change as many settings as you like first. When the picture is older than the
  settings, the note line says "Settings changed since the last Preview".
- It takes some seconds: about 12 s on a Large map (14.3 km), longer on the largest sizes. The status line counts
  them, and the editor stays usable meanwhile.
- The picture shows the land coloured by height and ground: blue water, greens and browns low down, light colours
  high up. Trees are never drawn in it.

**Apply to map** puts the previewed map onto your map, now with your climate's own trees, rocks and ground textures.
- If you changed a setting since the last Preview, or have not previewed yet, it makes the preview first and then
  applies it ("Making the preview, then applying..."). Your map always gets what the settings show.
- Changing a setting while it waits cancels it ("nothing applied"), and so does closing the window: press Apply to
  map again.
- **Keep towns / Keep industries** (Settings tab, "When applying"), as in the game's own generator window: unticked
  (the default), Apply first removes all towns, then all industries with their roads. Ticked, they stay where they
  are on the new land. On a new map, leave them unticked and place towns afterwards.

**Undo** puts back the terrain from before the last Apply (one step). It restores the shape of the land only: not
its trees, and not towns or industries that Apply removed.

**Lower tree density** (Settings tab, Temperate maps for now) gives about half as many trees in exactly the same
forests. Changing only this box makes the next Preview quick, because the terrain is not made again.

**Closing the window** keeps a finished preview ready for Apply; press Preview to see it again.

## 3. Map types
Each map type is its own layout of sea, rivers and high ground. The line under the Map type box describes the chosen
type. In brackets: the name of its side box (which edge gets the main feature, section 4) and its default Ship rivers.

- **Great River Valley** (River comes from, plus a Sea box; one ship river): one big river crosses the map in a broad
  valley between uplands and reaches the sea. River shipping, a long valley railway, towns on the valley floor: the
  safest first map. With **Sea** None there is no sea and the river leaves the map at the far edge.
- **Delta Lowlands** (Sea side; several ship rivers): a wide, flat coastal plain where the big river splits into
  channels across a delta. The flattest type, with room for big towns and airports and many bridges to build. Low at
  every Terrain step (tops about 100 m at Hilly).
- **Mountain Range with Passes** (Sea side, or None; no ship river): one long mountain belt parallel to the sea, with
  foothills and two passes (about 6 km long on a Medium map) graded for railways. Linking both sides is the game.
  Snow on the highest peaks from Moderate up, on more of the range from Hilly.
- **Alpine** (Sea side, None pre-selected; no ship river): snow-capped massifs scattered over high ground, broad
  valleys between them and two long passes (about 10 km) over the main ridge, like the game's own mountain regions.
  Snow already at Gentle. No sea unless you choose a Sea side.
- **Rolling Plains** (River comes from; one ship river): inland, no sea: gentle swells and a big river for ships
  crossing the map. The easiest map for long, straight lines; no snow.
- **Lake District** (Rivers flow towards; no ship river): inland hill country with long, narrow lakes strung along
  the rivers (about 9 lakes on a Medium map). Scenic routes around and across the lakes. The rivers leave the map on
  the chosen edge; the higher hills lie opposite.
- **Large Bays** (Sea side; no ship river): a coast cut by two or three deep, sheltered bays with rivers at their
  heads. Harbours: ships cross the bays, trains go the long way round.
- **Peninsulas** (Sea side; no ship river): a mainland with two or three long peninsulas; about half the map is sea.
  Ships take the short way, land routes are long.
- **Island Chain** (no side box; no ship river): islands of different sizes with sounds between them. Only about 13 %
  of the map is land, and there is one short stream at most. A game of ships and ferries.
- **Coastal Region** (Sea side; one ship river): a ragged coast with headlands and coves, a coastal plain and hills
  inland. A bit of everything.
- **Highland Plateau** (Sea side, or None; no ship river): a lowland (by the sea or inland), a steep slope (the
  escarpment) and a high, flat plateau cut by river gorges. Getting a railway up the escarpment is the challenge; the
  plateau has flat land on top. The highest ground of the non-mountain types (8 % of the land in the snow at Hilly).
- **Sea Strait** (Strait runs; no ship river, the strait is the ship water): a sea channel splits the map from edge to
  edge into two banks.
  - **Strait runs:** East-West (the water runs from the west edge to the east edge, land to the north and south),
    North-South, or one of two diagonals. On maps three or more times as long as wide, or under about 3 km across, a
    diagonal runs nearly straight, only a few degrees off the long side.
  - Wide sounds for ships and ferries, with flat shores and water 2 m deep close to the shore for harbours.
  - A few **narrows** of about 350-400 m of water (never under 300 m): one on Small and Medium maps, two on 16 km
    maps, three on the largest maps and on long strips. The banks there stand about 16-26 m above the water and rise
    gently behind, so a railway can reach a bridge. The game's automatic road links between towns stop at 250 m of
    bridge, so they should leave the narrows to you.
  - Ships can always sail from end to end (the Report checks it). Each bank gets a bigger river from its far edge.

**The map types side by side** (Hilly, Medium map; land as a share of the map, the rest as a share of the land):

| Map type | Land | Flat land | Under 8.5 % | Tops | Rivers, lakes |
|---|---|---|---|---|---|
| Great River Valley | 90 % | 24 % | 42 % | 304 m | 1-2, 0-2 |
| Delta Lowlands | 72 % | 56 % | 86 % | 102 m | 4, 2 |
| Mountain Range with Passes | 92 % | 12 % | 34 % | 461 m | 3, 2 |
| Alpine | 91-97 % | 9 % | 31 % | 418 m | 5, 2 |
| Rolling Plains | 96 % | 36 % | 64 % | 145 m | 4, 3 |
| Lake District | 88 % | 14 % | 43 % | 306 m | 4-7, 9 |
| Large Bays | 78 % | 11 % | 36 % | 328 m | 2-3, 2 |
| Peninsulas | 52 % | 10 % | 31 % | 333 m | 1-4, 0-2 |
| Island Chain | 13 % | 12 % | 39 % | 168 m | 1, 0 |
| Coastal Region | 77 % | 24 % | 45 % | 318 m | 3, 2 |
| Highland Plateau | 86 % | 16 % | 41 % | 378 m | 3-5, 3 |
| Sea Strait | 77 % | 24 % | 48 % | 314 m | 2-3, 2 |
| *the game's own Temperate* | | 11 % | 39 % | 333 m | |

Alpine has 97 % land with its pre-selected Sea side None, 91 % with a sea. Mountain Range, Highland Plateau and every
other type were measured with their sea.

### Climates
The map types are made for Temperate, and they work in all four climates. The land is the same in each: the same
settings, seed and map size give the same heights, rivers and lakes on Temperate, Dry, Subarctic and Tropical. The
climate decides how the land is finished: its own trees, rocks and ground, and the heights where snow and bare rock
begin. The numbers and tables in this guide were measured on Temperate; only snow and bare rock differ elsewhere.
- **Temperate:** rock from about 280 m, snow from about 330 m.
- **Subarctic:** rock from about 130 m, snow from about 210 m, much lower than on Temperate. Alpine, Mountain Range
  and Highland Plateau reach the snow from Gentle, most other map types from Moderate; Island Chain and Rolling Plains
  only a few peaks from Rugged; Delta Lowlands hardly ever (at most a spot at Mountainous). These steps are for the
  sliders at 100 %.
- **Tropical:** no snow, but bare rock from about 210 m: the same map types reach it at the same Terrain steps as
  Subarctic's snow.
- **Dry:** no snow. Shrubs, cacti and desert rocks instead of forests.

On Dry, Subarctic and Tropical the Settings tab names the map types that suit the climate best. Map types made for
these climates are planned.

## 4. Settings tab, control by control

### Generator
"Ultimate Terrain Generator (this mod)", or any other terrain generator the game lists for your map's climate (the
game's own and those of other installed mods). Another generator shows its own settings, and its Preview makes its
full map, also only when you press it. Seed, Keep towns, Keep industries, Apply to map and Undo work the same. The
Report then shows the land, slope and height lines, so you can compare generators on the same numbers. The Terrain
parameters tab is hidden. The game's own **Keep Heightmap** and **Keep Assets** options are not offered here: use the
game's own Generate tab when you need them.

### Map type
Section 3. **Changing the map type** keeps Terrain, Water, Ship rivers, Lower tree density, Seed and the sliders. The
side box keeps your choice when it means the same on the new type (Sea side North on Mountain Range stays North on
Alpine); otherwise it shows the new type's pre-selection (None on Alpine, Random on the others). The Sea box goes back
to "At the river mouth". The boxes always show what the next Preview uses.

### Terrain (Gentle, Moderate, Hilly, Rugged, Mountainous)
How high and steep the whole map is; Hilly, the middle step, is pre-selected. Each step up gives higher hills and
mountains, less flat land, more steep land, steeper mountain passes and more snow. The layout, the rivers and the
lakes stay the same. The steps are even; the last one, Rugged to Mountainous, makes the biggest jump in steepness.
Numbers for every step: section 6.
- The flat valley floors survive at every step, so even Mountainous keeps some flat land along the rivers.
- **Tip:** Terrain sets the map's character, including how steep the passes and valley sides are. Overall height
  (section 5) only scales the heights. For high mountains with easy passes, keep Terrain at Hilly or lower and raise
  Overall height.

### Water (Dry, Normal, Wet)
How many rivers and lakes. Wetter means more and longer rivers reaching further up the side valleys, more lakes and
oxbow lakes, and a little more flat valley floor. The hills, the layout and the number of ship rivers stay the same;
rivers run a little wider at Wet (still under 60 m).

| Water | Dry | Normal | Wet |
|---|---|---|---|
| Rivers: Great River Valley | 1 (15 km) | 1-2 (18 km) | 4-5 (29 km) |
| Rivers: Rolling Plains | 1-2 (17 km) | 4 (29 km) | 7 (44 km) |
| Rivers: Mountain Range | 1 (2 km) | 3 (10 km) | 7-8 (26 km) |
| Lakes wanted (Great River Valley, Rolling Plains) | 1 | 3 | 5 |
| Oxbow lakes, at most | 1 | 3 | 5 |

- **Tip:** Water sets the base and the Rivers and Lakes sliders fine-tune it. Dry suits open land with few bridges;
  Wet gives a river map full of bridges and more places for lakes. On Sea Strait, Dry keeps the bank rivers too small
  to become ship rivers.

### Ship rivers (Map type default, None, One, Several)
How many rivers are made wide and deep enough for ships: 120-180 m wide (widest at the mouth) and 5 m deep, all the way
to the sea or the map edge. Every other river stays 18-58 m wide, so its bridges are short. The first choice names
the type's default: One on Great River Valley, Rolling Plains and Coastal Region, Several on Delta Lowlands, None on
the others.
- **One:** the largest river that reaches the sea or the map edge. **Several:** that one and up to two more, if the
  map has rivers big enough.
- A ship river needs a large river. Mountain types rarely have one: Mountain Range with One got a 1 km ship river on
  one seed and none on the other. The Report's note then says so and what to try.
- A ship river comes with a broad, flat valley floor, and lakes keep away from it:

| Ship rivers | None | One | Several |
|---|---|---|---|
| Great River Valley: ship rivers (length) | 0 | 1 (15 km) | 1-2 (17 km) |
| Great River Valley: flat land | 15 % | 24 % | 27 % |
| Rolling Plains: ship rivers / flat land | 0 / 28 % | 1 / 36 % | 3 / 38 % |
| Mountain Range: ship rivers (length) | 0 | 0-1 (0.5 km) | 2-3 (7 km) |

- **Tip:** for ships on a mountain map choose Several together with Water Wet or Rivers 150 % or more, or use a larger
  map. On types with a ship river, keep the Rivers slider above about 40 % (section 5).

### The side box: Sea side, River comes from, Rivers flow towards, Strait runs
Which edge of the map gets the type's main feature. **Random** (the pre-selection, except on Alpine) lets the seed
choose. A chosen edge fixes where the feature goes, but the seed still mirrors the layout along that edge, so
different seeds still give different maps. Its name depends on the map type:
- **Sea side** (Delta Lowlands, Mountain Range, Alpine, Large Bays, Peninsulas, Coastal Region, Highland Plateau): the
  edge with the sea; the range, the bays or the plateau lie inland from it.
- **None** (Mountain Range, Alpine, Highland Plateau): no sea. The land goes on where the sea would be, still falling
  towards that edge, and the rivers leave the map there; the seed picks the edge. The land share rises from about
  91 % to 97 %, while flat land, heights, rivers and pass grades stay nearly the same. On Highland Plateau the heights
  inland change too, so the same seed gives a noticeably different map.
- **River comes from** (Great River Valley, Rolling Plains): where the big river enters; it ends on the opposite edge.
- **Rivers flow towards** (Lake District): where the rivers leave the map.
- **Strait runs** (Sea Strait): section 3. Island Chain has no side box.

### Sea (Great River Valley only: At the river mouth, None)
**None:** no sea. The valley goes on to the edge opposite where the river comes from, and the river (a ship river by
default) leaves the map there, about 180 m wide. The land share rises to about 97 %, and flat land stays the same.
The same seed keeps its layout, but the river's bends and the heights change noticeably, and a few more lakes can
appear. Coast roughness then shows "-".

### Trees: Lower tree density (Temperate, this mod's generator)
Ticked, the finished map gets about half as many trees. The forests stay exactly where they are, with the same forest
floor; only the number of trees in them drops. For slower computers. Not a terrain setting: the land is the same
either way. On Dry, Subarctic and Tropical maps the box is not shown yet.

### Seed and New seed
Any text. The same settings, the same seed and the same map size give the same map; the same seed on another map size
gives a different map. **New seed** picks a random one.

### When applying: Keep towns, Keep industries
Section 2. Both are unticked at first.

### Map size and notes
The tab shows your map's size (set when you create the map in the editor). Under about 6 km across it notes that the
map gets few or no rivers. On Dry, Subarctic and Tropical maps it notes that the map types are made for Temperate and
names the ones that suit that climate best (section 3, "Climates").

## 5. Terrain parameters tab, slider by slider
Ten sliders fine-tune the map. Each one multiplies what the map type is designed to have at the chosen Terrain step:
100 % is as designed, lower gives less, higher gives more, up to 200 % (Lakes up to 300 %). They move in steps of
5 %, and **Reset all to 100 %** puts every slider back. A change counts from the next Preview (or Apply). Because
they multiply the design, the same slider does more at a higher Terrain step and on a high map type such as Mountain
Range than on a low one such as Delta Lowlands.

**When a slider does nothing.** Its value then reads "-" and a note above the sliders names it:
- **Coast roughness** on maps without sea: always on Rolling Plains and Lake District; on Mountain Range, Alpine and
  Highland Plateau with Sea side None; on Great River Valley with Sea None.
- **Rivers, Lakes, River bends and Valley width** on Island Chain: its islands have room for one short stream at most,
  so these change little there. Rivers can still remove that stream (0 %) or add one or two more short ones (200 %).

The slider can still be moved; its value is kept for other map types. Without a "-", some sliders also stop having an
effect at some point: Overall height above about 75-100 % on Island Chain, Lakes once the rivers have no more lake
sites, and Rivers below 10 %.

### Overall height (0-200 %)
How high the whole land rises: hills, mountains and plateaus together. **Lower** gives flatter, easier land; at 0 %
the whole map is flat, 1-3 m above the water, with the rivers and lakes still cut into it. **Higher** gives higher,
steeper land and more snow. 100 % is the map type's designed height for the Terrain step.

| Overall height (Great River Valley) | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Tops | 3 m | 160 m | 304 m | 422 m | 521 m |
| Flat land | all | 31 % | 24 % | 23 % | 22 % |
| Under 8.5 % | all | 60 % | 42 % | 34 % | 31 % |
| Very steep | 0 % | 6 % | 24 % | 36 % | 43 % |
| Snow | 0 % | 0 % | 0.5 % | 6 % | 13 % |

- Flat land falls only slowly, because the valley floors stay flat at every value. Rivers, lakes and ship rivers do
  not change.
- 200 % gives 1.5 to 2 times the height of 100 %, not double (the slopes round off the tops). Rolling Plains reaches
  tops of about 280 m and still almost no snow; Mountain Range reaches 690 m.
- **Passes keep their grade:** on Mountain Range the steepest 100 m stays at 3.9-4.1 % from 50 % to 200 %; only the
  summits rise (57 m to 135 m).
- **Island Chain:** above about 75-100 % nothing changes; the islands are too small to rise higher.
- **Tip:** 50-75 % for an easy building map with gentle hills; 150 % or more for snow on a Great River Valley or
  Coastal Region. To keep the character but change the scale, use this instead of the Terrain step.

### Hill country (0-200 %)
How much of the land is hill country: patches of hills a few kilometres across (about 3.5 km), each hill about 800 m
across, with lower, open land between them. **Lower** gives more open land between the hills; at 0 % there are no hill
patches at all, only the smooth sides and ridges of the river valleys. **Higher** spreads the hills over more land.
100 % puts hill country on 50-60 % of the land (more at higher Terrain steps); 200 % on all of it.

| Hill country | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Under 8.5 %: Great River Valley | 66 % | 52 % | 42 % | 34 % | 32 % |
| Under 8.5 %: Rolling Plains | 98 % | 77 % | 64 % | 58 % | 58 % |
| Under 8.5 %: Mountain Range | 67 % | 49 % | 34 % | 22 % | 21 % |
| Flat land: Rolling Plains | 53 % | 45 % | 36 % | 27 % | 26 % |
| Very steep: Great River Valley | 1 % | 16 % | 24 % | 26 % | 25 % |
| Tops: Great River Valley | 186 m | 263 m | 304 m | 339 m | 349 m |

- The strongest slider for land a railway can use. It also lowers the map, since the hill patches carry the highest
  ground.
- 150 % and 200 % are nearly the same: by then almost all the land is hill country already.
- Not how tall the hills are: that is Hill height.
- **Tip:** 0-50 % for long, easy lines across open land (Rolling Plains at 0 %: 98 % of the land under 8.5 %). Raise
  it when the open land between the hills feels too empty.

### Hill height (0-200 %)
How tall the hills in the hill country are. Where they are and how much land they cover stay the same (that is Hill
country). **Lower** gives low hills that roads and railways cross easily; **higher** gives tall, steep ones. The map
type's own mountains (the range, the massifs, the plateau) are not hills: they stay.

| Hill height (Great River Valley) | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Tops | 238 m | 272 m | 304 m | 335 m | 368 m |
| Very steep | 9 % | 15 % | 24 % | 30 % | 35 % |
| Under 8.5 % | 52 % | 45 % | 42 % | 40 % | 39 % |
| Flat land | 26 % | 25 % | 24 % | 24 % | 24 % |
| Rise and fall within 256 m | 27 m | 34 m | 40 m | 47 m | 53 m |

- Flat land hardly moves, because it lies outside the hill patches. What changes is how hard the hills are to cross:
  the rise and fall over a short stretch (256 m) doubles from 0 % to 200 %.
- Mountain Range at 0 %: 25 % flat land and 61 % under 8.5 %, while the mountain belt itself stays (tops 404 m).
- **Tip:** lower it to make the hill country passable without changing where the open land is; raise it for a hilly
  map that still has wide open plains between the hills.

### Surface detail (0-200 %)
Small bumps a few metres high and 15-250 m across on hills and slopes, so they look natural rather than smooth.
Plains, valley floors, beaches and pass floors get none: the bumps fade in from a few metres above the water, so the
land you build on most stays smooth. **Lower** gives smoother hills, **higher** rougher ground; 0 % turns them off.

| Ground moved compared with 0 % (typical) | at 100 % | at 200 % | largest at 200 % |
|---|---|---|---|
| Rolling Plains | 0.6 m | 1.1 m | 4.5 m |
| Great River Valley | 1.2 m | 2.3 m | 10 m |
| Mountain Range | 1.9 m | 3.6 m | 15 m |

- A subtle slider: the slope classes barely move (from 0 % to 200 %, very steep land rises by 5 points at most and
  flat land stays the same). It changes the look close up. The bumps are a little larger at higher Terrain steps.
- **Tip:** most of the carved look comes from Erosion; Surface detail adds the fine roughness on top. Leave it at
  100 % unless the hills look too smooth or too bumpy close up.

### Erosion (0-200 %)
Ridges and gullies running straight down the slopes, as if carved by rain over a long time: main gullies about 300 m
apart, smaller ones about 115 m apart on their flanks. The steeper the slope, the deeper they are (a 40 % slope at
100 % gets main gullies about 13 m deep); flat land gets none. **0 %** gives smooth slopes; **higher** gives rugged,
deeply cut hillsides.

| Erosion | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Very steep: Great River Valley | 17 % | 19 % | 24 % | 29 % | 34 % |
| Very steep: Mountain Range | 26 % | 27 % | 32 % | 36 % | 41 % |
| Very steep: Rolling Plains | 2 % | 3 % | 4 % | 7 % | 11 % |
| Under 8.5 %: Rolling Plains | 69 % | 68 % | 64 % | 61 % | 58 % |

- Much stronger than Surface detail: at 100 % it typically moves the ground by 3-6 m, up to 25-40 m in the deepest
  gullies (more at Mountainous), and twice that at 200 %. Flat land and the heights of the tops do not change.
- Around 100-120 % the hills of Great River Valley and Mountain Range are about as deeply creased as the game's own
  Temperate hills.
- **Tip:** 0-50 % for smoother hillsides that are easier to build roads across; 150-200 % for dramatic mountains.

### Coast roughness (0-200 %)
Coves, headlands and small bays along the sea coast. **0 %** keeps the map type's own coastline (its big bays,
peninsulas and curves) without the small ragged edge; **higher** makes it more jagged. At 100 % the coast wanders in
and out by up to about 150-200 m, at 200 % about 300 m.

| Coast roughness: length of the sea coast | 0 % | 100 % | 200 % |
|---|---|---|---|
| Great River Valley | 43 km | 45 km | 47 km |
| Mountain Range | 39 km | 40 km | 46 km |
| Coastal Region | 56 km | 58 km | 61 km |

- It changes the coast's shape, not how much land there is: land share, flat land and slopes move by 1-2 points at
  most.
- No effect without a sea ("-"). On Sea Strait it roughens the sounds and the flanks of the headlands, but keeps the
  narrows and their landings clean.
- **Tip:** lower it for long, straight shores for quays and coastal railways; raise it for more natural coves and
  harbour sites.

### Rivers (0-200 %)
How many rivers and streams. **Above 100 %** smaller valleys get their own streams, reaching further up into the
hills; **below 100 %** only the larger rivers stay. 100 % is what the Water setting gives; 0 % works like 10 %.
Rivers also run a little wider when the slider is high (still under 60 m).

| Rivers (count and total length) | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Great River Valley | 1 (14 km) | 1 (15 km) | 1-2 (18 km) | 2-3 (23 km) | 4 (27 km) |
| Rolling Plains | 1 (16 km) | 2 (19 km) | 4 (29 km) | 4 (34 km) | 5 (38 km) |
| Mountain Range | 0 | 1-2 (2 km) | 3 (10 km) | 5-7 (19 km) | 7 (24 km) |

- Each river brings its own valley floor, so flat land rises a little with more rivers (Mountain Range 11 % to 14 %).
- **Low values shrink or remove the map type's ship river**, because a ship river needs a large river:
  - Great River Valley at 0-10 %: the ship river is only 0.7-0.9 km long and flat land drops to 10-16 %. The Report
    still says "ship rivers 1", with no note: look at its length. From 20 % it is whole again.
  - Rolling Plains at 0-10 %: no ship river (the Report notes it); whole from 30 %.
  - Coastal Region: no ship river below 30 %; whole from 40 %.
  - Delta Lowlands: only one ship river up to 40-50 %.
- **Tip:** 150-200 % for a dense river network with many short bridges; 50 % for fewer rivers and more open land, but
  keep it above about 40 % on types with a ship river.

### Lakes (0-300 %)
How many lakes form along the rivers. Lakes form only in natural hollows on a river, at least 400 m from the sea and
not beside a ship river, so a map can run out of places: above 100 % it may have no room for more, and the Report then
notes "N lakes wanted, M made". **0 %** gives no lakes, apart from the small oxbow lakes beside river bends (River
bends and Water control those). At Water Normal, 100 % asks for 2 lakes on Mountain Range, Alpine, Large Bays,
Peninsulas, Coastal Region and Sea Strait, 3 on Great River Valley, Rolling Plains and Highland Plateau, 5 on Delta
Lowlands and 9 on Lake District; Dry asks for a third of that, Wet for more.

| Lakes: wanted / made | 0 % | 50 % | 100 % | 150 % | 200 % | 300 % |
|---|---|---|---|---|---|---|
| Lake District | 0 | 5 / 5 | 9 / 9 | 14 / 11-14 | 18 / 11-16 | 27 / 11-16 |
| Mountain Range | 0 | 1 / 1 | 2 / 2 | 3 / 3 | 4 / 4 | 5 / 4-5 |
| Rolling Plains | 0 | 2 / 2 | 3 / 3 | 5 / 3-4 | 6 / 3-4 | 9 / 3-4 |
| Great River Valley | 0 | 2 / 0-2 | 3 / 0-2 | 5 / 0-2 | 6 / 0-2 | 9 / 0-2 |

- Most maps run out of sites soon after 100 %; one of the two Great River Valley test seeds had no lake site at all.
- Lakes take land: Lake District is 99 % land at 0 %, 88 % at 100 % and 86 % at 200 %.
- **Tip:** for more lakes, Water Wet (more rivers, more sites) or a new seed helps more than this slider; for a real
  lake map choose Lake District.

### River bends (0-200 %)
How much the rivers wind. **0 %** gives almost straight rivers that follow the valley's gentle curve, easy to run a
railway beside. **Higher** gives wide, looping bends and more oxbow lakes. Bends are about 11 times the river's width
apart (1.3-2 km on a ship river, a few hundred metres on small rivers), each one different. The flat valley floor is
as wide as the band the bends sweep, so **more bends also mean wider flat valley floors**.

| River bends (Great River Valley) | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| River length compared with its valley | 1.00 x | 1.06 x | 1.21 x | 1.44 x | 1.77 x |
| How far the bends swing to each side (mean) | 0 m | 190 m | 390 m | 520 m | 590 m |
| Flat land | 17 % | 21 % | 24 % | 27 % | 29 % |
| Oxbow lakes | 0 | 0-1 | 2 | 3 | 3 |

- Rolling Plains winds about as much; its flat land goes from 29 % to 38 %. Mountain rivers are small and wind less
  (Mountain Range 1.00 x to 1.31 x, oxbow lakes only from 150 %).
- Oxbow lakes need tight bends on rivers at least 30 m wide; Water caps them at 1 / 3 / 5.
- **Tip:** for straight rivers with plenty of flat land beside them, set River bends to 0 % and raise Valley width to
  150-200 %.

### Valley width (0-200 %)
How wide the flat valley floors along the rivers are, and how far the gentle valley sides reach before the hills.
**Wider** gives more flat land beside the rivers for towns, stations and railways; **0 %** gives narrow valleys with
steep sides (the floor is then just the band the bends sweep, plus about 40 m). Biggest on maps with big rivers.

| Valley width | 0 % | 50 % | 100 % | 150 % | 200 % |
|---|---|---|---|---|---|
| Flat land: Great River Valley | 17 % | 21 % | 24 % | 29 % | 34 % |
| Under 8.5 %: Great River Valley | 35 % | 38 % | 42 % | 46 % | 51 % |
| Very steep: Great River Valley | 28 % | 27 % | 24 % | 20 % | 16 % |
| Flat land: Rolling Plains | 31 % | 33 % | 36 % | 38 % | 40 % |
| Flat land: Mountain Range | 11 % | 11.5 % | 12 % | 12 % | 12 % |

- Mountain types barely change: their rivers are few and small.
- On Sea Strait it also sets how far the gentle rise behind the shore plain reaches.
- **Tip:** the strongest slider for flat building land on a river map.

### Which slider for which wish
The numbers are for Great River Valley at Hilly (flat land 24 %, 42 % under 8.5 %, tops 304 m at the defaults).

| You want | Try |
|---|---|
| More flat land for towns | Valley width 200 % (34 %), a ship river (24 % against 15 %), River bends 200 % (29 %) |
| More land a railway can use | Hill country 0 % (66 %) or 50 % (52 %), Overall height 50 % (60 %), Valley width 200 % (51 %) |
| Higher mountains, more snow | Overall height 150 % (tops 422 m) or 200 % (521 m); Terrain Rugged or Mountainous |
| A rugged, carved look | Erosion 150-200 %; Surface detail for fine roughness on top |
| More rivers | Water Wet, Rivers 150-200 % |
| More lakes | Lake District; Water Wet; Lakes above 100 % only while sites remain |
| Straight rivers to follow | River bends 0 %, with Valley width 150-200 % to keep the flat floors |
| Smoother coasts | Coast roughness 0-50 % |

## 6. Terrain steps at a glance
Each step from Gentle to Mountainous changes the heights, the flat land, the pass grades and the snow evenly; the
layout, the rivers and the lakes stay the same. The snow rows are for Temperate (section 3, "Climates").

| Terrain | Gentle | Moderate | Hilly | Rugged | Mountainous |
|---|---|---|---|---|---|
| Pass grade (steepest 100 m) | 2.5 % | 3.25 % | 4 % | 5 % | 6 % |
| Tops: Great River Valley | 168 m | 236 m | 304 m | 378 m | 463 m |
| Tops: Mountain Range (highest point) | 248 m (313 m) | 364 m (475 m) | 461 m (617 m) | 562 m (792 m) | 688 m (877 m) |
| Flat land: Great River Valley | 30 % | 26 % | 24 % | 23 % | 22 % |
| Flat land: Rolling Plains | 54 % | 44 % | 36 % | 30 % | 22 % |
| Flat land: Mountain Range | 20 % | 15 % | 12 % | 8 % | 4 % |
| Under 8.5 %: Great River Valley | 63 % | 52 % | 42 % | 34 % | 26 % |
| Very steep: Great River Valley | 6 % | 15 % | 24 % | 33 % | 51 % |
| Snow: Great River Valley | 0 % | 0 % | 0.5 % | 3 % | 13 % |
| Snow: Mountain Range | 0 % | 1.6 % | 4 % | 7 % | 13 % |
| Snow: Alpine | 0.8 % | 1.9 % | 2.7 % | 4.5 % | 7.3 % |

- **Passes** (Mountain Range, Alpine) meet their grade: measured 2.4-2.5 % at Gentle up to 5.9-6.0 % at Mountainous.
  A railway can be built up to 8.5 %, so every step stays passable. The pass summits are low saddles (the highest
  about 60 m at Gentle, 140 m at Mountainous), while the mountains around them reach 300-880 m.
- Hill country covers 50 % of the land at Gentle, 55 % at Moderate and 60 % from Hilly up.
- With the sliders at 100 %, Rolling Plains and Delta Lowlands stay below Temperate's snow at every step. Island
  Chain and narrow peninsulas stay lower than other types: their height is limited by the distance to the coast.

## 7. Report tab, line by line
After a Preview the Report describes the map you are looking at. An example (Great River Valley, Medium map):

```
For: great_river_valley, terrain Hilly, water Normal, ship rivers 1, seed oeyrx62dl8
land 90 %, water 10 %
land slope: flat (<3 %) 27 %, rail (3-8.5 %) 16 %, steep (8.5-25 %) 31 %, very steep 26 %
land height: median 56 m, 99 % 319 m, max 483 m
rivers 2 (+0 delta channels), 21.4 km; ship rivers 1, 14.1 km (100 % of their course >= 2 m deep)
lakes 2 (2.32 km2), oxbow lakes 2; puddles 0
note: 3 lakes wanted, 2 made: the rivers offer no more lake sites (lakes form only in natural basins on a river)
```

Mountain Range and Alpine add a passes line, Sea Strait a strait line:

```
passes: 6.2 km, summit 86 m, steepest 100 m 3.9 % (target 4.0 %); 6.2 km, summit 49 m, steepest 100 m 3.7 % (target 4.0 %)
strait: 1 narrows (364 m across at the water line), narrowest crossing 364 m; ships pass end to end: yes
```

- **For:** the settings the map was made with: map type, Terrain step, Water, Ship rivers as a number (0 = None,
  1 = One, 2 = Several; the type's default is filled in), the side only when you chose one (north, east, south, west,
  none; on Sea Strait ew, ns, swne, nwse), "sea none" for Great River Valley without sea, the seed, and after
  "advanced:" every slider not at 100 %. The slider names there: height = Overall height, hills = Hill country,
  hillHeight = Hill height, detail = Surface detail, gullies = Erosion, coast = Coast roughness, rivers = Rivers,
  lakes = Lakes, meander = River bends, valley = Valley width. The same line on a map of the same size gives the same
  map: note it to make a map again, or paste it into a bug report.
- **land / water:** how much of the map is land, and how much is sea, lakes and rivers. *Too much water:* a type with
  more land (table in section 3), Lakes lower, or Sea side None where offered (about 97 % land). *More water:*
  Peninsulas, Large Bays, Island Chain or Sea Strait.
- **land slope:** the land in four classes that add up to 100 %: flat (under 3 %), rail (3-8.5 %), steep (8.5-25 %)
  and very steep (over 25 %). Flat plus rail is the land a railway can use. *More flat land:* Valley width up, a ship
  river, River bends up, Hill country down, or a lower Terrain step. *More railway land:* Hill country or Hill height
  down, Overall height down. *Less very steep land:* Erosion down, Hill height down, a lower Terrain step.
- **land height:** the median (half the land is lower), 99 % (the tops) and max (the highest point). A 99 % above
  about 330 m means snowy tops on Temperate (about 210 m on Subarctic). *Higher or lower:* Overall height, or the
  Terrain step.
- **rivers N (+M delta channels), X km:** the rivers and their tributaries, each counted once, with delta channels
  counted apart, and their total length. *More:* Water Wet, Rivers above 100 %. *Fewer:* Water Dry, Rivers lower.
- **ship rivers N, X km (P % of their course >= 2 m deep):** the rivers ships can use, the length of their ship
  water, and how much of it is at least 2 m deep (should be 100 %). Check the length, not only the count: a ship river
  under a kilometre or two is little more than a river mouth (often the Rivers slider set too low). *More:* Ship
  rivers One or Several, Water Wet, Rivers above 100 %, another seed or a larger map.
- **lakes N (A km2), oxbow lakes N; puddles N:** the lakes on the rivers and their total area; oxbow lakes (small
  horseshoe lakes beside river bends) apart. Puddles are stray bits of water on land and should be 0. *More lakes:*
  Lake District, Water Wet, another seed, Lakes above 100 % while sites remain. *More oxbow lakes:* River bends up,
  Water Wet.
- **passes** (Mountain Range, Alpine): for each pass its length, its summit, the grade of its steepest 100 m (about a
  train's length; stretches over water count as level, as a bridge would be) and the target grade of the Terrain
  step. *Gentler passes:* a lower Terrain step. Overall height raises the summits but keeps the grade.
- **strait** (Sea Strait): how many narrows and each one's width at the water line, the narrowest crossing anywhere,
  and whether ships can pass from end to end (checked every 25 m: at least 100 m of water 2 m deep). The strait counts
  as neither a river nor a ship river.
- **note:** the map could not give what you asked for. For ship rivers it says what to try. The lakes note ("N lakes
  wanted, M made") appears whenever fewer lakes were made than wanted, also at the default settings: it is
  information, not an error.
- **Another generator:** only the land, slope and height lines, followed by "Rivers, lakes and passes are counted only
  for this mod's own maps." Enough to compare how much flat and railway land each generator gives.

## 8. Questions and problems
**I cannot find the UTG button.** It is in the top-left corner of the screen, next to the map layers button. It
appears only in the map editor, with the mod added on the Add Mods tab.

**The UTG button opens nothing.** Hover over it. If the tooltip says the window cannot open safely, another mod changed
the game's windows in a way this mod cannot work around: turn off mods that change game windows, then load the map
again.

**My map has no big river.** Pick a map type with a ship river by default (Great River Valley, Rolling Plains, Coastal
Region; Delta Lowlands has several) or set Ship rivers to One or Several. Rivers need room: maps under about 6 km
across get few or none, and Island Chain has at most one short stream. Also try Water Wet, Rivers above 100 %,
another seed or a larger map; the Report's note says when the map has too few large rivers.

**The Report says "ship rivers 1", but the ship river is tiny.** The Rivers slider is probably below about 20-40 %,
which leaves too little water for a full ship river (section 5, Rivers). Raise it to 50 % or more.

**I moved a slider and the map did not change.** Press Preview: changes count from the next Preview. If it shows "-",
it has no effect on this map (section 5). Some sliders also reach a limit: Lakes once the rivers have no more lake
sites, Overall height above about 75-100 % on Island Chain. Surface detail is subtle and shows mainly close up.

**I raised Lakes or asked for ship rivers, but the map has fewer.** Lakes form only in natural hollows along the
rivers, and ship rivers need large rivers. The Report's note says so (for ship rivers also what to try).

**Towns or industries disappeared after Apply.** Apply removes them unless Keep towns / Keep industries is ticked, and
Undo does not bring them back. Tick the boxes before Apply, or make the terrain first and place towns and industries
afterwards.

**Preview takes a while.** That is normal: the whole map is made from scratch, about 12 s on a Large map and longer
on the largest sizes. The status line shows the progress, and the editor stays usable. Because Preview runs only when
you press it, change all your settings first and preview once.

**There are no trees in the preview, or after Undo.** Previews never draw trees; they appear after Apply to map. Undo
brings back the shape of the land only.

**The note says "Settings changed since the last Preview".** The picture is older than your settings. Press Preview,
or Apply to map, which makes the new preview first.

**Apply says "nothing applied".** A setting changed while Apply waited for its preview, or the preview failed or did
not finish (the status line says which). Press Apply to map again.

**My Subarctic map is very snowy, and my Dry or Tropical map has no snow.** The map types have the same heights in
every climate, and each climate draws snow at its own height: about 330 m on Temperate, about 210 m on Subarctic, none
on Dry and Tropical (Tropical shows bare rock from about 210 m instead). For less snow on Subarctic, choose a lower
Terrain step or Overall height; for snowy tops on most map types, Moderate or higher (section 3, "Climates").

**The game is slow with all the trees.** On Temperate, tick Lower tree density and Preview or Apply again.

**I want Keep Heightmap or Keep Assets with one of the game's generators.** This window does not offer them: use the
game's own Generate tab for that.

**How do I make the same map again, or share it?** Same settings, same seed, same map size: the Report's "For:" line
lists them.

**The buttons stay greyed out.** They wait while a map is made or applied. If the game never answers, they work again
after about a minute and a half, and the status line says what happened.

**What are the `utg_placeholder` files?** The tool needs them to finish the map (trees, rocks and ground) and keeps
them in the game's `heightmaps` and `biomes` folders in the user data folder. They are safe to delete; the tool writes
them again.

**How do I report a problem?** Please post on the mod page what you saw (a screenshot helps), the map size and the
Report's "For:" line. For files, turn on **Debug tools** in this mod's settings (on the Mods tab where you add the
mod, before the map editor starts). The window then shows a Debug row; its files go into the game's `heightmaps`
folder in the user data folder (Run test also writes into `biomes`):
- **Run test** (this mod's generator, any of the four climates): one click for a preview, Apply, the finished map
  exported and the log saved, everything a bug report needs. It replaces your terrain and removes towns and
  industries unless kept, so use a spare map.
- **Save log:** everything the tool logged this session; the status line names the file.
- **Export** saves the current terrain as a heightmap image; **Test set** makes a fixed set of maps without touching
  yours (several minutes), for comparing versions.

## 9. Limits
- **Map editor only.** Save the map and start a game from it: main menu > New Game, choose the map, Play Map.
- **Map types made for Temperate.** On Dry, Subarctic and Tropical they keep their shape and get that climate's own
  trees, rocks and ground; snow and bare rock begin at that climate's own heights (section 3, "Climates"). Map types
  made for those climates are planned. Lower tree density is on Temperate only, for now.
- **All water is at sea level.** The game has one water level for the whole map, so there are no lakes up in the
  hills and no waterfalls; rivers run in low valleys.
- **Undo** is one step and restores the shape of the land only.
- **Map size:** under about 6 km across there are few or no rivers. The experimental sizes Huge and larger
  (20-28 km) take longest and use a lot of memory while the map is made.
- **Seeds vary.** The numbers in this guide are averages of two seeds on Medium maps; counts of rivers and lakes vary
  most from seed to seed.
