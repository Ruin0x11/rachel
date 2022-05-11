local wx = require("wx")
local fs = require("lib.fs")
local util = require("lib.util")
local ID = require("lib.ids")

local tile_cell = {}

function tile_cell.create(scrollwin, image, caption, filepath)
	local panel = wx.wxPanel(scrollwin, wx.wxID_ANY)

	if type(image) == "string" then
		filepath = image
		image = wx.wxImage(filepath)
		caption = fs.basename(fs.normalize(filepath))
	end

	local image_control = wx.wxStaticBitmap(
		panel,
		wx.wxID_ANY,
		wx.wxBitmap(image),
		wx.wxDefaultPosition,
		wx.wxDefaultSize
	)
	local filename_text = wx.wxStaticText(
		panel,
		wx.wxID_ANY,
		caption,
		wx.wxDefaultPosition,
		wx.wxDefaultSize,
		wx.wxALIGN_CENTRE_HORIZONTAL
	)

	local sizer_horiz = wx.wxBoxSizer(wx.wxHORIZONTAL)
	sizer_horiz:Add(image_control, 0, wx.wxALIGN_CENTRE + wx.wxALL, 5)
	sizer_horiz:Add(filename_text, 1, wx.wxALIGN_CENTRE + wx.wxALL, 5)

	panel.image = image
	panel.selected = false
	panel.panel = panel
	panel.text = filename_text
	panel.filepath = filepath

	panel:SetSizer(sizer_horiz)
	sizer_horiz:SetSizeHints(panel)

	for _, ctrl in ipairs({ panel, filename_text, image_control }) do
		util.connect(ctrl, wx.wxEVT_LEFT_DOWN, panel, "on_left_mouse_down")
	end
	panel.on_left_mouse_down = tile_cell.on_left_mouse_down

	return util.subclass(panel, tile_cell)
end

function tile_cell:set_selected(selected)
	self.selected = selected
	if selected then
		self.panel:SetBackgroundColour(wx.wxBLUE)
		self.text:SetForegroundColour(wx.wxWHITE)
	else
		self.panel:SetBackgroundColour(wx.wxColour(240, 240, 240))
		self.text:SetForegroundColour(wx.wxBLACK)
	end
	self.panel:Refresh()
end

-- FIXME: No wxNewEventType()!

function tile_cell:on_left_mouse_down(event)
	local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.TILE_PICKER)
	evt:SetEventObject(self)
	self:ProcessEvent(evt)
	self:Refresh()
end

return tile_cell
