# if [[ $(uname -p) == 'arm' ]]; then
#     eval "$(/opt/homebrew/bin/brew shellenv)"
# else
#     eval "$(/usr/local/Homebrew/bin/brew shellenv)"
# fi
eval "$(/opt/homebrew/bin/brew shellenv)"
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
# export TERM='xterm-256color'
export EDITOR='nvim'
export VISUAL='nvim'
export SSH_AUTH_SOCK=`gpgconf --list-dirs agent-ssh-socket`
export GPG_TTY=$(tty)
