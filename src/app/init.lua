local wx = require("wx")
local wxaui = require("wxaui")
local wxlua = require("wxlua")
local util = require("lib.util")
local debug_server = require("app.debug_server")
local atlas = require("app.atlas")
-- local properties = require("app.properties")
local repl = require("app.repl")
local config = require("config")
local fs = require("lib.fs")
local tile_picker = require("app.tile_picker")
local chips = require("lib.chips")
local suffix_dialog = require("dialog.suffix_dialog")
local config_dialog = require("dialog.config_dialog")
local split_dialog = require("dialog.split_dialog")

local ID = require("lib.ids")

--- @class app
local app = class.class("app")

function app:init()
	self.wx_app = wx.wxGetApp()

	self.name = "rachel"
	self.version = "0.1.0"
	self.wx_version = util.wx_version()
	self.width = 1024
	self.height = 768

	self.last_folder = ""
	self.last_atlas_filepath = ""

	self.file_menu = wx.wxMenu()
	self.file_menu:Append(ID.NEW, "&New...\tCTRL+N", "Import an atlas")
	self.file_menu:Append(ID.OPEN, "&Open...\tCTRL+O", "Open an atlas")
	self.file_menu:Append(ID.SAVE, "&Save...\tCTRL+S", "Save an atlas")
	self.file_menu:Append(ID.SAVE_CONFIG, "Save Config", "Saves the current config")
	self.file_menu:Append(ID.SAVE_CONFIG_AS, "Save Config As...", "Saves the current config")
	self.export_menu = wx.wxMenu()
	self.export_menu:Append(ID.EXPORT_TILESHEET, "&Tilesheet...", "Exports this atlas as a single bitmap image.")
	self.export_menu:Append(
		ID.EXPORT_GRAPHIC_FOLDER,
		"&Graphic Folder...",
		"Exports this atlas in the user/graphic format (character.bmp only)."
	)
	self.file_menu:Append(ID.EXPORT, "&Export", self.export_menu)
	self.file_menu:Append(ID.CLOSE, "&Close\tCTRL+W", "Close the current file")
	self.file_menu:Append(ID.EXIT, "E&xit", "Quit the program")
	self.tools_menu = wx.wxMenu()
	self.tools_menu:Append(ID.QUICK_SET_ALL, "&Quick Set All...", "Set all tiles based on suffix")
	self.tools_menu:Append(ID.RESET_ALL, "&Reset All...", "Reset all tiles to those of the original image")
	self.tools_menu:Append(
		ID.SPLIT_ATLAS,
		"&Split Atlas...",
		"Split an existing tile atlas into separate images (based on the current atlas)"
	)
	self.tools_menu:AppendCheckItem(ID.SHOW_REPL, "Show &REPL", "Show the REPL")
	self.tools_menu:AppendCheckItem(ID.SHOW_ALL_REGIONS, "Show &All Regions", "Show all tile boundaries as a grid")
	self.help_menu = wx.wxMenu()
	self.help_menu:Append(ID.ABOUT, "&About", "About this program")

	self.menu_bar = wx.wxMenuBar()
	self.menu_bar:Append(self.file_menu, "&File")
	self.menu_bar:Append(self.tools_menu, "&Tools")
	self.menu_bar:Append(self.help_menu, "&Help")

	self.frame = wx.wxFrame(
		wx.NULL,
		wx.wxID_ANY,
		self.name,
		wx.wxDefaultPosition,
		wx.wxSize(self.width, self.height),
		wx.wxDEFAULT_FRAME_STYLE
	)
	self.frame.MenuBar = self.menu_bar

	self.status_bar = self.frame:CreateStatusBar(ID.STATUS_BAR)
	local info = self:get_info()
	local status_txt_width = self.status_bar:GetTextExtent(info)
	self.status_bar:SetFieldsCount(1)
	self.frame:SetStatusWidths({ -1, status_txt_width })
	self.frame:SetStatusText(info)

	self.wx_app.TopWindow = self.frame
	self.frame:Show(true)

	self.aui = wxaui.wxAuiManager()
	self.aui:SetManagedWindow(self.frame)

	self.widget_repl = repl:new(self, self.frame)
	self.widget_atlas = atlas:new(self, self.frame)
	-- self.widget_properties = properties:new(self, self.frame)
	self.widget_tile_picker = tile_picker:new(self, self.frame)

	self.debug_server = debug_server:new(self, config.debug_server.port)

	self.aui:Update()

	util.connect(self.frame, ID.NEW, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_new")
	util.connect(self.frame, ID.OPEN, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_open")
	util.connect(self.frame, ID.SAVE, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_save")
	util.connect(self.frame, ID.SAVE_CONFIG, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_save_config")
	util.connect(self.frame, ID.SAVE_CONFIG_AS, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_save_config_as")
	util.connect(self.frame, ID.CLOSE, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_close")
	util.connect(self.frame, ID.EXIT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_exit")
	util.connect(self.frame, ID.ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_about")

	util.connect(
		self.export_menu,
		ID.EXPORT_TILESHEET,
		wx.wxEVT_COMMAND_MENU_SELECTED,
		self,
		"on_menu_export_tilesheet"
	)
	util.connect(
		self.export_menu,
		ID.EXPORT_GRAPHIC_FOLDER,
		wx.wxEVT_COMMAND_MENU_SELECTED,
		self,
		"on_menu_export_graphic_folder"
	)

	util.connect(self.tools_menu, ID.QUICK_SET_ALL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_quick_set_all")
	util.connect(self.tools_menu, ID.RESET_ALL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_reset_all")
	util.connect(self.tools_menu, ID.SPLIT_ATLAS, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_split_atlas")
	util.connect(self.tools_menu, ID.SHOW_REPL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_show_repl")
	util.connect(self.tools_menu, ID.SHOW_ALL_REGIONS, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_show_all_regions")

	for _, id in ipairs({
		ID.SAVE,
		ID.CLOSE,
		ID.SAVE_CONFIG,
		ID.EXPORT_TILESHEET,
		ID.EXPORT_GRAPHIC_FOLDER,
		ID.QUICK_SET_ALL,
		ID.RESET_ALL,
		ID.SPLIT_ATLAS,
	}) do
		self:connect_frame(id, wx.wxEVT_UPDATE_UI, self, "on_update_ui")
	end

	self:connect_frame(wx.wxID_ANY, wx.wxEVT_DESTROY, self, "on_destroy")

	self.frame:SetFocus()
end

function app:add_pane(ctrl, args)
	local info = wxaui.wxAuiPaneInfo()

	for k, v in pairs(args) do
		if type(k) == "number" then
			info = info[v](info)
		else
			if k:match("[A-Z]") then
				-- MinSize()
				info = info[k](info, v)
			else
				-- dock_proportion
				info[k] = v
			end
		end
	end

	info = info:CloseButton(false)

	self.aui:AddPane(ctrl, info)

	return info
end

function app:connect(...)
	return util.connect(self.wx_app, ...)
end

function app:connect_frame(...)
	return util.connect(self.frame, ...)
end

function app:print(fmt, ...)
	if self.widget_repl then
		self.widget_repl:DisplayShellMsg(string.format(fmt, ...))
	end
end

function app:print_error(fmt, ...)
	if self.widget_repl then
		self.widget_repl:DisplayShellErr(repl.filterTraceError(string.format(fmt, ...)))
	end
end

function app:show_error(str)
	wx.wxMessageBox(str, "wxLua Error", wx.wxOK + wx.wxCENTRE + wx.wxICON_ERROR, self.frame)
end

function app:run()
	self.wx_app:MainLoop()
end

--
-- Events
--

function app:on_destroy(event)
	if event:GetEventObject():DynamicCast("wxObject") == self.frame:DynamicCast("wxObject") then
		-- You must ALWAYS UnInit() the wxAuiManager when closing
		-- since it pushes event handlers into the frame.
		self.aui:UnInit()
	end
end

function app:try_create_atlas(path, config_file, atlas_type)
	local ok, err = xpcall(
		self.widget_atlas.create_new,
		debug.traceback,
		self.widget_atlas,
		path,
		config_file,
		atlas_type
	)
	if not ok then
		self:print_error(err)
		self:show_error(("Unable to create atlas '%s'.\n\n%s"):format(path, err))
	end
end

function app:try_save_config(path)
	local page = self.widget_atlas:get_current_page()
	if page == nil then
		return
	end

	local f, err = io.open(path, "w")

	if not f then
		self:print_error(err)
		self:show_error(("Unable to save config '%s'.\n\n%s"):format(path, err))
		return
	end

	f:write("return " .. inspect(page.config))
	f:close()

	page.config_modified = false
	page.config_filename = path
	self.frame:SetStatusText("Saved config to " .. path)
end

function app:on_menu_new(_)
	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Import atlas",
		self.last_folder,
		"",
		"Atlas images (character.bmp)|character.bmp",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
	if file_dialog:ShowModal() ~= wx.wxID_OK then
		file_dialog:Destroy()
		return
	end

	local path = fs.normalize(file_dialog:GetPath())
	file_dialog:Destroy()

	config_dialog.query(self.frame, path, function(config_filename, atlas_type)
		self:try_create_atlas(path, config_filename, atlas_type)
	end)
end

function app:on_menu_open(_)
	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Load atlas",
		self.last_folder,
		"",
		"Atlas files (*.ratlas)|*.ratlas",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
	if file_dialog:ShowModal() == wx.wxID_OK then
		local path = fs.normalize(file_dialog:GetPath())
	end
	file_dialog:Destroy()
end

function app:on_menu_save(_)
	local page = self.widget_atlas:get_current_page()
	if page == nil then
		return
	end

	self.widget_atlas:set_modified(page, false)
end

function app:on_menu_save_config(_)
	local page = self.widget_atlas:get_current_page()
	if not page then
		self.frame:SetStatusText("No config is loaded.")
		return
	end

	local filename = page.config_filename
	self:try_save_config(filename)
end

function app:on_menu_save_config_as(_)
	local page = self.widget_atlas:get_current_page()
	if not page then
		self.frame:SetStatusText("No config is loaded.")
		return
	end

	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Save config",
		"resources/configs",
		"",
		"Config files (*.rachel)|*.rachel",
		wx.wxFD_SAVE + wx.wxFD_OVERWRITE_PROMPT
	)
	if file_dialog:ShowModal() == wx.wxID_OK then
		local filename = file_dialog:GetPath()
		self:try_save_config(filename)
	end
end

function app:on_menu_revert(_)
	self.widget_atlas:reload_current()
end

function app:on_menu_close(_)
	self.widget_atlas:close_current()
end

function app:on_menu_split_atlas(_)
	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Load atlas image",
		self.last_atlas_filepath,
		"",
		"Atlas images (character.bmp)|character.bmp",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
	if file_dialog:ShowModal() ~= wx.wxID_OK then
		file_dialog:Destroy()
		return
	end

	local image_filename = fs.normalize(file_dialog:GetPath())
	self.last_atlas_filepath = image_filename
	file_dialog:Destroy()

	split_dialog.query(self.frame, image_filename, function(config_filename, atlas_type, suffix)
		self:split_atlas_images(image_filename, suffix, config_filename, atlas_type)
	end)
end

function app:on_menu_export_tilesheet(event)
	local page = self.widget_atlas:get_current_page()
	if page == nil then
		return
	end

	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Export tilesheet",
		fs.parent(page.filename),
		fs.basename(page.filename),
		"Image files (*.bmp)|*.bmp",
		wx.wxFD_SAVE + wx.wxFD_OVERWRITE_PROMPT
	)
	if file_dialog:ShowModal() ~= wx.wxID_OK then
		file_dialog:Destroy()
		return
	end

	local path = file_dialog:GetPath()
	page.image:SaveFile(path, wx.wxBITMAP_TYPE_BMP)

	self.frame:SetStatusText(("Exported to %s."):format(path))
end

function app:on_menu_export_graphic_folder(event)
	local page = self.widget_atlas:get_current_page()
	if page == nil then
		return
	end

	local dir_dialog = wx.wxDirDialog(
		self.frame,
		"Export graphic folder",
		fs.parent(page.filename),
		wx.wxFD_SAVE + wx.wxDD_DIR_MUST_EXIST
	)
	if dir_dialog:ShowModal() ~= wx.wxID_OK then
		dir_dialog:Destroy()
		return
	end

	local dir = fs.normalize(dir_dialog:GetPath())

	local progress_dialog = wx.wxProgressDialog(
		"Exporting",
		"",
		#page.regions,
		self.frame,
		wx.wxPD_AUTO_HIDE + wx.wxPD_ELAPSED_TIME
	)

	local ok = false

	for i, region in ipairs(page.regions) do
		ok = progress_dialog:Update(i, tostring(region.index))
		if not ok then
			break
		end
		if region.type == "chara" or region.type == "item" then
			local filepath = fs.join(dir, ("%s_%d.bmp"):format(region.type, region.index))
			local cut = chips.get_subimage(page.image, region)
			local original = chips.get_subimage(page.original_image, region)
			if cut:GetData() ~= original:GetData() then
				chips.save_subimage(cut, filepath)
			end
		end
	end

	if ok then
		self.frame:SetStatusText(("Exported %d images to %s."):format(#page.regions, dir))
	end
end

function app:on_menu_quick_set_all(event)
	suffix_dialog.query(self.frame, function(suffix)
		self.widget_atlas:quick_set_all(suffix)
	end)
end

function app:on_menu_reset_all(event)
	local res = wx.wxMessageBox(
		wxT("Are you sure you want to reset all tiles?"),
		wxT("Alert"),
		wx.wxYES_NO + wx.wxCENTRE + wx.wxICON_QUESTION,
		self.frame
	)
	if res ~= wx.wxYES then
		return
	end
	self.widget_atlas:reset_all()
end

function app:split_atlas_images(filepath, suffix, config_filename, atlas_type)
	if suffix == "" then
		self:show_error('Invalid suffix: "' .. suffix .. '"')
	end

	local image = wx.wxImage(filepath)
	local page = self.widget_atlas:get_current_page()

	local atlas_config = assert(loadfile(config_filename))()

	local regions = atlas_config.atlases[atlas_type]

	if regions == nil or regions.tile_prefix == nil then
		self:show_error(
			"Unsupported atlas file: "
				.. atlas_type
				.. '"\n\nSupported files: '
				.. table.concat(table.keys(atlas_config.atlases), ", ")
		)
	end

	local progress_dialog = wx.wxProgressDialog(
		"Splitting",
		"",
		#regions,
		self.frame,
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
		local cut = chips.get_subimage(image, region)
		local original = chips.get_subimage(page.original_image, region)
		if cut:GetData() ~= original:GetData() then
			chips.save_subimage(cut, path)
		end
	end

	progress_dialog:Destroy()
	self.widget_atlas:refresh_current_region()

	if ok then
		wx.wxMessageBox("Saved " .. #regions .. " images.", "Success", wx.wxOK + wx.wxICON_INFORMATION, self.frame)
	end
end

function app:on_update_ui(event)
	event:Enable(self.widget_atlas:has_some())
end

function app:on_menu_exit(_)
	self.frame:Close()
end

function app:on_menu_show_repl(event)
	self.widget_repl:set_visible(event:IsChecked())
end

function app:on_menu_show_all_regions(event)
	config.atlas.show_all_regions = event:IsChecked()
	self.widget_atlas.panel:Refresh()
end

function app:get_info()
	return ("%s ver. %s\n%s built with %s\n%s %s"):format(
		self.name,
		self.version,
		wxlua.wxLUA_VERSION_STRING,
		wx.wxVERSION_STRING,
		jit.version,
		jit.arch
	)
end

function app:on_menu_about(_)
	wx.wxMessageBox(self:get_info(), ("About %s"):format(self.name), wx.wxOK + wx.wxICON_INFORMATION, self.frame)
end

return app
