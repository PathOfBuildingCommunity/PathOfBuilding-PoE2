local gimpbatch = require("Tree/gimpbatch/gimp_batch")
local nvtt = LoadModule("Tree/nvtt")
local json = require("dkjson")

-- by session we would like to dont extract the same file multiple times
main.treeCacheExtract = main.treeCacheExtract or { }
local cacheExtract = main.treeCacheExtract

if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("passive_skill_stat_descriptions.csd")

local function extractFromGgpk(listToExtract, useRegex)
	useRegex = useRegex or false
	local sweetSpotCharacter = 6000
	printf("Extracting ...")
	local fileList = ''
	for _, fname in ipairs(listToExtract) do
		-- we are going to validate if the file is already extracted in this session
		if not cacheExtract[fname] then
			cacheExtract[fname] = true
			fileList = fileList .. '"' .. string.lower(fname) .. '" '

			if fileList:len() > sweetSpotCharacter then
				main.ggpk:ExtractFilesWithBun(fileList, useRegex)
				fileList = ''
			end
		end
	end

	if fileList:len() > 0 then
		main.ggpk:ExtractFilesWithBun(fileList, useRegex)
		fileList = ''
	end
end

local function bits(int, s, e)
	return bit.band(bit.rshift(int, s), 2 ^ (e - s + 1) - 1)
end
local function toFloat(int)
	local s = (-1) ^ bits(int, 31, 31)
	local e = bits(int, 23, 30) - 127
	if e == -127 then
		return 0 * s
	end
	local m = 1
	for i = 0, 22 do
		m = m + bits(int, i, i) * 2 ^ (i - 23)
	end
	return s * m * 2 ^ e
end
local function getInt(f)
	local int = f:read(4)
	return bytesToInt(int)
end
local function getLong(f)
	local bytes = f:read(8)
	local a, b, c, d, e, f, g, h = bytes:byte(1, 8)
	return a + b * 256 + c * 65536 + d * 16777216 + e * 4294967296 + f * 1099511627776 + g * 281474976710656 + h * 72057594037927936
end
local function getFloat(f)
	return toFloat(getInt(f))
end
local function getUint16(f)
    -- Read 2 bytes
    local bytes = f:read(2)

    -- Convert the 2 bytes to an unsigned integer (little-endian)
    local b1, b2 = bytes:byte(1, 2)
    local uint16 = b1 + b2 * 256

    return uint16
end
local function round_to(num, decimal_places)
    local multiplier = 10 ^ decimal_places
    return math.floor(num * multiplier + 0.5) / multiplier
end

local function print_table(t, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    if type(t) ~= "table" then
        print(prefix .. tostring(t))
        return
    end

    for key, value in pairs(t) do
        if type(value) == "table" then
            print(prefix .. tostring(key) .. ": {")
            print_table(value, indent + 1)
            print(prefix .. "}")
        else
            print(prefix .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

local function newSheet(name, startWidth, saturation)
	return {
		name = name,
		startWidth = startWidth,
		saturation = saturation,
		sprite = { },
		files = {}
	}
end
local function addToSheet(sheet, icon, section, metadata)
	sheet.files[icon] = sheet.files[icon] or {}
	if sheet.files[icon][section] then
		-- check if metadata alias already exists
		if metadata.alias then
			for _, meta in pairs(sheet.files[icon][section]) do
				if meta.alias == metadata.alias then
					return
				end
			end
		else
			for _, meta in pairs(sheet.files[icon][section]) do
				if meta.alias == nil then
					return
				end
			end
		end
	end
	sheet.files[icon][section] = sheet.files[icon][section] or {}
	table.insert(sheet.files[icon][section], metadata)
end

local function calculateDDSPack(sheet, from_base, to_base, is4kEnabled)
	local stackTextures = {}
	local ddsCoords = {}

	-- stract all files first from GGG pack
	local filesToExtract = { }
	for icon, _ in pairs(sheet.files) do
		table.insert(filesToExtract, icon)

		if is4kEnabled then
			local icon4k = icon:gsub("(.*/)([^/]+)$", "%14k/%2")
			table.insert(filesToExtract, icon4k)
		end
	end
	extractFromGgpk(filesToExtract)

	for icon, sections in pairs(sheet.files) do
		local tex = Texture.new()
		local rc
		if is4kEnabled then
			local icon4k = icon:gsub("(.*/)([^/]+)$", "%14k/%2")
			rc = tex:Load(from_base .. string.lower(icon4k))
		end
		if not rc then
			rc = tex:Load(from_base .. string.lower(icon))
		end

		local info = tex:Info()
		local ident = string.format("%d_%d_%s", info.width, info.height, info.formatStr)

		if not stackTextures[ident] then
			stackTextures[ident] = {}
		end

		table.insert(stackTextures[ident], {
			tex = tex,
			icon = icon,
			sections = sections
		})
	end


	for iden, stackInfo in pairs(stackTextures) do
		local stacks = {}
		local file = sheet.name .. "_" .. iden .. ".dds.zst"
		ddsCoords[file] = {}
		for position, stack in ipairs(stackInfo) do
			for _, metadatas in pairs(stack.sections) do
				for _, meta in ipairs(metadatas) do
					local icon = meta.alias or stack.icon
					ddsCoords[file][icon] = position
				end
			end
			table.insert(stacks, stack.tex)
		end
		local stackTex = Texture.new()
		local rc = stackTex:StackTextures(stacks)
		rc = stackTex:Save(to_base .. file)
	end
	sheet.ddsCoords = ddsCoords
end

local function parseUIImages()
	local file = "art/uiimages1.txt"
	local text
	if main.ggpk.txt[file] then
		text = main.ggpk.txt[file]
	else
		extractFromGgpk({file})
		text = convertUTF16to8(getFile(file))
		main.ggpk.txt[file] = text
	end
	
	local images = {}
	
	for line in text:gmatch("[^\r\n]+") do
		local index = 0
		local name = ""
		for field in line:gmatch('"?([^%s"]+)"?') do
			if index == 0 then
				name = string.lower(field)
				images[name] = {}
			elseif index ==1 then
				images[name]["path"] = string.lower(field)
			elseif index == 2 then
				images[name]["x"] = tonumber(field)
			elseif index == 3 then
				images[name]["y"] = tonumber(field)
			elseif index == 4 then
				images[name]["width"] = tonumber(field)
			elseif index == 5 then
				images[name]["height"] = tonumber(field)
			end
			index = index + 1
		end
	end
	printf("UI Images parsed")
	return images
end

--[[
	===== Extraction =====
	Extraction of passives tree from psg file
	workflow:
		- read data file
		- get psg file
		- parse psg file
			- check version (only support version 3 for now)
--]]

-- parse UI Images
printf("Getting uiimages ...")
local uiImages = parseUIImages()
-- uncomment next line if wanna print what we found
-- print_table(uiImages, 0)

-- Set to true if you want to generate assets
local generateAssets = false
local use4kIfPossible = false
-- Find a way to get the default passive tree
local idPassiveTree = 'Default'
-- Find a way to get version
local basePath = GetWorkDir() .. "/../TreeData/"
local version = "0_1"
local path = basePath .. version .. "/"
local fileTree = path .. "tree.lua"

printf("Getting passives tree...")

local rowPassiveTree =  dat("passiveskilltrees"):GetRow("Id", idPassiveTree)

if rowPassiveTree == nil then
	printf("Passive tree not found")
	return
end

local psgFile = rowPassiveTree.PassiveSkillGraph .. ".psg"

printf("Extracting passives tree " .. idPassiveTree .. " from " .. psgFile)

extractFromGgpk({psgFile})

printf("Parsing passives tree " .. idPassiveTree .. " from " .. main.ggpk.oozPath .. psgFile)

local f = io.open(main.ggpk.oozPath .. psgFile, "rb")

-- validate version
local pgb_version = getUint16(f)
if pgb_version ~= 3 then
	printf("Version " .. version .. " not supported")
	return
end

f:read(11)

local psg = { 
	passives = { },
	groups = { },
}

printf("Parsing passives...")
local passivesCount = getInt(f)

printf("Passive count: " .. passivesCount)
for i = 1 , passivesCount do
	table.insert(psg.passives, getLong(f))
end

printf("Parsing groups...")
local groupCount = getInt(f)

printf("Group count: " .. groupCount)
for i = 1 , groupCount do
	local group = { 
		x = getFloat(f),
		y = getFloat(f),
		flags = getInt(f),
		unk1 = getInt(f),
		unk2 = f:read(1):byte(),
		passives = { },
	}

	local passiveCount = getInt(f)
	for j = 1, passiveCount do
		local passive = {
			id = getInt(f),
			radious = getInt(f),
			position = getInt(f),
			connections = { },
		}

		local connectionCount = getInt(f)

		for k = 1, connectionCount do
			table.insert(passive.connections, {
				id = getInt(f),
				radious = getInt(f),
			})
		end

		table.insert(group.passives, passive)
	end

	table.insert(psg.groups, group)
end

f:close()

printf("Passives tree " .. idPassiveTree .. " parsed")

-- uncomment next line if wanna print what we found
-- print_table(psg, 0)

--[[
	===== Generation =====
	Generation of passives tree from psg file
	workflow:
		- generate classes
		- generate groups
		- generate nodes
		- generate sprites (with sprite sheet)
		- generate zoom levels
		- generate constants
--]]

-- we use functions to generate a new table and not shared table
local function commonMetadata(alias)
	local metadata = {
		alias = alias,
	}
	return metadata
end

local defaultMaxWidth = 1500
local sheets = {
	newSheet("skills",  defaultMaxWidth, 100),
	newSheet("skills-disabled", defaultMaxWidth, 60),
	newSheet("background", defaultMaxWidth, 100),
	newSheet("group-background", defaultMaxWidth, 100),
	newSheet("mastery-active-effect", defaultMaxWidth, 100),
	newSheet("ascendancy-background", defaultMaxWidth, 100),
	newSheet("oils", defaultMaxWidth, 100),
	newSheet("lines", defaultMaxWidth, 100),
	newSheet("jewelsockets", defaultMaxWidth, 100),
}
local sheetLocations = {
	["skills"] = 1,
	["skills-disabled"] = 2,
	["background"] = 3,
	["group-background"] = 4,
	["mastery-active-effect"] = 5,
	["ascendancy-background"] = 6,
	["oils"] = 7,
	["lines"] = 8,
	["jewelsockets"] = 9,
}
local function getSheet(sheetLocation)
	return sheets[sheetLocations[sheetLocation]]
end

-- Looking for Background2
printf("Extracting Background2...")
local bg2 = uiImages["art/2dart/uiimages/common/background2"]
if not bg2 then
	printf("Background2 not found")
	goto final
end

-- for support we needs to _out.dds when .dds
addToSheet(getSheet("background"), bg2.path, "background", commonMetadata("Background2"))

-- add Group Background base ond UIArt from PassiveTree\
printf("Getting Background Group...")
local uIArt = rowPassiveTree.UIArt

local gBgSmall = uiImages[string.lower(uIArt.GroupBackgroundSmall)].path
addToSheet(getSheet("group-background"), gBgSmall, "groupBackground", commonMetadata("PSGroupBackground1"))

local gBgMedium = uiImages[string.lower(uIArt.GroupBackgroundMedium)].path
addToSheet(getSheet("group-background"), gBgMedium, "groupBackground", commonMetadata("PSGroupBackground2"))

local gBgLarge = uiImages[string.lower(uIArt.GroupBackgroundLarge)].path
addToSheet(getSheet("group-background"), gBgLarge, "groupBackground", commonMetadata("PSGroupBackground3"))

printf("Getting PassiveFrame")
local pFrameNormal = uiImages[string.lower(uIArt.PassiveFrameNormal)].path
addToSheet(getSheet("group-background"), pFrameNormal, "frame", commonMetadata("PSSkillFrame"))

local pFrameActive = uiImages[string.lower(uIArt.PassiveFrameActive)].path
addToSheet(getSheet("group-background"), pFrameActive, "frame", commonMetadata("PSSkillFrameActive"))

local pFrameCanAllocate = uiImages[string.lower(uIArt.PassiveFrameCanAllocate)].path
addToSheet(getSheet("group-background"), pFrameCanAllocate, "frame", commonMetadata("PSSkillFrameHighlighted"))

printf("Getting KeystoneFrame")
local kFrameNormal = uiImages[string.lower(uIArt.KeystoneFrameNormal)].path
addToSheet(getSheet("group-background"), kFrameNormal, "frame", commonMetadata("KeystoneFrameUnallocated"))

local kFrameActive = uiImages[string.lower(uIArt.KeystoneFrameActive)].path
addToSheet(getSheet("group-background"), kFrameActive, "frame", commonMetadata("KeystoneFrameAllocated"))

local kFrameCanAllocate = uiImages[string.lower(uIArt.KeystoneFrameCanAllocate)].path
addToSheet(getSheet("group-background"), kFrameCanAllocate, "frame", commonMetadata("KeystoneFrameCanAllocate"))

printf("Getting NotableFrame")
local nFrameNormal = uiImages[string.lower(uIArt.NotableFrameNormal)].path
addToSheet(getSheet("group-background"), nFrameNormal, "frame", commonMetadata("NotableFrameUnallocated"))

local nFrameActive = uiImages[string.lower(uIArt.NotableFrameActive)].path
addToSheet(getSheet("group-background"), nFrameActive, "frame", commonMetadata("NotableFrameAllocated"))

local nFrameCanAllocate = uiImages[string.lower(uIArt.NotableFrameCanAllocate)].path
addToSheet(getSheet("group-background"), nFrameCanAllocate, "frame", commonMetadata("NotableFrameCanAllocate"))

printf("Getting GroupBackgroundBlank")
local gBgSmallBlank = uiImages[string.lower(uIArt.GroupBackgroundSmallBlank)].path
addToSheet(getSheet("group-background"), gBgSmallBlank, "groupBackground", commonMetadata("PSGroupBackgroundSmallBlank"))

local gBgMediumBlank = uiImages[string.lower(uIArt.GroupBackgroundMediumBlank)].path
addToSheet(getSheet("group-background"), gBgMediumBlank, "groupBackground", commonMetadata("PSGroupBackgroundMediumBlank"))

local gBgLargeBlank = uiImages[string.lower(uIArt.GroupBackgroundLargeBlank)].path
addToSheet(getSheet("group-background"), gBgLargeBlank, "groupBackground", commonMetadata("PSGroupBackgroundLargeBlank"))

printf("Getting JewelSocketFrame")
local jFrameNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketCanAllocate")].path
addToSheet(getSheet("group-background"), jFrameNormal, "frame", commonMetadata("JewelFrameCanAllocate"))

local jFrameActive = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketActive")].path
addToSheet(getSheet("group-background"), jFrameActive, "frame", commonMetadata("JewelFrameAllocated"))

local jFrameCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketNormal")].path
addToSheet(getSheet("group-background"), jFrameCanAllocate, "frame", commonMetadata("JewelFrameUnallocated"))

printf("Getting Ascendancy frames")
local ascFrameNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallCanAllocate")].path
addToSheet(getSheet("group-background"), ascFrameNormal, "frame", commonMetadata("AscendancyFrameSmallCanAllocate"))

local ascFrameActive = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallNormal")].path
addToSheet(getSheet("group-background"), ascFrameActive, "frame", commonMetadata("AscendancyFrameSmallNormal"))

local ascFrameCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallAllocated")].path
addToSheet(getSheet("group-background"), ascFrameCanAllocate, "frame", commonMetadata("AscendancyFrameSmallAllocated"))

local ascFrameLargeNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeNormal")].path
addToSheet(getSheet("group-background"), ascFrameLargeNormal, "frame", commonMetadata("AscendancyFrameLargeNormal"))

local ascFrameLargeCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeCanAllocate")].path
addToSheet(getSheet("group-background"), ascFrameLargeCanAllocate, "frame", commonMetadata("AscendancyFrameLargeCanAllocate"))

local ascFrameLargeAllocated = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeAllocated")].path
addToSheet(getSheet("group-background"), ascFrameLargeAllocated, "frame", commonMetadata("AscendancyFrameLargeAllocated"))

local ascMiddle = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyMiddle")].path
addToSheet(getSheet("group-background"), ascMiddle, "frame", commonMetadata("AscendancyMiddle"))

local ascStart = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenStartNodeBackgroundInactive")].path
addToSheet(getSheet("group-background"), ascStart, "startNode", commonMetadata("PSStartNodeBackgroundInactive"))

-- adding passive tree assets
addToSheet(getSheet("ascendancy-background"), "art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircle.dds", "ascendancyBackground", commonMetadata("BGTree"))
addToSheet(getSheet("ascendancy-background"), "art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircleactive2.dds", "ascendancyBackground", commonMetadata("BGTreeActive"))

-- adding lines to sprite
addToSheet(getSheet("lines"), "art/2dart/passivetree/passiveskillscreencurvesactivetogether.dds", "line", commonMetadata( "CurvesActive"))
addToSheet(getSheet("lines"), "art/2dart/passivetree/passiveskillscreencurvesintermediatetogether.dds", "line", commonMetadata( "CurvesIntermediate"))
addToSheet(getSheet("lines"), "art/2dart/passivetree/passiveskillscreencurvesnormaltogether.dds", "line", commonMetadata( "CurvesNormal"))

-- adding jewel sockets
local jewelArt = dat("passivejewelart")
for jewel in jewelArt:Rows() do
	local asset = uiImages[string.lower(jewel.JewelArt)]
	printf("Adding jewel socket " .. jewel.Item.Name .. " " .. asset.path .. " to sprite")
	local name = jewel.Item.Name
	addToSheet(getSheet("jewelsockets"), asset.path, "jewelpassive", commonMetadata(name))
end

local tree = {
	["tree"] = idPassiveTree,
	["min_x"]= 0,
    ["min_y"]= 0,
    ["max_x"]= 0,
    ["max_y"]= 0,
	["classes"] = {},
	["groups"] = { },
	["nodes"]= { },
	["assets"]={},
	["ddsCoords"] = {},
	["constants"]= { -- calculate this
        ["classes"]= {
            ["StrDexIntClass"]= 0,
            ["StrClass"]= 1,
            ["DexClass"]= 2,
            ["IntClass"]= 3,
            ["StrDexClass"]= 4,
            ["StrIntClass"]= 5,
            ["DexIntClass"]= 6
        },
        ["characterAttributes"]= {
            ["Strength"]= 0,
            ["Dexterity"]= 1,
            ["Intelligence"]= 2
        },
        ["PSSCentreInnerRadius"]= 130,
        ["skillsPerOrbit"]= {},
        ["orbitRadii"]= {
			0, 82, 162, 335, 493, 662, 846, 251, 1080, 1322
        }
    },
}

printf("Generating classes...")
local ignoreFilter = "^%[DNT%]"
for i, classId in ipairs(psg.passives) do
	local passiveRow = dat("passiveskills"):GetRow("PassiveSkillNodeId", classId)
	if passiveRow == nil then
		printf("Class " .. passiveRow.id .. " not found")
		goto continue
	end

	if passiveRow.Name:find(ignoreFilter) ~= nil then
		printf("Ignoring class " .. passiveRow.Name)
		goto continue
	end

	local listCharacters = passiveRow.ClassStart
	
	if listCharacters == nil then
		printf("Characters not found")
		goto continue
	end

	for j, character in ipairs(listCharacters) do
		if character.Name:find(ignoreFilter) ~= nil then
			printf("Ignoring character " .. character.Name)
			goto continue2
		end
		local classDef = {
			["name"] = character.Name,
			["base_str"] = character.BaseStrength,
			["base_dex"] = character.BaseDexterity,
			["base_int"] = character.BaseIntelligence,
			["ascendancies"] = {},
		}

		-- add assets
		addToSheet(getSheet("ascendancy-background"), character.PassiveTreeImage, "ascendancyBackground", commonMetadata( "Classes" .. character.Name))

		-- We are going to ignore for now, because current tree doesnt use that
		--addToSheet(getSheet("group-background"), uiImages[string.lower(character.SkillTreeBackground)].path, "startNode", commonMetadata( "center" .. string.lower(character.Name)))

		local ascendancies = dat("ascendancy"):GetRowList("Class", character)
		for k, ascendency in ipairs(ascendancies) do
			if ascendency.Name:find(ignoreFilter) ~= nil then
				printf("Ignoring ascendency " .. ascendency.Name .. " for class " .. character.Name)
				goto continue3
			end
			table.insert(classDef.ascendancies, {
				["id"] = ascendency.Name,
				["name"] = ascendency.Name,
			})

			-- add assets
			addToSheet(getSheet("ascendancy-background"), ascendency.PassiveTreeImage, "ascendancyBackground", commonMetadata( "Classes" .. ascendency.Name))

			:: continue3 ::
		end

		if #classDef.ascendancies == 0 then
			printf("No ascendancies found for class " .. character.Name)
			goto continue2
		end
		table.insert(tree.classes,classDef)
		:: continue2 ::
	end
	:: continue ::
end


-- for now we are harcoding attributes id
local base_attributes = {
	[26297] = {}, -- str
	[14927] = {}, -- dex
	[57022] = {}--int
}

for id, _ in pairs(base_attributes) do
	local base = dat("passiveskills"):GetRow("PassiveSkillNodeId", id)
	if base == nil then
		printf("Base attribute " .. id .. " not found")
		goto continue
	end

	if base.Name:find(ignoreFilter) ~= nil then
		printf("Ignoring base attribute " .. base.Name)
		goto continue
	end

	local attribute = {
		["name"] = base.Name,
		["icon"] = base.Icon,
		["stats"] = {},
	}

	-- Stats
	if base.Stats ~= nil then
		local parseStats = {}
		for k, stat in ipairs(base.Stats) do
			parseStats[stat.Id] = { min = base["Stat" .. k], max = base["Stat" .. k] }
		end
		local out, orders = describeStats(parseStats)
		for k, line in ipairs(out) do
			table.insert(attribute["stats"], line)
		end
	end

	addToSheet(getSheet("skills"), base.Icon, "normalActive", commonMetadata(nil))
	base_attributes[id] = attribute
	:: continue ::
end

printf("Generating tree groups...")

local orbitsConstants = { }
local ascendancyGroups = {}
local missingStatInfo = {}
for i, group in ipairs(psg.groups) do
	local groupIsAscendancy = false
	local treeGroup = {
		["x"] = round_to(group.x, 2),
		["y"] = round_to(group.y, 2),
		["orbits"] ={},
		["nodes"] = {}
	}

	local orbits = { }
	for j, passive in ipairs(group.passives) do
		local node = {
			["skill"] = passive.id,
			["group"] = i,
			["orbit"] = passive.radious,
			["orbitIndex"] = passive.position,
			["connections"] = {},	
		}

		-- Get Information from passive Skill
		local passiveRow = dat("passiveskills"):GetRow("PassiveSkillNodeId", passive.id)
		if passiveRow == nil then
			printf("Passive skill " .. passive.id .. " not found")
		else
			if passiveRow.Name:find(ignoreFilter) ~= nil then
				printf("Ignoring passive skill " .. passiveRow.Name)
				goto exitnode
			end
			node["name"] = escapeGGGString(passiveRow.Name)
			node["icon"] = passiveRow.Icon
			if passiveRow.Keystone then
				node["isKeystone"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "keystoneActive", commonMetadata(nil))
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "keystoneInactive", commonMetadata(nil))
			elseif passiveRow.Notable then
				node["isNotable"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "notableActive", commonMetadata(nil))
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "notableInactive", commonMetadata(nil))
			elseif passiveRow.IsOnlyImage then
				node["isOnlyImage"] = true
			elseif passiveRow.JewelSocket then
				node["isJewelSocket"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "socketActive", commonMetadata(nil))
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "socketInactive", commonMetadata(nil))
			else
				addToSheet(getSheet("skills"), passiveRow.Icon, "normalActive", commonMetadata(nil))
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "normalInactive", commonMetadata(nil))
			end

			-- Ascendancy
			if passiveRow.Ascendancy ~= nil then
				groupIsAscendancy = true
				if passiveRow.Ascendancy.Name:find(ignoreFilter) ~= nil then
					printf("Ignoring node ascendancy " .. passiveRow.Ascendancy.Name)
					goto exitnode
				end
				node["ascendancyName"] = passiveRow.Ascendancy.Name
				node["isAscendancyStart"] = passiveRow.AscendancyStart or nil

				ascendancyGroups = ascendancyGroups or {}
				ascendancyGroups[passiveRow.Ascendancy.Name] = ascendancyGroups[passiveRow.Ascendancy.Name] or { }
				ascendancyGroups[passiveRow.Ascendancy.Name].startId = passiveRow.AscendancyStart and passive.id or ascendancyGroups[passiveRow.Ascendancy.Name].startId
				ascendancyGroups[passiveRow.Ascendancy.Name][i] = true
			end

			-- Stats
			if passiveRow.Stats ~= nil then
				node["stats"] = node["stats"] or {}
				local parseStats = {}
				local totalStats = 0
				local namesStats = ""
				for k, stat in ipairs(passiveRow.Stats) do
					parseStats[stat.Id] = { min = passiveRow["Stat" .. k], max = passiveRow["Stat" .. k] }
					totalStats = totalStats + 1
					namesStats = namesStats .. stat.Id .. " | "
				end
				local out, orders, missing = describeStats(parseStats)
				if #out < totalStats then
					table.insert(missingStatInfo, "====================================")
					table.insert(missingStatInfo,"Stats not found for passive " .. passiveRow.Name .. " " .. passive.id)
					table.insert(missingStatInfo,"Stats found: " .. totalStats)
					table.insert(missingStatInfo,namesStats)
					table.insert(missingStatInfo,"Stats out: " .. #out)
					for k, line in ipairs(out) do
						table.insert(missingStatInfo,line)
					end
					table.insert(missingStatInfo,"Missing: ")
					for k, _ in pairs(missing) do
						if k ~= 1 then
							table.insert(missingStatInfo,k)
						end
					end
					table.insert(missingStatInfo,"====================================")
				end
				for k, line in ipairs(out) do
					table.insert(node["stats"], line)
				end
			end

			-- support for images
			if passiveRow.MasteryGroup ~= nil then
				node["activeEffectImage"] = passiveRow.MasteryGroup.Background

				local uiEffect = uiImages[string.lower(passiveRow.MasteryGroup.Background)]
				addToSheet(getSheet("mastery-active-effect"), uiEffect.path, "masteryActiveEffect", commonMetadata(passiveRow.MasteryGroup.Background))
			end

			-- if the passive is "Attribute" we are going to add values
			if passiveRow.Attribute == true then
				node["options"] = {}
				node["isAttribute"] = true
				for attId, value in pairs(base_attributes) do
					table.insert(node["options"], {
						["id"] = attId,
						["name"] = base_attributes[attId].name,
						["icon"] = base_attributes[attId].icon,
						["stats"] = base_attributes[attId].stats,
					})
				end
			end

			-- support for granted skills
			if passiveRow.GrantedSkill ~= nil then
				node["stats"] = node["stats"] or {}

				for _, gemEffect in pairs(passiveRow.GrantedSkill.GemEffects) do
					local skillname = gemEffect.GrantedEffect.ActiveSkill.DisplayName
					table.insert(node["stats"], "Grants Skill: " .. skillname)

					-- -- include the stat description
					local statDescription =string.sub(string.lower(gemEffect.GrantedEffect.ActiveSkill.StatDescription), 1, -2)
					local handle = NewFileSearch("ggpk/" .. statDescription ..".csd")
					local almostOnce = false
					while handle do
						almostOnce = true
						print(statDescription:gsub("metadata/statdescriptions", "") .. ".csd")
						-- loadStatFile(statDescription:gsub("metadata/statdescriptions/", "") .. ".csd")
						if not handle:NextFile() then
							break
						end
					end
					if not almostOnce then
						table.insert(missingStatInfo, "===================================>Missing stat" .. statDescription)
					end
				end
			end

			-- support for Passive Points Granted
			if passiveRow.PassivePointsGranted > 0 then
				node["stats"] = node["stats"] or {}
				table.insert(node["stats"], "Grants ".. passiveRow.PassivePointsGranted .." Passive Skill Point")
			end

			-- support for Weapon points granted
			if passiveRow.WeaponPointsGranted > 0 then
				node["stats"] = node["stats"] or {}
				table.insert(node["stats"],  passiveRow.WeaponPointsGranted .." Passive Skill Points become Weapon Set Skill Points")
			end

			-- support for oils
			local bResult = dat("blightcraftingresults"):GetRow("PassiveSkillsKey", passiveRow)

			if bResult ~= nil then
				node["recipe"] = {}
				local bCraftRecipe = dat("blightcraftingrecipes"):GetRow("BlightCraftingResultsKey", bResult)
				if bCraftRecipe ~= nil then
					for _, item in ipairs(bCraftRecipe.Recipe) do
						table.insert(node["recipe"], item.NameShort)

						-- add to sprite sheet
						addToSheet(getSheet("oils"), item.Oil.ItemVisualIdentityKey.DDSFile, "oil", commonMetadata(item.NameShort))
					end
				end
			end

			-- support for switchnodes
			local switchNode = dat("classpassiveskilloverrides"):GetRow("OriginalNode", passiveRow)
			if switchNode ~= nil then
				node["isSwitchable"] = true
				local nodeInfo = {
					["id"] = switchNode.SwitchedNode.PassiveSkillNodeId,
					["name"] = switchNode.SwitchedNode.Name,
					["icon"] = switchNode.SwitchedNode.Icon,
					["stats"] = {},
				}

				-- add to assets
				addToSheet(getSheet("skills"), switchNode.SwitchedNode.Icon, "normalActive", commonMetadata(nil))
				addToSheet(getSheet("skills-disabled"), switchNode.SwitchedNode.Icon, "normalInactive", commonMetadata(nil))

				-- Stats
				if switchNode.SwitchedNode.Stats ~= nil then
					local parseStats = {}
					for k, stat in ipairs(switchNode.SwitchedNode.Stats) do
						parseStats[stat.Id] = { min = switchNode.SwitchedNode["Stat" .. k], max = switchNode.SwitchedNode["Stat" .. k] }
					end
					local out, orders = describeStats(parseStats)
					for k, line in ipairs(out) do
						table.insert(nodeInfo["stats"], line)
					end
				end

				node["options"] = {
					[switchNode.Character.Name] = nodeInfo
				}
			end

			-- classStartName
			if #passiveRow.ClassStart > 0 then
				node["classesStart"] = {}
				for _, classStart in ipairs(passiveRow.ClassStart) do
					if classStart.Name:find(ignoreFilter) == nil then
						table.insert(node["classesStart"], classStart.Name)
					end
				end
			end

			-- Multiple Choice and MultipleChoiceOption support
			if passiveRow.MultipleChoice then
				node["isMultipleChoice"] = true
			end
			if passiveRow.MultipleChoiceOption then
				node["isMultipleChoiceOption"] = true
			end
		end
		
		for k, connection in ipairs(passive.connections) do
			table.insert(node.connections, {
				id = connection.id,
				orbit = connection.radious,
			})
		end

		orbits[passive.radious + 1] = true
		orbitsConstants[passive.radious + 1] = math.max(orbitsConstants[passive.radious + 1] or 1, passive.position)
		tree.nodes[passive.id] = node
		table.insert(treeGroup.nodes, passive.id)
		:: exitnode ::
	end

	for orbit, _ in pairs(orbits) do
		table.insert(treeGroup.orbits, orbit - 1)
	end

	if #treeGroup.nodes > 0 then
		tree.groups[i] = treeGroup

		if not groupIsAscendancy then
			tree.min_x = math.min(tree.min_x, group.x)
			tree.min_y = math.min(tree.min_y, group.y)
			tree.max_x = math.max(tree.max_x, group.x)
			tree.max_y = math.max(tree.max_y, group.y)
		end
	else
		printf("Group " .. i .. " is empty")
	end
end

-- write file with missing Stats
if #missingStatInfo > 0 then
	local file = io.open(basePath .. version .. "/missingStats.txt", "w")
	for _, line in ipairs(missingStatInfo) do
		file:write(line .. "\n")
	end
	file:close()
end

-- updating skillsPerOrbit
printf("Updating skillsPerOrbit...")
for i, orbit in ipairs(orbitsConstants) do
	-- only numbers base on 12
	orbit = i == 1 and orbit or math.ceil(orbit / 12) * 12
	tree.constants.skillsPerOrbit[i] = orbit
end

-- Update position of ascendancy base on min / max 
-- get the orbit radious + harcoded value, calculate the angle of the class start
-- translate the ascendancy to the new position in arc position
local widthTree, heightTree = tree.max_x - tree.min_x, tree.max_y - tree.min_y
local radiousTree = math.max(widthTree, heightTree) / 2
local arcAngle = { [0] = 0, [1] = 0, [2] = 12, [3] = 24, [4] = 36, [5] = 48, [6] = 60}

for i, classId in ipairs(psg.passives) do
	local nodeStart = tree.nodes[classId]
	local group = tree.groups[nodeStart.group]
	local angleToCenter = math.atan2(group.y, group.x)
	local harcoded = radiousTree + 2800

	-- calculate how many ascendancies in that plase?
	local total = 0
	local classes = {}

	for _, class in ipairs(tree.classes) do
		for _, nodeClasses in ipairs(nodeStart.classesStart) do
			if nodeClasses == class.name then
				total = total + #class.ascendancies
				table.insert(classes, class)
			end
		end
	end

	local startAngle = angleToCenter - math.rad(arcAngle[total] / 2)
	local angleStep = math.rad(arcAngle[total] / (total - 1)) or 0

	local j = 1
	for _, class in ipairs(classes) do
		for _, ascendancy in ipairs(class.ascendancies) do
			local info = ascendancyGroups[ascendancy.id]
			local ascendancyNode = tree.nodes[info.startId]
			local groupAscendancy = tree.groups[ascendancyNode.group]

			local angle = startAngle + (j - 1) * angleStep
			local newX = harcoded * math.cos(angle)
			local newY = harcoded * math.sin(angle)

			local offsetX = newX - groupAscendancy.x
			local offsetY = newY - groupAscendancy.y
		
			-- now update the whole groups with the offset
			for groupId, value in pairs(info) do
				if type(value) == "boolean" then
					local group = tree.groups[groupId]
					group.x = group.x + offsetX
					group.y = group.y + offsetY

					-- recalculate min / max
					tree.min_x = math.min(tree.min_x, group.x - harcoded / 2)
					tree.min_y = math.min(tree.min_y, group.y - harcoded / 2)
					tree.max_x = math.max(tree.max_x, group.x + harcoded / 2)
					tree.max_y = math.max(tree.max_y, group.y + harcoded / 2)
				end
			end
			j = j + 1
		end
	end
end

MakeDir(basePath .. version)

printf("Generating sprite info...")
for i, sheet in ipairs(sheets) do
	printf("Calculating sprite dimensions for " .. sheet.name)
	calculateDDSPack(sheet, main.ggpk.oozPath, basePath .. version .. "/", use4kIfPossible)

	for file, fileInfo in pairs(sheet.ddsCoords) do
		tree.ddsCoords[file] = fileInfo
	end
end

printf("Generating decompose lines images...")
local linesFiles = {
	{
		file = "art/2dart/passivetree/passiveskillscreencurvesactivetogether.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask.dds",
		extension = ".png",
		basename = "orbitactive",
		first = "LineConnector",
		prefix = "Orbit",
		posfix = "Active",
		meta = 0.3835,
		minmapfile = 0,
		minmapmask = 0,
		total = 10
	},
	{
		file = "art/2dart/passivetree/passiveskillscreencurvesintermediatetogether.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask.dds",
		extension = ".png",
		basename = "orbitintemediate",
		first = "LineConnector",
		prefix = "Orbit",
		posfix = "Intermediate",
		total = 10
	},
	{
		file = "art/2dart/passivetree/passiveskillscreencurvesnormaltogether.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask.dds",
		extension = ".png",
		basename = "orbitnormal",
		first = "LineConnector",
		prefix = "Orbit",
		posfix = "Normal",
		total = 10
	}
}

local linesDds = {}
for _, lines in ipairs(linesFiles) do
	table.insert(linesDds, lines.file)
	table.insert(linesDds, lines.mask)
end

extractFromGgpk(linesDds)
nvtt.ExportDDSToPng(main.ggpk.oozPath, basePath .. version .. "/", "lines", linesDds, true)

-- change extension from dds to png
for _, lines in ipairs(linesFiles) do
	lines.file = lines.file:gsub(".dds", ".png")
	lines.mask = lines.mask:gsub(".dds", ".png")
end

gimpbatch.extract_lines_from_image("lines_extract", linesFiles, main.ggpk.oozPath, basePath .. version .. "/", GetScriptPath() .. "/Tree/gimpbatch/extract_lines.scm", generateAssets)

printf("generate lines info into assets")
-- Generate sprites
for _, lines in ipairs(linesFiles) do
	local curveOrbitfile = 9
	for i = 0, lines.total - 1 do
		local name
		local middle
		if i == 0 then
			name = lines.first .. lines.posfix
			middle = 0
		elseif i == 3 then
			curveOrbitfile = curveOrbitfile - 1
			middle = curveOrbitfile
			curveOrbitfile = curveOrbitfile - 1
			name = lines.prefix .. i .. lines.posfix
		elseif i == 7 then
			middle = 7
			name = lines.prefix .. i .. lines.posfix
		else
			name = lines.prefix .. i .. lines.posfix
			middle = curveOrbitfile

			curveOrbitfile = curveOrbitfile - 1
		end

		tree.assets[name] = {
			lines.basename .. middle .. lines.extension
		}
	end
end

printf("Generating file in " .. fileTree)
local out, err = io.open(fileTree, "w")
if out == nil then
	printf("Error opening file " .. fileTree)
	printf(err)
	return
end
out:write('return ')
writeLuaTable(out, tree, 1)
out:close()
printf("File " .. fileTree .. " generated")

local fileTreeJson = fileTree:gsub(".lua", ".json")
printf("Generating json file in " .. fileTreeJson)
local out, err = io.open(fileTreeJson, "w")
if out == nil then
	printf("Error opening file " .. fileTreeJson)
	printf(err)
	return
end
out:write(json.encode(tree))
out:close()
:: final ::