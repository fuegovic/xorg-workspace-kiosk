# Xorg Workspace Kiosk

Automated multi-workspace kiosk system for Ubuntu/Linux that launches applications and webpages across different workspaces in fullscreen mode with automatic crash recovery.

## Features

- 🚀 **Multiple Workspaces**: Launch different apps/webpages on separate workspaces
- 🌐 **Browser Support**: Chromium and Firefox in kiosk mode
- 🎯 **Custom Applications**: Launch any application fullscreen
- 🔄 **Auto Recovery**: Automatic restart on crash via systemd
- 💚 **Health Monitoring**: Periodic checks and auto-restart of missing windows
- ⚙️ **Interactive Setup**: Easy configuration wizard or manual config file
- 📝 **Logging**: Full activity logging for debugging

## Use Cases

- Digital signage displays
- Monitoring dashboards
- Information kiosks
- Multi-screen control centers
- Home automation displays
- Industrial control panels

## Requirements

- **OS**: Ubuntu 22.04+ (or Debian-based Linux)
- **Display Server**: Xorg (NOT Wayland)
- **Desktop Environment**: GNOME, XFCE, KDE, or any DE with workspace support

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/xorg-workspace-kiosk.git
cd xorg-workspace-kiosk

# Run interactive installer
chmod +x install.sh
./install.sh
```

The installer will:
1. Guide you through workspace configuration
2. Install dependencies (`wmctrl`, `xdotool`, `chromium-browser`)
3. Set up systemd service for auto-start
4. Configure health monitoring

## Configuration

### Interactive Setup

When you run `install.sh` without an existing `workspaces.conf`, you'll be prompted:

```
How many workspaces do you want to configure? (1-10): 3

--- Workspace 0 ---
What would you like to launch here?
  1) Chromium (webpage)
  2) Firefox (webpage)
  3) Custom application
Choice (1-3): 1
Enter URL (include https://): https://grafana.example.com
Friendly name (optional): Monitoring Dashboard
...
```

### Manual Configuration

Create `workspaces.conf` in the project directory:

```ini
[workspace-0]
type = chromium
url = https://dashboard.example.com
name = Dashboard

[workspace-1]
type = firefox
url = https://monitoring.example.com
name = Monitoring

[workspace-2]
type = app
command = /usr/bin/spotify
name = Music Player
```

**Configuration Options:**

| Field | Description | Required |
|-------|-------------|----------|
| `type` | `chromium`, `firefox`, or `app` | Yes |
| `url` | Website URL (for chromium/firefox) | For browsers |
| `command` | Full command/path (for app) | For apps |
| `name` | Friendly name for logging | No |

### Supported Application Types

#### Chromium Browser
```ini
[workspace-0]
type = chromium
url = https://example.com
```

#### Firefox Browser
```ini
[workspace-1]
type = firefox
url = https://example.com
```

#### Custom Application
```ini
[workspace-2]
type = app
command = /full/path/to/application --args
```

## Usage

### Start/Stop Service

```bash
# Start workspace automation
systemctl --user start workspace-automation.service

# Stop workspace automation
systemctl --user stop workspace-automation.service

# Restart workspace automation
systemctl --user restart workspace-automation.service

# Check status
systemctl --user status workspace-automation.service
```

The service auto-starts on login.

### View Logs

```bash
# View systemd service logs
journalctl --user -u workspace-automation.service -f

# View automation script logs
tail -f ~/workspace-automation.log

# View health check logs
tail -f ~/kiosk-health.log
```

### Disable Screen Blanking

To keep displays on 24/7:

```bash
xset s off         # Disable screen saver
xset -dpms         # Disable power management
xset s noblank     # Prevent blanking
```

These commands are applied automatically via `~/.xinitrc` during installation.

## Troubleshooting

### Switching from Wayland to Xorg

1. Log out
2. At login screen, click the gear/settings icon
3. Select "Ubuntu on Xorg" (or similar)
4. Log back in

### Windows Opening as Tabs

Make sure you're **not** using Snap Chromium:

```bash
# Check if Snap version is installed
snap list | grep chromium

# Remove Snap version
sudo snap remove chromium

# Install apt version
sudo apt install chromium-browser
```

### Windows Not Appearing

```bash
# Check X server
echo $DISPLAY
xset q

# Verify configuration
cat ~/.config/workspaces.conf

# Check logs for errors
journalctl --user -u workspace-automation.service -n 50
```

### Workspace Count

Ubuntu GNOME defaults to 4 workspaces. To add more:

**Settings** → **Multitasking** → **Workspaces** → Set to "Fixed" with desired count

### Application Not Launching

Ensure you're using **full absolute paths**:

```ini
# ❌ Wrong
command = python script.py

# ✓ Correct
command = /home/username/.venv/bin/python /home/username/script.py
```

## Advanced Configuration

### Adjust Launch Timing

Edit `~/bin/workspace-launcher.sh`:

- Change `sleep 5` in launch functions (wait after launching)
- Change `sleep 3` in main loop (delay between workspaces)

### Health Check Frequency

```bash
crontab -e
```

Change `*/5` to desired interval (e.g., `*/10` for every 10 minutes).

### Custom Browser Flags

Edit `~/bin/workspace-launcher.sh` and modify:
- `CHROMIUM_BASE_FLAGS`
- `FIREFOX_BASE_FLAGS`

## Architecture

```
┌─────────────────────────────────────┐
│     Login → systemd user service     │
└──────────────┬──────────────────────┘
               │
┌──────────────▼──────────────────────┐
│   workspace-launcher.sh              │
│   - Reads workspaces.conf            │
│   - Launches apps sequentially       │
│   - Assigns to workspaces            │
│   - Applies fullscreen               │
└──────────────┬──────────────────────┘
               │
    ┌──────────┴──────────┐
    │                     │
┌───▼───────┐    ┌───────▼─────┐
│ Chromium  │    │   Firefox   │
│ / Firefox │    │   / Apps    │
│ Windows   │    │   Windows   │
└───────────┘    └─────────────┘
    │                     │
┌───▼─────────────────────▼──────┐
│   Health Monitor (cron)         │
│   - Checks every 5 min          │
│   - Restarts if windows missing │
└─────────────────────────────────┘
```

### Technology Stack

- **Display**: Xorg
- **Window Management**: `wmctrl`, `xdotool`
- **Browsers**: Chromium, Firefox (kiosk mode)
- **Service Management**: systemd user services
- **Monitoring**: Cron + bash scripts

## Uninstallation

```bash
# Stop and disable service
systemctl --user stop workspace-automation.service
systemctl --user disable workspace-automation.service

# Remove files
rm ~/.config/systemd/user/workspace-automation.service
rm ~/.config/workspaces.conf
rm ~/bin/workspace-launcher.sh
rm ~/bin/kiosk-health-check.sh

# Remove cron job
crontab -e  # Delete the kiosk-health-check line

# Remove logs (optional)
rm ~/workspace-automation.log ~/kiosk-health.log
```

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details

## Credits

Built with:
- [wmctrl](http://tripie.sweb.cz/utils/wmctrl/) - X window management
- [xdotool](https://www.semicomplete.com/projects/xdotool/) - X11 automation

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/yourusername/xorg-workspace-kiosk/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/yourusername/xorg-workspace-kiosk/discussions)

---

**Made for Ubuntu/Linux kiosk deployments** 🐧
