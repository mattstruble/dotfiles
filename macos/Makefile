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
brew_cellar = git curl ripgrep yaml-language-server
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

###
### MAKE LOGIC 
###

### Convert user defined targets into filepaths ###

# Transform zsh_cellar into target directories
cellar_targets := $(foreach wrd, $(brew_cellar), $(CELLAR)/$(wrd)) 

# Transform zsh_cask into target directories
cask_targets := $(foreach wrd, $(brew_cask), $(CASK)/$(wrd))

# Transform zsh user plugins into target directories 
zsh_user_targets := $(foreach wrd, $(zsh_users), $(ZSH)/custom/plugins/$(wrd))

active_plugins := $(zsh_builtin)  $(notdir $(basename $(zsh_custom_plugins)))

## TODO: 
# - Make singular function for enabling the plugins by doing a sed replace of the plugins in zshrc 
# - Create a lookup for the custom plugin repositories to their respective install targets 
# - Clean call to delete custom plugins? 

### Make targets

all: $(cellar_targets) $(cask_targets) $(zsh_user_targets) $(zsh_builtin)
	$(info $(active_plugins))
.PHONY: all $(zsh_builtin)

$(cellar_targets): $(BREW)
	$(info "Installing $(@F)...")
	brew install $(@F)

$(cask_targets): $(BREW) 
	$(info $@)
	$(info "Installing $(@F)...")
	brew install --cask $(@F) 

$(zsh_user_targets): $(ZSH)
	$(info "Installing $(@F)...")
	#git clone https://github.com/zsh-users/$(@F).git $(ZSH)/custom/plugins/$(@F)
	
$(zsh_builtin): $(ZSH)
	$(info "Enabling $(@F)...")

#all: $(CELLAR)/git $(ZSH)/custom/themes/powerlevel10k

#$(ZSH)/custom/plugins/zsh-history-substring-search: $(ZSH)/custom/plugins/zsh-syntax-hightlingting
#	echo "Installing zsh-history-substring-search"
#	git clone https://github.com/zsh-users/zsh-history-substring-search.git $(ZSH)/custom/plugins/zsh-history-substring-search

#$(ZSH)/custom/plugins/zsh-syntax-highlighting: $(ZSH)
#	echo "Installing zsh-syntax-highlighting"
#	git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $(ZSH)/custom/plugins/zsh-syntax-highlighting

#$(ZSH)/custom/plugins/zsh-autosuggestions: $(ZSH)
#	echo "Installing zsh-autosuggestions"
#	git clone https://github.com/zsh-users/zsh-autosuggestions.git $(ZSH)/custom/plugins/zsh-autosuggestions

#$(ZSH)/custom/themes/powerlevel10k: $(ZSH)
#	echo "Installing powerlevel10k theme"
#	git clone https://github.com/romkatv/powerlevel10k.git $(ZSH)/custom/themes/powerlevel10k
#	sed -i '' 's#^ZSH_THEME.*$$#ZSH_THEME="powerlevel10k/powerlevel10k"#g' ~/.zshrc	

$(ZSH): 
	$(info $@)
	$(info "Installing oh-my-zsh")
	sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

#$(CELLAR)/git: 
#	echo "Installing git..." 
#	brew install git 

#$(CASK)/iterm2:  
#	echo "Installing iterm2..."
#	brew install --cask iterm2 

$(BREW):
	$(info $@) 
	$(info "Installing homebrew..") 
	@/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@echo 'eval "$$(/opt/homebrew/bin/brew shellenv)"' >> $(HOME)/.zprofile
	@eval "$$(/opt/homebrew/bin/brew shellenv)"
