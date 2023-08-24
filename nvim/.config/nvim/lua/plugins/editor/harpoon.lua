--------------------------
-- HARPOON
--------------------------

return {
	"ThePrimeagen/harpoon",
	lazy = true,
	keys = {
		{ "<leader>a", ":lua require('harpoon.mark').add_file<cr>", desc = "Harpoon add file" },
		{ "<C-e>", ":lua require('harpoon.ui').toggle_quick_menu<cr>", desc = "Toggle Harpoon menu" },
		{ "<C-o>", ":lua require('harpoon.ui').nav_file(1)<cr>", desc = "Harpoon File 1" },
		{ "<C-t>", ":lua require('harpoon.ui').nav_file(2)<cr>", desc = "Harpoon File 2" },
		{ "<C-i>", ":lua require('harpoon.ui').nav_file(3)<cr>", desc = "Harpoon File 3" },
		{ "<C-f>", ":lua require('harpoon.ui').nav_file(4)<cr>", desc = "Harpoon File 4" },
	},
}
