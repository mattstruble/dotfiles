local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local slack = sbar.add("item", "widgets.slack", {
	position = "right",
	icon = {
		string = "󰒱",
		font = {
			style = settings.font.style_map["Regular"],
			size = 19.0,
		},
	},
	label = {
		font = { family = settings.font.numbers },
		string = "",
	},
	update_freq = 180,
})

slack:subscribe({ "routine", "system_woke" }, function()
	sbar.exec("lsappinfo info -only StatusLabel 'Slack'", function(slack_info)
		local label = ""

		local color = colors.green

		if slack_info:match("•") then
			color = colors.yellow
			label = "•"
		elseif slack_info:match("%d+") then
			color = colors.red
			label = slack_info:match("%d+")
		end

		slack:set({
			icon = {
				color = color,
			},
			label = { string = label },
		})
	end)
end)

slack:subscribe("mouse.clicked", function(env)
	sbar.exec("open -a 'Slack'")
end)

sbar.add("item", "widgets.slack.padding", {
	position = "right",
	width = settings.group_paddings,
})
