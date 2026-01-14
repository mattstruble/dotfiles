return {
    { "qvalentin/helm-ls.nvim", ft = "helm" },
    {
        "mason-org/mason.nvim",
        opts = {
            ensure_installed = {
                "helm-ls"
            }
        }
    },
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "helm-ls",
            },
        },
    },
}
