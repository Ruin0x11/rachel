local wx = require("wx")
local util = require("lib.util")
local binprint = require("lib.binprint")

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

local function is_color(key, value)
   -- dumb heuristic
   local match = binprint.print_key(key):match("color")
      and binprint.is_table(value)
      and (#value[2] == 3 or #value[2] == 4)

   if not match then
      return false
   end

   for _, v in ipairs(value[2]) do
      if not binprint.is_numeric(v[2]) then
         return false
      end
   end

   return true
end

local function get_color(value)
   local c = {}

   for i, v in ipairs(value[2]) do
      c[i] = v[2] and v[2][2] or 255
   end

   return wx.wxColour(c[1], c[2], c[3], c[4] or 255)
end

function properties:push_property(label, key, value)
   local t = value[1]
   local v = value[2]
   local prop

   if binprint.is_numeric(value) then
      prop = wx.wxFloatProperty(label, wx.wxPG_LABEL, v)
      self.grid:Append(prop)
   elseif binprint.is_boolean(value) then
      prop = wx.wxBoolProperty(label, wx.wxPG_LABEL, v)
      self.grid:Append(prop)
      self.grid:SetPropertyAttribute( prop, wx.wxPG_BOOL_USE_CHECKBOX, true )
   elseif binprint.is_string(value) then
      prop = wx.wxStringProperty(label, wx.wxPG_LABEL, v)
      self.grid:Append(prop)
   elseif is_color(key, value) then
      local color = get_color(value)
      prop = wx.wxColourProperty(label, wx.wxPG_LABEL, color)
      self.grid:Append(prop)
   else
      prop = wx.wxStringProperty(label, wx.wxPG_LABEL, inspect(v):sub(1, 32))
      self.grid:Append(prop)
      self.grid:DisableProperty(prop)
   end
end

function properties:update_properties(node)
   self.grid:Clear()

   if node == nil then
      return
   end

   self.app:print("%s %s", node.type, inspect(node):sub(0, 100))

   -- table or class instance
   if binprint.is_simple_key(node.type) then
      self.grid:Append(wx.wxPropertyCategory(("Leaf (%s)"):format(binprint.print_key(node.key))))
      self:push_property("Value", node.key, node.value)
   elseif binprint.is_table(node.type) then
      self.grid:Append(wx.wxPropertyCategory(("Table (%s)"):format(binprint.print_key(node.key))))
      if is_color(node.key, node.value) then
         self:push_property("Value", node.key, node.value)
      else
         for _, pair in ipairs(node.data) do
            local key, value = pair[1], pair[2]
            local label = binprint.print_key(key)
            self:push_property(label, key, value)
         end
      end
   end
end

--
-- Events
--

function properties:on_property_grid_changed(event)
   local prop = event:GetProperty()

   if prop then
      self.app:print("OnPropertyGridChange(%s, value=%s)", prop:GetName(), prop:GetValueAsString())
   else
      self.app:print("OnPropertyGridChange(NULL)")
   end
end

return properties
