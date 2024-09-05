###
### GLOBALS
###

LDFLAGS="-L/opt/homebrew/opt/lapack/lib"
CPPFLAGS="-I/opt/homebrew/opt/lapack/include"

ZSH=$(HOME)/.oh-my-zsh
NIX-PATH=/nix/var/nix/profiles/default/bin/nix
NIX-FLAKE=~/.config/nix-darwin/flake.nix
NIX-DARWIN=/run/current-system/sw/bin/darwin-rebuild
XCODE=/Library/Developer/CommandLineTools

ARCH=$(shell uname -p)

ifeq ($(ARCH),arm)
	BREW_HOME=/opt/homebrew
else
	BREW_HOME=/usr/local/Homebrew
endif

BREW=$(BREW_HOME)/bin/brew

###
### MAKE LOGIC
###


### Make targets

.PHONY: all
all: setup start

### INSTALL

$(BREW):
	$(info "Installing homebrew...")
	@/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@eval "$$(/opt/homebrew/bin/brew shellenv)"

# https://zero-to-nix.com/start/install
$(NIX-PATH):
	$(info "Installing nix...")
	curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
	@echo "Hello Nix" | nix run "https://flakehub.com/f/NixOS/nixpkgs/*#ponysay"
	nix-env -f '<nixpkgs>' -iA nixVersions.latest --impure --keep-going

# https://github.com/LnL7/nix-darwin?tab=readme-ov-file#step-2-installing-nix-darwin
$(NIX-DARWIN): $(BREW) $(NIX-PATH)
	$(info "Installing nix-darwin")
	# -sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
	cd nix-darwin && nix run nix-darwin -- switch --flake . --impure

$(XCODE):
	$(info "Installing XCODE...")
	xcode-select --install

.PHONY: install
install: $(BREW) $(XCODE) $(NIX-DARWIN)

### SETUP

.stow-local-ignore:
	ln -s stow/.stow-global-ignore '.stow-local-ignore'

.stowrc:
	ln -s stow/.stowrc '.stowrc'

.PHONY: stow-symlink
stow-symlink: .stow-local-ignore .stowrc

.PHONY: stow
stow: stow-symlink
	for file in *; do \
		if [ -d $${file} ]; then \
			stow $${file}; \
			echo "$${file} stowed."; \
		fi \
	done

unstow:
	for file in *; do \
		if [ -d $${file} ]; then \
			stow -D $${file}; \
			echo "$${file} stowed."; \
		fi \
	done

.PHONY: setup
setup: install


### REBUILD

.PHONY: nix_rebuild
nix_rebuild: $(NIX-DARWIN)
	cd nix-darwin && darwin-rebuild switch --flake . --impure

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

### CLEAN

clean_nix:
	nix-collect-garbage

clean: clean_nix

### CONFIGURE


### START
.PHONY: start_zsh
start_zsh: $(stow_dirs)
	/bin/zsh ~/.zshrc

.PHONY: start_yabai
start_yabai: start_zsh
	yabai --start-service

.PHONY: start_skhd
start_skhd: start_zsh
	skhd --start-service

.PHONY: start_tmux
start_tmux: start_zsh
	tmux source-file ~/.tmux.conf

.PHONY: start_gpg
start_gpg:
	gpg-agent --daemon --enable-ssh-support

.PHONY: start
start: start_zsh start_yabai start_skhd start_gpg

.PHONY: restart_yabai
restart_yabai:
	yabai --restart-service

.PHONY: restart skhd
restart_skhd:
	skhd --restart-service

.PHONY: restart_tmux
restart_tmux:
	tmux source-file ~/.tmux.conf

.PHONY: restart_nix_daemon
restart_nix_daemon:
	sudo launchctl unload /Library/LaunchDaemons/org.nixos.nix-daemon.plist
	sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist

.PHONY: restart
restart: restart_yabai restart_skhd restart_tmux
