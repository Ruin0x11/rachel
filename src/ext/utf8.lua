if utf8 == nil then
	local ok
	ok, utf8 = pcall(require, "utf8")
	if not ok then
		-- require the luarocks version (starwing/utf8)
		local ok, result = pcall(require, "lua-utf8")
		if not ok then
			error("Please install luautf8 from luarocks.")
		end
		utf8 = result
		package.loaded["utf8"] = result
	end
end
