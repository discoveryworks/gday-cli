# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Testing
```bash
npm test         # Run all BATS unit tests
npm run test:all # Run BATS + BDD + installation tests
npm run test:bdd # Run Cucumber BDD tests for time-handling
npm run test:install # Test installation methods (requires Docker)
```

### Manual Testing
```bash
./bin/gday --help     # Test help output
./bin/gday            # Test main functionality (requires setup)
./bin/gday auth       # Re-authenticate with Google Calendar
```

### Development Commands
```bash
chmod +x bin/gday     # Make executable after changes
```

## Architecture Overview

**gday-cli** is a bash-based CLI tool that integrates Google Calendar with daily productivity workflows. The codebase follows a modular shell script architecture:

### Core Structure
- `bin/gday` - Main executable entry point that orchestrates the entire application
- `lib/` - Modular shell script libraries containing specialized functionality
- `config.yml.example` - Template configuration file for user setup

### Library Modules
- `lib/banner.sh` - Version display and visual branding (currently 1.7.0)
- `lib/config.sh` - YAML configuration parsing, calendar validation, and setup management
- `lib/calendar.sh` - Google Calendar integration via gcalcli, event processing, and time formatting
- `lib/oura.sh` - Oura Ring health data integration with sleep, readiness, and activity metrics

### Key Dependencies
- **gcalcli** - Google Calendar CLI (peer dependency)
- **bash/zsh** - Shell environment
- **awk/sed** - Text processing for calendar data parsing

### Configuration System
The tool uses a YAML-based configuration at `~/.config/gday/config.yml` with:
- Calendar names that must match Google Calendar exactly
- Configurable prompt groups with frequency controls (daily, rotating, random)
- Filtered appointments list for customized "Later Today" views

### Data Flow
1. Load and validate YAML configuration
2. Authenticate and fetch calendar data via gcalcli
3. Process calendar events into 30-minute time blocks
4. Generate formatted markdown output with prompts and schedule tables
5. Apply filtering for "Later Today" section

### Time Processing
The calendar system automatically:
- Converts events into 30-minute blocks for consistent formatting
- Handles all-day events separately
- Snaps 15-minute appointments to nearest :00 or :30 time slots
- Adds time-appropriate emoji indicators

## Important Notes

- Version numbers are maintained in multiple locations (banner.sh, package.json, bin/gday) and should be kept in sync
- Calendar names in config must match Google Calendar names exactly (case-sensitive)
- The tool is designed for macOS with specific date command syntax (`date -v`)
- Uses associative arrays in some places - ensure compatibility across shell environments