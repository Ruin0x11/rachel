local wx = require("wx")
local wxaui = require("wxaui")
local fs = require("lib.fs")
local util = require("lib.util")
local atlas_view = require("widget.atlas_view")
local ID = require("lib.ids")
local chips = require("lib.chips")

local atlas = class.class("input")

function atlas:init(app, frame)
	self.app = app

	self.history = {}

	self.panel = wx.wxPanel(frame, wx.wxID_ANY)
	self.sizer = wx.wxBoxSizer(wx.wxVERTICAL)

	local notebook_style = wxaui.wxAUI_NB_DEFAULT_STYLE + wxaui.wxAUI_NB_TAB_EXTERNAL_MOVE + wx.wxNO_BORDER
	self.notebook = wxaui.wxAuiNotebook(self.panel, wx.wxID_ANY, wx.wxDefaultPosition, wx.wxDefaultSize, notebook_style)
	self.sizer:Add(self.notebook, 1, wx.wxEXPAND, 5)

	local index_text = wx.wxStaticText(self.panel, wx.wxID_ANY, "Index: ")
	self.index_text_ctrl = wx.wxTextCtrl(
		self.panel,
		wx.wxID_ANY,
		"",
		wx.wxDefaultPosition,
		wx.wxSize(80, 20),
		wx.wxTE_PROCESS_ENTER
	)

	self.delete_button = wx.wxButton(self.panel, ID.BAR_DELETE, "Delete")

	local index_text_sizer = wx.wxBoxSizer(wx.wxHORIZONTAL)
	index_text_sizer:Add(index_text, 0, wx.wxALL + wx.wxALIGN_CENTRE, 5)
	index_text_sizer:Add(self.index_text_ctrl, 1, wx.wxALL + wx.wxGROW + wx.wxCENTER, 5)
	index_text_sizer:Add(self.delete_button, 1, wx.wxALL + wx.wxGROW + wx.wxCENTER, 5)

	self.sizer:Add(index_text_sizer, 0, wx.wxALIGN_BOTTOM, 0)

	-- FIXME: No wxNewEventType()!

	util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CHANGED, self, "on_auinotebook_page_changed")
	util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CLOSED, self, "on_auinotebook_page_closed")
	util.connect(self.notebook, wxaui.wxEVT_AUINOTEBOOK_PAGE_CLOSE, self, "on_auinotebook_page_close")
	util.connect(self.notebook, wx.wxEVT_COMMAND_FILEPICKER_CHANGED, self, "on_atlas_tile_hovered")
	util.connect(self.notebook, wx.wxEVT_COMMAND_ENTER, self, "on_atlas_tile_selected")
	util.connect(self.notebook, wx.wxEVT_COMMAND_TREE_SEL_CHANGED, self, "on_atlas_tile_activated")
	util.connect(self.notebook, ID.ATLAS_RESET, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_atlas_reset")
	util.connect(self.index_text_ctrl, wx.wxEVT_TEXT_ENTER, self, "on_index_text_enter")
	util.connect(self.index_text_ctrl, wx.wxEVT_UPDATE_UI, self, "on_update_ui")
	util.connect(self.delete_button, ID.BAR_DELETE, wx.wxEVT_COMMAND_BUTTON_CLICKED, self, "on_delete_button_clicked")
	util.connect(self.delete_button, ID.BAR_DELETE, wx.wxEVT_UPDATE_UI, self, "on_update_ui_bar_delete_button")

	self.page_data = {}
	self.filenames = {}

	self.panel:SetSizer(self.sizer)
	self.sizer:SetSizeHints(self.panel)

	-- util.connect(self.history_box, wx.wxEVT_COMBOBOX, self, "on_combobox")

	self.pane = self.app:add_pane(self.panel, {
		Name = wxT("Atlas View"),
		Caption = wxT("Atlas View"),
		MinSize = wx.wxSize(200, 100),
		"CenterPane",
		PaneBorder = false,
	})
end

function atlas:create_new(image_filename, config_filename, atlas_type, at_index)
	image_filename = fs.normalize(image_filename)
	local atlas_config = assert(loadfile(config_filename))()
	local tab_name = fs.basename(image_filename)
	local regions = atlas_config.atlases[atlas_type]

	if regions == nil then
		self.app:show_error(("Atlas config does not support editing '%s'."):format(tab_name))
		return
	end

	local image = wx.wxImage()
	assert(image:LoadFile(image_filename))

	local data = {}

	local atlas_view = atlas_view.create(self.notebook, image, regions, data)

	local page_bmp = wx.wxArtProvider.GetBitmap(wx.wxART_NORMAL_FILE, wx.wxART_OTHER, wx.wxSize(16, 16))

	if at_index then
		self.notebook:InsertPage(at_index, atlas_view, tab_name, false, page_bmp)
	else
		self.notebook:AddPage(atlas_view, tab_name, false, page_bmp)
	end

	local index = self.notebook:GetPageIndex(atlas_view)

	self.page_data[index] = {
		source_filename = image_filename,
		config_filename = config_filename,
		config = atlas_config,
		atlas_type = atlas_type,
		original_image = image,
		image = image:Copy(),
		tab_name = tab_name,
		filename = nil, -- only set on .ratlas load
		regions = regions,
		atlas_view = atlas_view,
		index = index,
		atlas_modified = false,
		config_modified = false,
	}
	-- self.filenames[filename] = index
	self.notebook:SetSelection(index)

	-- select the first tile on the atlas
	atlas_view:select(1)
end

function atlas:add_page(page, at_index)
	local page_bmp = wx.wxArtProvider.GetBitmap(wx.wxART_NORMAL_FILE, wx.wxART_OTHER, wx.wxSize(16, 16))

	if at_index then
		self.notebook:InsertPage(at_index, page.atlas_view, page.tab_name, false, page_bmp)
	else
		self.notebook:AddPage(page.atlas_view, page.tab_name, false, page_bmp)
	end

	local index = self.notebook:GetPageIndex(page.atlas_view)
	page.index = index

	self.page_data[index] = page
	self.filenames[page.filename] = index
	self.notebook:SetSelection(index)

	-- select the first tile on the atlas
	page.atlas_view:select(1)
end

function atlas:open_file(atlas_filename)
	atlas_filename = fs.normalize(atlas_filename)

	local existing_idx = self.filenames[atlas_filename]
	if existing_idx then
		self.notebook:SetSelection(existing_idx)
		return
	end

	-- self:add_page(filename, config_filename, atlas_type)
end

function atlas:replace_chip(page, region, image, path)
	if type(image) == "string" then
		path = image
		image = wx.wxImage()
		if not image:LoadFile(path) then
			self.app:show_error(("Unable to load file '%s'."):format(path))
		end
	end

	if image:GetWidth() > region.w or image:GetHeight() > region.h then
		self.app:show_error(
			("Region is incorrect size (expected (%d, %d), got (%d %d))"):format(
				region.w,
				region.h,
				image:GetWidth(),
				image:GetHeight()
			)
		)
		return
	end

	local blank = wx.wxImage(region.w, region.h)
	page.image:Paste(blank, region.x, region.y)
	page.image:Paste(image, region.x, region.y + (region.h - image:GetHeight()))

	local data = page.atlas_view.win.data
	data[region.index] = data[region.index] or {}
	data[region.index].replacement_path = path and fs.to_relative(path, wx.wxGetCwd()) or nil
	page.atlas_view:update_bitmap(page.image)
	-- self.app.widget_properties:update_properties(region)
	self:set_modified(page, true)
end

function atlas:reset_chip(page, region)
	local image = page.original_image:GetSubImage(wx.wxRect(region.x, region.y, region.w, region.h))
	page.image:Paste(image, region.x, region.y)
	local data = page.atlas_view.win.data
	data[region.index] = data[region.index] or {}
	data[region.index].replacement_path = nil
	page.atlas_view:update_bitmap(page.image)
	-- self.app.widget_properties:update_properties(region)
	self:set_modified(page, true)
end

function atlas:has_some()
	return self.notebook:GetPageCount() > 0
end

function atlas:iter_pages()
	return fun.iter(self.page_data)
end

function atlas:get_current_page()
	if not self:has_some() then
		return nil
	end
	local page = self.notebook:GetCurrentPage()
	local index = self.notebook:GetPageIndex(page)
	return self.page_data[index]
end

function atlas:get_hovered_region()
	local page = self:get_current_page()
	if page == nil then
		return nil
	end
	return page.regions[page.atlas_view.win.hovered]
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
	local data = page.atlas_view.win.data
	data[region.index] = data[region.index] or {}
	return data[region.index]
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

function atlas:refresh_current_region()
	local region = self:get_current_region()
	-- self.app.widget_properties:update_properties(region)
	self.app.widget_tile_picker:update_cells(region)
	if region ~= nil then
		self.index_text_ctrl:SetValue(tostring(region.index))
	else
		self.index_text_ctrl:SetValue("")
	end
end

function atlas:reset_all()
	local page = self:get_current_page()
	page.image:Destroy()
	page.image = page.original_image:Copy()
	table.replace_with(page.atlas_view.win.data, {})
	self:refresh_current_region()
end

function atlas:quick_set_all(suffix)
	local page = self:get_current_page()

	local regions = page.regions
	if regions.tile_prefix == nil then
		self:show_all("Cannot quick set for this atlas: " .. page.tab_name)
	end

	local progress_dialog = wx.wxProgressDialog(
		"Applying",
		"",
		#regions,
		self.app.frame,
		wx.wxPD_AUTO_HIDE + wx.wxPD_ELAPSED_TIME
	)

	local ok = true

	for i, region in ipairs(regions) do
		local dir = chips.get_chip_variant_dir(region)
		local filename = ("%s_%d_%s.bmp"):format(regions.tile_prefix, region.index, suffix)
		local path = fs.join(dir, filename)
		ok = progress_dialog:Update(i, filename)
		if not ok then
			break
		end
		if wx.wxFileExists(path) then
			self:replace_chip(page, region, path)
		end
	end

	progress_dialog:Destroy()
	self:refresh_current_region()
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

function atlas:on_auinotebook_page_changed(event)
	local page = self:get_current_page()
	local can_export = page and (page.tab_name == "character.bmp" or page.tab_name == "item.bmp") or false
	self.app.export_menu:Enable(ID.EXPORT_GRAPHIC_FOLDER, can_export)
end

function atlas:on_auinotebook_page_close(event)
	local index = event:GetSelection()
	local page = self.page_data[index]

	if page.config_modified then
		local res = wx.wxMessageBox(
			wxT("There are unsaved changes to the config. Are you sure you want to close this pane?"),
			wxT("Alert"),
			wx.wxYES_NO + wx.wxCENTRE + wx.wxICON_WARNING,
			self.app.frame
		)
		if res ~= wx.wxYES then
			event:Veto()
			return
		end
	end

	if page.atlas_modified then
		local res = wx.wxMessageBox(
			wxT("There are unsaved changes. Are you sure you want to close this pane?"),
			wxT("Alert"),
			wx.wxYES_NO + wx.wxCENTRE + wx.wxICON_WARNING,
			self.app.frame
		)
		if res ~= wx.wxYES then
			event:Veto()
			return
		end
	end
end

function atlas:on_auinotebook_page_closed(event)
	local index = event:GetSelection()
	local page = self.page_data[index]
	if page.filename then
		self.filenames[page.filename] = nil
	end
	self.page_data[index] = nil
	self:refresh_current_region()
end

function atlas:on_atlas_tile_hovered(event)
	local region = self:get_hovered_region()
	if region then
		self.app.frame:SetStatusText(("(%d, %d) - %s [%d]"):format(region.x, region.y, region.name, region.index))
	end
end

function atlas:on_atlas_tile_selected(event)
	self:refresh_current_region()
end

function atlas:on_atlas_tile_activated(event)
	local page = self:get_current_page()
	local region = self:get_current_region()
	local dir = chips.get_chip_variant_dir(region)

	local file_dialog = wx.wxFileDialog(
		self.app.frame,
		"Load image",
		dir,
		"",
		"Image files (*.bmp,*.png,*.jpg,*.jpeg)|*.bmp;*.png;*.jpg;*.jpeg",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
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

function atlas:on_update_ui(event)
	event:Enable(self:has_some())
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

function atlas:on_delete_button_clicked(event)
	local page = self:get_current_page()
	table.iremove_value(page.regions, self:get_current_region())
	page.atlas_view:select(nil)
	self:refresh_current_region()
end

function atlas:on_update_ui_bar_delete_button(event)
	event:Enable(self:get_current_region() ~= nil)
end

return atlas
