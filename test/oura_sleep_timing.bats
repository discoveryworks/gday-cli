#!/usr/bin/env bats

# BATS test suite for Oura sleep timing calculations
# Tests the core algorithms that determine bedtime, sleep onset, and wake times

load 'helpers/bats-support/load'
load 'helpers/bats-assert/load'

# Set up test environment
setup() {
  # Get project root directory
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  
  # Source the Oura library
  source "$PROJECT_ROOT/lib/oura.sh"
  
  # Set fixtures directory
  export FIXTURES_DIR="$PROJECT_ROOT/test/fixtures"
}

@test "analyze_bedtime_from_activity detects bedtime from activity transition" {
  # Create a realistic 288-character activity pattern (24 hours × 12 intervals)
  # Day pattern: morning (2), active day (3), evening (2), bedtime transition (2->1), sleep (0)
  local day_part="222233333322223333222233332222333322223333222233332222333322223333"  # 12 hours of day
  local evening_part="222222222222222222222222"  # 2 hours of evening activity (6-8 PM)
  local bedtime_part="2211111111111111"  # 1.5 hours: active (22), then bedtime (1s) - this creates the transition
  local sleep_part="0000000000000000000000000000000000000000000000000000000000000000"  # 5.5 hours sleep
  local wake_part="1111111111111111222222222222"  # 2 hours wake up + morning
  
  # Ensure exactly 288 characters
  local activity_pattern="${day_part}${day_part}${day_part}${evening_part}${bedtime_part}${sleep_part}${wake_part}"
  activity_pattern="${activity_pattern:0:288}"  # Trim to exactly 288 characters
  
  # Test the function
  run analyze_bedtime_from_activity "$activity_pattern" "2025-08-09"
  
  # Should detect bedtime when activity drops from 2 to sustained 1s
  assert_success
  assert_output --regexp "^[0-9]{2}:[0-9]{2}$"
  refute_output "N/A"
}

@test "analyze_bedtime_from_activity handles empty activity data" {
  run analyze_bedtime_from_activity "" "2025-08-09"
  
  assert_success
  assert_output "N/A"
}

@test "analyze_bedtime_from_activity handles null activity data" {
  run analyze_bedtime_from_activity "null" "2025-08-09"
  
  assert_success
  assert_output "N/A"
}

@test "find_sleep_onset_from_periods returns earliest session" {
  local sleep_data=$(cat "$FIXTURES_DIR/oura_sleep_periods.json")
  
  run find_sleep_onset_from_periods "$sleep_data"
  
  assert_success
  assert_output "2025-08-08T22:45:59-04:00"
}

@test "format_sleep_time converts ISO timestamp to readable time" {
  run format_sleep_time "2025-08-08T22:45:59-04:00"
  
  assert_success
  assert_output "10:45PM"
}

@test "format_sleep_time handles invalid timestamps" {
  run format_sleep_time "invalid"
  
  assert_success
  # Function should handle gracefully (returns empty string or input)
}

@test "format_sleep_time handles N/A input" {
  run format_sleep_time "N/A"
  
  assert_success
  assert_output "N/A"
}

@test "seconds_to_hhmm converts seconds to HH:MM format" {
  # Test conversion of sleep duration in seconds to HH:MM format
  run seconds_to_hhmm 20970  # 5 hours 49 minutes 30 seconds
  
  assert_success
  assert_output "5:49"
}

@test "seconds_to_hhmm handles invalid input" {
  run seconds_to_hhmm "invalid"
  
  assert_success
  assert_output "N/A"
}

@test "seconds_to_hhmm handles N/A input" {
  run seconds_to_hhmm "N/A"
  
  assert_success
  assert_output "N/A"
}

@test "extract_oura_score extracts score from data" {
  local sleep_data=$(cat "$FIXTURES_DIR/oura_daily_sleep.json")
  
  run extract_oura_score "$sleep_data" "2025-08-09" "score"
  
  assert_success
  assert_output "80"
}

@test "extract_oura_score returns N/A for missing date" {
  local sleep_data=$(cat "$FIXTURES_DIR/oura_daily_sleep.json")
  
  run extract_oura_score "$sleep_data" "2025-01-01" "score"
  
  assert_success
  assert_output "N/A"
}

@test "calculate_average computes average score" {
  local sleep_data=$(cat "$FIXTURES_DIR/oura_daily_sleep.json")
  
  run calculate_average "$sleep_data" "score"
  
  assert_success
  # Should calculate average of the scores in the fixture data
  assert_output --regexp "^[0-9]+$"
}

@test "get_yesterday_date returns date in YYYY-MM-DD format" {
  run get_yesterday_date
  
  assert_success
  assert_output --regexp "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
}

@test "get_date_days_ago returns correct date format" {
  run get_date_days_ago 7
  
  assert_success
  assert_output --regexp "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
}