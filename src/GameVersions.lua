-- Game versions
---Default target version for unknown builds and builds created before 3.0.0.
legacyTargetVersion = "3_0"
---Default target for new builds and target to convert legacy builds to.
liveTargetVersion = "4_0"

-- Skill tree versions
---Added for convenient indexing of skill tree versions.
---@type string[]
treeVersionList = { "4_0" }
--- Always points to the latest skill tree version.
latestTreeVersion = treeVersionList[#treeVersionList]
---Tree version where multiple skill trees per build were introduced to PoBC.
defaultTreeVersion = treeVersionList[1]
---Display, comparison and export data for all supported skill tree versions.
---@type table<string, {display: string, num: number, url: string}>
treeVersions = {
	["4_0"] = {
		display = "POE 2",
		num = 4.0,
	},
}
