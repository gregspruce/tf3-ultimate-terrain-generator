-- Sizes and spacing of the Ultimate Terrain Generator Studio window.
-- The engine loads every *.css.lua in a mod's content/gui folder, as it does the base game's own stylesheets
-- (base gui/main/*.css.lua, built with gui/main/stylesheetutil.lua makeAdder). Selectors: "!<class>" matches
-- meta.class (a node may carry several: "a, b"), "#<id>" a window id, "!window-expanded" a window with expanded = true,
-- "!font-small/medium/large" the game's text-size setting (an ancestor class, base statistics.css.lua:82-99). Sizes
-- are UI pixels or screen shares ("84vw"), {width, height}, -1 = not set; gravity -1 = fill; padding is
-- {top, right, bottom, left}.
--
-- Layout (2026-10-08 review, the base map editor's generator window as the model: map_editor.css.lua:12-40, 76-87):
--   * the window takes screen shares; no API tells a mod the screen size or the UI scale, so shares are the only way
--     to fit 1280 x 720 up to 4K (normal 84vw x 80vh, Larger window 96vw x 88vh; both leave room for the game bar);
--   * the settings column has a FIXED pixel width per text size, sized for two "label + field" pairs side by side
--     (pair = label + spacing + combo), so fields never overflow or float in empty space on large screens;
--   * the tab pages scroll inside the column (tab headers stay), the buttons sit below, the preview FILLS the rest.
-- Width budget of the column at medium text: 2 x (110 + 10 + 200) + 24 between pairs + 28 page padding + 16 tab
-- padding + 8 scroll bar = 716 -> 720 px. Small text: 2 x (96 + 10 + 180) + 76 = 648 -> 650. Large: 2 x (128 + 10 +
-- 230) + 76 = 812 -> 820. On a 1280 px screen (84vw = 1075 px) the preview keeps ~330 px (Larger window: ~480 px).
local ssu = require "::/gui/main/stylesheetutil.lua"

-- per text size: settings column, label, combo, wide label (sliders), seed field, text width inside a page
local SIZES = {
	small = { col = 650, label = 96, combo = 180, wide = 150, seed = 200, text = 598 },
	medium = { col = 720, label = 110, combo = 200, wide = 170, seed = 220, text = 668 },
	large = { col = 820, label = 128, combo = 230, wide = 200, seed = 250, text = 768 },
}

function data()
	local result = {}
	local a = ssu.makeAdder(result)
	-- note colour from the game's palette (base map_editor.css.lua reads it the same way); none if unavailable
	local okC, colors = pcall(function()
		return api.gui.genericRep.get(api.gui.genericRep.find("::/gui/main/default_colors.gres")).data
	end)
	local accent = okC and colors and colors.AccentLight or nil

	-- Window size from the SCREEN (owner 2026-10-08, 5120 x 1440: the window took 84 % of the width and the preview pane
	-- stretched to ~3500 px; pixel maxSize caps were ignored by the window in game). Since the 2026-10-08 game update
	-- `api.util.getGraphicsPresetParam().screenExtent` gives the screen size ({ width, height }, api/tealdef util.d.tl),
	-- so the width is computed here, once when the stylesheet loads: settings column + spacing + a SQUARE preview
	-- (height of the window minus title and buttons) + padding, as a share of the screen width, never more than the
	-- 16:9 share (84vw / Larger 96vw), never less than 30vw. Without the screen size: the 16:9 shares as before.
	-- Example (medium text): 1920 x 1080 -> 80vw; 5120 x 1440 -> 36vw; 3840 x 2160 -> 62vw.
	-- In game (run 8) the screen size was NOT readable here when the stylesheet loads (the window stayed 84vw), so the
	-- WINDOW SCRIPT reads it when the window opens and gives the window one class per size: "utg-wNN" (normal, NN vw)
	-- and "utg-xNN" (Larger window), NN = 30 .. 96 in steps of 2. Without a class: the 16:9 shares below.
	-- Size only: the window script places it (movable, initialX/Y 0.5 = centred in the free space; owner run 7). A
	-- gravity / anchorPoint here would pin it like the base Statistics window (2026-10-08 .. run 7: not movable).
	-- 80vh leaves 10vh below a centred window, clear of the 64 px game bar from 640 px screen height up.
	a("#utg.studio.window", { size = { "84vw", "80vh" } })
	a("#utg.studio.window!window-expanded", { size = { "96vw", "88vh" } })
	for share = 30, 96, 2 do
		a("#utg.studio.window!utg-w" .. share, { size = { share .. "vw", "80vh" } })
		a("#utg.studio.window!utg-x" .. share .. "!window-expanded", { size = { share .. "vw", "88vh" } })
	end
	a("#utg.studio.window Window::Content", { padding = { 8, 12, 12, 12 } })

	-- two panes: fixed column left, preview filling the rest
	a("!utg-studio", { innerSpacing = { 16, 0 }, gravity = { -1, -1 } })
	a("!utg-left", { gravity = { 0, -1 }, innerSpacing = { 0, 8 } })
	a("!utg-tabs", { gravity = { -1, -1 } })
	a("!utg-tab-page", { gravity = { -1, -1 } })
	a("!utg-scroll", { gravity = { -1, -1 } })
	a("!utg-right", { gravity = { -1, -1 }, innerSpacing = { 0, 8 } })
	a("!utg-pane-head", { gravity = { 1, 0 } })
	a("!utg-studio-preview", { gravity = { -1, -1 } })
	a("!utg-preview-empty", { gravity = { 0.5, 0.5 }, textAutoWrap = true, maxSize = { 420, -1 } })

	-- pages, rows and fields
	a("!utg-page", { padding = { 12, 14, 12, 14 }, innerSpacing = { 0, 12 }, gravity = { -1, 0 } })
	a("!utg-row", { innerSpacing = { 16, 0 } }) -- 16 px between pairs leaves slack at medium text (664 -> 656 of 668 px)
	a("!utg-field", { innerSpacing = { 10, 0 } })
	a("!utg-buttons", { innerSpacing = { 10, 0 }, padding = { 2, 0, 2, 0 } })
	-- buttons: the look (filled "primary", outlined "secondary", greyed when disabled) comes from the game's own classes
	-- (base main/default.css.lua); here only a common minimum width, so a row of short labels reads as buttons
	a("!utg-button", { minSize = { 96, 0 } })
	a("!utg-check", { gravity = { 0, 0.5 } })

	-- a game generator's parameters use the base widgets ("script-param-wrap" with "left-parameters" label and
	-- "right-parameters" field); the base styles them only inside its own map-editor window
	-- (map_editor.css.lua:90-127, 164-169), so the same rules scoped to our pages:
	a("!utg-page !script-param-wrap", { gravity = { -1, 0 } })
	a("!utg-page !script-param-wrap > BoxLayout", { gravity = { -1, 0.5 } })
	a("!utg-page !script-param-wrap !left-parameters", { size = { -1, 30 }, gravity = { 0, 0.5 } })
	a("!utg-page !script-param-wrap !right-parameters", { size = { 220, -1 }, gravity = { 1, -1 } })
	a("!utg-page !script-param-wrap DoubleSpinBox", { padding = { 0, 0, 0, 4 } })
	a("!utg-page !script-param-wrap DoubleSpinBox Button", { padding = { 2, 2, 2, 2 } })
	a("!utg-page !script-param-wrap ToggleButton", { padding = { 4, 4, 4, 4 } })
	a("!utg-page !script-param-wrap ToggleButton > FloatingLayout > TextView", { size = { 50, 24 },
		textAlignment = { 0.5, 0.5 } })
	a("!utg-page !right-parameters > BoxLayout", { innerSpacing = { 4, 4 } })
	a("!utg-label", { gravity = { 0, 0.5 } })
	a("!utg-label-wide", { gravity = { 0, 0.5 } })
	a("!utg-label-small", { gravity = { 0, 0.5 } })
	a("!utg-slider", { gravity = { -1, 0.5 }, minSize = { 160, 0 } })
	a("!utg-value", { size = { 64, -1 }, gravity = { 0, 0.5 }, textAlignment = { 1, 0.5 } })
	a("!utg-help", { textAutoWrap = true })
	a("!utg-desc", { textAutoWrap = true })
	a("!utg-note", { textAutoWrap = true, color = accent })
	a("!utg-status", { textAutoWrap = true, minSize = { 0, 44 } })

	-- medium sizes without a text-size class first (fallback), then one set per text size
	for _, name in ipairs({ "default", "small", "medium", "large" }) do
		local s = SIZES[name] or SIZES.medium
		local f = name == "default" and "" or ("!font-" .. name .. " ")
		a(f .. "!utg-left", { size = { s.col, -1 } })
		a(f .. "!utg-label", { size = { s.label, -1 } })
		a(f .. "!utg-label-wide", { size = { s.wide, -1 } })
		a(f .. "!utg-combo", { size = { s.combo, -1 } })
		a(f .. "!utg-combo-wide", { size = { s.text - s.label - 10, -1 } }) -- generator names are long
		a(f .. "!utg-seed", { size = { s.seed, -1 } })
		for _, cls in ipairs({ "!utg-help", "!utg-desc", "!utg-note", "!utg-status" }) do
			a(f .. cls, { maxSize = { s.text, -1 } })
		end
	end
	return result
end
