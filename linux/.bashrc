# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

# If not running interactively, don't do anything
#[ -z "$PS1" ] && return

## This makes sub sourcing work, so can move large chunks to their own file
source $HOME/.subbash/sourcer
export DITA_HOME=/3rdparty/DITA-OT1.8
export DITA_HOME=/3rdparty/DITA-OT1.8
export PATH=$PATH:/usr/lib/openmpi/bin
