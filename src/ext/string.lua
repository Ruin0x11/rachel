function string.split(s, re)
	local i1, ls = 1, {}
	if not re then
		re = "%s+"
	end
	if re == "" then
		return { s }
	end
	while true do
		local i2, i3 = s:find(re, i1)
		if not i2 then
			local last = s:sub(i1)
			if last ~= "" then
				ls[#ls + 1] = last
			end
			if #ls == 1 and ls[1] == "" then
				return {}
			else
				return ls
			end
		end
		ls[#ls + 1] = s:sub(i1, i2 - 1)
		i1 = i3 + 1
	end
end

function string.escape_for_gsub(s)
	return string.gsub(s, "([^%w])", "%%%1")
end

function string.escape_magic(s)
	return s:gsub("([%(%)%.%%%+%-%*%?%[%^%$%]])", "%%%1")
end

function string.has_prefix(s, prefix)
	return string.find(s, "^" .. string.escape_for_gsub(prefix))
end

function string.has_suffix(s, suffix)
	return string.find(s, string.escape_for_gsub(suffix) .. "$")
end

function string.strip_prefix(s, prefix)
	return string.gsub(s, "^" .. string.escape_for_gsub(prefix), "")
end

function string.strip_suffix(s, suffix)
	return string.gsub(s, string.escape_for_gsub(suffix) .. "$", "")
end

function string.strip_whitespace(s)
	local from = s:match("^%s*()")
	return from > #s and "" or s:match(".*%S", from)
end

function string.left_pad(s, length, pad)
	local res = string.rep(pad or " ", length - #s) .. s
	return res, res ~= s
end

function string.right_pad(s, length, pad)
	local res = s .. string.rep(pad or " ", length - #s)
	return res, res ~= s
end

function string.trim(str, chars)
	if not chars then
		return str:match("^[%s]*(.-)[%s]*$")
	end
	chars = string.escape_magic(chars)
	return str:match("^[" .. chars .. "]*(.-)[" .. chars .. "]*$")
end
