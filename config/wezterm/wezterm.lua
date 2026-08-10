local wezterm = require("wezterm")

local config = wezterm.config_builder()

----------------------------------------------------
-- Theme
----------------------------------------------------
local themes = {
	dark = {
		color_scheme = "Kanagawa (Wave)",
		foreground = "#dcd7ba",
		background = "#1f1f28",
		tab_bar_bg = "#363646",
		window_background_opacity = 0.85,
		macos_window_background_blur = 20,
		tab_active_fg = "#dcd7ba",
		tab_inactive_fg = "#727169",
		tab_separator_fg = "#363646",
		tab_accent = "#98bb6c",
		tab_dot_inactive = "#54546d",
	},
	light = {
		color_scheme = "Tokyo Night Day",
		foreground = "#3760bf",
		background = "#e1e2e7",
		tab_bar_bg = "#eaebef",
		window_background_opacity = 1.0,
		macos_window_background_blur = 0,
		tab_active_fg = "#3760bf",
		tab_inactive_fg = "#8990b3",
		tab_separator_fg = "#c4c8da",
		tab_accent = "#587539",
		tab_dot_inactive = "#a8aecb",
	},
}

-- ここを "dark" / "light" で切り替え
local theme = themes["dark"]

local kanagawa_wave = {
	foreground = "#dcd7ba",
	background = "#1f1f28",
	cursor_bg = "#c8c093",
	cursor_fg = "#c8c093",
	cursor_border = "#c8c093",
	selection_fg = "#c8c093",
	selection_bg = "#2d4f67",
	scrollbar_thumb = "#16161d",
	split = "#16161d",
	ansi = { "#090618", "#c34043", "#76946a", "#c0a36e", "#7e9cd8", "#957fb8", "#6a9589", "#c8c093" },
	brights = { "#727169", "#e82424", "#98bb6c", "#e6c384", "#7fb4ca", "#938aa9", "#7aa89f", "#dcd7ba" },
	indexed = { [16] = "#ffa066", [17] = "#ff5d62" },
}

config.automatically_reload_config = true
config.font = wezterm.font_with_fallback({
	"Hack Nerd Font",
	"HackGen Console NF",
	"Noto Color Emoji",
})
config.font_size = 14.0
config.use_ime = true
config.window_background_opacity = theme.window_background_opacity
config.macos_window_background_blur = theme.macos_window_background_blur
config.force_reverse_video_cursor = true
config.color_schemes = {
	["Kanagawa (Wave)"] = kanagawa_wave,
}
config.color_scheme = theme.color_scheme

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true
-- Stitch スタイル：fancy モードで上下余白を確保
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.tab_max_width = 32

-- タブバー：fancy モード用フレーム設定（薄い背景＋上下余白）
config.window_frame = {
	inactive_titlebar_bg = theme.tab_bar_bg,
	active_titlebar_bg = theme.tab_bar_bg,
	font = wezterm.font({ family = "Hack Nerd Font", weight = "Bold" }),
	font_size = 12.0,
}

-- タブバーを背景色に合わせる
config.window_background_gradient = {
	colors = { theme.background, theme.background },
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- nightlyのみ使用可能
-- タブの閉じるボタンを非表示
config.show_close_tab_button_in_tabs = false

-- Stitch スタイル：タブバー背景=ウィンドウ背景・タブ単色
config.colors = {
	foreground = theme.foreground,
	background = theme.background,
	tab_bar = {
		background = theme.tab_bar_bg,
		inactive_tab_edge = "none",
		active_tab = {
			bg_color = theme.tab_bar_bg,
			fg_color = theme.tab_active_fg,
		},
		inactive_tab = {
			bg_color = theme.tab_bar_bg,
			fg_color = theme.tab_inactive_fg,
		},
		inactive_tab_hover = {
			bg_color = theme.tab_bar_bg,
			fg_color = theme.tab_active_fg,
			italic = false,
		},
		new_tab = {
			bg_color = theme.tab_bar_bg,
			fg_color = theme.tab_inactive_fg,
		},
		new_tab_hover = {
			bg_color = theme.tab_bar_bg,
			fg_color = theme.tab_active_fg,
		},
	},
}

-- Stitch スタイル：先頭ドット + タブ間 │ + アクティブのみ下線
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local is_last = tab.tab_index == (#tabs - 1)
	local fg = theme.tab_inactive_fg
	local dot_color = theme.tab_dot_inactive
	if tab.is_active then
		fg = theme.tab_accent
		dot_color = theme.tab_accent
	end

	local title = wezterm.truncate_right(tab.active_pane.title, max_width - 6)

	local elements = {
		{ Attribute = { Underline = "None" } },
		{ Attribute = { Intensity = "Normal" } },
		{ Foreground = { Color = dot_color } },
		{ Text = " ● " },
		{ Foreground = { Color = fg } },
		{ Attribute = { Intensity = "Bold" } },
		{ Attribute = { Underline = tab.is_active and "Single" or "None" } },
		{ Text = title },
		{ Attribute = { Underline = "None" } },
		{ Text = " " },
	}

	if not is_last then
		table.insert(elements, { Foreground = { Color = theme.tab_separator_fg } })
		table.insert(elements, { Text = "│" })
	end

	return elements
end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.leader = { key = " ", mods = "CTRL", timeout_milliseconds = 2000 }

config.mouse_bindings = {
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Up = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Down = { streak = 1, button = "Middle" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Up = { streak = 1, button = "Middle" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Up = { streak = 2, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
	{
		event = { Up = { streak = 3, button = "Left" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
}

require("claude_session").apply_to_config(config)

return config
