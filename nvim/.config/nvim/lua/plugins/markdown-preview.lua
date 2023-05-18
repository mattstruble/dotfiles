--------------------------
-- MARKDOWN PREVIEW
--------------------------

return {
	"iamcco/markdown-preview.nvim",
	lazy = true,
	build = function()
		vim.fn["mkdp#util#install"]()
	end,
    -- stylua: ignore
    keys = {
        { "<leader>mp", ":MarkdownPreview", desc = "Markdown Preview"},
        { "<leader>mps", ":MarkdownPreviewStop", desc = "Markdown Preview Stop"},
        { "<leader>mpt", ":MarkdownPreviewToggle", desc = "Markdown Preview Toggle"},
    },
}
