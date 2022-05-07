local fs = {}

local dir_sep = package.config:sub(1,1)
local is_windows = dir_sep == "\\"

--
-- These functions are from luacheck.
--

local function ensure_dir_sep(path)
   if string.sub(path, -1) ~= dir_sep then
      return path .. dir_sep
   end

   return path
end

function fs.split_base(path)
   if is_windows then
      if string.match(path, "^%a:\\") then
         return string.sub(path, 1, 3), string.sub(path, 4)
      else
         -- Disregard UNC paths and relative paths with drive letter.
         return "", path
      end
   else
      if string.match(path, "^/") then
         if string.match(path, "^//") then
            return "//", string.sub(path, 3)
         else
            return "/", string.sub(path, 2)
         end
      else
         return "", path
      end
   end
end

function fs.is_absolute(path)
   return fs.split_base(path) ~= ""
end

local function join_two_paths(base, path)
   if base == "" or fs.is_absolute(path) then
      return path
   else
      return ensure_dir_sep(base) .. path
   end
end

function fs.normalize(path)
   -- if is_windows then
   --    path = path:lower()
   -- end
   path = path:gsub("[/\\]", dir_sep)
   local base, rest = fs.split_base(path)

   local parts = {}

   for part in rest:gmatch("[^"..dir_sep.."]+") do
      if part ~= "." then
         if part == ".." and #parts > 0 and parts[#parts] ~= ".." then
            parts[#parts] = nil
         else
            parts[#parts + 1] = part
         end
      end
   end

   if base == "" and #parts == 0 then
      return "."
   else
      return base..table.concat(parts, dir_sep)
   end
end

function fs.basename(path)
   return string.gsub(path, "(.*" .. dir_sep .. ")(.*)", "%2")
end

function fs.filename_part(path)
   return string.gsub(fs.basename(path), "(.*)%..*", "%1")
end

function fs.extension_part(path)
   return string.gsub(fs.basename(path), ".*%.(.*)", "%1")
end

function fs.parent(path)
   return string.match(path, "^(.+)" .. dir_sep)
end

function fs.join(base, ...)
   local res = base

   for i = 1, select("#", ...) do
      res = join_two_paths(res, select(i, ...))
   end

   res = fs.normalize(res)

   return res
end

return fs
