local mason_status, mason = pcall(require, "mason")
if not mason_status then
  return
end

local mason_lspconfig_status, mason_lspconfig = pcall(require, "mason-lspconfig")
if not mason_lspconfig_status then
  return
end

local mason_null_ls_status, mason_null_ls = pcall(require, "mason-null-ls")
if not mason_null_ls_status then
  return
end

mason.setup()

mason_lspconfig.setup({
  ensure_installed = {
    "bashls",
    "cmake",
    "dockerls",
    "docker_compose_language_service",
    -- "groovyls",
    "ltex",
    "marksman",
    "pylsp",
    "pyright",
    "sqlls",
    "taplo",
    "terraformls",
    "yamlls",
    "lua_ls",
  },
  automatic_installation = true,
})

mason_null_ls.setup({
  ensure_installed = {
    "prettier",
    "stylua",
    "checkmake",
    "chktex",
    "codespell",
    "hadolint",
    "markdownlint",
    "sqlfluff",
    "ruff",
    "black",
    "actionlint",
    "buildifier",
    "mypy",
    "pylint",
    "terraform_validate",
    "autoflake",
    "beautysh",
    "json_tool",
    "latexindent",
    "terraform_fmt",
    "trim_whitespace",
  },
  automatic_installation = true,
})
