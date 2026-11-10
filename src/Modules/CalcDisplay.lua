-- 计算页列表的显示适配；原始计算输出与效果名称始终保持原值。
local CalcDisplay = { }
CalcDisplay.__index = CalcDisplay

local effectKeys = {
	['Power Charges'] = 'term.calculation_modifier.power_charges',
	['Frenzy Charges'] = 'term.calculation_modifier.frenzy_charges',
	['Endurance Charges'] = 'term.calculation_modifier.endurance_charges',
	['Absorption Charges'] = 'calcs.effect.absorption_charges',
	['Affliction Charges'] = 'calcs.effect.affliction_charges',
	['Brutal Charges'] = 'calcs.effect.brutal_charges',
	['Siphoning Charges'] = 'calcs.effect.siphoning_charges',
	['Challenger Charges'] = 'calcs.effect.challenger_charges',
	['Blitz Charges'] = 'calcs.effect.blitz_charges',
	['Inspiration Charges'] = 'calcs.effect.inspiration_charges',
	['Ghost Shrouds'] = 'calcs.effect.ghost_shrouds',
	['Crab Barriers'] = 'calcs.effect.crab_barriers',
	['Blood Charges'] = 'calcs.effect.blood_charges',
	['Spirit Charges'] = 'calcs.effect.spirit_charges',
	['Cruelty'] = 'calcs.effect.cruelty',
	['Fortify'] = 'calcs.effect.fortify',
	['Onslaught'] = 'calcs.effect.onslaught',
	['Unholy Might'] = 'calcs.effect.unholy_might',
	['Chaotic Might'] = 'calcs.effect.chaotic_might',
	['Tailwind'] = 'calcs.effect.tailwind',
	['Adrenaline'] = 'calcs.effect.adrenaline',
	["Alchemist's Genius"] = 'calcs.effect.alchemists_genius',
	['Her Embrace'] = 'calcs.effect.her_embrace',
	['Lesser Massive Shrine'] = 'calcs.effect.lesser_massive_shrine',
	['Lesser Brutal Shrine'] = 'calcs.effect.lesser_brutal_shrine',
	['Diamond Shrine'] = 'calcs.effect.diamond_shrine',
	['Massive Shrine'] = 'calcs.effect.massive_shrine',
	['Wither'] = 'calcs.effect.wither',
	['Rage'] = 'term.calculation_modifier.rage',
	['ArmourBreak'] = 'calcs.effect.armour_break',
	['Withered'] = 'calcs.effect.wither',
}

--- <summary>按已登记技能身份建立显示索引，缓存引用而非当前语言文本。</summary>
function CalcDisplay.New(skills)
	local names = { }
	for _, skill in pairs(skills) do
		if skill.nameKey then names[skill.name] = skill end
	end
	-- 能量球调节的全局增益仍使用旧效果名，与技能本身共享显示引用。
	names['Charge Infusion'] = skills.ChargeRegulationPlayer
	names['EternalRage'] = skills.EternalRagePlayer
	return setmetatable({ names = names }, CalcDisplay)
end

-- 只翻译已识别的技能或效果，未知用户名称保留原样。
local function effectName(self, name)
	if self.names[name] then return localisation:Field(self.names[name], 'name') end
	return effectKeys[name] and localisation:Text(effectKeys[name]) or name
end

--- <summary>显示光环、战斗增益和减益列表，保留原顺序、层数与计算输出。</summary>
function CalcDisplay:EffectList(actor, field)
	local raw = actor and actor.output[field] or ''
	if localisation.language == 'en' then return raw end
	local entries = { }
	for entry in raw:gmatch('[^,]+') do
		entry = entry:match('^%s*(.-)%s*$')
		local count, name = entry:match('^(%d+) (.+)$')
		if count and effectKeys[name] then
			entries[#entries + 1] = localisation:Text('calcs.effect.counted', { count = count, effect = effectName(self, name) })
		else
			local name, stacks = entry:match('^(.-) %((%d+) stacks?%)$')
			entries[#entries + 1] = name and (self.names[name] or effectKeys[name]) and localisation:Text('calcs.effect.stacked', { effect = effectName(self, name), count = stacks }) or effectName(self, entry)
		end
	end
	return table.concat(entries, ', ')
end

return CalcDisplay
