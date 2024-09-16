local wezterm = require("wezterm")
local config = {}

config.color_scheme = "Catppuccin Mocha"

config.font = wezterm.font("Iosevka Nerd Font Mono", { weight = "Bold", italic = false })
config.font_size = 18

config.enable_tab_bar = false

config.window_background_opacity = 0.7
config.macos_window_background_blur = 50
config.window_padding = {
	left = 5,
	right = 5,
	top = 5,
	bottom = 5,
}
config.window_decorations = "RESIZE"

config.hide_mouse_cursor_when_typing = true

-- config.default_prog = { "/bin/zsh", "-l", "-c", "tmux attach || tmux" }

return config
