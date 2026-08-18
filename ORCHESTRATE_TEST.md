# Dotfiles Repository

This repository contains personal dotfiles and system configuration for a macOS development environment. It uses GNU Stow to symlink configuration files into place; Nix/nix-darwin declaratively manages packages, system settings, and home-manager profiles. Running `make` from the repo root bootstraps the entire environment.

- **nix-darwin** — Nix flake for declarative macOS system configuration via nix-darwin and home-manager, with custom modules for tools including AWS CLI, ebook-mcp, llm-wiki, and Neovim treesitter grammars.
- **pi** — Configuration and assets for the Pi coding agent, which runs as a subagent-based AI development assistant with planner, orchestrator, and builder profiles.
- **.opencode** — OpenCode AI editor configuration, including migration plan documents and Node.js package definitions for editor extensions and integrations.
- **nvim** — Neovim configuration managed via Stow, with plugin configs for LSP, completion, treesitter, fuzzy finding (fzf-lua), and a broad set of editing and UI enhancements.
- **zsh** — Zsh shell configuration including environment setup, aliases, and Powerlevel10k prompt settings.
