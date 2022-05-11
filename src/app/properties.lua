local wx = require("wx")
local util = require("lib.util")

local properties = class.class("input")

function properties:init(app, frame)
	self.app = app

	self.panel = wx.wxPanel(frame, wx.wxID_ANY)
	self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

	self.manager = wx.wxPropertyGridManager(
		self.panel,
		wx.wxID_ANY,
		wx.wxDefaultPosition,
		wx.wxSize(400, 400),
		wx.wxPG_SPLITTER_AUTO_CENTER + wx.wxPG_BOLD_MODIFIED
	)
	self.grid = self.manager:GetGrid()
	self.sizer:Add(self.manager, 1, wx.wxEXPAND, 5)

	self.prop_category = wx.wxPropertyCategory("Chip")
	self.prop_index = wx.wxFloatProperty("Index", wx.wxPG_LABEL, 0)
	self.prop_name = wx.wxStringProperty("Name", wx.wxPG_LABEL, "")
	self.prop_position = wx.wxStringProperty("Position", wx.wxPG_LABEL, "")
	self.prop_size = wx.wxStringProperty("Size", wx.wxPG_LABEL, "")
	self.prop_replacement = wx.wxStringProperty("Replacement", wx.wxPG_LABEL, "")

	self:update_properties()

	util.connect(self.manager, wx.wxEVT_PG_CHANGED, self, "on_property_grid_changed")

	self.panel:SetSizer(self.sizer)
	self.sizer:SetSizeHints(self.panel)

	self.pane = self.app:add_pane(self.panel, {
		Name = wxT("Data Properties"),
		Caption = wxT("Data Properties"),
		MinSize = wx.wxSize(200, 150),
		BestSize = wx.wxSize(400, 200),
		"Right",
		PaneBorder = false,
		dock_proportion = 1,
	})
end

function properties:push_property(label, key, value)
	local prop = wx.wxStringProperty(label, wx.wxPG_LABEL, value)
	self.grid:Append(prop)
end

function properties:update_properties(region)
	self.grid:Clear()

	if region == nil then
		return
	end

	local data = self.app.widget_atlas:get_data(region)

	self.grid:Append(self.prop_category)

	self.prop_index:SetValue(region.index)
	self.grid:Append(self.prop_index)
	self.grid:DisableProperty(self.prop_index)

	self.prop_name:SetValue(region.name)
	self.grid:Append(self.prop_name)

	self.prop_position:SetValue(("(%d, %d)"):format(region.x / 48, region.y / 48))
	self.grid:Append(self.prop_position)
	self.grid:DisableProperty(self.prop_position)

	self.prop_size:SetValue(("(%d, %d)"):format(region.w, region.h))
	self.grid:Append(self.prop_size)
	self.grid:DisableProperty(self.prop_size)

	self.prop_replacement:SetValue(data.replacement_path or "")
	self.grid:Append(self.prop_replacement)
	self.grid:DisableProperty(self.prop_replacement)
end

--
-- Events
--

function properties:on_property_grid_changed(event)
	local prop = event:GetProperty()

	if prop then
		self.app:print("OnPropertyGridChange(%s, value=%s)", prop:GetName(), prop:GetValueAsString())

		local page = self.app.widget_atlas:get_current_page()
		local region = self.app.widget_atlas:get_current_region()
		if region then
			if prop:GetName() == "Name" then
				region.name = prop:GetValueAsString()
				region.has_name = nil
				page.config_modified = true
			end
		end
	else
		self.app:print("OnPropertyGridChange(NULL)")
	end
end

return properties
