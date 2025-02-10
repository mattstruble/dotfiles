pkgs:

with pkgs;

let
  exe =
    if pkgs.stdenv.targetPlatform.isx86_64 then haskell.lib.justStaticExecutables else pkgs.lib.id;
in
[
  # _1password  # currently labeled as broken
  # _1password-gui
  asciidoctor
  aspell
  aspellDicts.en
  ansible
  ansible-lint
  awscli2
  perl
  black
  cacert
  cargo
  checkmake
  # coreutils
  codespell
  cowsay
  curl
  darwin.cctools
  diffstat
  diffutils
  direnv
  # docker
  # docker-client
  # docker-compose
  docutils
  fd
  ffmpeg
  fortune
  fzf
  fzf-zsh
  # gitMinimal
  git-extras
  git-crypt
  gitlint
  gdtoolkit_4
  gnugrep
  gnumake
  gnupg
  gnuplot
  gnused
  go
  gradle
  groovy
  iperf
  jiq
  jq
  jupyter
  killall
  kubectl
  lazygit
  less
  libtiff
  libevent
  ldns
  libfido2
  luarocks
  markdownlint-cli
  markdownlint-cli2
  mypy
  # neovim
  nix-diff
  nix-index
  nix-info
  nix-prefetch-scripts
  nixpkgs-fmt
  nixpkgs-lint
  nixfmt-rfc-style
  nmap
  nodejs
  nodePackages.csslint
  nodePackages.eslint
  nodePackages.js-beautify
  nodejs
  obsidian
  opam
  openjdk
  opensc
  openssh
  openssl
  openvpn
  pandoc
  pass-git-helper
  pdfgrep
  perl
  perlPackages.ImageExifTool
  pinentry_mac
  plantuml
  postgresql
  pre-commit
  protobufc
  protonmail-bridge
  psrecord
  pstree
  pv
  pyenv
  pyright
  (pkgs.lowPrio python3)
  reattach-to-user-namespace
  rename
  renameutils
  ripgrep
  rsync
  ruby
  ruff
  # rustup
  rustfmt
  shfmt
  shellcheck
  shellharden
  # skhd
  sops
  sqlite
  sqlite-analyzer
  sqldiff
  sqruff
  squashfsTools
  stern
  stow
  terraform
  terraform-ls
  terraform-lsp
  terragrunt
  terminal-notifier
  # texliveSmall
  texlivePackages.lacheck
  tex-fmt
  tmux
  translate-shell
  tree
  tree-sitter
  (pkgs.lowPrio ctags)
  uncrustify
  universal-ctags
  virtualenv
  wget
  write-good
  # yabai
  yamlfmt
  yaml-language-server
  yamllint
  yarn
  yubikey-agent
  yubikey-manager
  yubikey-personalization
  zfs-prune-snapshots
  zoxide
  zsh
  zsh-autosuggestions
  zsh-fzf-history-search
  zsh-powerlevel10k
  zsh-syntax-highlighting
  zsh-vi-mode
]
