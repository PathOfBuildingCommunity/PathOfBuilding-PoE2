-- 语言资源共用的 CSV 解析器，保留引号内换行、逗号和双引号。
local CSV = { }

--- <summary>逐行读取 UTF-8 CSV，并把字段数组交给调用者。</summary>
function CSV.Read(text, callback)
	text = text:gsub("^\239\187\191", "")
	local row, field, pos = { }, { }, 1
	local quoted = false
	while pos <= #text do
		local nextPos = text:find(quoted and '"' or '[,\r\n"]', pos)
		if not nextPos then field[#field + 1] = text:sub(pos); break end
		field[#field + 1] = text:sub(pos, nextPos - 1)
		local char = text:sub(nextPos, nextPos)
		pos = nextPos + 1
		if char == '"' then
			if quoted and text:sub(pos, pos) == '"' then
				field[#field + 1] = '"'; pos = pos + 1
			else quoted = not quoted end
		elseif not quoted then
			row[#row + 1] = table.concat(field); field = { }
			if char ~= ',' then
				if char == '\r' and text:sub(pos, pos) == '\n' then pos = pos + 1 end
				callback(row); row = { }
			end
		end
	end
	assert(not quoted, "CSV 引号未闭合")
	if #field > 0 or #row > 0 then row[#row + 1] = table.concat(field); callback(row) end
end

return CSV
