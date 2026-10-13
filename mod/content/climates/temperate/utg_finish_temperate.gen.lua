function data()
return {
	climate = "::/climates/temperate/temperate.clima",
	desc = {
		cargoTypeSet = {
			cargoClassesExcluded = { },
			cargoClassesIncluded = { },
			cargoTypesExcluded = { },
			cargoTypesIncluded = { },
		},
		name = _("UTG finishing pass (Temperate)"),
	},
	editorOnly = true,
	isImportGenerator = true,
	nodeTree = "utg_finish_temperate_gen.tree",
	order = 50,
	params = {
		{
			defaultIndex = 1,
			images = { },
			key = "utg_forests",
			name = _("Lower tree density"),
			tags = { },
			tooltip = _("Fewer tree models for lower-spec computers (about half). Where forests grow stays the same; only how many trees are placed changes."),
			uiType = "ComboBox",
			valueIndices = { },
			values = { _("Normal"), _("Lower"), },
			yearFrom = 0,
			yearTo = 0,
		},
	},
	previewSeed = "yQKiK",
	updateScript = {
		fileName = "",
		params = { },
	},
}
end
