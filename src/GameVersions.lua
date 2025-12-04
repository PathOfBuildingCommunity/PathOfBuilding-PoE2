-- Game versions
---Default target version for unknown builds and builds created before 3.0.0.
legacyTargetVersion = "0_0"
---Default target for new builds and target to convert legacy builds to.
liveTargetVersion = "0_1"

-- Skill tree versions
---Added for convenient indexing of skill tree versions.
---@type string[]
treeVersionList = { "0_1", "0_2", "0_3" }
--- Always points to the latest skill tree version.
latestTreeVersion = treeVersionList[#treeVersionList]
---Tree version where multiple skill trees per build were introduced to PoBC.
defaultTreeVersion = treeVersionList[1]
---Display, comparison and export data for all supported skill tree versions.
---@type table<string, {display: string, num: number}>
treeVersions = {
	["0_1"] = {
		display = "0_1",
		num = 0.1,
	},
	["0_2"] = {
		display = "0_2",
		num = 0.2,
	},
	["0_3"] = {
		display = "0_3",
		num = 0.3,
	},
}
