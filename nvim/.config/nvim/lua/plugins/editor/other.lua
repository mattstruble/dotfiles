return {
	"rgroli/other.nvim",
	name = "other-nvim",
	lazy = true,
	cmd = {
		"Other",
		"OtherTabNew",
		"OtherSplit",
		"OtherVSplit",
	},
	opts = {
		style = {
			border = "rounded",
		},
	},
    -- stylua: ignore
    keys = {
        { "<leader>ll", "<cmd>Other<cr>", desc = "Other"},
        { "<leader>ltn", "<cmd>OtherTabNew<cr>", desc = "Other New Tab"},
        { "<leader>lh", "<cmd>OtherSplit<cr>", desc = "Other Horizontal Split"},
        { "<leader>lv", "<cmd>OtherVSplit<cr>", desc = "Other Vertical Split"},
        { "<leader>lc", "<cmd>OtherClear<cr>", desc = "Other Clear"}
    }
,
}
