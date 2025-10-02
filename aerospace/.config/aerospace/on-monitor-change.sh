#!/bin/bash

# AeroSpace Monitor Configuration Change Handler
# This script runs when monitor configuration changes (connect/disconnect external monitor)

# Get the number of connected monitors
monitor_count=$(aerospace list-monitors | wc -l | tr -d ' ')

# Define workspace assignments for different configurations
if [ "$monitor_count" -eq 1 ]; then
    # Laptop only configuration
    echo "Switching to laptop-only mode"
    
    # Move apps to laptop-optimized workspaces (letter-based)
    aerospace list-windows --monitor all --app-bundle-id app.zen-browser.zen --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} B 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id org.mozilla.firefox --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} B 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.mitchellh.ghostty --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} T 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id md.obsidian --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} N 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.tinyspeck.slackmacgap --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} S 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id us.zoom.xos --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} Z 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.microsoft.Outlook --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} O 2>/dev/null || true
    
else
    # External monitor configuration (ultrawide)
    echo "Switching to external monitor mode (ultrawide - 2 apps per workspace)"
    
    # Move apps to ultrawide monitor optimized workspaces (numbered, 2 apps each)
    aerospace list-windows --monitor all --app-bundle-id app.zen-browser.zen --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id org.mozilla.firefox --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.mitchellh.ghostty --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 1 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.tinyspeck.slackmacgap --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 2 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id com.microsoft.Outlook --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 2 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id md.obsidian --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 3 2>/dev/null || true
    aerospace list-windows --monitor all --app-bundle-id us.zoom.xos --format '%{window-id}' | xargs -I {} aerospace move-node-to-workspace --window-id {} 3 2>/dev/null || true
fi

echo "Monitor configuration change handled: $monitor_count monitor(s) detected"
