Feature: Time Block Processing for Calendar Events
  As a user of gday-cli
  I want consistent and predictable time handling
  So that my schedule displays correctly with proper emoji indicators

  Background:
    Given I have a calendar with various appointment types
    And the system uses 30-minute time blocks as the basic unit

  Scenario: appointments should get clock emoji when no emoji present
    Given an appointment has no emoji
    When the system processes the appointment
    Then a clock emoji showing the appropriate time should be prepended

  Scenario: off-hour appointments should round down and get cherry indicator
    Given an appointment starts at neither :00 nor :30
    When the system processes the appointment
    Then it should round down to earlier time and add 🍒 sub-pomodoro indicator

  Scenario Outline: cherry tomato calculation for off-hour times
    Given an appointment starting at "<appointment_time>"
    When the system calculates the base emoji
    Then it should be treated as "<treated_as>" and show "<emoji>"

    Examples:
      | appointment_time | treated_as | emoji |
      | 10:15am          | 10:00am    | 🕙🍒  |
      | 10:45am          | 10:30am    | 🕥🍒  |
      | 2:15pm           | 2:00pm     | 🕑🍒  |
      | 11:50am          | 11:30am    | 🕦🍒  |

  Scenario: off-hour appointments should snap to boundaries after first block
    Given a multi-block appointment starting at 10:15am
    When the system processes subsequent blocks after the first
    Then subsequent blocks should snap to boundaries: 10:30am, 11:00am
    And not continue the offset pattern: 10:45am, 11:15am

  Scenario Outline: time progression for multi-pomodoro appointments
    Given an appointment starting at "<appointment_start>"
    When the appointment spans multiple pomodoros
    Then the pomodoros should be at "<pomodoro_1>", "<pomodoro_2>", "<pomodoro_3>"

    Examples:
      | appointment_start | pomodoro_1 | pomodoro_2 | pomodoro_3 |
      | 10:15am           | 10:15am    | 10:30am    | 11:00am    |
      | 2:45pm            | 2:45pm     | 3:00pm     | 3:30pm     |
      | 11:50am           | 11:50am    | 12:00pm    | 12:30pm    |

  Scenario: repeated emojis should show cherry only once
    Given a 3-pomodoro appointment at 10:15am
    When the system generates repeated emojis
    Then cherry should appear once: 🕙🍒 → 🕙🍒🕙 → 🕙🍒🕙🕙

  Scenario Outline: emoji repetition patterns
    Given an appointment at an off-hour time
    When displaying pomodoro "<pomodoro_number>"
    Then the display should be "<display>" following "<rule>"

    Examples:
      | pomodoro_number | display  | rule                 |
      | 1               | 🕙🍒      | cherry + base        |
      | 2               | 🕙🍒🕙    | cherry once + repeat |
      | 3               | 🕙🍒🕙🕙  | cherry once + repeat |

  Scenario: pomodoros should be treated as unique appointments
    Given multiple 🍅 at different times
    When the system processes the schedule
    Then each should appear chronologically and hide when conflicted

  Scenario Outline: pomodoro conflict resolution
    Given a pomodoro scheduled at "<time>"
    And a real appointment status of "<real_appointment>"
    When the system processes conflicts
    Then the pomodoro should show: "<pomodoro_shows>"

    Examples:
      | time    | real_appointment | pomodoro_shows |
      | 10:00am | Meeting          | false          |
      | 10:30am | (none)           | true           |
      | 11:00am | Call             | false          |

  Scenario: sorting strategies should group or order appointments
    Given appointments with same title at different times
    When I use "--sort-alpha" flag
    Then appointments should be grouped together
    But when I use "--sort-interleaved" flag
    Then appointments should keep strict chronological order

  Scenario: table formatting should handle emojis correctly
    Given appointments with emojis
    When the system formats the table
    Then time column should be 8 chars wide
    And emojis should count as 2x visual width

  Scenario: hour transitions should handle AM/PM correctly
    Given an appointment crossing hour boundaries
    When the system calculates subsequent block times
    Then AM/PM should transition correctly

  Scenario Outline: AM/PM transition rules
    Given an appointment at "<from_time>"
    When it extends to the next hour
    Then the time should become "<to_time>" following "<rule>"

    Examples:
      | from_time | to_time  | rule           |
      | 11:45am   | 12:00pm  | am→pm at noon  |
      | 11:45pm   | 12:00am  | pm→am at mid   |
      | 12:45pm   | 1:00pm   | stay pm        |
      | 12:45am   | 1:00am   | stay am        |