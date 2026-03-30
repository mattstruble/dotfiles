return {
    on_attach = function(client)
        -- Disable hover in favor of ty
        client.server_capabilities.hoverProvider = false
    end,
}
