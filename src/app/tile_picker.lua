local wx = require("wx")
local util = require("lib.util")
local tile_cell = require("widget.tile_cell")
local chips = require("lib.chips")
local fs = require("lib.fs")

local tile_picker = class.class("input")

function tile_picker:init(app, frame)
	self.app = app

	self.scrollwin = wx.wxScrolledWindow(frame, wx.wxID_ANY)

	self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)
	self.scrollwin:SetSizer(self.sizer)
	self.scrollwin:ShowScrollbars(1, 1)
	self.sizer:SetSizeHints(self.scrollwin)

	self.cells = {}
	self:update_cells()

	-- FIXME: No wxNewEventType()!

	util.connect(self.scrollwin, wx.wxEVT_COMMAND_ENTER, self, "on_tile_cell_selected")

	self.pane = self.app:add_pane(self.scrollwin, {
		Name = wxT("Tile Picker"),
		Caption = wxT("Tile Picker"),
		MinSize = wx.wxSize(200, 100),
		BestSize = wx.wxSize(400, 500),
		"Right",
		PaneBorder = false,
		dock_proportion = 100000,
	})
	self.scrollwin:Refresh()
end

local function get_region(image, region)
	return image:GetSubImage(wx.wxRect(region.x, region.y, region.w, region.h))
end

function tile_picker:update_cells(region)
	for _, cell in ipairs(self.cells) do
		cell:Destroy()
	end

	self.cells = {}
	self.selected = 1

	if region == nil then
		return
	end

	local page = self.app.widget_atlas:get_current_page()
	local data = self.app.widget_atlas:get_data(region)

	local selected = 1
	local n = 1
	if data.replacement_path then
		self:add_cell(wx.wxImage(data.replacement_path), "<current>", data.replacement_path)
		n = 2
	end
	self:add_cell(get_region(page.original_image, region), "<original>")

	for i, file in chips.iter_subimage_variants(region) do
		self:add_cell(file)

		if data.replacement_path and data.replacement_path == file then
			selected = i + n
		end
	end

	local vs = self.scrollwin:GetVirtualSize()
	self.scrollwin:SetScrollbars(1, 1, vs:GetWidth(), vs:GetHeight())
	self.scrollwin:SetSizer(self.sizer)
	self.selected = selected
	self:select_cell(selected)
end

function tile_picker:select_cell(idx_or_obj)
	local obj = idx_or_obj
	if type(idx_or_obj) == "number" then
		local cell = assert(self.cells[idx_or_obj], idx_or_obj)
		obj = cell.panel:DynamicCast("wxObject")
	end

	for i, cell in self:iter_cells() do
		local selected = cell.panel:DynamicCast("wxObject") == obj
		cell:set_selected(selected)
		if selected then
			if self.selected ~= i then
				self.selected = i
				local page = self.app.widget_atlas:get_current_page()
				local region = self.app.widget_atlas:get_current_region()
				self.app.widget_atlas:replace_chip(page, region, cell.image, cell.filepath)
			end
		end
	end

	self.scrollwin:Refresh()
end

function tile_picker:add_cell(image, caption, path)
	local cell = tile_cell.create(self.scrollwin, image, caption, path)
	self.sizer:Add(cell.panel, 0, wx.wxEXPAND, 5)
	self.cells[#self.cells + 1] = cell
	self.app.aui:Update()
end

function tile_picker:iter_cells()
	return fun.iter(self.cells)
end

function tile_picker:on_tile_cell_selected(event)
	self:select_cell(event:GetEventObject())
end

return tile_picker
