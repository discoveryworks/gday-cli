# Time Handling Documentation

This document explains how gday-cli processes time blocks and displays emoji indicators.

## Overview

gday-cli uses 30-minute time blocks (pomodoros) as the basic scheduling unit. It handles various time formats and edge cases to provide consistent, readable schedule output.

## Core Concepts

### Standard Time Mapping
Appointments at standard half-hour boundaries get exact clock emojis:
- 10:00am → 🕙
- 10:30am → 🕥  
- 11:00am → 🕚

### Off-Hour Time Handling
Appointments not on :00 or :30 boundaries get special treatment:
- **First pomodoro**: Shows actual time + cherry indicator
- **Subsequent pomodoros**: Snap to 30-minute boundaries

### Cherry Tomato Indicator (🍒)
The cherry represents "smaller than a 25-minute pomodoro" and indicates the appointment doesn't start on a standard boundary.

## Examples

### Off-Hour Appointment Processing
```
Original: "Meeting at 10:15am for 90 minutes"

Pomodoro 1: 10:15am 🕙🍒 Meeting
Pomodoro 2: 10:30am 🕥🕥 Meeting  
Pomodoro 3: 11:00am 🕚🕚🕚 Meeting
```

### Emoji Repetition Pattern
For multi-pomodoro appointments, cherry appears only once:
- Pomodoro 1: 🕙🍒 (cherry + base)
- Pomodoro 2: 🕙🍒🕙 (cherry once + repeat)
- Pomodoro 3: 🕙🍒🕙🕙 (cherry once + repeat)

### Time Boundary Snapping
| Start Time | Pomodoro 1 | Pomodoro 2 | Pomodoro 3 |
|------------|------------|------------|------------|
| 10:15am    | 10:15am    | 10:30am    | 11:00am    |
| 2:45pm     | 2:45pm     | 3:00pm     | 3:30pm     |
| 11:50am    | 11:50am    | 12:00pm    | 12:30pm    |

### Pomodoro Conflict Resolution
| Time    | Real Appointment | 🍅 Shows |
|---------|------------------|----------|
| 10:00am | Meeting          | No       |
| 10:30am | (none)           | Yes      |
| 11:00am | Call             | No       |

### Sorting Strategies
| Flag               | Behavior                   |
|--------------------|----------------------------|
| `--sort-alpha`     | Group same appointments    |
| `--sort-interleaved` | Strict chronological order |

### Hour Transitions
| From Time | To Time  | Rule          |
|-----------|----------|---------------|
| 11:45am   | 12:00pm  | am→pm at noon |
| 11:45pm   | 12:00am  | pm→am at mid  |
| 12:45pm   | 1:00pm   | stay pm       |
| 12:45am   | 1:00am   | stay am       |

## Configuration

Time handling behavior is configured in `config/time-rules.yml`. Key settings:

- `emoji_mappings`: Clock emoji for each standard time
- `off_hour_rules.cherry_indicator`: Cherry emoji (🍒)
- `time_progression.boundary_minutes`: Standard boundaries [0, 30]
- `pomodoro_rules.conflicts`: How to handle scheduling conflicts
- `sorting_rules.default`: Default sorting strategy

## Implementation

The core logic is implemented in `lib/calendar.sh`:
- `get_emoji_for_time()`: Maps times to emojis
- `get_next_boundary_time()`: Calculates boundary snapping
- `generate_repeated_emoji()`: Handles emoji repetition
- `insert_chronological()`: Maintains chronological order for pomodoros