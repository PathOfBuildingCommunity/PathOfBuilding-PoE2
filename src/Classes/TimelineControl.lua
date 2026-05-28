-- Path of Building
--
-- Class: Timeline Control
-- Passive-tree progression scrubber; scrubbing really re-allocates nodes.
-- Scrub buttons are sibling controls on TreeTab.
--
local t_insert = table.insert
local m_min = math.min
local m_max = math.max
local m_floor = math.floor
local m_ceil = math.ceil

-- 0/1 regular point + weapon-set bucket for a node (ascendancy = no point)
local function pointBucket(node)
	if not node or node.ascendancyName then return 0, 0, 0 end
	return 1, node.allocMode == 1 and 1 or 0, node.allocMode == 2 and 1 or 0
end

-- Must track buildMode:EstimatePlayerProgress
local function levelFromCounts(build, reg, ws1, ws2, extra)
	return build:EstimateLevelForPoints(reg - extra - m_min(ws1, ws2))
end

-- node -> category for colouring / notable-jump
local function nodeCategory(node)
	if not node then return "minor" end
	if node.ascendancyName then return "ascend" end
	if node.type == "Keystone" then return "keystone" end
	if node.type == "Notable" then return "notable" end
	if node.allocMode and node.allocMode ~= 0 then return "weapon" end
	return "minor"
end

-- category -> display (colour, text code, label); one row each so none half-added
local catDef = {
	minor    = { rgb = { 0.70, 0.70, 0.70 }, code = "^xB0B0B0", label = "Minor" },
	weapon   = { rgb = { 1, 0.55, 0.15 },    code = "^xFF8C26", label = "Weapon-set" },
	notable  = { rgb = { 0.45, 0.55, 1 },    code = "^x7088FF", label = "Notable" },
	keystone = { rgb = { 1, 0.85, 0.2 },     code = "^xFFD933", label = "Keystone" },
	ascend   = { rgb = { 0.30, 0.85, 0.35 }, code = "^x4CD959", label = "Ascendancy" },
	respec   = { rgb = { 0.90, 0.20, 0.20 }, code = "^xE53333", label = "Respec" },
}
-- Safe lookup: Draw runs every frame
local function catOf(c)
	return catDef[c] or catDef.minor
end

local TimelineControlClass = newClass("TimelineControl", "Control", "TooltipHost", function(self, anchor, rect, treeTab)
	self.Control(anchor, rect)
	self.TooltipHost()
	self.treeTab = treeTab
	self.build = treeTab.build
	self.hoverStage = nil
	self.tooltipFunc = function(tooltip, stageIndex)
		self:StageTooltip(tooltip, stageIndex)
	end
end)

function TimelineControlClass:GetProg()
	local spec = self.build.spec
	if spec then
		local timeline = spec:Progression()
		if timeline:IsEnabled() then
			return spec, timeline.data, timeline
		end
	end
end

-- Character level at stage k; matches buildMode:EstimatePlayerProgress
function TimelineControlClass:LevelAt(spec, k)
	local count, ws1, ws2 = 0, 0, 0
	for id in pairs(spec:Progression():StateAt(k)) do
		local r, w1, w2 = pointBucket(spec.nodes[id])
		count, ws1, ws2 = count + r, ws1 + w1, ws2 + w2
	end
	local extra = self.build.calcsTab and self.build.calcsTab.mainOutput
		and self.build.calcsTab.mainOutput.ExtraPoints or 0
	return levelFromCounts(self.build, count, ws1, ws2, extra)
end

function TimelineControlClass:StageCategory(spec, stage)
	if stage.kind == "respec" then return "respec" end
	return nodeCategory(spec.nodes[stage.alloc[1]])
end

function TimelineControlClass:StageNode(spec, stage)
	return stage.alloc[1] and spec.nodes[stage.alloc[1]] or nil
end

function TimelineControlClass:StageTooltip(tooltip, stageIndex)
	tooltip:Clear()
	local spec, prog = self:GetProg()
	if not prog then return end
	local stage = prog.stages[stageIndex]
	if not stage then return end
	local lvl = (self._frameLevels and self._frameLevels[stageIndex]) or self:LevelAt(spec, stageIndex)
	if stage.kind == "respec" then
		tooltip:AddLine(16, catDef.respec.code.."Respec  -  entry "..stageIndex)
		tooltip:AddSeparator(6)
		tooltip:AddLine(14, "^7Refunds "..#stage.dealloc..", adds "..#stage.alloc)
		tooltip:AddLine(14, "^7~ Level "..lvl)
	else
		local node = self:StageNode(spec, stage)
		local cat = self:StageCategory(spec, stage)
		tooltip:AddLine(16, catOf(cat).code..(node and node.dn or "?"))
		tooltip:AddSeparator(6)
		tooltip:AddLine(14, catOf(cat).code..catOf(cat).label.."^7   ~ Level "..lvl)
		if node and node.allocMode and node.allocMode ~= 0 then
			tooltip:AddLine(14, catDef.weapon.code.."Weapon Set "..node.allocMode)
		end
		tooltip:AddLine(13, "^7Entry "..stageIndex.." / "..#prog.stages)
	end
end

-- Apply a scrub to index i (0 = nothing taken, #stages = final tree)
function TimelineControlClass:ScrubTo(i)
	local _, prog, tl = self:GetProg()
	if not prog then return end
	-- ScrubToStage closes any open respec block itself.
	local n = #prog.stages
	i = m_max(0, m_min(i, n))
	-- Returning to live ends edit-history mode (user-facing seam; the capture dance re-scrubs
	-- via tl:ScrubToStage directly and is unaffected)
	if i >= n then prog.editHistory = false end
	tl:ScrubToStage(i >= n and nil or i)
end

-- End a drag: apply the deferred target, clear state
function TimelineControlClass:CommitDrag()
	local _, prog = self:GetProg()
	if prog and self.pendingScrub and self.pendingScrub ~= self:CursorIndex(prog) then
		self:ScrubTo(self.pendingScrub)
	end
	self.dragging = false
	self.pendingScrub = nil
end

function TimelineControlClass:CursorIndex(prog)
	return prog.scrubStage or #prog.stages
end

function TimelineControlClass:ScrubStep(dir)
	local _, prog = self:GetProg()
	if not prog then return end
	self:ScrubTo(self:CursorIndex(prog) + dir)
end

function TimelineControlClass:StepNotable(dir)
	local spec, prog = self:GetProg()
	if not prog then return end
	local n = #prog.stages
	local i = self:CursorIndex(prog)
	repeat
		i = i + dir
		if i <= 0 or i >= n then break end
	until self:StageCategory(spec, prog.stages[i]) ~= "minor"
	self:ScrubTo(i)
end

function TimelineControlClass:IsMouseOver()
	return self:IsShown() and self:IsMouseInBounds()
end

-- Track geometry; ty is the bar baseline (markers above, level labels below)
function TimelineControlClass:TrackGeom()
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local tx = x + 12
	local tw = width - 24
	local ty = y + height - 22
	return tx, ty, tw
end

function TimelineControlClass:StageAtX(cx)
	local _, prog = self:GetProg()
	if not prog or #prog.stages == 0 then return nil end
	local tx, _, tw = self:TrackGeom()
	local n = #prog.stages
	local f = m_max(0, m_min((cx - tx) / tw, 1))
	-- ceil: cursor is in cell i when f in ((i-1)/n, i/n]
	return m_max(1, m_min(m_ceil(f * n), n))
end

function TimelineControlClass:Draw(viewPort)
	local x, y = self:GetPos()
	local width, height = self:GetSize()
	local spec, prog = self:GetProg()

	SetDrawLayer(nil, 0)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, x, y, width, height)
	SetDrawColor(0.05, 0.05, 0.05)
	DrawImage(nil, x + 1, y + 1, width - 2, height - 2)

	if not prog then
		SetDrawColor(1, 1, 1)
		DrawString(x + 8, y + 6, "LEFT", 14, "VAR", "^7No passive progression for this tree.")
		return
	end

	local n = #prog.stages
	local curIdx = self:CursorIndex(prog)
	-- While dragging the bar tracks the target; real re-alloc catches up on settle/mouse-up
	local viewIdx = (self.dragging and self.pendingScrub) or curIdx
	local cx = select(1, GetCursorPos())
	local hover = self:IsMouseInBounds() and self:StageAtX(cx) or nil
	self.hoverStage = hover
	local infoIdx = m_max(1, m_min(hover or curIdx, m_max(1, n)))

	-- One pass building per-stage cat/level/L10; readout, bar, tooltip all reuse these
	local cats, levels, grid = { }, { }, { }
	if n > 0 then
		local extra = self.build.calcsTab and self.build.calcsTab.mainOutput
			and self.build.calcsTab.mainOutput.ExtraPoints or 0
		local present, reg, ws1, ws2 = { }, 0, 0, 0
		local function addId(id, sign)
			local r, w1, w2 = pointBucket(spec.nodes[id])
			reg = reg + r * sign
			ws1 = ws1 + w1 * sign
			ws2 = ws2 + w2 * sign
		end
		local lastBucket = 0
		for i = 1, n do
			local stage = prog.stages[i]
			for _, id in ipairs(stage.alloc) do if not present[id] then present[id] = true addId(id, 1) end end
			for _, id in ipairs(stage.dealloc) do if present[id] then present[id] = nil addId(id, -1) end end
			levels[i] = levelFromCounts(self.build, reg, ws1, ws2, extra)
			cats[i] = self:StageCategory(spec, stage)
			local bucket = m_floor(levels[i] / 10)
			if bucket > lastBucket then
				lastBucket = bucket
				t_insert(grid, { i = i, label = "L" .. (bucket * 10) })
			end
		end
	end
	self._frameLevels = n > 0 and levels or nil

	local readout
	if n == 0 then
		readout = "^7Allocate nodes to build the passive progression"
	else
		local stage = prog.stages[infoIdx]
		local cat, lvl = cats[infoIdx], levels[infoIdx]
		if stage.kind == "respec" then
			readout = string.format("^7Entry %d / %d   %s[Respec]^7   refund %d / add %d   ~ Lvl %d",
				infoIdx, n, catDef.respec.code, #stage.dealloc, #stage.alloc, lvl)
		else
			local node = self:StageNode(spec, stage)
			local ws = (node and node.allocMode and node.allocMode ~= 0) and ("  "..catDef.weapon.code.."[WS"..node.allocMode.."]") or ""
			readout = string.format("^7Point %d / %d   %s%s ^7- %s%s%s   ^7~ Lvl %d",
				infoIdx, n, catOf(cat).code, node and node.dn or "?",
				catOf(cat).code, catOf(cat).label, ws, lvl)
		end
	end
	if prog.respecOpen then
		readout = readout .. "    ^xDD4444recording respec"
	elseif prog.scrubStage ~= nil then
		readout = readout .. (prog.editHistory
			and "    ^x33AAFF(editing history - new points insert here)"
			or  "    ^x33AAFF(scrubbed - new points replace from here)")
	end
	SetDrawColor(1, 1, 1)
	DrawString(x + 12, y + 5, "LEFT", 16, "VAR", readout)

	do
		local order = { "minor", "notable", "keystone", "ascend", "weapon", "respec" }
		local lx = x + width - 10
		for j = #order, 1, -1 do
			local c = order[j]
			lx = lx - DrawStringWidth(12, "VAR", catOf(c).label)
			SetDrawColor(1, 1, 1)
			DrawString(lx, y + 7, "LEFT", 12, "VAR", "^7"..catOf(c).label)
			lx = lx - 8
			local rgb = catOf(c).rgb
			SetDrawColor(rgb[1], rgb[2], rgb[3])
			DrawImage(nil, lx, y + 8, 7, 9)
			lx = lx - 14
		end
	end

	-- progress bar: one cell per node
	local tx, ty, tw = self:TrackGeom()
	local barTop = ty - 20
	local barH = ty - barTop
	SetDrawColor(0.13, 0.13, 0.13)
	DrawImage(nil, tx, barTop, tw, barH)
	if n > 0 then
		for i = 1, n do
			local x0 = m_floor(tx + tw * (i - 1) / n + 0.5)
			local x1 = m_floor(tx + tw * i / n + 0.5)
			local w = m_max(1, x1 - x0)
			local rgb = catOf(cats[i]).rgb
			local dim = (i > viewIdx) and 0.38 or 1
			SetDrawColor(rgb[1] * dim, rgb[2] * dim, rgb[3] * dim)
			DrawImage(nil, x0, barTop, w, barH)
			SetDrawColor(0, 0, 0)
			DrawImage(nil, x1 - 1, barTop, 1, barH)
			if cats[i] == "respec" and w >= 8 then
				SetDrawColor(1, 1, 1)
				DrawString(x0 + w / 2, barTop + barH / 2 - 6, "CENTER", 11, "VAR", "^7R")
			end
		end
		for _, g in ipairs(grid) do
			local gx = m_floor(tx + tw * (g.i - 1) / n + 0.5)
			SetDrawColor(1, 1, 1)
			DrawImage(nil, gx, barTop, 1, barH)
			DrawString(gx + 2, ty + 4, "LEFT", 11, "VAR", "^8" .. g.label)
		end
		if hover then
			local hx0 = m_floor(tx + tw * (hover - 1) / n + 0.5)
			local hx1 = m_floor(tx + tw * hover / n + 0.5)
			SetDrawColor(0.6, 0.85, 1)
			DrawImage(nil, hx0, barTop - 2, m_max(1, hx1 - hx0), 2)
			DrawImage(nil, hx0, ty, m_max(1, hx1 - hx0), 2)
		end
		local kx = m_floor(tx + tw * viewIdx / n + 0.5)
		SetDrawColor(1, 1, 1)
		DrawImage(nil, kx - 1, barTop - 4, 3, barH + 8)
		main:DrawArrow(kx, barTop - 5, 9, 6, "DOWN")
	end

	if self.dragging and IsKeyDown("LEFTBUTTON") then
		local seg = self:StageAtX(select(1, GetCursorPos()))
		if seg then
			if seg == self.pendingScrub then
				-- settled: do the real re-allocation
				if seg ~= curIdx then self:ScrubTo(seg) end
			else
				-- still moving: defer the recompute
				self.pendingScrub = seg
			end
		end
	elseif self.dragging then
		self:CommitDrag()
	end

	if hover then
		-- anchor tooltip at cursor column so it flips above the bottom bar
		local cuX = select(1, GetCursorPos())
		SetDrawLayer(nil, 100)
		self:DrawTooltip(cuX, y, 8, height, viewPort, hover)
		SetDrawLayer(nil, 0)
	end
end

function TimelineControlClass:OnKeyDown(key)
	if not self:IsShown() or not self:IsEnabled() then return end
	if key == "LEFTBUTTON" then
		-- Not over the track: release focus for the sibling buttons
		if not self:IsMouseInBounds() then
			self.dragging = false
			return
		end
		local seg = self:StageAtX(select(1, GetCursorPos()))
		if seg then
			self.dragging = true
			self.pendingScrub = seg
			self:ScrubTo(seg)
		end
	end
	return self
end

function TimelineControlClass:OnKeyUp(key)
	if not self:IsShown() or not self:IsEnabled() then return end
	if key == "LEFTBUTTON" then
		-- Release focus on button-up; apply the final dragged position
		self:CommitDrag()
		return
	elseif self:IsMouseInBounds() and (key == "WHEELUP" or key == "RIGHT") then
		self:ScrubStep(1)
	elseif self:IsMouseInBounds() and (key == "WHEELDOWN" or key == "LEFT") then
		self:ScrubStep(-1)
	else
		return
	end
	return self
end
