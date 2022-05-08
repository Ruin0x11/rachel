local wx = require("wx")
local util = require("lib.util")
local tile_cell = require("widget.tile_cell")

local tile_picker = class.class("input")

function tile_picker:init(app, frame)
   self.app = app

   self.scrollwin = wx.wxScrolledWindow(frame, wx.wxID_ANY)
   self.panel = wx.wxPanel(self.scrollwin, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   for _ = 1, 5 do
      local cell = tile_cell.create(self.panel, "C:/build/HarmonyTest/src/mod/extra_themes/themes/compilation/petsbig/chara_393.bmp")
      self.sizer:Add(cell.panel, 0, wx.wxEXPAND, 5)
   end

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = wxT("Tile Picker"),
                                    Caption = wxT("Tile Picker"),
                                    MinSize = wx.wxSize(200, 100),
                                    BestSize = wx.wxSize(400, 300),
                                    "Right",
                                    PaneBorder = false
                                 })
end

return tile_picker
