local wx = require("wx")
local fs = require("lib.fs")

local chips = {}

function chips.get_chip_variant_dir(region)
	return fs.join("resources", "chips", "chara", region.index)
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
