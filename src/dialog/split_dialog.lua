local wx = require("wx")
local ID = require("lib.ids")
local util = require("lib.util")
local fs = require("lib.fs")
local configs = require("lib.configs")

local split_dialog = {}

function split_dialog.query(parent, atlas_filename, cb)
	local dialog = wx.wxDialog(
		parent or wx.NULL,
		wx.wxID_ANY,
		"Select atlas config",
		wx.wxDefaultPosition,
		wx.wxDefaultSize
	)
	local panel = wx.wxPanel(dialog, wx.wxID_ANY)
	local config_static_text = wx.wxStaticText(panel, wx.wxID_ANY, "Config: ")
	local config_combo_box = wx.wxComboBox(panel, ID.CONFIG_BOX, "", wx.wxDefaultPosition, wx.wxDefaultSize)

	local configs = configs.get_configs()

	for _, d in ipairs(configs) do
		config_combo_box:Append(("%s - %s"):format(d.config.variant, d.config.version))
	end

	local atlas_static_text = wx.wxStaticText(panel, wx.wxID_ANY, "Atlas: ")
	local atlas_combo_box = wx.wxComboBox(panel, wx.wxID_ANY, "", wx.wxDefaultPosition, wx.wxDefaultSize)

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

	local flex_grid_sizer = wx.wxFlexGridSizer(0, 2, 0, 0)
	flex_grid_sizer:AddGrowableCol(1, 0)
	flex_grid_sizer:Add(config_static_text, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5)
	flex_grid_sizer:Add(config_combo_box, 0, wx.wxGROW + wx.wxALIGN_CENTER + wx.wxALL, 5)
	flex_grid_sizer:Add(atlas_static_text, 0, wx.wxALIGN_CENTER_VERTICAL + wx.wxALL, 5)
	flex_grid_sizer:Add(atlas_combo_box, 0, wx.wxGROW + wx.wxALIGN_CENTER + wx.wxALL, 5)
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

	local idx
	for _, seg in ipairs(string.split(atlas_filename, fs.dir_sep)) do
		for i, config in ipairs(configs) do
			if seg == config.folder_name then
				idx = i - 1
			end
		end
	end
	if idx then
		config_combo_box:SetSelection(idx)
	end

	local idx2 = atlas_combo_box:FindString(fs.basename(atlas_filename))
	if idx2 ~= wx.wxNOT_FOUND then
		atlas_combo_box:SetSelection(idx2)
	end

	dialog.config_combo_box = config_combo_box
	dialog.atlas_combo_box = atlas_combo_box
	dialog.text_ctrl = text_ctrl
	dialog.cb = cb
	dialog.configs = configs
	dialog.atlases = {}

	util.connect_self(dialog, ID.CONFIG_BOX, wx.wxEVT_COMBOBOX, split_dialog, "on_config_combo_box_changed")
	util.connect_self(dialog, ID.SUFFIX_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, split_dialog, "on_ok_button_clicked")
	util.connect_self(
		dialog,
		ID.SUFFIX_CANCEL,
		wx.wxEVT_COMMAND_BUTTON_CLICKED,
		split_dialog,
		"on_cancel_button_clicked"
	)
	util.connect_self(dialog, wx.wxEVT_CLOSE_WINDOW, split_dialog, "on_close_window")
	util.connect_self(dialog, ID.SUFFIX_OK, wx.wxEVT_UPDATE_UI, split_dialog, "on_update_ui_ok_button")

	config_combo_box:SetSelection(config_combo_box:GetCount() - 1)

	dialog:Centre()
	dialog:Show(true)

	dialog = util.subclass(dialog, split_dialog)
	dialog:update_atlas_combo_box(dialog)
	return dialog
end

function split_dialog:get_current_config(event)
	local selection = self.config_combo_box:GetCurrentSelection()
	return self.configs[selection + 1]
end

function split_dialog:update_atlas_combo_box()
	self.atlas_combo_box:Clear()
	local config = self:get_current_config()
	if config == nil then
		return
	end
	for _, atlas_name in util.ordered_pairs(table.keys(config.config.atlases)) do
		self.atlas_combo_box:Append(atlas_name)
	end
	self.atlas_combo_box:SetSelection(0)
end

function split_dialog:on_config_combo_box_changed(event)
	self:update_atlas_combo_box()
end

function split_dialog:on_ok_button_clicked(event)
	self:Destroy()

	local config = self:get_current_config()
	if config then
		self.cb(config.file, self.atlas_combo_box:GetStringSelection(), self.text_ctrl:GetValue())
	end
end

function split_dialog:on_cancel_button_clicked(event)
	self:Destroy()
end

function split_dialog:on_close_window(event)
	self:Destroy()
	event:Skip()
end

function split_dialog:on_update_ui_ok_button(event)
	local value = self.text_ctrl:GetValue()
	event:Enable(value ~= "")
end

return split_dialog
