# AeroSpace Monitor-Based Workspace Configuration

This setup allows you to have different workspace assignments based on whether you're using your laptop alone or with an external monitor.

## Workspace Layouts

### Laptop Mode (Built-in Display Only)
- **Workspace B**: Browser (Zen Browser, Firefox)
- **Workspace T**: Terminal (Ghostty)
- **Workspace N**: Notes (Obsidian)
- **Workspace S**: Slack
- **Workspace Z**: Zoom
- **Workspace O**: Outlook

### Regular External Monitor Mode
Uses the same individual workspace layout as laptop mode:
- **Workspace B**: Browser (Zen Browser, Firefox)
- **Workspace T**: Terminal (Ghostty)
- **Workspace N**: Notes (Obsidian)
- **Workspace S**: Slack
- **Workspace Z**: Zoom
- **Workspace O**: Outlook

### Ultrawide Monitor Mode (3440x1440, 3840x1600, 5120x1440, etc.)
Optimized for ultrawide displays with 2 apps per workspace:
- **Workspace 1**: Browser + Terminal (2 apps side-by-side)
- **Workspace 2**: Slack + Outlook (2 apps side-by-side)
- **Workspace 3**: Notes + Zoom (2 apps side-by-side)

## How to Switch Modes

### 1. Keyboard Shortcuts (Manual Override)
- **Alt + Shift + Ctrl + L**: Force laptop/individual workspace mode
- **Alt + Shift + Ctrl + M**: Force ultrawide/2-app workspace mode

*Note: These shortcuts override auto-detection and manually force a specific mode*

### 2. Manual Script Execution
```bash
# Switch to laptop mode
~/.config/aerospace/switch-mode.sh laptop

# Switch to monitor mode
~/.config/aerospace/switch-mode.sh monitor
```

### 3. Automatic Detection
Run the auto-detection script to automatically switch based on connected monitors:
```bash
~/.config/aerospace/auto-detect-mode.sh
```

**Smart Detection Features:**
- **Ultrawide Detection**: Automatically switches to 2-app layout for ultrawide monitors (3440x1440, 3840x1600, 5120x1440, etc.)
- **Regular External Monitor**: Uses individual workspace layout for standard external monitors
- **Brand Recognition**: Identifies monitors by brand name (DELL, LG, Samsung, etc.)
- **Clamshell Mode**: Works when laptop is closed with external monitor
- **Model Detection**: Recognizes specific ultrawide models (U3818DW, U3419W, CRG9, etc.)

## Setting Up Automatic Switching

### Option 1: Run on Login
Add this to your shell profile (`.zshrc`, `.bashrc`, etc.):
```bash
# Auto-detect AeroSpace mode on terminal startup
~/.config/aerospace/auto-detect-mode.sh >/dev/null 2>&1 &
```

### Option 2: Periodic Check with Cron
Add a cron job to check every minute:
```bash
# Edit crontab
crontab -e

# Add this line:
* * * * * ~/.config/aerospace/auto-detect-mode.sh >/dev/null 2>&1
```

### Option 3: Manual Trigger
Create an alias in your shell profile:
```bash
alias aerospace-detect="~/.config/aerospace/auto-detect-mode.sh"
```

## Files Created

- `switch-mode.sh`: Manual mode switcher
- `auto-detect-mode.sh`: Automatic monitor detection and switching
- `on-monitor-change.sh`: Monitor change handler (for future AeroSpace versions)
- `.current_mode`: State file to track current mode

## Customization

To modify workspace assignments, edit the scripts in `~/.config/aerospace/`:
- Laptop mode assignments are in the "laptop" case of `switch-mode.sh`
- Monitor mode assignments are in the "monitor" case of `switch-mode.sh`

## Troubleshooting

1. **Scripts not executing**: Make sure they're executable with `chmod +x`
2. **Apps not moving**: Check app IDs with `aerospace list-apps`
3. **Mode not switching**: Run `aerospace-detect` manually to see error messages
4. **Notifications not working**: Install `terminal-notifier` with `brew install terminal-notifier`

## App IDs Reference

Current app IDs configured:
- Zen Browser: `app.zen-browser.zen`
- Firefox: `org.mozilla.firefox`
- Ghostty Terminal: `com.mitchellh.ghostty`
- Outlook: `com.microsoft.Outlook`
- Slack: `com.tinyspeck.slackmacgap`
- Zoom: `us.zoom.xos`
- Obsidian: `md.obsidian`
- 1Password: `com.1password.1password` (always floating)

To find app IDs for other applications, run: `aerospace list-apps`
