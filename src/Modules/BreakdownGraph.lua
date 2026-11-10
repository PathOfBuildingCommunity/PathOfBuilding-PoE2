local M = {}

local m_max = math.max
local m_min = math.min
local m_log10 = math.log10
local m_floor = math.floor
local s_format = string.format
local t_insert = table.insert

local function armourFunc(graphData, hit)
	local armourDR =  m_min(graphData.baseDR / 100 + graphData.armour / (graphData.armour + 10 * hit), graphData.maxDR / 100)
	return m_max(armourDR - graphData.overwhelm / 100, 0)
end
local maxEvasion = data.misc.EvadeChanceCap / 100
local function evasionFunc(graphData, accuracy)
	local uncappedEvasion = (1 - (0.95 * graphData.evasion) / (graphData.evasion + 4 * accuracy))
	return 1 - m_min(maxEvasion, m_max(0.05, uncappedEvasion))
end
local maxDeflection = data.misc.DeflectionChanceCap / 100
local function deflectionFunc(graphData, accuracy)
	local penChance = accuracy / (accuracy + graphData.deflection * 0.12)
	local uncappedDeflection = (1 -
		penChance) * 1.5
	return m_min(maxDeflection, uncappedDeflection)
end

local function xToFrac(x, xMin, xMax, log)
	if log then
		local lo, hi = m_log10(xMin), m_log10(xMax)
		return (m_log10(m_max(x, 1e-6)) - lo) / (hi - lo)
	end
	return (x - xMin) / (xMax - xMin)
end

local function fracToX(frac, xMin, xMax, log)
	if log then
		local lo, hi = m_log10(xMin), m_log10(xMax)
		return 10 ^ (lo + frac * (hi - lo))
	end
	return xMin + frac * (xMax - xMin)
end

local function formatLabel(n)
	if n >= 1000000 then
		return s_format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return s_format("%.1fk", n / 1000)
	else
		return s_format("%d", n)
	end
end

local function drawDashedLine(x, yStart, yEnd)
	local dashPxLength = 3
	local spacingPxLength = 4
	local y = yStart
	while y < yEnd do
		DrawImage(nil, x, y, 1, dashPxLength)
		y += dashPxLength + spacingPxLength
	end
end

local tooltip = new("Tooltip"):Tooltip()

local graphConfigs = {
	armour = {
		yCapForStat = |gd| -> gd.maxDR / 100,
		func = armourFunc,
		xLabel = |v| -> string.format("Hit: %d", v),
		yLabel = |v| -> string.format("DR: %d%%", v * 100),
		xLog = true,
		xMax = |gd| -> gd.maxHit * 4,
		xMin = |gd| -> gd.configHit / 10,
	},
	deflection = {
		yCapForStat = |_| -> maxDeflection,
		func = deflectionFunc,
		xLabel = |v| -> string.format("Enemy Accuracy: %d", v),
		yLabel = |v| -> string.format("Def. Chance: %d%%", v * 100),
		xMax = |gd| -> gd.configAccuracy * 3,
		xMin = |gd| -> gd.configAccuracy / 10,
	},
	evasion = {
		yCapForStat = |_| -> maxEvasion,
		func = evasionFunc,
		xLabel = |v| -> string.format("Enemy Accuracy: %d", v),
		yLabel = |v| -> string.format("Dodge Chance: %d%%", v * 100),
		xMax = |gd| -> gd.configAccuracy * 3,
		xMin = |gd| -> gd.configAccuracy / 10,
	}
}
---@param sectionX number
---@param sectionY number
---@param sectionWidth number
---@param sectionHeight number
---@param graphData ArmourGraphData|EvasionGraphData|DeflectionGraphData
function M.DrawGraph(sectionX, sectionY, sectionWidth, sectionHeight, graphData)
	local config
	if graphData.armour then
		config = graphConfigs.armour
	elseif graphData.deflection then
		config = graphConfigs.deflection
	elseif graphData.evasion then
		config = graphConfigs.evasion
	end
	-- value used for max y label
	local yCapForStat = config.yCapForStat(graphData)
	local yTickText = string.format("%d%%", yCapForStat * 100)

	local yLabelWidth = DrawStringWidth(16, "VAR", yTickText)
	local graphLeftPad, graphRightPad = 8 + yLabelWidth, 10
	local graphTopPad, graphBottomPad = 6, 40
	local graphX, graphY = sectionX + graphLeftPad, sectionY + graphTopPad
	local graphWidth, graphHeight = sectionWidth - (graphLeftPad + graphRightPad), sectionHeight - (graphTopPad + graphBottomPad)
	-- draw background
	SetDrawColor(1, 1, 1)
	DrawImage(nil, graphX - 1, graphY - 1, graphWidth + 2, graphHeight + 2)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, graphX, graphY, graphWidth, graphHeight)
	local xMin = config.xMin(graphData)
	local xMax = config.xMax(graphData)
	local log = config.xLog
	local samples = {}
	for i = 0, graphWidth do
		samples[i] = config.func(graphData, fracToX(i / graphWidth, xMin, xMax, log))
	end

	local bottomY = sectionY + graphTopPad + graphHeight
	local subSamples = 4
	for i = 1, #samples do
		local pointX = graphX + i - 1
		local yLeft, yRight = bottomY - samples[i - 1] * graphHeight, bottomY - samples[i] * graphHeight
		-- since the shape at this point is actually a slope, this is the top and bottom y of the top edge of the slope
		local top = m_max(m_floor(m_min(yLeft, yRight)), graphY)
		local bottom = m_min(m_floor(m_max(yLeft, yRight)), bottomY - 1)
		-- draw a fully solid 1 x h bar
		SetDrawColor(0.5, 0.5, 0.5)
		DrawImage(nil, pointX, bottom + 1, 1, bottomY - bottom - 1)
		-- draw 1 x 1 pixels to anti-alias the top edge
		for row = top, bottom do
			local alpha = 0
			for s = 1, subSamples do
				-- interpolate between the left and right y value
				local y = yLeft + (yRight - yLeft) * (s - 0.5) / subSamples
				-- test how much is actually covered vertically here
				alpha += m_min(m_max(row + 1 - y, 0), 1)
			end
			SetDrawColor(0.5, 0.5, 0.5, alpha / subSamples)
			DrawImage(nil, pointX, row, 1, 1)
		end
	end

	SetDrawColor(1, 1, 1)
	local textSize = 16
	local textY = bottomY + 2

	-- min x
	DrawString(graphX + 1, textY, nil, textSize, "VAR", formatLabel(xMin))
	if graphData.armour then
		-- hit x
		DrawString(xToFrac(graphData.configHit, xMin, xMax, true) * graphWidth + graphX, textY, "CENTER_X", textSize, "VAR", formatLabel(graphData.configHit) .. "\nEnemy Hit")
		-- max hit x
		DrawString(xToFrac(graphData.maxHit, xMin, xMax, true) * graphWidth + graphX, textY, "CENTER_X", textSize, "VAR", formatLabel(graphData.maxHit) .. "\nMax Hit")
		-- dashed line hit x
		drawDashedLine(xToFrac(graphData.configHit, xMin, xMax, true) * graphWidth + graphX, graphY, graphY + graphHeight)
		-- dashed line max hit x
		drawDashedLine(xToFrac(graphData.maxHit, xMin, xMax, true) * graphWidth + graphX, graphY, graphY + graphHeight)
	elseif graphData.evasion or graphData.deflection then
		-- configured enemy accuracy label and dashed line
		DrawString(xToFrac(graphData.configAccuracy, xMin, xMax) * graphWidth + graphX, textY, "CENTER_X", textSize, "VAR", formatLabel(graphData.configAccuracy) .. "\nEnemy Accuracy")
		drawDashedLine(xToFrac(graphData.configAccuracy, xMin, xMax) * graphWidth + graphX, graphY, graphY + graphHeight)
	end
	-- max x
	DrawString(sectionX + sectionWidth - 8, textY, "RIGHT_X", textSize, "VAR", formatLabel(xMax))

	-- max y tick and label
	local yTickPos = (1 - yCapForStat) * graphHeight + graphY
	DrawImage(nil, graphX - 3, yTickPos, 5, 1)
	DrawString(graphX - 3, yTickPos - 8, "RIGHT_X", 16, "VAR", yTickText)

	-- zero y label
	DrawString(graphX - 3, graphY + graphHeight - 8, "RIGHT_X", 16, "VAR", "0%")

	local cursorX, cursorY = GetCursorPos()

	-- draw hover tooltip which shows exact value
	if graphX <= cursorX and cursorX <= (graphX + graphWidth) and graphY <= cursorY and cursorY <= (graphY + graphHeight) then
		local xPx = (cursorX - graphX) - 1
		local x = fracToX(xPx / graphWidth, xMin, xMax, log)
		local y = samples[xPx]
		if y then
			local ttTextSize = 16
			tooltip:Clear()
			tooltip:AddLine(ttTextSize, config.xLabel(x))
			tooltip:AddLine(ttTextSize, config.yLabel(y))

			-- draw tooltip to the top right of the point on the line
			local w, h = GetScreenSize()
			local lineX = graphX + xPx
			local _, ttHeight = tooltip:GetSize()
			local lineY = bottomY - y * graphHeight
			-- this gets around the breakdown cell borders drawing on top of the graph
			SetDrawLayer(nil, 11)
			tooltip:Draw(lineX + 6, lineY - ttHeight + 3, nil, nil, { width = w, height = h, x = 0, y = 0 })
			SetDrawLayer(nil, 10)

			-- a dot (actually a small square) on the line
			SetDrawColor(1, 1, 1)
			DrawImage(nil, lineX, lineY - 1, 3, 3)
		end
	end
end

return M
