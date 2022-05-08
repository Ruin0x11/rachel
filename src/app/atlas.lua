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

   local index_text = wx.wxStaticText(self.panel, wx.wxID_ANY, "Index: ")
   self.index_text_ctrl = wx.wxTextCtrl(self.panel, wx.wxID_ANY, "",
                                        wx.wxDefaultPosition, wx.wxSize(80, 20),
                                        wx.wxTE_PROCESS_ENTER)

   local index_text_sizer = wx.wxFlexGridSizer(2, 2, 0, 0)
   index_text_sizer:AddGrowableCol(1)
   index_text_sizer:Add(index_text,  0, wx.wxALL + wx.wxALIGN_LEFT, 0)
   index_text_sizer:Add(self.index_text_ctrl, 1, wx.wxALL + wx.wxGROW + wx.wxCENTER, 0)

   self.sizer:Add(index_text_sizer, 0, wx.wxALIGN_BOTTOM, 0)

   -- FIXME: No wxNewEventType()!

   util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CLOSED, self, "on_auinotebook_page_closed")
   util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CLOSE, self, "on_auinotebook_page_close")
   util.connect(self.notebook, wx.wxEVT_COMMAND_ENTER, self, "on_atlas_tile_selected")
   util.connect(self.notebook, wx.wxEVT_COMMAND_TREE_SEL_CHANGED, self, "on_atlas_tile_activated")
   util.connect(self.notebook, ID.ATLAS_RESET, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_atlas_reset")
   util.connect(self.index_text_ctrl, wx.wxEVT_TEXT_ENTER, self, "on_index_text_enter")

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
   local config_filename = "C:/build/rachel/resources/configs/plus_2.12.rachel"
   local atlas_config = assert(loadfile(config_filename))()
   local tab_name = fs.basename(filename)
   local regions = atlas_config.atlases[tab_name]

   if regions == nil then
      self.app:show_error(("Atlas config does not support editing '%s'."):format(tab_name))
      return
   end

   local image = wx.wxImage()
   assert(image:LoadFile(filename))

   local data = {}

   local atlas_view = atlas_view.create(self.notebook, image, regions, data)

   local page_bmp = wx.wxArtProvider.GetBitmap(wx.wxART_NORMAL_FILE, wx.wxART_OTHER, wx.wxSize(16,16))

   if at_index then
      self.notebook:InsertPage(at_index, atlas_view, tab_name, false, page_bmp)
   else
      self.notebook:AddPage(atlas_view, tab_name, false, page_bmp)
   end

   local index = self.notebook:GetPageIndex(atlas_view)

   self.page_data[index] = {
      config_filename = config_filename,
      config = atlas_config,
      original_image = image,
      image = image:Copy(),
      tab_name = tab_name,
      filename = filename,
      regions = regions,
      atlas_view = atlas_view,
      index = index,
      atlas_modified = false,
      config_modified = false
   }
   self.filenames[filename] = index
   self.notebook:SetSelection(index)

   atlas_view:select(1)
   self:split_and_save()
end

local function get_chip_variant_dir(index)
   return fs.join("resources", "chips", "chara", index)
end

function atlas:split_and_save()
   local suffix = "base"
   local page = self:get_current_page()
   if page == nil then
      return
   end

   for _, region in ipairs(page.regions) do
      local dir = get_chip_variant_dir(region.index)
      local path = fs.join(dir, ("chara_%d_%s.bmp"):format(region.index, suffix))
      local cut = page.image:GetSubImage(wx.wxRect(region.x, region.y, region.w, region.h))
      if not wx.wxDirExists(dir) then
         wx.wxMkdir(dir)
      end
      if wx.wxFileExists(path) then
         wx.wxRemoveFile(path)
      end
      cut:SaveFile(path, wx.wxBITMAP_TYPE_BMP)
   end
end

function atlas:replace_chip(page, region, path)
   local image = wx.wxImage()

   if not image:LoadFile(path) then
      self.app:show_error(("Unable to load file '%s'."):format(path))
   end

   if image:GetWidth() ~= region.w or image:GetHeight() ~= region.h then
      self.app:show_error(("Region is incorrect size (expected (%d, %d), got (%d %d))")
         :format(region.w, region.h, image:GetWidth(), image:GetHeight()))
   end

   page.image:Paste(image, region.x, region.y)
   local data = page.atlas_view.win.data
   data[region.index] = data[region.index] or {}
   data[region.index].replacement_path = fs.to_relative(path, wx.wxGetCwd())
   page.atlas_view:update_bitmap(page.image)
   self.app.widget_properties:update_properties(region)
   self:set_modified(page, true)
end

function atlas:reset_chip(page, region)
   local image = page.original_image:GetSubImage(wx.wxRect(region.x, region.y, region.w, region.h))
   page.image:Paste(image, region.x, region.y)
   local data = page.atlas_view.win.data
   data[region.index] = data[region.index] or {}
   data[region.index].replacement_path = nil
   page.atlas_view:update_bitmap(page.image)
   self.app.widget_properties:update_properties(region)
   self:set_modified(page, true)
end

function atlas:has_some()
   return self.notebook:GetPageCount() > 0
end

function atlas:iter_pages()
   return fun.iter(self.page_data)
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

function atlas:get_data(region)
   local page = self:get_current_page()
   if page == nil then
      return nil
   end
   return page.atlas_view.win.data[region.index]
end

function atlas:try_close_page(page)
   return self.notebook:DeletePage(page.index)
end

function atlas:set_modified(page, modified)
   page.atlas_modified = modified
   if modified then
      self.notebook:SetPageText(page.index, page.tab_name .. "*")
   else
      self.notebook:SetPageText(page.index, page.tab_name)
   end
end

function atlas:reload_current()
   local page = self:get_current_page()
   if page == nil then
      return
   end

   if self:try_close_page(page) then
      self:add_page(page.filename, page.index)
   end
end

function atlas:close_current()
   local page = self:get_current_page()
   if page == nil then
      return
   end

   self:try_close_page(page)
end

function atlas:close_all()
   while self:has_some() do
      local page = self:get_current_page()
      if not self:try_close_page(page) then
         return
      end
   end
end

--
-- Events
--

function atlas:on_auinotebook_page_close(event)
   local index = event:GetSelection()
   local page = self.page_data[index]

   if page.config_modified then
      local res = wx.wxMessageBox(wxT("There are unsaved changes to the config. Are you sure you want to close this pane?"),
                                  wxT("Alert"), wx.wxYES_NO + wx.wxCENTRE, self.app.frame);
      if res ~= wx.wxYES then
         event:Veto()
         return
      end
   end

   if page.atlas_modified then
      local res = wx.wxMessageBox(wxT("There are unsaved changes. Are you sure you want to close this pane?"),
                                  wxT("Alert"), wx.wxYES_NO + wx.wxCENTRE, self.app.frame);
      if res ~= wx.wxYES then
         event:Veto()
         return
      end
   end
end


function atlas:on_auinotebook_page_closed(event)
   local index = event:GetSelection()
   local page = self.page_data[index]
   self.filenames[page.filename] = nil
   self.page_data[index] = nil
end

function atlas:on_atlas_tile_selected(event)
   local region = self:get_current_region()
   if region == nil then
      return
   end
   self.app.widget_properties:update_properties(region)
   self.index_text_ctrl:SetValue(tostring(region.index))
end

function atlas:on_atlas_tile_activated(event)
   local page = self:get_current_page()
   local region = self:get_current_region()
   local dir = get_chip_variant_dir(region.index)

   local file_dialog = wx.wxFileDialog(self.app.frame, "Load image", dir,
                                       "",
                                       "Image files (*.bmp,*.png,*.jpg,*.jpeg)|*.bmp;*.png;*.jpg;*.jpeg",
                                       wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST)
   if file_dialog:ShowModal() == wx.wxID_OK then
      local path = file_dialog:GetPath()

      self:replace_chip(page, region, path)
   end
   file_dialog:Destroy()
end

function atlas:on_menu_atlas_reset(event)
   local page = self:get_current_page()
   local region = self:get_current_region()

   if page and region then
      self:reset_chip(page, region)
   end
end

function atlas:on_index_text_enter(event)
   local page = self:get_current_page()
   local region = self:get_current_region()

   if page and region then
      local index = tonumber(self.index_text_ctrl:GetValue())
      if index ~= nil then
         local i = page.atlas_view:select_by_index(index)
         if i == nil then
            -- Tall sprites
            page.atlas_view:select_by_index(index + 33)
         end
      end
   end
end

return atlas
