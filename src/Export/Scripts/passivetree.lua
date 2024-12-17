local gimpbatch = require("gimpbatch.gimp_batch")
local ddsfiles = require("ddsfiles")
local nvtt = require("nvtt")

if not loadStatFile then
	dofile("statdesc.lua")
end
loadStatFile("stat_descriptions.csd")
loadStatFile("passive_skill_stat_descriptions.csd")

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

local function newSheet(name, maxWidth, saturation, maxGroups)
	return {
		name = name,
		maxWidth = maxWidth,
		saturation = saturation,
		maxGroups = maxGroups,
		sprites = { },
		files = {}
	}
end
local function addToSheet(sheet, icon, section, metadata)
	sheet.files[icon] = sheet.files[icon] or {}
	if sheet.files[icon][section] then
		return
	end
	sheet.files[icon][section] = metadata
end
local function calculateSheetCoords(sheet, path_base, path_to)
	for i = 0, sheet.maxGroups - 1 do
		local coords = { }
		local sortedFiles = { }
		local lastHeight = 0
		local maxWidthFound = 0
		local group = {
			x=0, 
			y=0,
			w = sheet.maxWidth,
			h = 0,
			filename = sheet.name .. "-" .. i .. ".png",
		}

		for icon, sections in pairs(sheet.files) do
			for section, metadata in pairs(sections) do
				if not metadata[i + 1] then
					goto continue
				end

				local width = metadata[i + 1].width
				local height = metadata[i + 1].height
				local alias = metadata.alias
				local convert = metadata.convert or nil

				if convert then
					icon = string.gsub(icon, ".dds", "_out.dds")
				end
				local mipmap = ddsfiles.findClosestDDSMipmap( path_base .. string.lower(icon), width, height)

				-- update width and heigth is the closest mipmap is different

				table.insert(sortedFiles, {
					icon = icon,
					section = section,
					alias = alias,
					width = width,
					height = height,
					mipmap = mipmap,
				})

				:: continue ::
			end
		end

		table.sort(sortedFiles, function(a, b)
			return a.height < b.height
		end)

		for _, iconInfo in pairs(sortedFiles) do
			if group.x + iconInfo.width > group.w or iconInfo.height ~= lastHeight then
				group.x = 0
				group.y = group.y + lastHeight
				group.h = group.y + iconInfo.height
			end
			table.insert(coords, {
				icon = iconInfo.icon,
				x = group.x,
				y = group.y,
				w = iconInfo.width,
				h = iconInfo.height,
				alias = iconInfo.alias,
				section = iconInfo.section,
				mipmap = iconInfo.mipmap,
			})
			group.x = group.x + iconInfo.width
			maxWidthFound = math.max(maxWidthFound, group.x)
			lastHeight = iconInfo.height
		end
		group.x = 0
		group.y = 0
		group.coords = coords

		if maxWidthFound > 0 and maxWidthFound < group.w then
			group.w = maxWidthFound
		end

		table.insert(sheet.sprites, group)
	end

	sheet.files = {}
end

local function generateSprite(sheet, path_base, path_out,executeCommand)
	for i, group in ipairs(sheet.sprites) do
		if #group.coords == 0 then
			goto continue
		end
		gimpbatch.combine_dds_to_sprite(
			sheet.name .. "-" .. (i-1),
			group,
			path_base,
			path_out, GetRuntimePath() .. "/lua/gimpbatch/combine_dds.scm",
			sheet.saturation,
			executeCommand
		)
		:: continue ::
	end
end

local function extractFromGgpk(listToExtract, useRegex)
	useRegex = useRegex or false
	local sweetSpotCharacter = 6000
	printf("Extracting ...")
	local fileList = ''
	for _, fname in ipairs(listToExtract) do
		fileList = fileList .. '"' .. string.lower(fname) .. '" '

		if fileList:len() > sweetSpotCharacter then
			main.ggpk:ExtractFilesWithBun(fileList, useRegex)
			fileList = ''
		end
	end

	if fileList:len() > 0 then
		main.ggpk:ExtractFilesWithBun(fileList, useRegex)
		fileList = ''
	end
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

-- common DDS conversion, while Gimp doesnt support other format we need to always format to bc1a
local ddsFormat = "bc1a"

-- Set to true if you want to generate assets
local generateAssets = false
-- Find a way to get the default passive tree
local idPassiveTree = 'Default'
-- Find a way to get version
local basePath = GetWorkDir() .. "/../TreeData/"
local version = "4_0"
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
local function commonBackgroundMetadata(alias, maxWBase, maxHBase , maxGroups, convert)
	local metadata = {
		alias = alias,
		convert = convert
	}

	for i = 0, maxGroups-1  do
		table.insert(metadata, {
			width = maxWBase / (2 ^ (maxGroups - 1 - i)),
			height = maxHBase / (2 ^ (maxGroups - 1 - i)),
		})
	end

	return metadata
end

function skillNormalMetadata() 
	return commonBackgroundMetadata(nil, 64, 64, 4, nil)
end
function skillKeystoneMetadata ()
	return commonBackgroundMetadata(nil, 128, 128, 4, nil)
end
function skillNotableMetadata()
	return commonBackgroundMetadata(nil, 128, 128, 4, nil)
end
function masteryMetadata()
	return commonBackgroundMetadata(nil, 256, 256, 4, nil)
end

local defaultMaxWidth = 86*14
local maxGroups = 5 -- this is base on imageZoomLevels
local sheets = {
	newSheet("skills",  defaultMaxWidth, 100, maxGroups),
	newSheet("skills-disabled", defaultMaxWidth, 40, maxGroups),
	newSheet("mastery", defaultMaxWidth, 100, maxGroups),
	newSheet("mastery-active-selected", defaultMaxWidth, 100, maxGroups),
	newSheet("mastery-disabled", defaultMaxWidth, 40, maxGroups),
	newSheet("mastery-connected", defaultMaxWidth, 100, maxGroups),
	newSheet("background", 2400, 100, maxGroups),
	newSheet("group-background", defaultMaxWidth, 100, maxGroups),
	newSheet("mastery-active-effect", defaultMaxWidth, 100, maxGroups),
	newSheet("ascendancy", 2400, 100, maxGroups),
	newSheet("ascendancy-background", 2400, 100, maxGroups),
}
local sheetLocations = {
	["skills"] = 1,
	["skills-disabled"] = 2,
	["mastery"] = 3,
	["mastery-active-selected"] = 4,
	["mastery-disabled"] = 5,
	["mastery-connected"] = 6,
	["background"] = 7,
	["group-background"] = 8,
	["mastery-active-effect"] = 9,
	["ascendancy"] = 10,
	["ascendancy-background"] = 11,
}
local function getSheet(sheetLocation)
	return sheets[sheetLocations[sheetLocation]]
end

-- Extract all PassiveSkillScreen from uiimage
printf("Extracting PassiveSkillScreen...")
local listPassiveSkillDds = {}
for icon, iconInfo in pairs(uiImages) do
	-- for now exclude 4k files
	if icon:find("passiveskillscreen") and not icon:find("4k") then
		table.insert(listPassiveSkillDds, iconInfo.path)
	end
end
extractFromGgpk(listPassiveSkillDds)

-- we need to convert the dds to a ssuported version with nttd tools
printf("Converting PassiveSkillScreen...")
nvtt.CompressDDSIntoOtherFormat(main.ggpk.oozPath, basePath .. version .. "/", "passiveSkillScreen", listPassiveSkillDds, ddsFormat, false)

-- Looking for Background2
printf("Extracting Background2...")
local bg2 = uiImages["art/2dart/uiimages/common/background2"]
if not bg2 then
	printf("Background2 not found")
	goto final
end

-- for support we needs to _out.dds when .dds
addToSheet(getSheet("background"), bg2.path, "background", commonBackgroundMetadata("Background2", 1024, 1024, 4, ddsFormat))

-- add Group Background base ond UIArt from PassiveTree\
printf("Getting Background Group...")
local uIArt = rowPassiveTree.UIArt

local gBgSmall = uiImages[string.lower(uIArt.GroupBackgroundSmall)].path
addToSheet(getSheet("group-background"), gBgSmall, "groupBackground", commonBackgroundMetadata("PSGroupBackground1", 360, 369, 4, ddsFormat))

local gBgMedium = uiImages[string.lower(uIArt.GroupBackgroundMedium)].path
addToSheet(getSheet("group-background"), gBgMedium, "groupBackground", commonBackgroundMetadata("PSGroupBackground2", 468, 468, 4, ddsFormat))

local gBgLarge = uiImages[string.lower(uIArt.GroupBackgroundLarge)].path
addToSheet(getSheet("group-background"), gBgLarge, "groupBackground", commonBackgroundMetadata("PSGroupBackground3", 740, 376, 4, ddsFormat))

printf("Getting PassiveFrame")
local pFrameNormal = uiImages[string.lower(uIArt.PassiveFrameNormal)].path
addToSheet(getSheet("group-background"), pFrameNormal, "frame", commonBackgroundMetadata("PSSkillFrame", 104, 104, 4, ddsFormat))

local pFrameActive = uiImages[string.lower(uIArt.PassiveFrameActive)].path
addToSheet(getSheet("group-background"), pFrameActive, "frame", commonBackgroundMetadata("PSSkillFrameActive", 104, 104, 4, ddsFormat))

local pFrameCanAllocate = uiImages[string.lower(uIArt.PassiveFrameCanAllocate)].path
addToSheet(getSheet("group-background"), pFrameCanAllocate, "frame", commonBackgroundMetadata("PSSkillFrameHighlighted", 104, 104, 4, ddsFormat))

addToSheet(getSheet("group-background"), "art/2dart/uieffects/passiveskillscreen/nodeframemask.dds", "frame", commonBackgroundMetadata("PSSkillFrameMask", 104, 104, 4, ddsFormat))

printf("Getting KeystoneFrame")
local kFrameNormal = uiImages[string.lower(uIArt.KeystoneFrameNormal)].path
addToSheet(getSheet("group-background"), kFrameNormal, "frame", commonBackgroundMetadata("KeystoneFrameUnallocated", 220, 224, 4, ddsFormat))

local kFrameActive = uiImages[string.lower(uIArt.KeystoneFrameActive)].path
addToSheet(getSheet("group-background"), kFrameActive, "frame", commonBackgroundMetadata("KeystoneFrameAllocated", 220, 224, 4, ddsFormat))

local kFrameCanAllocate = uiImages[string.lower(uIArt.KeystoneFrameCanAllocate)].path
addToSheet(getSheet("group-background"), kFrameCanAllocate, "frame", commonBackgroundMetadata("KeystoneFrameCanAllocate", 220, 224, 4, ddsFormat))

printf("Getting NotableFrame")
local nFrameNormal = uiImages[string.lower(uIArt.NotableFrameNormal)].path
addToSheet(getSheet("group-background"), nFrameNormal, "frame", commonBackgroundMetadata("NotableFrameUnallocated", 152, 156, 4, ddsFormat))

local nFrameActive = uiImages[string.lower(uIArt.NotableFrameActive)].path
addToSheet(getSheet("group-background"), nFrameActive, "frame", commonBackgroundMetadata("NotableFrameAllocated", 152, 156, 4, ddsFormat))

local nFrameCanAllocate = uiImages[string.lower(uIArt.NotableFrameCanAllocate)].path
addToSheet(getSheet("group-background"), nFrameCanAllocate, "frame", commonBackgroundMetadata("NotableFrameCanAllocate", 152, 156, 4, ddsFormat))

printf("Getting GroupBackgroundBlank")
local gBgSmallBlank = uiImages[string.lower(uIArt.GroupBackgroundSmallBlank)].path
addToSheet(getSheet("group-background"), gBgSmallBlank, "groupBackground", commonBackgroundMetadata("PSGroupBackgroundSmallBlank", 440, 440, 4, ddsFormat))

local gBgMediumBlank = uiImages[string.lower(uIArt.GroupBackgroundMediumBlank)].path
addToSheet(getSheet("group-background"), gBgMediumBlank, "groupBackground", commonBackgroundMetadata("PSGroupBackgroundMediumBlank", 756, 756, 4, ddsFormat))

local gBgLargeBlank = uiImages[string.lower(uIArt.GroupBackgroundLargeBlank)].path
addToSheet(getSheet("group-background"), gBgLargeBlank, "groupBackground", commonBackgroundMetadata("PSGroupBackgroundLargeBlank", 952, 952, 4, ddsFormat))

printf("Getting JewelSocketFrame")
local jFrameNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketCanAllocate")].path
addToSheet(getSheet("group-background"), jFrameNormal, "frame", commonBackgroundMetadata("JewelFrameCanAllocate", 104, 104, 4, ddsFormat))

local jFrameActive = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketActive")].path
addToSheet(getSheet("group-background"), jFrameActive, "frame", commonBackgroundMetadata("JewelFrameAllocated", 104, 104, 4, ddsFormat))

local jFrameCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/SanctumPassiveSkillScreenJewelSocketNormal")].path
addToSheet(getSheet("group-background"), jFrameCanAllocate, "frame", commonBackgroundMetadata("JewelFrameUnallocated", 104, 104, 4, ddsFormat))

printf("Getting Ascendancy frames")
local ascFrameNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallCanAllocate")].path
addToSheet(getSheet("group-background"), ascFrameNormal, "frame", commonBackgroundMetadata("AscendancyFrameSmallCanAllocate", 160, 164, 4, ddsFormat))

local ascFrameActive = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallNormal")].path
addToSheet(getSheet("group-background"), ascFrameActive, "frame", commonBackgroundMetadata("AscendancyFrameSmallNormal", 160, 164, 4, ddsFormat))

local ascFrameCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameSmallAllocated")].path
addToSheet(getSheet("group-background"), ascFrameCanAllocate, "frame", commonBackgroundMetadata("AscendancyFrameSmallAllocated", 160, 164, 4, ddsFormat))

local ascFrameLargeNormal = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeNormal")].path
addToSheet(getSheet("group-background"), ascFrameLargeNormal, "frame", commonBackgroundMetadata("AscendancyFrameLargeNormal", 208, 208, 4, ddsFormat))

local ascFrameLargeCanAllocate = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeCanAllocate")].path
addToSheet(getSheet("group-background"), ascFrameLargeCanAllocate, "frame", commonBackgroundMetadata("AscendancyFrameLargeCanAllocate", 208, 208, 4, ddsFormat))

local ascFrameLargeAllocated = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyFrameLargeAllocated")].path
addToSheet(getSheet("group-background"), ascFrameLargeAllocated, "frame", commonBackgroundMetadata("AscendancyFrameLargeAllocated", 208, 208, 4, ddsFormat))

local ascMiddle = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenAscendancyMiddle")].path
addToSheet(getSheet("group-background"), ascMiddle, "frame", commonBackgroundMetadata("AscendancyMiddle", 92, 92, 4, ddsFormat))

local ascStart = uiImages[string.lower("Art/2DArt/UIImages/InGame/PassiveSkillScreenStartNodeBackgroundInactive")].path
addToSheet(getSheet("group-background"), ascStart, "startNode", commonBackgroundMetadata("PSStartNodeBackgroundInactive", 528, 528, 4, ddsFormat))

-- we need to stract lines from dds
local listAdditionalAssets = {
	"art/2dart/passivetree/passiveskillwormholelightpulse.dds",
	"art/2dart/passivetree/passiveskillscreencurvesnormaltogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesnormalbluetogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesnormalalttogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesintermediatetogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesintermediatebluetogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesintermediatealttogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesactivetogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesactivebluetogether.dds",
	"art/2dart/passivetree/passiveskillscreencurvesactivealttogether.dds",
	"art/2dart/passivetree/atlaspassiveskillscreencurvesnormalbluetogether.dds",
	"art/2dart/passivetree/atlaspassiveskillscreencurvesintermediatebluetogether.dds",
	"art/2dart/passivetree/atlaspassiveskillscreencurvesactivebluetogether.dds",
	"art/2dart/passivetree/ascendancypassiveskillscreencurvesnormaltogether.dds",
	"art/2dart/passivetree/ascendancypassiveskillscreencurvesintermediatetogether.dds",
	"art/2dart/passivetree/ascendancypassiveskillscreencurvesbackingtogether.dds",
	"art/2dart/passivetree/ascendancypassiveskillscreencurvesactivetogether.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreenstartnodebackgroundinactive.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreenpointsbackground.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreenplusframenormal.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreenplusframecanallocate.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passiveskillscreenplusframeactive.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/hudpassiveskillscreennormal.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/hudpassiveskillscreenhover.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/hudpassiveskillscreendown.dds",
	"art/2dart/uieffects/passiveskillscreen/plusframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/passivemasterybuttonmask.dds",
	"art/2dart/uieffects/passiveskillscreen/notableframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/nodeframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/linestogethermask.dds",
	"art/2dart/uieffects/passiveskillscreen/keystoneframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/jewelsocketframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/expansionjewelsocketframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/atlaswormholeframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/atlasnotableframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/atlasnodeframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/atlaskeystoneframemask.dds",
	"art/2dart/uieffects/passiveskillscreen/ascendancyframesmallmask.dds",
	"art/2dart/uieffects/passiveskillscreen/ascendancyframelargemask.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/ptscrollbarthumb.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/ptscrollbarbgright.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/ptscrollbarbgleft.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/ptscrollbarbgcenter.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepopupsplitallocation.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepopupapply.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepaneltop.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelsetnormal.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelsetactive.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelgold.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelbuttonpressed.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelbuttonnormal.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelbuttonhover.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanelbot.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanel3.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanel2.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreepanel.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircleactive2.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircleactive.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircle.dds",
	"art/textures/interface/2d/2dart/uiimages/ingame/passivetree/ascendancypassivetreepaneltop.dds",
}

printf("Extracting Additional Assets...")
extractFromGgpk(listAdditionalAssets)
nvtt.CompressDDSIntoOtherFormat(main.ggpk.oozPath, basePath .. version .. "/", "additionalAssets", listAdditionalAssets, ddsFormat, true)

-- adding passive tree assets
addToSheet(getSheet("ascendancy-background"), "art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircle.dds", "ascendancyBackground", commonBackgroundMetadata("BGTree", 2000, 2000, 4, ddsFormat))
addToSheet(getSheet("ascendancy-background"), "art/textures/interface/2d/2dart/uiimages/ingame/passivetree/passivetreemaincircleactive2.dds", "ascendancyBackground", commonBackgroundMetadata("BGTreeActive", 2000, 2000, 4, ddsFormat))

printf("Generating decompose lines images...")
local linesFiles = {
	{
		file = "art/2dart/passivetree/passiveskillscreencurvesactivetogether_out.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask_out.dds",
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
		file = "art/2dart/passivetree/passiveskillscreencurvesintermediatetogether_out.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask_out.dds",
		extension = ".png",
		basename = "orbitintemediate",
		first = "LineConnector",
		prefix = "Orbit",
		posfix = "Intermediate",
		meta = 0.3835,
		minmapfile = 0,
		minmapmask = 0,
		total = 10
	},
	{
		file = "art/2dart/passivetree/passiveskillscreencurvesnormaltogether_out.dds",
		mask = "art/2dart/uieffects/passiveskillscreen/linestogethermask_out.dds",
		extension = ".png",
		basename = "orbitnormal",
		first = "LineConnector",
		prefix = "Orbit",
		posfix = "Normal",
		meta = 0.3835,
		minmapfile = 0,
		minmapmask = 0,
		total = 10
	}
}
gimpbatch.extract_lines_dds("lines", linesFiles, main.ggpk.oozPath, basePath .. version .. "/", GetRuntimePath() .. "/lua/gimpbatch/extract_lines.scm", generateAssets)

local tree = {
	["pob"] = 1,
	["tree"] = idPassiveTree,
	["min_x"]= 0,
    ["min_y"]= 0,
    ["max_x"]= 0,
    ["max_y"]= 0,
	["classes"] = {},
	["groups"] = { },
	["nodes"]= { },
	["assets"] = {},
	["sprites"] = {},
	["imageZoomLevels"] = {
        0.1246,
        0.2109,
        0.2972,
        0.3835,
		0.9013 -- calculate
	},
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
		addToSheet(getSheet("ascendancy-background"), character.PassiveTreeImage, "ascendancyBackground", commonBackgroundMetadata( "Classes" .. character.Name, 1500, 1500, 4, ddsFormat))
		addToSheet(getSheet("group-background"), uiImages[string.lower(character.SkillTreeBackground)].path, "startNode", commonBackgroundMetadata( "center" .. string.lower(character.Name), 1024, 1024, 4, ddsFormat))

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
			addToSheet(getSheet("ascendancy-background"), ascendency.PassiveTreeImage, "ascendancyBackground", commonBackgroundMetadata( "Classes" .. ascendency.Name, 1500, 1500, 4, ddsFormat))

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

	base_attributes[id] = attribute
	:: continue ::
end

printf("Generating tree groups...")

local orbitsConstants = { }
for i, group in ipairs(psg.groups) do
	tree.min_x = math.min(tree.min_x, group.x)
	tree.min_y = math.min(tree.min_y, group.y)
	tree.max_x = math.max(tree.max_x, group.x)
	tree.max_y = math.max(tree.max_y, group.y)

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
			node["name"] = passiveRow.Name
			node["icon"] = passiveRow.Icon
			if passiveRow.Keystone then
				node["isKeystone"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "keystoneActive", skillKeystoneMetadata())
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "keystoneInactive", skillKeystoneMetadata())
			elseif passiveRow.Notable then
				node["isNotable"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "notableActive", skillNotableMetadata())
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "notableInactive", skillNotableMetadata())
			elseif passiveRow.Mastery then
				node["isMastery"] = true
				node["inactiveIcon"] = passiveRow.MasteryGroup.IconInactive
				node["activeIcon"] = passiveRow.MasteryGroup.IconActive
				
				addToSheet(getSheet("mastery"), passiveRow.Icon, "mastery", masteryMetadata())
				addToSheet(getSheet("mastery-disabled"), passiveRow.MasteryGroup.IconInactive, "masteryInactive", masteryMetadata())
				addToSheet(getSheet("mastery-connected"), passiveRow.MasteryGroup.IconInactive, "masteryConnected", masteryMetadata())
				addToSheet(getSheet("mastery-active-selected"), passiveRow.MasteryGroup.IconActive, "masteryActiveSelected", masteryMetadata())


				-- node["masteryEffects"] = {}

				-- for _, masteryEffect in ipairs(passiveRow.MasteryGroup.MasteryEffects) do
				-- 	local effect = {
				-- 		effect = masteryEffect.Hash,
				-- 		stats = {},
				-- 	}

				-- 	local parseStats = {}
				-- 	for k, stat in ipairs(masteryEffect.Stats) do
				-- 		parseStats[stat.Id] = { min = masteryEffect["Stat" .. k], max = masteryEffect["Stat" .. k] }
				-- 	end
				-- 	local out, orders = describeStats(parseStats)
				-- 	for k, line in ipairs(out) do
				-- 		table.insert(effect.stats, line)
				-- 	end

				-- 	table.insert(node["masteryEffects"], effect)
				-- end
			elseif passiveRow.JewelSocket then
				node["isJewelSocket"] = true
				addToSheet(getSheet("skills"), passiveRow.Icon, "socketActive", skillNormalMetadata())
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "socketInactive", skillNormalMetadata())
			else
				addToSheet(getSheet("skills"), passiveRow.Icon, "normalActive", skillNormalMetadata())
				addToSheet(getSheet("skills-disabled"), passiveRow.Icon, "normalInactive", skillNormalMetadata())
			end

			-- Ascendancy
			if passiveRow.Ascendancy ~= nil then
				if passiveRow.Ascendancy.Name:find(ignoreFilter) ~= nil then
					printf("Ignoring node ascendancy " .. passiveRow.Ascendancy.Name)
					goto exitnode
				end
				node["ascendancyName"] = passiveRow.Ascendancy.Name
				node["isAscendancyStart"] = passiveRow.AscendancyStart or nil
			end

			-- Stats
			if passiveRow.Stats ~= nil then
				node["stats"] = {}
				local parseStats = {}
				for k, stat in ipairs(passiveRow.Stats) do
					parseStats[stat.Id] = { min = passiveRow["Stat" .. k], max = passiveRow["Stat" .. k] }
				end
				local out, orders = describeStats(parseStats)
				for k, line in ipairs(out) do
					table.insert(node["stats"], line)
				end
			end

			-- add Mastery Effect to other type of nodes different than Mastery
			if passiveRow.MasteryGroup ~= nil then
				node["activeEffectImage"] = passiveRow.MasteryGroup.Background

				local uiEffect = uiImages[string.lower(passiveRow.MasteryGroup.Background)]
				addToSheet(getSheet("mastery-active-effect"), uiEffect.path, "masteryActiveEffect", commonBackgroundMetadata(passiveRow.MasteryGroup.Background, 768, 768, 4, ddsFormat))
			end

			-- if the passive is "Attribute" we are going to add values
			if passiveRow.Name == "Attribute" then
				node["options"] = {}
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
		end
		
		for k, connection in ipairs(passive.connections) do
			table.insert(node.connections, {
				id = connection.id,
				orbit = connection.radious,
			})
		end

		-- classStartIndex: is this node exist in psg.passives
		for k, classStartIndex in ipairs(psg.passives) do
			if classStartIndex == passive.id then
				node["classStartIndex"] = k - 1
				break
			end
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
	else
		printf("Group " .. i .. " is empty")
	end
end

-- updating skillsPerOrbit
printf("Updating skillsPerOrbit...")
for i, orbit in ipairs(orbitsConstants) do
	-- only numbers base on 12
	orbit = i == 1 and orbit or math.ceil(orbit / 12) * 12
	tree.constants.skillsPerOrbit[i] = orbit
end

MakeDir(basePath .. version)

printf("Generating list to extract dds from sheets...")
local listDds = {}
local convertList = {}
for i, sheet in ipairs(sheets) do
	for icon, section in pairs(sheet.files) do
		listDds[icon] = true

		for section, metadata in pairs(section) do
			if metadata.convert then
				convertList[metadata.convert] = convertList[metadata.convert] or {}
				convertList[metadata.convert][icon] = true
			end
		end
	end
end

local fileList = { }
for icon, _ in pairs(listDds) do
	table.insert(fileList, icon)
end
extractFromGgpk(fileList)

printf("Converting dds from sheets...")
fileList = { }
for convert, icons in pairs(convertList) do
	for icon, _ in pairs(icons) do
		table.insert(fileList, icon)
	end
	nvtt.CompressDDSIntoOtherFormat(main.ggpk.oozPath, basePath .. version .. "/", convert, fileList, convert, true)
	fileList = { }
end

printf("Generating sprite info...")
local sections = {}
for i, sheet in ipairs(sheets) do
	printf("Calculating sprite dimensions for " .. sheet.name)
	calculateSheetCoords(sheet, main.ggpk.oozPath, basePath .. version .. "/")

	printf("Generating sprite sheet images...")
	generateSprite(sheet, main.ggpk.oozPath, basePath .. version .. "/", generateAssets)

	printf("Generating sprite info for " .. sheet.name)
	-- now we are going to creeate sprites base on section and zoom level
	-- this is base on imageZoomLevels
	for j, group in ipairs(sheet.sprites) do
		local zoomLevel = tree.imageZoomLevels[j]
		for _, coords in pairs(group.coords) do
			local icon = coords.alias or coords.icon
			local sprite = {
				x = coords.x,
				y = coords.y,
				w = coords.w,
				h = coords.h,
			}

			-- validate with mipmap if w and h are different and use that spaced
			if coords.mipmap and coords.mipmap.width ~= sprite.w then
				sprite.w = coords.mipmap.width
			end

			if coords.mipmap and coords.mipmap.height ~= sprite.h then
				sprite.h = coords.mipmap.height
			end

			if sections[coords.section] == nil then
				sections[coords.section] = {}
			end
			if sections[coords.section][zoomLevel] == nil then
				sections[coords.section][zoomLevel] = {
					filename = group.filename,
					w = group.w,
					h = group.h,
					coords = { },
				}
			end

			sections[coords.section][zoomLevel].coords[icon] = sprite
			:: continue ::
		end
	end
end

tree.sprites = sections

printf("generate lines info into assets")
-- Generate sprites

for _, lines in ipairs(linesFiles) do
	for i = 0, lines.total - 1 do
		local name
		if i == 0 then
			name = lines.first .. lines.posfix
		else
			name = lines.prefix .. i .. lines.posfix
		end

		tree.assets[name] = {
			[lines.meta] = lines.basename .. i .. lines.extension
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
:: final ::