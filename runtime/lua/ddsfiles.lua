local module = {}
local function getInt(file)
    -- Read a 4-byte integer from the file
    local bytes = file:read(4)
    local b1, b2, b3, b4 = bytes:byte(1, 4)
    return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function parseDDSHeader(file)
    -- Read and verify the DDS magic number
    if file:read(4) ~= "DDS " then
        error("Not a valid DDS file")
    end

    -- Skip to the height and width
    file:seek("set", 12) -- Skip magic + size field
    local height = getInt(file)
    local width = getInt(file)

    -- Skip to the mipmap count
    file:seek("set", 28)
    local mipmapCount = getInt(file)

    return width, height, mipmapCount
end

local function calculateMipmaps(baseWidth, baseHeight, mipmapCount)
    local mipmaps = {}
    local width, height = baseWidth, baseHeight

    for i = 0, mipmapCount - 1 do
        mipmaps[#mipmaps + 1] = {level = i, width = width, height = height}
        if width == 1 and height == 1 then break end
        width = math.max(1, math.floor(width / 2))
        height = math.max(1, math.floor(height / 2))
    end

    return mipmaps
end

local function findClosestMipmap(mipmaps, targetWidth, targetHeight)
    local closest = nil
    local minDiff = math.huge

    for _, mip in ipairs(mipmaps) do
        local diff = math.abs(mip.width - targetWidth) + math.abs(mip.height - targetHeight)
        if diff < minDiff then
            minDiff = diff
            closest = mip
        end
    end

    return closest
end

local cacheInfo = {}

function module.getMaxSize(filePath)
	if not cacheInfo[filePath] then
		local file = io.open(filePath, "rb")
		if not file then
			error("Cannot open file: " .. filePath)
		end

		-- Parse the DDS header
		local baseWidth, baseHeight, mipmapCount = parseDDSHeader(file)
		file:close()

		-- Calculate mipmaps
		cacheInfo[filePath] = calculateMipmaps(baseWidth, baseHeight, mipmapCount)
	end
	local mipmaps = cacheInfo[filePath]
	return mipmaps[1].width, mipmaps[1].height
end

function module.findClosestDDSMipmap(filePath, targetWidth, targetHeight)
	-- Check if the mipmaps have already been calculated	
	if not cacheInfo[filePath] then
		local file = io.open(filePath, "rb")
		if not file then
			error("Cannot open file: " .. filePath)
		end

		-- Parse the DDS header
		local baseWidth, baseHeight, mipmapCount = parseDDSHeader(file)
		file:close()

		-- Calculate mipmaps
		cacheInfo[filePath] = calculateMipmaps(baseWidth, baseHeight, mipmapCount)
	end

	local mipmaps = cacheInfo[filePath]
    -- Find the closest mipmap
    local closest = findClosestMipmap(mipmaps, targetWidth, targetHeight)

    return closest
end

return module