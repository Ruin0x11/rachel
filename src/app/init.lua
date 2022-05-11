local wx = require("wx")
local wxaui = require("wxaui")
local wxlua = require("wxlua")
local util = require("lib.util")
local debug_server = require("app.debug_server")
local atlas = require("app.atlas")
local properties = require("app.properties")
local repl = require("app.repl")
local config = require("config")
local fs = require("lib.fs")
local tile_picker = require("app.tile_picker")
local chips = require("lib.chips")

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

	self.last_folder = "C:/Users/"
	self.last_atlas_filepath = ""

	self.file_menu = wx.wxMenu()
	self.file_menu:Append(ID.OPEN, "&Open...\tCTRL+O", "Open an atlas")
	self.file_menu:Append(ID.SAVE, "&Save...\tCTRL+S", "Save an atlas")
	self.file_menu:Append(ID.SAVE_CONFIG, "Save Config", "Saves the current config")
	self.file_menu:Append(ID.REVERT, "&Reload\tCTRL+R", "Reload the current file from disk")
	self.file_menu:Append(ID.CLOSE, "&Close\tCTRL+W", "Close the current file")
	self.file_menu:Append(ID.EXIT, "E&xit", "Quit the program")
	self.tools_menu = wx.wxMenu()
	self.tools_menu:Append(ID.QUICK_SET_ALL, "&Quick Set All...", "Set all tiles based on suffix")
	self.tools_menu:Append(ID.RESET_ALL, "&Reset All...", "Reset all tiles to those of the original image")
	self.tools_menu:Append(ID.SPLIT_ATLAS, "&Split Atlas...", "Split an existing tile atlas into separate images")
	self.tools_menu:AppendCheckItem(ID.SHOW_REPL, "Show &REPL", "Show the REPL")
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

	self:connect_frame(ID.OPEN, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_open")
	self:connect_frame(ID.REVERT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_revert")
	self:connect_frame(ID.SAVE, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_save")
	self:connect_frame(ID.SAVE_CONFIG, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_save_config")
	self:connect_frame(ID.CLOSE, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_close")
	self:connect_frame(ID.EXIT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_exit")
	self:connect_frame(ID.ABOUT, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_about")

	self:connect_frame(ID.QUICK_SET_ALL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_quick_set_all")
	self:connect_frame(ID.RESET_ALL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_reset_all")
	self:connect_frame(ID.SPLIT_ATLAS, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_split_atlas")
	self:connect_frame(ID.SHOW_REPL, wx.wxEVT_COMMAND_MENU_SELECTED, self, "on_menu_show_repl")

	self:connect_frame(ID.REVERT, wx.wxEVT_UPDATE_UI, self, "on_update_ui_revert")
	self:connect_frame(ID.CLOSE, wx.wxEVT_UPDATE_UI, self, "on_update_ui_close")

	self.wx_app.TopWindow = self.frame
	self.frame:Show(true)

	self.aui = wxaui.wxAuiManager()
	self.aui:SetManagedWindow(self.frame)

	self.widget_repl = repl:new(self, self.frame)
	self.widget_atlas = atlas:new(self, self.frame)
	self.widget_properties = properties:new(self, self.frame)
	self.widget_tile_picker = tile_picker:new(self, self.frame)

	self.debug_server = debug_server:new(self, config.debug_server.port)

	self.aui:Update()

	self:connect_frame(nil, wx.wxEVT_DESTROY, self, "on_destroy")

	self.widget_repl:activate()

	self:try_load_file("C:/Users/yuno/build/elonaplus2.12/graphic/character.bmp")
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

function app:try_load_file(path)
	local ok, err = xpcall(self.widget_atlas.open_file, debug.traceback, self.widget_atlas, path)
	if not ok then
		self:print_error(err)
		self:show_error(("Unable to load file '%s'.\n\n%s"):format(path, err))
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
	self.frame:SetStatusText("Saved config to " .. path)
end

function app:on_menu_open(_)
	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Load serialized file",
		self.last_folder,
		"",
		"Atlas files (*.ratlas)|*.ratlas",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
	if file_dialog:ShowModal() == wx.wxID_OK then
		local path = file_dialog:GetPath()
		self.last_filepath = path
		self:try_load_file(path)
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

	local filename = fs.normalize(page.config_filename)
	self:try_save_config(filename)
end

function app:on_menu_revert(_)
	self.widget_atlas:reload_current()
end

function app:on_menu_close(_)
	self.widget_atlas:close_current()
end

function app:get_suffix(cb)
	local dialog = wx.wxDialog(wx.NULL, wx.wxID_ANY, "Enter filename suffix", wx.wxDefaultPosition, wx.wxDefaultSize)
	local panel = wx.wxPanel(dialog, wx.wxID_ANY)
	local static_text = wx.wxStaticText(panel, wx.wxID_ANY, "Suffix: ")
	local text_ctrl = wx.wxTextCtrl(
		panel,
		ID.SUFFIX_TEXT,
		"",
		wx.wxDefaultPosition,
		wx.wxDefaultSize,
		wx.wxTE_PROCESS_ENTER
	)

	local text_w, text_h = text_ctrl:GetTextExtent("00000.00000")
	text_ctrl:SetInitialSize(wx.wxSize(text_w, -1))
	local flex_grid_sizer = wx.wxFlexGridSizer(0, 3, 0, 0)
	flex_grid_sizer:AddGrowableCol(1, 0)
	flex_grid_sizer:Add(static_text, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5)
	flex_grid_sizer:Add(text_ctrl, 0, wx.wxGROW + wx.wxALIGN_CENTER + wx.wxALL, 5)
	local sizer = wx.wxBoxSizer(wx.wxVERTICAL)

	local button_sizer = wx.wxBoxSizer(wx.wxHORIZONTAL)
	local ok_button = wx.wxButton(panel, ID.SUFFIX_OK, "&OK")
	local cancel_button = wx.wxButton(panel, ID.SUFFIX_CANCEL, "&Cancel")
	button_sizer:Add(ok_button, 0, wx.wxALIGN_CENTER + wx.wxALL, 5)
	button_sizer:Add(cancel_button, 0, wx.wxALIGN_CENTER + wx.wxALL, 5)

	sizer:Add(flex_grid_sizer, 1, wx.wxGROW + wx.wxALIGN_CENTER + wx.wxALL, 5)
	sizer:Add(button_sizer, 0, wx.wxALIGN_CENTER + wx.wxALL, 5)

	panel:SetSizer(sizer)
	sizer:SetSizeHints(dialog)

	dialog:Connect(wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_ENTER, function(event)
		dialog:ProcessEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ID.SUFFIX_OK))
	end)

	dialog:Connect(ID.SUFFIX_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		dialog:Destroy()
		cb(text_ctrl:GetValue())
	end)

	dialog:Connect(ID.SUFFIX_CANCEL, wx.wxEVT_COMMAND_BUTTON_CLICKED, function(event)
		dialog:Destroy()
	end)

	dialog:Connect(wx.wxEVT_CLOSE_WINDOW, function(event)
		dialog:Destroy()
		event:Skip()
	end)

	dialog:Centre()
	dialog:Show(true)
end

function app:on_menu_split_atlas(_)
	local file_dialog = wx.wxFileDialog(
		self.frame,
		"Load atlas image",
		self.last_atlas_filepath,
		"",
		"Image files (*.bmp,*.png,*.jpg,*.jpeg)|*.bmp;*.png;*.jpg;*.jpeg",
		wx.wxFD_OPEN + wx.wxFD_FILE_MUST_EXIST
	)
	if file_dialog:ShowModal() ~= wx.wxID_OK then
		file_dialog:Destroy()
		return
	end

	local path = fs.normalize(file_dialog:GetPath())
	local filename = fs.basename(path)
	self.last_atlas_filepath = path
	file_dialog:Destroy()

	self:get_suffix(function(suffix)
		local config_filename = "resources/configs/plus_2.12.rachel"
		app.split_atlas_images(self, path, suffix, config_filename)
	end)
end

function app:on_menu_quick_set_all(event)
	self:get_suffix(function(suffix)
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

function app:split_atlas_images(filepath, suffix, config_filename)
	if suffix == "" or suffix == "base" then
		self:show_error('Invalid suffix: "' .. suffix .. '"')
	end

	local image = wx.wxImage(filepath)
	local page = self.widget_atlas:get_current_page()

	local atlas_config = assert(loadfile(config_filename))()

	local basename = fs.basename(filepath)
	local regions = atlas_config.atlases[basename]

	if regions == nil then
		self:show_error(
			"Unsupported atlas file: "
				.. basename
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
		local filename = ("chara_%d_%s.bmp"):format(region.index, suffix)
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

	if ok then
		wx.wxMessageBox("Saved " .. #regions .. " images.", "Success", wx.wxOK + wx.wxICON_INFORMATION, self.frame)
	end

	self.app.widget_atlas:refresh_current_region()
end

function app:on_update_ui_revert(event)
	event:Enable(self.widget_atlas:has_some())
end

function app:on_update_ui_close(event)
	event:Enable(self.widget_atlas:has_some())
end

function app:on_menu_exit(_)
	self.frame:Close()
end

function app:on_menu_show_repl(event)
	self.widget_repl:set_visible(event:IsChecked())
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
