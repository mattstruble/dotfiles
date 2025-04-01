return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "yamllint",
        "yamlfmt",
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        yaml = { "yamllint" },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        yaml = { "yamlfmt" },
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              validate = true,
              format = { enable = true },
              keyOrdering = false,
              hover = true,
              completion = true,

              schemaStore = {
                enable = false,
                url = "https://www.schemastore.org/api/json/catalog.json"
              },

              -- Schemas detected by filename
              -- https://github.com/aorith/dotfiles/blob/ffdd40c0a4dcd2a07e1c2ecd8931fa7617744af6/topics/neovim/nvim/lua/aorith/plugins/lsp.lua
              schemas = {
                ["https://json.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
                ["https://raw.githubusercontent.com/docker/compose/master/compose/config/compose_spec.json"] =
                "{docker-,}compose*.{yml,yaml}",
                ["https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/argoproj.io/application_v1alpha1.json"] =
                "argocd-application.{yml,yaml}",
                ["https://json.schemastore.org/github-workflow.json"] = ".github/workflows/*.{yml,yaml}",
              },

            }
          }
        }
      }
    }

  },

}
