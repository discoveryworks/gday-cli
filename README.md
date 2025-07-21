# gday-cli

Personal calendar and task management CLI tool that integrates Google Calendar with daily productivity workflows.

## Installation

### Homebrew (Recommended)

```bash
brew tap jpb/gday-cli
brew install gday
```

### Manual Installation

```bash
git clone https://github.com/jpb/gday-cli.git
cd gday-cli
chmod +x bin/gday
sudo ln -sf $PWD/bin/gday /usr/local/bin/gday
```

## Quick Start

1. **Install dependencies:**
   ```bash
   pip install gcalcli
   ```

2. **Set up Google Calendar authentication:**
   ```bash
   gday auth
   ```

3. **Create configuration file:**
   ```bash
   mkdir -p ~/.config/gday
   cp config.yml.example ~/.config/gday/config.yml
   # Edit config.yml to add your calendar names
   ```

4. **Run gday:**
   ```bash
   gday              # Show today's schedule
   gday yesterday    # Show yesterday's schedule  
   gday later        # Show only "Later Today" section
   gday --help       # Show all commands
   ```

## Commands

| Command | Description |
|---------|-------------|
| `gday` | Show today's full schedule with prompts and calendar |
| `gday yesterday` | Show yesterday's schedule |
| `gday [day]` | Show most recent Monday/Tuesday/etc schedule |
| `gday later` | Show only "Later Today" filtered appointments |
| `gday filtered` | List appointments that are filtered from "Later Today" |
| `gday auth` | Re-authenticate with Google Calendar |
| `gday --help` | Show help and usage examples |

## Configuration

Edit `~/.config/gday/config.yml`:

```yaml
# Calendar Configuration
calendars:
  - "Work Calendar"
  - "Personal"  
  - "Appointments"

# Prompt Groups with Rotation
prompts:
  - name: "Daily Reflection"
    frequency: daily
    content:
      - "## What's top of mind today?"
      - "## What did you accomplish yesterday?"
  
  - name: "Weekly Planning" 
    frequency: rotating(2)  # Show 2 items, rotate through all
    content:
      - "## What are your 3 priorities this week?"
      - "## What meetings need preparation?"
      - "## What can you delegate or eliminate?"

# Appointments to exclude from "Later Today" section
filtered_appointments:
  - "🍅 Pomodoro Break"
  - "🍜 Lunch"
  - "Personal Time"
```

## Features

- **Smart Calendar Integration**: Fetches events from multiple Google Calendars
- **Configurable Prompts**: YAML-based prompt system with daily/rotating/random frequencies
- **Time Block Formatting**: Automatic 30-minute time blocks with emoji indicators
- **Filtered Views**: Exclude routine appointments from planning sections
- **Multi-day Support**: View any recent day's schedule
- **CLI-Native**: Designed for terminal-based workflows

## Requirements

- macOS (tested on macOS 14+)
- `gcalcli` (Google Calendar CLI)
- `zsh` or `bash` shell
- Google Calendar API access

## Troubleshooting

**"No Events" showing:**
- Run `gday auth` to re-authenticate
- Check calendar names in config match Google Calendar exactly
- Verify `gcalcli agenda today today` works independently

**Permission errors:**
- Ensure `~/.config/gday/config.yml` is readable
- Check Google Calendar sharing settings

**Missing dependencies:**
- Install gcalcli: `pip install gcalcli`
- On first run: `gcalcli init` to set up OAuth

## Contributing

This tool was extracted from a personal dotfiles repository. It's designed for individual productivity workflows but welcomes contributions for broader use cases.

## License

MIT License - see LICENSE file for details.

---

**Version:** 3.10.0  
**Author:** JPB  
**Repository:** https://github.com/jpb/gday-cli