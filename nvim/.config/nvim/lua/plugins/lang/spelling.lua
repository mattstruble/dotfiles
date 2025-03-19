return {
    {
        "williamboman/mason.nvim",
        opts = {
            ensure_installed = {
                "codespell",
                "write-good",
                "harper-ls"
            },
        },
    },
    {
        "mfussenegger/nvim-lint",
        opts = {
            linters_by_ft = {
                ["*"] = { "codespell", "write_good" },
            },
        },
    },
    {
        "cappyzawa/trim.nvim",
        opts = {},
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                harper_ls = {
                    enabled = true,
                    settings = {
                        userDictPath = "~/.config/harper-ls/dict.txt",
                        ["harper-ls"] = {
                            linters = {
                                BoringWords = true,
                                WrongQuotes = true,
                                ToDoHyphen = true
                            },
                            codeActions = {
                                ForceStable = true,
                            },
                            markdown = {
                                IgnoreLinkTitle = true
                            },
                            diagnosticSeverity = "hint",
                            isolateEnglish = false
                        }
                    }
                }
            }
        }
    }
}
