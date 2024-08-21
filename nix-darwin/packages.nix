pkgs:

with pkgs;

let
  exe =
    if pkgs.stdenv.targetPlatform.isx86_64 then
      haskell.lib.justStaticExecutables
    else
      pkgs.lib.id;
in
[
  asciidoctor
  aspell
  aspellDicts.en
  ansible
  ansible-lint
  awscli2
  perl
  biber
  black
  cacert
  checkmake
  coreutils
  cowsay
  curl
  darwin.cctools
  diffstat
  diffutils
  direnv
  docker
  docker-compose
  docutils
  fd
  ffmpeg
  fortune
  fzf
  fzf-zsh
  gitAndTools.delta
  gitAndTools.gh
  gitAndTools.ghi
  gitAndTools.gist
  gitAndTools.git-absorb
  gitAndTools.git-branchless
  gitAndTools.git-branchstack
  gitAndTools.git-cliff
  gitAndTools.git-codeowners
  gitAndTools.git-crypt
  gitAndTools.git-delete-merged-branches
  (pkgs.lowPrio gitAndTools.git-extras)
  (pkgs.lowPrio gitAndTools.git-fame)
  gitAndTools.git-gone
  gitAndTools.git-hub
  gitAndTools.git-imerge
  gitAndTools.git-lfs
  gitAndTools.git-machete
  gitAndTools.git-my
  gitAndTools.git-octopus
  gitAndTools.git-quick-stats
  gitAndTools.git-quickfix
  gitAndTools.git-recent
  gitAndTools.git-reparent
  gitAndTools.git-repo
  # (pkgs.lowPrio gitAndTools.git-scripts)
  gitAndTools.git-secret
  gitAndTools.git-series
  gitAndTools.git-sizer
  (pkgs.hiPrio gitAndTools.git-standup)
  gitAndTools.git-subrepo
  gitAndTools.git-vendor
  gitAndTools.git-when-merged
  gitAndTools.git-workspace
  gitAndTools.gitRepo
  gitAndTools.gitflow
  gitAndTools.gitls
  gitAndTools.gitstats
  gitAndTools.hub
  gitAndTools.tig
  gitAndTools.top-git
  gnugrep
  gnumake
  gnupg
  gnuplot
  gnused
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
  markdownlint-cli
  neovim
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
  poetry
  postgresql
  pre-commit
  protobufc
  protonmail-bridge
  psrecord
  pstree
  pv
  pyenv
  pyright
  (pkgs.lowPrio python311)
  reattach-to-user-namespace
  rename
  renameutils
  ripgrep
  rsync
  ruby
  ruff
  ruff-lsp
  rustup
  rustfmt
  shfmt
  shellcheck
  shellharden
  skhd
  sops
  sqlite
  sqlite-analyzer
  sqldiff
  squashfsTools
  stern
  stow
  terraform
  terraform-ls
  terraform-lsp
  terminal-notifier
  texliveSmall
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
  yabai
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
  zsh-syntax-highlighting
]
