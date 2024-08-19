{ pkgs, lib, config, hostname, inputs, .. };

let home = builtins.getEnv "HOME";
    tmpdir = "/tmp";
    xdg_configHome = "${home}/.config";
    xdg_dataHome = "${home}/local/share";
    xdg_cacheHome = "${home}/.cache";

in {
    services = {
        nix-daemon.enable = true;
        activate-system.enable = true;
    };

    fonts.packages = with pkgs: [
        ioseveka
    ];

    progams = {
        zsh = {
            enable = true
            enableCompletion = false;
        }
    };

    homebrew = {
        enable = true;
        onActivation = {
            autoUpdate = true;
            upgrade = true;
            cleanup = 'zap';
        };

        taps = [
            '1password/tap'
            'felixkratz/formulae'
            'koekeishiya/formulae'
        ];

        brews = [
            'ansible'
            'ansible-lint'
            'aws-shell'
            'awscli'
            'basictex'
            'biber'
            'bibtex2html'
            'bibtexconv'
            'black'
            'borders'
            'checkmake'
            'cowsay'
            'curl'
            'docker-completion'
            'docker-compose'
            'fd'
            'fish'
            'fortune'
            'fzf'
            'gh'
            'gimme-aws-creds'
            'git'
            'git-crypt'
            'git-lfs'
            'gnupg'
            'groovy'
            'openjdk'
            'groovy'
            'ical-buddy'
            'jq'
            'lazygit'
            'node'
            'npm'
            'openssl'
            'markdown-toc'
            'markdownlint-cli'
            'mas'
            'nmap'
            'openssh'
            'poetry'
            'prettier'
            'pre-commit'
            'protonmail-bridge'
            'pyenv'
            'pyenv-vertualenv'
            'pyright'
            'python-toml'
            'pyyaml'
            'reattach-to-user-namespace'
            'rename'
            'ripgrep'
            'ruff'
            'ruff-lsp'
            'rustup'
            'shellcheck'
            'shellharden'
            'skhd'
            'sops'
            'stern'
            'stow'
            'sqlite'
            'terraform'
            'texlive'
            'tmux'
            'tree-sitter'
            'uncrustify'
            'virtualenv'
            'vulture'
            'wget'
            'write-good'
            'yaml-language-server'
            'yamllint'
            'yarn'
            'ykman'
            'yubikey-agent'
            'yubikey-personalization'
            'zoxide'
        ];

        casks = [
                '1password-cli'
                'discord'
                'docker'
                'floorp'
                'flux'
                'font-iosevka-nerd-font'
                'godot'
                'iterm2'
                'mactex'
                'menuwhere'
                'monitorcontrol'
                'obsidian'
                'vagrant'
                'virtualbox'
                'wacom-tablet'
                'wezterm'
                'yubico-yubikey-manager'
        ];

        masApps = {
                'CopyClip' = 595191960;
                'Dropover' = 1355679052;
                'Hidden Bar' = 1452453066;
                'Pure Paste' = 1611378436;
                'Slack' = 803453959;
                'Velja' = 1607635845;
        };
    };


}
