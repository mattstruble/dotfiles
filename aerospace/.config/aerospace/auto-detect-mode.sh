#!/bin/bash

# Automatic AeroSpace Mode Detection and Switching
# This script detects your monitor configuration and switches modes automatically

# Get monitor information
monitor_info=$(aerospace list-monitors)
monitor_count=$(echo "$monitor_info" | wc -l | tr -d ' ')

# Get current mode from a state file (if it exists)
STATE_FILE="$HOME/.config/aerospace/.current_mode"
current_mode=""
if [ -f "$STATE_FILE" ]; then
    current_mode=$(cat "$STATE_FILE")
fi

# Determine the appropriate mode based on monitor characteristics
# Method 1: Check specifically for ultrawide displays
ultrawide_detected=false
if system_profiler SPDisplaysDataType 2>/dev/null | grep -qE "Ultra-wide|3440 x 1440|3840 x 1600|5120 x 1440|2560 x 1080"; then
    ultrawide_detected=true
fi

# Method 2: Check for known ultrawide monitor models
if echo "$monitor_info" | grep -qE "(U3818DW|U3419W|U3421WE|U4919DW|34WK95U|38WN95C|CRG9|CHG90)"; then
    ultrawide_detected=true
fi

# Method 3: Check if we have any external monitor (for laptop vs external distinction)
external_monitor_detected=false
if echo "$monitor_info" | grep -qE "(DELL|LG|Samsung|BenQ|ASUS|Acer|HP|ViewSonic|AOC|Philips|Studio Display|Pro Display)"; then
    external_monitor_detected=true
fi

# Method 4: Check if built-in display is present (if not, we're likely in clamshell mode)
builtin_display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Built-in")
if [ "$builtin_display_count" -eq 0 ] && [ "$monitor_count" -ge 1 ]; then
    external_monitor_detected=true
fi

# Determine target mode based on display type
if [ "$ultrawide_detected" = true ]; then
    target_mode="monitor"
    echo "Ultrawide monitor detected: $(echo "$monitor_info" | head -1) - using 2-app workspace layout"
elif [ "$external_monitor_detected" = true ]; then
    target_mode="laptop"
    echo "Regular external monitor detected: $(echo "$monitor_info" | head -1) - using individual workspace layout"
else
    target_mode="laptop"
    echo "Using built-in display only"
fi

# Only switch if the mode has changed
if [ "$current_mode" != "$target_mode" ]; then
    echo "Monitor configuration changed: $monitor_count monitor(s) detected"
    echo "Switching from '$current_mode' to '$target_mode' mode"
    
    # Run the mode switcher
    ~/.config/aerospace/switch-mode.sh "$target_mode"
    
    # Save the current mode
    echo "$target_mode" > "$STATE_FILE"
    
    # Send notification (if you have terminal-notifier installed)
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "AeroSpace" -message "Switched to $target_mode mode" -sound default
    fi
else
    echo "Already in $target_mode mode ($monitor_count monitor(s))"
fi
