BREW=/opt/homebrew
CELLAR=$(BREW)/Cellar
CASK=$(BREW)/Caskroom

HOME=/Users/${USER}

ZSH=$(HOME)/.oh-my-zsh

all: $(CELLAR)/git $(ZSH)/custom/themes/powerlevel10k

$(ZSH)/custom/themes/powerlevel10k: $(ZSH)
	git clone https://github.com/romkatv/powerlevel10k.git $(ZSH)/custom/themes/powerlevel10k
	sed -i '' 's#^ZSH_THEME.*$$#ZSH_THEME="powerlevel10k/powerlevel10k"#g' ~/.zshrc	

$(ZSH): $(CASK)/iterm2
	echo "Installing oh-my-zsh"
	sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

$(CELLAR)/git: 
	echo "Installing git..." 
	brew install git 

$(CASK)/iterm2:  
	echo "Installing iterm2..."
	brew install --cask iterm2 

$(BREW) $(CELLAR) $(CASK): 
	echo "Installing homebrew.." 
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	echo 'eval "$$(/opt/homebrew/bin/brew shellenv)"' >> $(HOME)/.zprofile
	eval "$$(/opt/homebrew/bin/brew shellenv)"
