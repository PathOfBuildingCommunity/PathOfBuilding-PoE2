-- skills.*: socket groups, gems and main skill selection.
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local function gemInfo(gem)
	local gemData = gem.gemData
	local granted = gemData and gemData.grantedEffect
	return {
		name = gemData and gemData.name or gem.nameSpec,
		level = gem.level,
		quality = gem.quality,
		enabled = gem.enabled ~= false,
		support = granted and granted.support or false,
		recognised = gemData ~= nil,
	}
end

local function groupInfo(b, index, group)
	local res = {
		index = index,
		label = group.label ~= "" and group.label or nil,
		displayLabel = util.strip(group.displayLabel),
		slot = group.slot,
		enabled = group.enabled ~= false,
		includeInFullDPS = group.includeInFullDPS or false,
		isMain = b.mainSocketGroup == index,
		gems = util.array(),
		activeSkills = util.array(),
	}
	for _, gem in ipairs(group.gemList or { }) do
		res.gems[#res.gems + 1] = gemInfo(gem)
	end
	for i, skill in ipairs(group.displaySkillList or { }) do
		local ge = skill.activeEffect and skill.activeEffect.grantedEffect
		res.activeSkills[#res.activeSkills + 1] = {
			index = i,
			name = ge and ge.name or "?",
			isMain = res.isMain and (group.mainActiveSkill or 1) == i,
		}
	end
	return res
end

function M.list()
	local b = session.build()
	local res = util.array()
	for i, group in ipairs(b.skillsTab.socketGroupList) do
		res[#res + 1] = groupInfo(b, i, group)
	end
	return res
end

local function getGroup(params)
	local b = session.build()
	local index = util.require(params, "group", "number")
	local group = b.skillsTab.socketGroupList[index]
	if not group then
		util.fail("No socket group at index " .. index)
	end
	return b, group, index
end

function M.set_main(params)
	local b, group, index = getGroup(params)
	b.mainSocketGroup = index
	if params.skill then
		group.mainActiveSkill = params.skill
	end
	session.recalc()
	return groupInfo(b, index, group)
end

-- Adds a socket group using PoB's clipboard format, one gem per line:
--   "<Gem Name> <level>/<quality> <state> <count>"  e.g. "Spark 20/0  1"
-- Plain gem names are also accepted and default to level 20, quality 0.
function M.add(params)
	local b = session.build()
	local lines = { }
	if params.label then
		lines[#lines + 1] = "Label: " .. params.label
	end
	if params.slot then
		lines[#lines + 1] = "Slot: " .. params.slot
	end
	local gems = params.gems or { }
	if type(params.text) == "string" then
		for line in params.text:gmatch("[^\r\n]+") do
			gems[#gems + 1] = line
		end
	end
	if #gems == 0 then
		util.fail("Provide 'gems' (list of gem names) or 'text'")
	end
	for _, gem in ipairs(gems) do
		if type(gem) == "table" then
			gem = ("%s %d/%d  1"):format(gem.name, gem.level or 20, gem.quality or 0)
		elseif not gem:match("%d+/%d+") then
			gem = gem .. " 20/0  1"
		end
		lines[#lines + 1] = gem
	end
	local before = #b.skillsTab.socketGroupList
	b.skillsTab:PasteSocketGroup(table.concat(lines, "\n"))
	if #b.skillsTab.socketGroupList == before then
		util.fail("No gems were recognised")
	end
	local index = #b.skillsTab.socketGroupList
	local info = groupInfo(b, index, b.skillsTab.socketGroupList[index])
	info.warnings = util.array()
	for _, gem in ipairs(info.gems) do
		if not gem.recognised then
			local suggestions = M.suggest(gem.name)
			info.warnings[#info.warnings + 1] = ("Unrecognised gem '%s'%s"):format(gem.name,
				#suggestions > 0 and (". Did you mean: " .. table.concat(suggestions, ", ") .. "?") or "")
		end
	end
	if params.makeMain or not b.mainSocketGroup or b.mainSocketGroup == 0 then
		b.mainSocketGroup = index
	end
	session.recalc()
	info.isMain = b.mainSocketGroup == index
	return info
end

-- Up to 5 gem names sharing a word with the given name.
function M.suggest(name)
	local res = { }
	for word in tostring(name):gmatch("%a%a%a+") do
		for _, gem in pairs(data.gems) do
			if #res < 5 and util.contains(gem.name, word) then
				local dup = false
				for _, r in ipairs(res) do dup = dup or r == gem.name end
				if not dup then res[#res + 1] = gem.name end
			end
		end
	end
	return res
end

function M.remove(params)
	local b, _, index = getGroup(params)
	table.remove(b.skillsTab.socketGroupList, index)
	if b.mainSocketGroup >= index then
		b.mainSocketGroup = math.max(1, b.mainSocketGroup - 1)
	end
	b.skillsTab:SetDisplayGroup(nil)
	session.recalc()
	return M.list()
end

-- Change one gem in a group: params.index (1-based gem position), optional name, level, quality, enabled.
function M.set_gem(params)
	local b, group, index = getGroup(params)
	local gem = group.gemList[util.require(params, "index", "number")]
	if not gem then
		util.fail("No gem at index " .. tostring(params.index))
	end
	if params.name then
		local found
		for id, gemData in pairs(data.gems) do
			if gemData.name == params.name then
				found = id
				break
			end
		end
		if not found then
			local suggestions = M.suggest(params.name)
			util.fail(("Unknown gem '%s'%s"):format(params.name, #suggestions > 0 and (". Did you mean: " .. table.concat(suggestions, ", ") .. "?") or ""))
		end
		gem.gemId = found
		gem.nameSpec = data.gems[found].name
		gem.skillId = data.gems[found].grantedEffectId
		gem.level = params.level or b.skillsTab:ProcessGemLevel(data.gems[found])
	end
	if params.level then gem.level = params.level end
	if params.quality then gem.quality = params.quality end
	if params.enabled ~= nil then gem.enabled = params.enabled end
	b.skillsTab:ProcessSocketGroup(group)
	session.recalc()
	return groupInfo(b, index, group)
end

function M.set_enabled(params)
	local b, group, index = getGroup(params)
	group.enabled = params.enabled ~= false
	session.recalc()
	return groupInfo(b, index, group)
end

return M
