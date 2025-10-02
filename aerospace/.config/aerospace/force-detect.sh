#!/bin/bash

# Force AeroSpace Mode Detection
# This script clears the current mode state and forces a fresh detection

STATE_FILE="$HOME/.config/aerospace/.current_mode"

echo "Forcing fresh mode detection..."

# Clear the state file to force detection
if [ -f "$STATE_FILE" ]; then
    echo "Clearing previous mode state: $(cat "$STATE_FILE")"
    rm "$STATE_FILE"
fi

# Run auto-detection
~/.config/aerospace/auto-detect-mode.sh
