-- 对照完整标签与运行时拼接格式，证明漏译来自缺词还是匹配边界。
local Dictionary = dofile('Modules/Localisation/Dictionary.lua')
local output = assert(io.open('Tests/Run/localisation-matching-probes.csv', 'wb'))
output:write('language,source,translation\n')
for _, language in ipairs({ 'zh-CN', 'zh-TW' }) do
	local dictionary = Dictionary.New()
	dictionary:LoadFolder('Locales/' .. language)
	for _, source in ipairs({
		'Active Skill', 'Active Skill:', '^7Active Skill:^7', '^7Active Skill^7:',
		'Intelligence', 'intelligence', 'INTELLIGENCE', 'Fire', 'FIRE',
		'Spell', 'Projectile', 'Spell, Projectile', 'Spell, Projectile, Fire',
		'Tier', 'Tier: 2', 'Cooldown Time', 'Cooldown Time: 1.00 sec', 'Both',
	}) do
		local values = { language, source, dictionary:Translate(source) }
		for i, value in ipairs(values) do values[i] = '"' .. value:gsub('"', '""') .. '"' end
		output:write(table.concat(values, ',') .. '\n')
	end
end
output:close()
print('标签格式对照探针完成：36 条')
