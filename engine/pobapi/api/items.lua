-- items.*: equipped items, equipping from item text and item parsing.
local util = require("pobapi.util")
local session = require("pobapi.session")

local M = { }

local function modLines(item)
	local lines = util.array()
	local function add(list, kind)
		for _, line in ipairs(list or { }) do
			if line.line and not line.variantList or (line.variantList and line.variantList[item.variant]) then
				lines[#lines + 1] = {
					text = util.strip(line.line),
					kind = kind,
					supported = not line.extra,
					crafted = line.crafted or nil,
				}
			end
		end
	end
	add(item.enchantModLines, "enchant")
	add(item.runeModLines, "rune")
	add(item.implicitModLines, "implicit")
	add(item.explicitModLines, "explicit")
	return lines
end

function M.describe(item, full)
	if not item then
		return nil
	end
	local res = {
		id = item.id,
		name = item.name,
		title = item.title,
		baseName = item.baseName,
		type = item.type,
		rarity = item.rarity,
		corrupted = item.corrupted or nil,
		itemLevel = item.itemLevel,
		quality = item.quality,
	}
	if full then
		res.mods = modLines(item)
		res.text = item:BuildRaw()
	end
	return res
end

function M.list(params)
	local b = session.build()
	local full = params.full ~= false
	local res = util.array()
	for _, slot in ipairs(b.itemsTab.orderedSlots) do
		local item = b.itemsTab.items[slot.selItemId]
		if item or params.includeEmpty then
			res[#res + 1] = {
				slot = slot.slotName,
				label = slot.label,
				jewelNodeId = slot.nodeId,
				item = M.describe(item, full),
			}
		end
	end
	return res
end

function M.slots()
	local b = session.build()
	local res = util.array()
	for _, slot in ipairs(b.itemsTab.orderedSlots) do
		if not slot.nodeId then
			res[#res + 1] = slot.slotName
		end
	end
	return res
end

local function parse(text)
	local item = new("Item"):Item(text)
	if not item.base then
		util.fail("Could not parse item (unknown base type). Paste the full item text copied from the game (Ctrl+C).")
	end
	item:NormaliseQuality()
	item:BuildModList()
	return item
end

function M.parse(params)
	local item = parse(util.require(params, "text", "string"))
	local res = M.describe(item, true)
	res.primarySlot = item:GetPrimarySlot()
	return res
end

function M.equip(params)
	local text = util.require(params, "text", "string")
	local b = session.build()
	local itemsTab = b.itemsTab
	parse(text) -- validate first for a clean error
	itemsTab:CreateDisplayItemFromRaw(text, true)
	local item = itemsTab.displayItem
	local slotName = params.slot or item:GetPrimarySlot()
	local slot = itemsTab.slots[slotName]
	if not slot then
		util.fail("Unknown slot: " .. tostring(slotName))
	end
	itemsTab:AddDisplayItem(true)
	slot:SetSelItemId(item.id)
	itemsTab:PopulateSlots()
	itemsTab:AddUndoState()
	session.recalc()
	return { slot = slotName, item = M.describe(item, true) }
end

function M.unequip(params)
	local slotName = util.require(params, "slot", "string")
	local b = session.build()
	local slot = b.itemsTab.slots[slotName]
	if not slot then
		util.fail("Unknown slot: " .. slotName)
	end
	slot:SetSelItemId(0)
	b.itemsTab:PopulateSlots()
	b.itemsTab:AddUndoState()
	session.recalc()
	return true
end

return M
