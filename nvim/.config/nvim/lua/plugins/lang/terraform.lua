vim.lsp.enable({ "terraformls", "tflint" })

return {
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                terraform = { "tflint" },
                hcl = { "tflint" },
            },
        },
    },
    {
        "stevearc/conform.nvim",
        opts = {
            formatters_by_ft = {
                terraform = { "terraform_fmt", "tofu_fmt", stop_after_first = true },
                hcl = { "terraform_fmt", "tofu_fmt", stop_after_first = true },
            },
        },
    },
}
