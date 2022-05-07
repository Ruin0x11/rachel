local wx = require("wx")
local wxaui = require("wxaui")
local fs = require("lib.fs")
local util = require("lib.util")
local atlas_view = require("widget.atlas_view")
local ID = require("lib.ids")

local atlas = class.class("input")

function atlas:init(app, frame)
   self.app = app

   self.history = {}

   self.panel = wx.wxPanel(frame, wx.wxID_ANY)
   self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

   local notebook_style = wxaui.wxAUI_NB_DEFAULT_STYLE
      + wxaui.wxAUI_NB_TAB_EXTERNAL_MOVE
      + wx.wxNO_BORDER
   self.notebook = wxaui.wxAuiNotebook(self.panel, wx.wxID_ANY,
                                       wx.wxDefaultPosition,
                                       wx.wxDefaultSize,
                                       notebook_style)
   self.sizer:Add(self.notebook, 1, wx.wxEXPAND, 5)

   util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CLOSED, self, "on_auinotebook_page_closed")
   util.connect(self.notebook, wx.wxEVT_COMMAND_ENTER, self, "on_atlas_tile_selected")

   self.page_data = {}
   self.filenames = {}

   self.panel:SetSizer(self.sizer)
   self.sizer:SetSizeHints(self.panel)

   -- util.connect(self.history_box, wx.wxEVT_COMBOBOX, self, "on_combobox")

   self.pane = self.app:add_pane(self.panel,
                                 {
                                    Name = wxT("Atlas View"),
                                    Caption = wxT("Atlas View"),
                                    MinSize = wx.wxSize(200, 100),
                                    "CenterPane",
                                    PaneBorder = false
                                 })
end

function atlas:open_file(filename)
   filename = fs.normalize(filename)

   local existing_idx = self.filenames[filename]
   if existing_idx then
      self.notebook:SetSelection(existing_idx)
      return
   end

   self:add_page(filename)
end

function atlas:add_page(filename, at_index)
   local std = "elonaplus"

   local regions = {
      { 48, 0, 48, 48 },
      { 96, 0, 48, 48 },
      { 144, 0, 48, 48 },
   }

   local atlas_view = atlas_view.create(self.panel, filename, regions, std)

   local page_bmp = wx.wxArtProvider.GetBitmap(wx.wxART_NORMAL_FILE, wx.wxART_OTHER, wx.wxSize(16,16))

   local basename = filename:gsub("(.*[/\\])(.*)", "%2")
   if at_index then
      self.notebook:InsertPage(at_index, atlas_view, basename, false, page_bmp)
   else
      self.notebook:AddPage(atlas_view, basename, false, page_bmp)
   end

   local index = self.notebook:GetPageIndex(atlas_view)

   self.page_data[index] = {
      filename = filename,
      regions = regions,
      std = std,
      atlas_view = atlas_view,
      index = index
   }
   self.filenames[filename] = index
   self.notebook:SetSelection(index)

   atlas_view:select(1)
end

function atlas:has_some()
   return self.notebook:GetPageCount() > 0
end

function atlas:get_current_page()
   local page = self.notebook:GetCurrentPage()
   local index = self.notebook:GetPageIndex(page)
   return self.page_data[index]
end

function atlas:get_current_region()
   local page = self:get_current_page()
   if page == nil then
      return nil
   end
   return page.regions[page.atlas_view.win.selected]
end

function atlas:reload_current()
   local page = self:get_current_page()
   if page == nil then
      return
   end

   self.notebook:DeletePage(page.index)
   self:add_page(page.filename, page.index)
end

function atlas:close_current()
   local page = self:get_current_page()
   if page == nil then
      return
   end

   self.notebook:DeletePage(page.index)
end

function atlas:close_all()
   self.notebook:DeleteAllPages()
end

--
-- Events
--

function atlas:on_auinotebook_page_closed(event)
   local index = event:GetSelection()
   local page = self.page_data[index]
   self.filenames[page.filename] = nil
   self.page_data[index] = nil
end

function atlas:on_atlas_tile_selected(event)
   print("Get!", inspect(self:get_current_region()))
end

return atlas
