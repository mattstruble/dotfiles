# Dotfiles Repository

This repository contains personal dotfiles and system configuration for a macOS development environment. It uses GNU Stow to symlink configuration files into place and Nix/nix-darwin to declaratively manage packages, system settings, and home-manager profiles. Running `make` from the repo root bootstraps the entire environment.

- **nix-darwin** — Nix flake that drives macOS system configuration via nix-darwin and home-manager; includes module definitions for tools like AWS CLI, ebook-mcp, llm-wiki, and Neovim treesitter grammars.
- **pi** — Configuration and assets for the Pi coding agent, which runs as a subagent-based AI development assistant with planner, orchestrator, and builder profiles.
- **.opencode** — OpenCode AI editor configuration, including prompt drafts and Node.js package definitions for editor extensions and integrations.
- **nvim** — Neovim configuration managed via Stow and extended through nix-darwin modules.
- **zsh** — Zsh shell configuration including environment setup, aliases, and Powerlevel10k prompt settings.
