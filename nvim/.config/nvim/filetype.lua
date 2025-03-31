vim.filetype.add({
    pattern = {
        [".*html.j2"] = "htmldjango",
        [".*html.jinja"] = "htmldjango",
        [".*html.jinja2"] = "htmldjango",

        [".*container"] = "systemd",
        [".*tofu"] = "terraform",

        [".*Jenkinsfile.*"] = "groovy",
        [".*tex"] = "tex",
        [".*ipynb"] = "jupyter",

        -- ansible
        [".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
        [".*/group_vars/.*/.*%.ya?ml"] = "yaml.ansible",
        [".*/playbook.*%.ya?ml"] = "yaml.ansible",
        [".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/roles/.*/handlers/.*%.ya?ml"] = "yaml.ansible",
        [".*/tasks/.*%.ya?ml"] = "yaml.ansible",
        [".*/molecule/.*%.ya?ml"] = "yaml.ansible",
    }
})
