return {
    settings = {
        ["harper-ls"] = {
            userDictPath = "~/.config/harper-ls/dict.txt",
            linters = {
                BoringWords = true,
                WrongQuotes = true,
                ToDoHyphen = true,
            },
            codeActions = {
                ForceStable = true,
            },
            markdown = {
                IgnoreLinkTitle = true,
            },
            diagnosticSeverity = "hint",
            isolateEnglish = false,
        },
    },
}
