function table.shallow_copy(t)
	local rtn = {}
	for k, v in pairs(t) do
		rtn[k] = v
	end
	return rtn
end

function table.replace_with(tbl, other)
	if tbl == other then
		return tbl
	end

	local mt = getmetatable(tbl)
	local other_mt = getmetatable(other)
	if mt and other_mt then
		table.replace_with(mt, other_mt)
	end

	for k, _ in pairs(tbl) do
		tbl[k] = nil
	end

	for k, v in pairs(other) do
		tbl[k] = v
	end

	return tbl
end

-- Returns the keys of a dictionary-like table.
-- @tparam table tbl
-- @treturn list
function table.keys(tbl)
	local arr = {}
	for k, _ in pairs(tbl) do
		arr[#arr + 1] = k
	end
	return arr
end

function table.index_of(tbl, value)
	for i, v in ipairs(tbl) do
		if v == value then
			return i
		end
	end

	return nil
end

--- Removes a value from a list-like table.
---
--- @tparam table tbl
--- @tparam any value
--- @treturn[opt] any the removed value
function table.iremove_value(tbl, value)
	local result

	local ind
	for i, v in ipairs(tbl) do
		if v == value then
			ind = i
			break
		end
	end
	if ind then
		result = table.remove(tbl, ind)
	end

	return result
end
