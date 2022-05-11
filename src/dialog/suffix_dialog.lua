local wx = require("wx")
local ID = require("lib.ids")
local util = require("lib.util")

local suffix_dialog = {}

function suffix_dialog.query(parent, cb)
	local dialog = wx.wxDialog(
		parent or wx.NULL,
		wx.wxID_ANY,
		"Enter filename suffix",
		wx.wxDefaultPosition,
		wx.wxDefaultSize
	)
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

	dialog.text_ctrl = text_ctrl
	dialog.cb = cb

	util.connect_self(dialog, wx.wxID_ANY, wx.wxEVT_COMMAND_TEXT_ENTER, suffix_dialog, "on_text_enter")
	util.connect_self(dialog, ID.SUFFIX_OK, wx.wxEVT_COMMAND_BUTTON_CLICKED, suffix_dialog, "on_ok_button_clicked")
	util.connect_self(
		dialog,
		ID.SUFFIX_CANCEL,
		wx.wxEVT_COMMAND_BUTTON_CLICKED,
		suffix_dialog,
		"on_cancel_button_clicked"
	)
	util.connect_self(dialog, wx.wxEVT_CLOSE_WINDOW, suffix_dialog, "on_close_window")
	util.connect_self(dialog, ID.SUFFIX_OK, wx.wxEVT_UPDATE_UI, suffix_dialog, "on_update_ui_ok_button")

	dialog:Centre()
	dialog:Show(true)

	return util.subclass(dialog, suffix_dialog)
end

function suffix_dialog:on_text_enter(event)
	self:ProcessEvent(wx.wxCommandEvent(wx.wxEVT_COMMAND_BUTTON_CLICKED, ID.SUFFIX_OK))
end

function suffix_dialog:on_ok_button_clicked(event)
	self:Destroy()
	self.cb(self.text_ctrl:GetValue())
end

function suffix_dialog:on_cancel_button_clicked(event)
	self:Destroy()
end

function suffix_dialog:on_close_window(event)
	self:Destroy()
	event:Skip()
end

function suffix_dialog:on_update_ui_ok_button(event)
	local value = self.text_ctrl:GetValue()
	event:Enable(value ~= "")
end

return suffix_dialog
