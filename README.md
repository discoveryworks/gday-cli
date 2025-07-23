🌞 Why did we build gday?
=============================

My calendar is a canonical source of truth for commitments of my time. But I live and breathe markdown. So gday pulls my calendar into markdown, breaks the day into pomodoro-sized chunks, and adds a little structure to my morning deck-clearing and day-planning.

🌞🌞 Who's it for?
=============================

Me! But maybe you too if you're brain is similarly shaped: terminal-first developers, productivity enthusiasts, and anyone who manages multiple Google Calendars while preferring command-line interfaces over GUI applications. Perfect for those who want calendar integration without leaving their development environment.


🌞🌞🌞 What does it do?
=============================
gday-cli fetches the day'sevents from gCal and renders them as a markdown table, as well as emiting a few configurable productivity prompts.


🌞🌞🌞🌞 How do I use it?
=============================

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


🌞🌞🌞🌞🌞 Extras
=============================

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
