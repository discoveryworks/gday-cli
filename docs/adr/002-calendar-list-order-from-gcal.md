# ADR-002: Calendar List Order Determined by Google Calendar

## Status
Accepted

## Context
The calendar validation display shows calendars in a different order than they appear in the user's `config.yml` file. Users may expect the validation output to match their configuration file order.

## Decision
Calendar list order in validation output will be determined by Google Calendar's API response order via `gcalcli list`, not by the order in the user's configuration file.

## Rationale
- **Validation purpose**: Primary goal is showing what Google Calendar has available
- **Discovery**: Helps users identify calendars they might want to configure
- **Troubleshooting**: Makes it easier to spot calendars with access issues
- **API consistency**: Reflects the actual order returned by Google Calendar

## Consequences
- Calendar validation output may not match config file order
- Users see all available calendars, not just configured ones
- Easier to discover new calendars to add to configuration
- Validation remains focused on Google Calendar accessibility rather than user preference ordering