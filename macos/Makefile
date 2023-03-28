###
### GLOBALS 
###

LDFLAGS="-L/opt/homebrew/opt/lapack/lib"
CPPFLAGS="-I/opt/homebrew/opt/lapack/include"

BREW=/opt/homebrew
CELLAR=$(BREW)/Cellar
CASK=$(BREW)/Caskroom

HOME=/Users/${USER}

ZSH=$(HOME)/.oh-my-zsh


###
### USER INPUT
###

### BREW TARGETS ###
brew_cellar = git curl ripgrep yaml-language-server tmux
brew_cask = iterm2

### ZSH CUSTOM PLUGINS ###
zsh_custom_plugins = \
	https://github.com/zsh-users/zsh-history-substring-search.git \
	https://github.com/zsh-users/zsh-syntax-highlighting.git \
	https://github.com/zsh-users/zsh-autosuggestions.git
	
### ZSH BUILT IN PLUGINS ###
zsh_builtin = \
	bazel \
	history \
	web-search \
	tmux \
	terraform \
	ripgrep \
	pyenv \
	poetry \
	macos \
	git

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
repo_map_fn = $(foreach repo, $(repo_list), $($(call strip_fn, $(repo))_REPO)=$(repo))

# Transforms a repo into the target $(call repo_to_target_fn, repo, target_dir)
repo_to_target_fn = $(foreach repo, $(call git_filter_fn, $(1)), $(2)/$(call strip_fn, $(repo)))

### Convert user defined targets into filepaths ###

### BREW 
# Transform zsh_cellar into target directories
cellar_targets := $(foreach wrd, $(brew_cellar), $(CELLAR)/$(wrd)) 

# Transform zsh_cask into target directories
cask_targets := $(foreach wrd, $(brew_cask), $(CASK)/$(wrd))

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

### Make targets

.PHONY: all zsh_enable_plugins zsh_install brew_install install

all: install

$(ZSH): 
	$(info "Installing oh-my-zsh")
	sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

$(BREW) $(CELLAR) $(CASK):
	$(info "Installing homebrew..") 
	@/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@echo 'eval "$$(/opt/homebrew/bin/brew shellenv)"' >> $(HOME)/.zprofile
	@eval "$$(/opt/homebrew/bin/brew shellenv)"

$(cellar_targets): $(BREW)
	$(info "Installing $(@F)...")
	brew install $(@F)

$(cask_targets): $(BREW) 
	$(info $@)
	$(info "Installing $(@F)...")
	brew install --cask $(@F) 

brew_install: $(cellar_targets) $(cask_targets)

$(zsh_custom_targets): $(ZSH)
	$(info "Installing $(@F)...")
	git clone $($(@F)_REPO) $@
	
zsh_enable_plugins: $(ZSH) $(zsh_custom_targets)
	$(info "Enabling plugins...")
	@sed -i '' 's|^plugins=\(.*\)|plugins=\($(active_plugins)\)|g' $(HOME)/.zshrc
	@grep "^plugins" $(HOME)/.zshrc

$(ZSH)/custom/themes/powerlevel10k: $(ZSH)
	echo "Installing powerlevel10k theme"
	git clone https://github.com/romkatv/powerlevel10k.git $(ZSH)/custom/themes/powerlevel10k
	sed -i '' 's#^ZSH_THEME.*$$#ZSH_THEME="powerlevel10k/powerlevel10k"#g' ~/.zshrc	

zsh_install: $(ZSH) zsh_enable_plugins $(zsh_custom_targets) $(ZSH)/custom/themes/powerlevel10k

$(tmux_custom_targets): $(CELLAR)/tmux
	$(info "Installing $(@F)..." )
	mkdir -p $@
	git clone $($(@F)_REPO) $@

tmux_install: $(CELLAR)/tmux #$(tmux_custom_targets)

install: zsh_install brew_install tmux_install


