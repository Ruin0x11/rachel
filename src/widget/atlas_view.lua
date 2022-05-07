local wx = require("wx")
local util = require("lib.util")
local ID = require("lib.ids")

local atlas_view = {}

function atlas_view.create(panel, filepath, regions)
   local image = wx.wxImage()
   assert(image:LoadFile(filepath))
   local bitmap = wx.wxBitmap(image)

   local scrollwin = wx.wxScrolledWindow(panel, wx.wxID_ANY)
   local win = wx.wxPanel(scrollwin, wx.wxID_ANY,
                                  wx.wxDefaultPosition, wx.wxSize(bitmap:GetWidth(), bitmap:GetHeight()),
                                  wx.wxTR_DEFAULT_STYLE + wx.wxNO_BORDER)

   win:SetBackgroundColour(wx.wxColour(220, 220, 128))

   win.bitmap = bitmap
   win.regions = regions
   win.selected = nil

   function win:on_paint(event)
      local dc = wx.wxPaintDC(self)
      local size = self:GetClientSize()
      dc:SetBrush(wx.wxBrush(self:GetBackgroundColour(), wx.wxBRUSHSTYLE_SOLID))
      dc:SetPen(wx.wxPen(wx.wxBLACK, 1, wx.wxPENSTYLE_SOLID))
      dc:DrawRectangle(0, 0, size:GetWidth(), size:GetHeight())
      dc:DrawBitmap(self.bitmap, 0, 0, false)
      dc:DrawText("asdf", 2, 2)

      dc:SetBrush(wx.wxTRANSPARENT_BRUSH)

      dc:SetPen(wx.wxPen(wx.wxRED, 1, wx.wxPENSTYLE_SOLID))
      for _, region in ipairs(self.regions) do
         if not region.has_name then
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

   function win:on_left_mouse_down(event)
      local x, y = event:GetPositionXY()
      for i, region in ipairs(self.regions) do
         if x >= region.x and y >= region.y and x < region.x + region.w and y < region.y + region.h then
            self:select(i)
            return
         end
      end

      self.selected = nil
      local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.ATLAS_WINDOW)
      wx.wxPostEvent(self, evt)
      self:Refresh()
   end

   function win:select(index)
      self.selected = index
      local evt = wx.wxCommandEvent(wx.wxEVT_COMMAND_ENTER, ID.ATLAS_WINDOW)
      wx.wxPostEvent(self, evt)
      self:Refresh()
   end

   util.connect(win, wx.wxEVT_PAINT, win, "on_paint")
   util.connect(win, wx.wxEVT_LEFT_DOWN, win, "on_left_mouse_down")

   scrollwin:SetScrollbars(1, 1, win.bitmap:GetWidth(), win.bitmap:GetHeight())
   scrollwin.win = win

   function scrollwin:select(index)
      self.win:select(index)
   end

   return scrollwin
end

return atlas_view
