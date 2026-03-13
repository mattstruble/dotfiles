return {
    "ggml-org/llama.vim",
    init = function()
        vim.g.llama_config = {
            show_info = 0,
            auto_fim = true,
            keymap_fim_accept = "<A-Space>",
            keymap_fim_trigger = "<A-f>",
            keymap_fim_accept_word = "<A-w>",
        }
    end,
}
