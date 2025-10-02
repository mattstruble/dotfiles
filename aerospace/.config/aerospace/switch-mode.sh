#!/bin/bash

# Manual AeroSpace Mode Switcher
# Usage: ./switch-mode.sh [laptop|monitor]

MODE=$1

if [ -z "$MODE" ]; then
    echo "Usage: $0 [laptop|monitor]"
    echo "  laptop  - Switch to laptop-only workspace layout"
    echo "  monitor - Switch to external monitor workspace layout"
    exit 1
fi

case $MODE in
    "laptop")
        echo "Switching to laptop-only mode..."
        
        # Move apps to laptop-optimized workspaces (letter-based)
        aerospace list-windows --monitor all --app-bundle-id app.zen-browser.zen --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} B 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id org.mozilla.firefox --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} B 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.mitchellh.ghostty --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} T 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id md.obsidian --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} N 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.tinyspeck.slackmacgap --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} S 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id us.zoom.xos --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} Z 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.microsoft.Outlook --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} O 2>/dev/null || true
        
        echo "Switched to laptop mode:"
        echo "  Browser: Workspace B"
        echo "  Terminal: Workspace T"
        echo "  Notes: Workspace N"
        echo "  Slack: Workspace S"
        echo "  Zoom: Workspace Z"
        echo "  Outlook: Workspace O"
        ;;
        
    "monitor")
        echo "Switching to external monitor mode (ultrawide - 2 apps per workspace)..."
        
        # Move apps to ultrawide monitor optimized workspaces (numbered, 2 apps each)
        aerospace list-windows --monitor all --app-bundle-id app.zen-browser.zen --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id org.mozilla.firefox --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.mitchellh.ghostty --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.tinyspeck.slackmacgap --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 2 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id com.microsoft.Outlook --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 2 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id md.obsidian --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 3 2>/dev/null || true
        aerospace list-windows --monitor all --app-bundle-id us.zoom.xos --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 3 2>/dev/null || true
        
        echo "Switched to monitor mode (ultrawide):"
        echo "  Browser + Terminal: Workspace 1"
        echo "  Slack + Outlook: Workspace 2"
        echo "  Notes + Zoom: Workspace 3"
        ;;
        
    *)
        echo "Invalid mode: $MODE"
        echo "Use 'laptop' or 'monitor'"
        exit 1
        ;;
esac
