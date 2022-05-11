local wx = require("wx")
local wxstc = require("wxstc")

local util = {}

function util.is_valid_property(ctrl, prop)
	-- some control may return `nil` values for non-existing properties, so check for that
	return pcall(function()
		return ctrl[prop]
	end) and ctrl[prop] ~= nil
end

function util.create_font(size, family, style, weight, underline, name, encoding)
	local font = wx.wxFont(size, family, style, weight, underline, "", encoding)
	if name > "" then
		-- assign the face name separately to detect when it fails to load the font
		font:SetFaceName(name)
		if util.is_valid_property(font, "IsOk") and not font:IsOk() then
			-- assign default font from the same family if the exact font is not loaded
			font = wx.wxFont(size, family, style, weight, underline, "", encoding)
		end
	end
	return font
end

util.ANYMARKERMASK = 2 ^ 24 - 1
util.MAXMARGIN = wxstc.wxSTC_MAX_MARGIN or 4

function util.fix_utf8(s, repl)
	local p, len, invalid = 1, #s, {}
	while p <= len do
		if s:find("^[%z\1-\127]", p) then
			p = p + 1
		elseif s:find("^[\194-\223][\128-\191]", p) then
			p = p + 2
		elseif
			s:find("^\224[\160-\191][\128-\191]", p)
			or s:find("^[\225-\236][\128-\191][\128-\191]", p)
			or s:find("^\237[\128-\159][\128-\191]", p)
			or s:find("^[\238-\239][\128-\191][\128-\191]", p)
		then
			p = p + 3
		elseif
			s:find("^\240[\144-\191][\128-\191][\128-\191]", p)
			or s:find("^[\241-\243][\128-\191][\128-\191][\128-\191]", p)
			or s:find("^\244[\128-\143][\128-\191][\128-\191]", p)
		then
			p = p + 4
		else
			if not repl then
				return
			end -- just signal invalid UTF8 string
			local repl = type(repl) == "function" and repl(s:sub(p, p)) or repl
			s = s:sub(1, p - 1) .. repl .. s:sub(p + 1)
			table.insert(invalid, p)
			-- adjust position/length as the replacement may be longer than one char
			p = p + #repl
			len = len + #repl - 1
		end
	end
	return s, invalid
end

function util.get_project()
	return "."
end

local version_mt = {
	--- Equality comparison for versions.
	-- All version numbers must be equal.
	-- If both versions have revision numbers, they must be equal;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if they are considered equivalent.
	__eq = function(v1, v2)
		if #v1 ~= #v2 then
			return false
		end
		for i = 1, #v1 do
			if v1[i] ~= v2[i] then
				return false
			end
		end
		if v1.revision and v2.revision then
			return (v1.revision == v2.revision)
		end
		return true
	end,
	--- Size comparison for versions.
	-- All version numbers are compared.
	-- If both versions have revision numbers, they are compared;
	-- otherwise the revision number is ignored.
	-- @param v1 table: version table to compare.
	-- @param v2 table: version table to compare.
	-- @return boolean: true if v1 is considered lower than v2.
	__lt = function(v1, v2)
		for i = 1, math.max(#v1, #v2) do
			local v1i, v2i = v1[i] or 0, v2[i] or 0
			if v1i ~= v2i then
				return (v1i < v2i)
			end
		end
		if v1.revision and v2.revision then
			return (v1.revision < v2.revision)
		end
		return false
	end,
}

local version_cache = {}
setmetatable(version_cache, {
	__mode = "kv",
})

--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
function util.parse_version(vstring)
	if not vstring then
		return nil
	end
	assert(type(vstring) == "string")

	local cached = version_cache[vstring]
	if cached then
		return cached
	end

	local version = {}
	local i = 1

	local function add_token(number)
		version[i] = version[i] and version[i] + number / 100000 or number
		i = i + 1
	end

	-- trim leading and trailing spaces
	vstring = vstring:match("^%s*(.*)%s*$")
	version.string = vstring
	-- store revision separately if any
	local main, revision = vstring:match("(.*)%-(%d+)$")
	if revision then
		vstring = main
		version.revision = tonumber(revision)
	end
	while #vstring > 0 do
		-- extract a number
		local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
		if token then
			add_token(tonumber(token))
		else
			-- extract a word
			token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
			if not token then
				return nil
			end
			local last = #version
			version[i] = deltas[token] or (token:byte() / 1000)
		end
		vstring = rest
	end
	setmetatable(version, version_mt)
	version_cache[vstring] = version
	return version
end

--- Utility function to compare version numbers given as strings.
-- @param a string: one version.
-- @param b string: another version.
-- @return boolean: True if a >= b.
function util.version_geq(a, b)
	return util.parse_version(a) >= util.parse_version(b)
end

function util.wx_version()
	return string.match(wx.wxVERSION_STRING, "[%d%.]+")
end

function util.os_name()
	return wx.wxPlatformInfo.Get():GetOperatingSystemFamilyName()
end

local PATH_CACHE = {}

-- Converts a filepath to a uniquely identifying Lua require path.
-- Examples:
-- api/chara/IChara.lua -> api.chara.IChara
-- mod/elona/init.lua   -> mod.elona
function util.convert_to_require_path(path)
	-- This function is gets hot since many functions call "require" in
	-- function bodies to get around circular dependencies.
	if PATH_CACHE[path] then
		return PATH_CACHE[path]
	end

	local old_path = path

	-- HACK: needs better normalization to prevent duplicate chunks. If
	-- this is not completely unique then two require paths could end
	-- up referring to the same file, breaking hotloading. The
	-- intention is any require path uniquely identifies a return value
	-- from `require`.
	path = string.strip_suffix(path, ".lua")
	path = string.gsub(path, "/", ".")
	path = string.gsub(path, "\\", ".")
	path = string.strip_suffix(path, ".init")
	path = string.gsub(path, "^%.+", "")

	PATH_CACHE[old_path] = path

	return path
end

-- from lume
function util.hotload(modname)
	-- the module name has to match exactly in the way it was
	-- originally required. this is because requiring a different path
	-- that refers to the same module will generate a completely new
	-- table for it in package.loaded.
	if package.loaded[modname] == nil then
		print("no module named " .. modname .. ", requiring")
		return require(modname)
	end
	local oldglobal = table.shallow_copy(_G)
	local updated = {}
	local function update(old, new)
		if updated[old] then
			return
		end
		updated[old] = true
		local oldmt, newmt = getmetatable(old), getmetatable(new)
		if oldmt and newmt then
			update(oldmt, newmt)
		end
		for k, v in pairs(new) do
			if type(v) == "table" then
				update(old[k], v)
			else
				old[k] = v
			end
		end
	end
	local err = nil
	local function onerror(e)
		for k in pairs(_G) do
			_G[k] = oldglobal[k]
		end
		err = string.trim(e)
	end
	local ok, oldmod = pcall(require, modname)
	oldmod = ok and oldmod or nil
	xpcall(function()
		package.loaded[modname] = nil
		local newmod = require(modname)
		--if type(oldmod) == "table" then update(oldmod, newmod) end
		if type(oldmod) == "table" then
			table.replace_with(oldmod, newmod)
		end
		for k, v in pairs(oldglobal) do
			if v ~= _G[k] and type(v) == "table" then
				update(v, _G[k])
				_G[k] = v
			end
		end
	end, onerror)
	package.loaded[modname] = oldmod
	if err then
		return nil, err
	end
	return oldmod
end

-- Generate a unique new wxWindowID
local ID_IDCOUNTER = wx.wxID_HIGHEST + 1
function util.new_id()
	ID_IDCOUNTER = math.floor(ID_IDCOUNTER + 1) -- make sure it's integer
	return ID_IDCOUNTER
end

function util.connect(...)
	local t = { ... }
	local emitter, id, event_id, receiver, cb
	if #t == 5 then
		emitter = t[1]
		id = assert(t[2], "must provide non-nil id")
		event_id = t[3]
		receiver = t[4]
		cb = t[5]
	elseif #t == 4 then
		id = nil
		emitter = t[1]
		event_id = t[2]
		receiver = t[3]
		cb = t[4]
	else
		error("connect must receive 4 or 5 arguments, got " .. tostring(#t))
	end

	if id == nil then
		emitter:Connect(event_id, function(event)
			receiver[cb](receiver, event)
		end)
	else
		emitter:Connect(id, event_id, function(event)
			receiver[cb](receiver, event)
		end)
	end
end

function util.connect_self(...)
	local t = { ... }
	local emitter, id, event_id, receiver, cb
	if #t == 5 then
		emitter = t[1]
		id = t[2]
		event_id = t[3]
		receiver = t[4]
		cb = t[5]
	elseif #t == 4 then
		id = nil
		emitter = t[1]
		event_id = t[2]
		receiver = t[3]
		cb = t[4]
	else
		error("connect must receive 4 or 5 arguments, got " .. tostring(#t))
	end

	if id == nil then
		emitter:Connect(event_id, function(event)
			receiver[cb](emitter, event)
		end)
	else
		emitter:Connect(id, event_id, function(event)
			receiver[cb](emitter, event)
		end)
	end
end

function util.read_file(file)
	local f = assert(io.open(file, "rb"))
	local content = f:read("*all")
	f:close()
	return content
end

local function cmp_multitype(op1, op2)
	local type1, type2 = type(op1), type(op2)
	if type1 ~= type2 then --cmp by type
		return type1 < type2
	elseif type1 == "number" or type1 == "string" then --type2 is equal to type1
		return op1 < op2 --comp by default
	elseif type1 == "boolean" then
		return op1 == true
	else
		return tostring(op1) < tostring(op2) --cmp by address
	end
end

local function __gen_ordered_index(t)
	local orderedIndex = {}
	for key in pairs(t) do
		table.insert(orderedIndex, key)
	end
	table.sort(orderedIndex, cmp_multitype) --### CANGE ###
	return orderedIndex
end

local function ordered_next(t, state)
	-- Equivalent of the next function, but returns the keys in the alphabetic
	-- order. We use a temporary ordered key table that is stored in the
	-- table being iterated.

	local key = nil
	--print("ordered_next: state = "..tostring(state) )
	if state == nil then
		-- the first time, generate the index
		t.__ordered_index = __gen_ordered_index(t)
		key = t.__ordered_index[1]
	else
		-- fetch the next value
		for i = 1, table.getn(t.__ordered_index) do
			if t.__ordered_index[i] == state then
				key = t.__ordered_index[i + 1]
			end
		end
	end

	if key then
		return key, t[key]
	end

	-- no more value to return, cleanup
	t.__ordered_index = nil
	return
end

function util.ordered_pairs(t)
	-- Equivalent of the pairs() function on tables. Allows to iterate
	-- in order
	return ordered_next, t, nil
end

function util.subclass(inst, tbl)
	for k, v in pairs(tbl) do
		if type(v) == "function" then
			inst[k] = function(...)
				return tbl[k](...)
			end
		end
	end
	return inst
end

return util
