###
### GLOBALS
###

LDFLAGS="-L/opt/homebrew/opt/lapack/lib"
CPPFLAGS="-I/opt/homebrew/opt/lapack/include"

ZSH=$(HOME)/.oh-my-zsh
NIX-PATH=/nix/var/nix/profiles/default/bin/nix
NIX-FLAKE=~/.config/nix-darwin/flake.nix
NIX-DARWIN=/run/current-system/sw/bin/darwin-rebuild


###
### USER INPUT
###


### TMUX PLUGINS ###
tmux_plugins = \
	https://github.com/tmux-plugins/tpm.git \
	https://github.com/tmux-plugins/tmux-resurrect.git


###
### MAKE LOGIC
###

### functions ###

# strip out the directories and extension from the provided variable $(call strip_fn, var)
strip_fn = $(notdir $(basename $(1)))

# Returns the filter that matches a git url (http%.git)
git_filter_fn = $(filter http%.git, $(1))

# Filter the variable to match http%.git, strip out the domain to just the repository, map it to name_REPO=<URL>
repo_map_fn = $(foreach repo, $(1), $(eval $(call strip_fn, $(repo))_REPO := $(repo)))

# Transforms a repo into the target $(call repo_to_target_fn, repo, target_dir)
repo_to_target_fn = $(foreach repo, $(1), $(2)/$(call strip_fn, $(repo)))

### Convert user defined targets into filepaths ###

### Oh-My-Zsh
active_plugins := $(zsh_builtin) $(call strip_fn, $(zsh_custom_plugins))

# Set up name_REPO variables and the associated target directory
$(call repo_map_fn, $(zsh_custom_plugins))
zsh_custom_targets := $(call repo_to_target_fn, $(zsh_custom_plugins), $(ZSH)/custom/plugins)

### TMUX
$(call repo_map_fn, $(tmux_plugins))
tmux_custom_targets := $(call repo_to_target_fn, $(tmux_plugins), $(HOME)/.tmux/plugins)

## TODO:
# - Clean call to delete custom plugins?
# - Make themes configurable above
# - BREW pathing is no longer working and everything is installing

### Make targets

.PHONY: all zsh_install zsh_enable_plugins start restart restart_tmux restart_skhd restart_yabai

all: stow install start

### SETUP

.stow-local-ignore:
	ln -s stow/.stow-global-ignore '.stow-local-ignore'

.stowrc:
	ln -s stow/.stowrc '.stowrc'

.PHONY: stow-symlink
stow-symlink: .stow-local-ignore .stowrc

.PHONY: stow
stow:
	for file in *; do \
		if [ -d $${file} ]; then \
			stow $${file}; \
			echo "$${file} stowed."; \
		fi \
	done

.PHONY: setup
setup: stow

### INSTALL

# https://zero-to-nix.com/start/install
$(NIX-PATH):
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# https://github.com/LnL7/nix-darwin?tab=readme-ov-file#step-2-installing-nix-darwin
$(NIX-DARWIN): $(NIX-PATH)
	mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
	cd nix-darwin && nix run nix-darwin -- switch --flake .

.PHONY: install
install: $(NIX-DARWIN)


### REBUILD

.PHONY: nix_rebuild
nix_rebuild: $(NIX-DARWIN)
	cd nix-darwin && darwin-rebuild switch --flake .

.PHONY: rebuild refresh
rebuild: nix_rebuild

refresh: rebuild

### UPDATE

.PHONY: update_nix
update_nix: $(NIX-DARWIN-PATH)
	nix-channel --update darwin
	darwin-rebuild changelog

.PHONY: update
update: update_nix

### CONFIGURE

$(stow_dirs):
	-stow -d ${CURDIR} -t ~ -R $@

stow: $(stow_dirs)

### START
start_zsh: $(stow_dirs)
	/bin/zsh ~/.zshrc

start_yabai: start_zsh
	yabai --start-service

start_skhd: start_zsh
	skhd --start-service

start_tmux: start_zsh
	tmux source-file ~/.tmux.conf

start_gpg:
	gpg-agent --daemon --enable-ssh-support

start: start_zsh start_yabai start_skhd start_gpg

restart_yabai:
	yabai --restart-service

restart_skhd:
	skhd --restart-service

restart_tmux:
	tmux source-file ~/.tmux.conf

restart: restart_yabai restart_skhd restart_tmux
