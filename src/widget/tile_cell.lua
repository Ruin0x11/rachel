local wx = require("wx")
local fs = require("lib.fs")
local util = require("lib.util")

local tile_cell = {}

function tile_cell.create(scrollwin, filepath)
	local panel = wx.wxPanel(scrollwin, wx.wxID_ANY)
	local image = wx.wxImage(filepath)

	local image_control = wx.wxStaticBitmap(
		scrollwin,
		wx.wxID_ANY,
		wx.wxBitmap(image),
		wx.wxDefaultPosition,
		wx.wxDefaultSize
	)

	local sizer_horiz = wx.wxBoxSizer(wx.wxHORIZONTAL)
	sizer_horiz:Add(image_control, 1, wx.wxEXPAND, 5)

	local panel2 = wx.wxPanel(panel, wx.wxID_ANY)
	sizer_horiz:Add(panel2, 1, wx.wxEXPAND, 5)

	local sizer_vert = wx.wxBoxSizer(wx.wxVERTICAL)
	local basename = fs.basename(filepath)
	local filename_text = wx.wxStaticText(panel2, wx.wxID_ANY, basename)
	sizer_vert:Add(filename_text, 1, wx.wxEXPAND, 5)

	panel2:SetSizer(sizer_vert)
	sizer_vert:SetSizeHints(panel2)

	panel.filepath = filepath
	panel.image = image
	panel.panel = panel

	panel:SetSizer(sizer_horiz)
	sizer_horiz:SetSizeHints(panel)

	return util.subclass(panel, tile_cell)
end

return tile_cell
