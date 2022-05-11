local wx = require("wx")
local util = require("lib.util")
local ID = require("lib.ids")

local atlas_window = {}

function atlas_window.create(scrollwin, image, regions, data)
	local win = wx.wxPanel(
		scrollwin,
		wx.wxID_ANY,
		wx.wxDefaultPosition,
		wx.wxSize(image:GetWidth(), image:GetHeight()),
		wx.wxTR_DEFAULT_STYLE + wx.wxNO_BORDER
	)

	win:SetBackgroundColour(wx.wxBLACK)

	win.bitmap = wx.wxBitmap(image)
	win.regions = regions
	win.data = data
	win.hovered = nil
	win.selected = nil
	win.lookup = {}
	for i, region in ipairs(win.regions) do
		win.lookup[region.index] = i
	end

	win.context_menu = wx.wxMenu()
	win.context_menu:Append(ID.ATLAS_RESET, "&Reset", "Reset this chip to its original state.")

	util.connect_self(win, wx.wxEVT_PAINT, atlas_window, "on_paint")
	util.connect_self(win, wx.wxEVT_MOTION, atlas_window, "on_motion")
	util.connect_self(win, wx.wxEVT_LEFT_DOWN, atlas_window, "on_left_mouse_down")
	util.connect_self(win, wx.wxEVT_LEFT_DCLICK, atlas_window, "on_left_mouse_dclick")
	util.connect_self(win, wx.wxEVT_RIGHT_DOWN, atlas_window, "on_right_mouse_down")

	return util.subclass(win, atlas_window)
end

function atlas_window:on_paint(event)
	local dc = wx.wxPaintDC(self)
	local size = self:GetClientSize()
	dc:SetBrush(wx.wxBrush(self:GetBackgroundColour(), wx.wxBRUSHSTYLE_SOLID))
	dc:SetPen(wx.wxPen(wx.wxBLACK, 1, wx.wxPENSTYLE_SOLID))
	dc:DrawRectangle(0, 0, size:GetWidth(), size:GetHeight())
	dc:DrawBitmap(self.bitmap, 0, 0, false)

	dc:SetBrush(wx.wxTRANSPARENT_BRUSH)

	dc:SetPen(wx.wxPen(wx.wxCYAN, 1, wx.wxPENSTYLE_SOLID))
	for _, region in ipairs(self.regions) do
		local d = self.data[region.index]
		if d and d.replacement_path then
			dc:DrawRectangle(region.x, region.y, region.w, region.h)
		end
	end

	dc:SetPen(wx.wxPen(wx.wxRED, 1, wx.wxPENSTYLE_SOLID))
	for _, region in ipairs(self.regions) do
		if region.has_name == false then
			dc:DrawRectangle(region.x, region.y, region.w, region.h)
		end
	end

	if self.selected ~= nil then
		local region = self.regions[self.selected]
		dc:SetPen(wx.wxPen(wx.wxYELLOW, 1, wx.wxPENSTYLE_SOLID))
		dc:DrawRectangle(region.x, region.y, region.w, region.h)
	end

	dc:delete()
end

function atlas_window:get_region_at(x, y)
	for i, region in ipairs(self.regions) do
		if x >= region.x and y >= region.y and x < region.x + region.w and y < region.y + region.h then
			return i
		end
	end

	return nil
end

-- FIXME: No wxNewEventType()!

function atlas_window:on_left_mouse_down(event)
	local x, y = event:GetPositionXY()
	local i = self:get_region_at(x, y)
	if i then
		self:select(i)
		return
	end

	self.selected = nil
	local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.ATLAS_WINDOW)
	wx.wxPostEvent(self, evt)
	self:Refresh()
end

function atlas_window:on_motion(event)
	local x, y = event:GetPositionXY()
	local i = self:get_region_at(x, y)
	if i then
		self.hovered = i
		local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_FILEPICKER_CHANGED, ID.ATLAS_WINDOW)
		wx.wxPostEvent(self, evt)
	end
end

function atlas_window:on_left_mouse_dclick(event)
	local x, y = event:GetPositionXY()
	local i = self:get_region_at(x, y)
	if i then
		self:activate(i)
	end
end

function atlas_window:on_right_mouse_down(event)
	local x, y = event:GetPositionXY()
	local i = self:get_region_at(x, y)
	if i then
		self:show_context_menu(i, event:GetPosition())
		return
	end
	self.selected = nil
	local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.ATLAS_WINDOW)
	wx.wxPostEvent(self, evt)
	self:Refresh()
end

function atlas_window:select(index)
	self.selected = index
	local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.ATLAS_WINDOW)
	wx.wxPostEvent(self, evt)
	self:Refresh()
end

function atlas_window:select_by_index(index)
	local i = self.lookup[index]
	if i then
		self:select(i)
	else
		self:select(nil)
	end
end

function atlas_window:activate(index)
	self.selected = index
	local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_TREE_SEL_CHANGED, ID.ATLAS_WINDOW)
	wx.wxPostEvent(self, evt)
	self:Refresh()
end

function atlas_window:show_context_menu(index, pos)
	self:select(index)
	self:PopupMenu(self.context_menu, pos)
end

return atlas_window
