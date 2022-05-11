local wx = require("wx")
local fs = require("lib.fs")

local chips = {}

function chips.get_chip_variant_dir(region)
	return fs.join("resources", "chips", region.type, region.index)
end

local EXTENSIONS = { "bmp", "jpg", "jpeg", "png" }

function chips.iter_subimage_variants(region)
	local is_image = function(path)
		return fun.iter(EXTENSIONS):any(function(i)
			return path:match("%." .. i .. "$")
		end)
	end
	local dir = chips.get_chip_variant_dir(region)
	return fs.iter_directory_items(dir):filter(is_image)
end

function chips.get_subimage(image, region)
	return image:GetSubImage(wx.wxRect(region.x, region.y, region.w, region.h))
end

function chips.save_subimage(cut, path)
	local dir = fs.parent(path)
	if not wx.wxDirExists(dir) then
		fs.mkdir_p(dir)
	end
	if wx.wxFileExists(path) then
		wx.wxRemoveFile(path)
	end
	cut:SaveFile(path, wx.wxBITMAP_TYPE_BMP)
end

return chips
