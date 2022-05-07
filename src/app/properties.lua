local wx = require("wx")
local util = require("lib.util")

local properties = class.class("input")

function properties:init(app, frame)
   self.app = app

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   self.manager = wx.wxPropertyGridManager(self.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxSize(400, 400),
                                           wx.wxPG_SPLITTER_AUTO_CENTER + wx.wxPG_BOLD_MODIFIED)
   self.grid = self.manager:GetGrid()
   self.sizer:Add(self.manager, 1, wx.wxEXPAND, 5)

   self:update_properties()

   util.connect(self.manager, wx.wxEVT_PG_CHANGED, self, "on_property_grid_changed")

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = wxT("Data Properties"),
                                    Caption = wxT("Data Properties"),
                                    MinSize = wx.wxSize(300, 200),
                                    BestSize = wx.wxSize(400, 300),
                                    "Right",
                                    PaneBorder = false
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

   self.grid:Append(wx.wxPropertyCategory(("Chip (%s)"):format("chara")))

   local prop = wx.wxFloatProperty("Index", wx.wxPG_LABEL, region.index)
   self.grid:Append(prop)
   self.grid:DisableProperty(prop)
   prop = wx.wxStringProperty("Name", wx.wxPG_LABEL, region.name)
   self.grid:Append(prop)
   prop = wx.wxStringProperty("Position", wx.wxPG_LABEL, ("(%d, %d)"):format(region.x, region.y))
   self.grid:Append(prop)
   self.grid:DisableProperty(prop)
   prop = wx.wxStringProperty("Size", wx.wxPG_LABEL, ("(%d, %d)"):format(region.w, region.h))
   self.grid:Append(prop)
   self.grid:DisableProperty(prop)
   prop = wx.wxStringProperty("Replacement", wx.wxPG_LABEL, (data and data.replacement_path) or "")
   self.grid:Append(prop)
   self.grid:DisableProperty(prop)
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
