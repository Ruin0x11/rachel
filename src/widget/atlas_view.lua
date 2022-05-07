local wx = require("wx")
local util = require("lib.util")
local atlas_window = require("widget.atlas_window")

local atlas_view = {}

function atlas_view.create(panel, image, regions, data)
   local scrollwin = wx.wxScrolledWindow(panel, wx.wxID_ANY)
   local win = atlas_window.create(scrollwin, image, regions, data)

   scrollwin:SetScrollbars(1, 1, win.bitmap:GetWidth(), win.bitmap:GetHeight())
   scrollwin.win = win

   return util.subclass(scrollwin, atlas_view)
end

function atlas_view:select(index)
   self.win:select(index)
end

function atlas_view:select_by_index(index)
   self.win:select_by_index(index)
   if self.win.selected then
      local size = self:GetClientSize()
      local w, h = size:GetWidth(), size:GetHeight()
      local r = self.win.regions[self.win.selected]
      self:Scroll(r.x + r.w - w, r.y + r.h - h)
   end
end

function atlas_view:update_bitmap(image)
   self.win.bitmap = wx.wxBitmap(image)
   self:Refresh()
end

return atlas_view
