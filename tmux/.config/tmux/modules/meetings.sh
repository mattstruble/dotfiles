#!/bin/bash
# https://github.com/omerxx/dotfiles/blob/master/tmux/scripts/cal.sh

show_meetings() {
	local index=$1
	local icon
	local color
	local result
	local text
	local module

	icon="$(get_tmux_option "@catppuccin_meetings_icon" "")"
	color="$(get_tmux_option "@catppuccin_meetings_color" "$thm_blue")"
	text="$(get_tmux_option "@catppuccin_meetings_text" "#( $HOME/.config/tmux/scripts/ical.sh )")"
	module=$(build_status_module "$index" "$icon" "$color" "$text")

	echo "$module"
}
