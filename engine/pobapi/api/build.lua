-- build.*: create, load, export and describe the active build.
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local function mainSkillName(b)
	local group = b.skillsTab.socketGroupList[b.mainSocketGroup]
	if not group or not group.displaySkillList then
		return nil
	end
	local skill = group.displaySkillList[group.mainActiveSkill or 1]
	return skill and skill.activeEffect and skill.activeEffect.grantedEffect and skill.activeEffect.grantedEffect.name
end

function M.info()
	local b = session.build()
	local spec = b.spec
	local used, ascUsed = spec:CountAllocNodes()
	return {
		name = b.buildName,
		className = spec.curClassName,
		ascendClassName = spec.curAscendClassName ~= "None" and spec.curAscendClassName or nil,
		level = b.characterLevel,
		levelAutoMode = b.characterLevelAutoMode,
		treeVersion = spec.treeVersion,
		targetVersion = b.targetVersion,
		pointsUsed = used,
		ascendancyPointsUsed = ascUsed,
		mainSocketGroup = b.mainSocketGroup,
		mainSkill = mainSkillName(b),
		bandit = b.bandit,
	}
end

function M.new(params)
	session.setMode(params.name or "New Build")
	return M.info()
end

function M.load_xml(params)
	local xml = util.require(params, "xml", "string")
	if not xml:find("<PathOfBuilding", 1, true) then
		util.fail("Not a Path of Building build XML")
	end
	session.setMode(params.name or "Imported Build", xml)
	session.frame()
	return M.info()
end

function M.export_xml()
	local xml = session.build():SaveDB("code")
	if not xml then
		util.fail("Failed to serialise build", "internal")
	end
	return { xml = xml }
end

function M.set_level(params)
	local level = util.require(params, "level", "number")
	local b = session.build()
	b.characterLevel = math.min(math.max(math.floor(level), 1), 100)
	b.characterLevelAutoMode = false
	b.configTab:BuildModList()
	session.recalc()
	return M.info()
end

-- Accepts class/ascendancy by name (case-insensitive).
function M.set_class(params)
	local b = session.build()
	local spec = b.spec
	local tree = spec.tree
	if params.className then
		local classId = tree.classNameMap[params.className]
		if not classId then
			for name, id in pairs(tree.classNameMap) do
				if name:lower() == tostring(params.className):lower() then
					classId = id
				end
			end
		end
		if not classId then
			util.fail("Unknown class: " .. tostring(params.className))
		end
		if classId ~= spec.curClassId then
			spec:SelectClass(classId)
		end
	end
	if params.ascendClassName then
		local wanted = tostring(params.ascendClassName):lower()
		local found
		for id, asc in pairs(spec.curClass.classes) do
			if asc.name:lower() == wanted then
				found = id
			end
		end
		if not found then
			util.fail("Unknown ascendancy for " .. spec.curClassName .. ": " .. tostring(params.ascendClassName))
		end
		spec:SelectAscendClass(found)
	end
	b.buildFlag = true
	session.recalc()
	return M.info()
end

return M
