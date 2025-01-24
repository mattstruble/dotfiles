return {
	{
		"williamboman/mason.nvim",
		opts = {
			ensure_installed = {
				"nixpkgs-fmt",
				"nil_ls",
				"nixfmt",
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				nix = { "nix" },
			},
		},
	},
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				nix = { "nixfmt", "nixpkgs_fmt" },
			},
		},
	},
}
