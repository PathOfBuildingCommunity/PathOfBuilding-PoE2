-- 精确输入别名必须按业务域隔离，跨语言冲突也不能取决于当前显示语言或遍历顺序。
return function(equal)
	local NameInputs = dofile('Modules/Localisation/NameInputs.lua')
	local objects = { first = { nameKey = 'first' }, duplicate = { nameKey = 'same' }, second = { nameKey = 'second' }, unknown = { } }
	local catalogs = {
		en = { first = { text = 'First' }, same = { text = 'First' }, second = { text = 'Second' } },
		['zh-CN'] = { first = { text = '简体一' }, same = { text = '同名' }, second = { text = '同名' } },
		['zh-TW'] = { first = { text = '繁體一' }, second = { text = '简体一' } },
	}
	local names = NameInputs.New(objects, catalogs)
	equal(names:Resolve('First'), 'First', '英文身份保持原文')
	equal(names:Resolve('繁體一'), 'First', '精确繁体译名可转换')
	local text, status = names:Resolve('同名')
	equal(text, '同名', '同语言同名冲突保持原文')
	equal(status, 'ambiguous', '同语言同名冲突可诊断')
	text, status = names:Resolve('简体一')
	equal(text, '简体一', '跨语言同名冲突保持原文')
	equal(status, 'ambiguous', '跨语言冲突不随当前语言改变')
	text, status = names:Resolve('未登记名字')
	equal(text, '未登记名字', '未知名称保持原文')
	equal(status, nil, '未知名称允许既有输入词典继续处理')
	local duplicates = NameInputs.New({ { nameKey = 'first' }, { nameKey = 'same' } }, {
		en = catalogs.en, ['zh-CN'] = { first = { text = '同名' }, same = { text = '同名' } },
	})
	text, status = duplicates:Resolve('同名')
	equal(text, 'First', '多个对象的同一英文名称不构成译名歧义')
	equal(status, 'resolved', '无歧义别名明确报告解析成功')
end
