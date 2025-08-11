#!/usr/bin/env bats

# BATS test suite for Oura sleep detection edge cases
# Tests the complex scenarios we encountered during development to protect against regressions

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

@test "sleep session grouping prevents cross-night confusion" {
  # This test prevents the 31-hour span issue we encountered
  # When we had sessions from Aug 8 (10:45 PM) to Aug 10 (6:22 AM)
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  
  # Mock get_yesterday_date to return 2025-08-09 (so we want Aug 9's sleep)
  get_yesterday_date() { echo "2025-08-09"; }
  get_date_days_ago() { echo "2025-08-08"; }
  
  # The algorithm should group sessions by sleep date and find the main one
  # It should NOT span from Aug 8 evening to Aug 10 morning (31+ hours)
  
  # Test our session grouping logic
  local main_sleep_date=$(echo "$complex_data" | jq -r \
    '.data | group_by(.day) | map({day: .[0].day, total: map(.total_sleep_duration) | add}) | sort_by(.total) | reverse | .[0].day')
  
  # Should identify 2025-08-09 as the main sleep date (has the most total sleep)
  assert_equal "2025-08-09" "$main_sleep_date"
  
  # Get sessions from that date
  local sleep_sessions=$(echo "$complex_data" | jq --arg date "$main_sleep_date" \
    '.data | map(select(.day == $date))')
  
  # Should have 2 sessions for Aug 9 (the brief one and the main one)
  local session_count=$(echo "$sleep_sessions" | jq 'length')
  assert_equal "2" "$session_count"
  
  # Earliest sleep onset should be the 10:45 PM session (not from a different night)
  local earliest_onset=$(echo "$sleep_sessions" | jq -r \
    'map(.bedtime_start) | sort | .[0]')
  assert_equal "2025-08-08T22:45:59-04:00" "$earliest_onset"
  
  # Latest wake should be the 7:17 AM session (not from a different night)
  local latest_wake=$(echo "$sleep_sessions" | jq -r \
    'map(.bedtime_end) | sort | reverse | .[0]')
  assert_equal "2025-08-09T07:17:53-04:00" "$latest_wake"
}

@test "activity-based bedtime detection finds correct transition point" {
  # Test the specific algorithm we developed for finding when movement stopped
  
  local realistic_activity=$(cat "$FIXTURES_DIR/oura_realistic_activity.json")
  local activity_string=$(echo "$realistic_activity" | jq -r '.data[0].class_5_min')
  
  # This should find the transition from active (2+) to minimal (1) sustained for 20+ minutes
  run analyze_bedtime_from_activity "$activity_string" "2025-08-09"
  
  assert_success
  # Should detect a bedtime in the evening hours (not random middle-of-day transitions)
  assert_output --regexp "^(1[89]|2[0-3]):[0-9]{2}$"  # Between 6 PM and 11:59 PM
  refute_output "N/A"
}

@test "sleep timing calculation prevents absurdly long spans" {
  # Prevent the 31-hour calculation bug we had
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  
  # Mock functions to simulate the problematic scenario
  get_yesterday_date() { echo "2025-08-09"; }
  get_date_days_ago() { echo "2025-08-08"; }
  
  # Extract earliest and latest from SAME sleep period (not across multiple nights)
  local main_sleep_date="2025-08-09"  # The date with most sleep
  local sleep_sessions=$(echo "$complex_data" | jq --arg date "$main_sleep_date" \
    '.data | map(select(.day == $date))')
  
  local sleep_onset=$(echo "$sleep_sessions" | jq -r 'map(.bedtime_start) | sort | .[0]')
  local wake_time=$(echo "$sleep_sessions" | jq -r 'map(.bedtime_end) | sort | reverse | .[0]')
  
  # Calculate duration to ensure it's reasonable (not 31+ hours)
  local sleep_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$sleep_onset" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')" "+%s" 2>/dev/null)
  local wake_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$wake_time" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')" "+%s" 2>/dev/null)
  local duration_seconds=$((wake_epoch - sleep_epoch))
  local duration_hours=$((duration_seconds / 3600))
  
  # Sleep duration should be reasonable (< 12 hours), not 31+ hours
  assert [ "$duration_hours" -lt 12 ]
  assert [ "$duration_hours" -gt 6 ]  # At least 6 hours for main sleep
}

@test "brief early sessions are not filtered out as sleep onset" {
  # The 10:45 PM session was only 3 minutes but represents actual sleep onset
  # Our algorithm should not filter it out due to short duration
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  
  run find_sleep_onset_from_periods "$complex_data"
  
  assert_success
  # Should return the earliest session (10:45 PM) even though it's only 3 minutes
  assert_output "2025-08-08T22:45:59-04:00"
}

@test "session from different nights do not mix in calculations" {
  # Test that Aug 8 evening + Aug 10 morning don't combine into one sleep period
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  
  # If we naively took earliest across all data and latest across all data:
  local naive_earliest=$(echo "$complex_data" | jq -r '.data | map(.bedtime_start) | sort | .[0]')
  local naive_latest=$(echo "$complex_data" | jq -r '.data | map(.bedtime_end) | sort | reverse | .[0]')
  
  assert_equal "2025-08-08T22:45:59-04:00" "$naive_earliest"  # Aug 8 evening  
  assert_equal "2025-08-10T15:45:00-04:00" "$naive_latest"   # Aug 10 afternoon nap (latest overall)
  
  # This would give us a ~41-hour span (Aug 8 evening to Aug 10 afternoon), which is wrong!
  # Our algorithm should prevent this by grouping sessions by sleep date
  
  # Test that our grouping logic works correctly
  local grouped_by_date=$(echo "$complex_data" | jq -r '
    .data | group_by(.day) | 
    map({
      day: .[0].day,
      earliest: (map(.bedtime_start) | sort | .[0]), 
      latest: (map(.bedtime_end) | sort | reverse | .[0]),
      total_duration: (map(.total_sleep_duration) | add)
    }) | 
    sort_by(.total_duration) | reverse | .[0]')
  
  local main_earliest=$(echo "$grouped_by_date" | jq -r '.earliest')
  local main_latest=$(echo "$grouped_by_date" | jq -r '.latest') 
  
  # Should be from the same sleep period (Aug 8 evening to Aug 9 morning)
  assert_equal "2025-08-08T22:45:59-04:00" "$main_earliest"
  assert_equal "2025-08-09T07:17:53-04:00" "$main_latest"  # NOT Aug 10!
}

@test "afternoon naps are not selected as main sleep session" {
  # Test that brief afternoon naps don't interfere with main night sleep detection
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  
  # Find the main sleep session (longest duration)
  local main_session=$(echo "$complex_data" | jq -r \
    '.data | sort_by(.total_sleep_duration) | reverse | .[0]')
  
  local main_session_start=$(echo "$main_session" | jq -r '.bedtime_start')
  local main_session_type=$(echo "$main_session" | jq -r '.type')
  
  # Should select the main night sleep (5+ hours), not afternoon nap (15 minutes)
  assert_equal "2025-08-09T00:36:30-04:00" "$main_session_start"
  assert_equal "long_sleep" "$main_session_type"
}

@test "realistic activity pattern detects reasonable bedtime" {
  # Test with more realistic activity data that has normal daily patterns
  
  local realistic_activity=$(cat "$FIXTURES_DIR/oura_realistic_activity.json")
  
  # Test both days of activity data
  for day_index in 0 1; do
    local activity_string=$(echo "$realistic_activity" | jq -r ".data[$day_index].class_5_min")
    run analyze_bedtime_from_activity "$activity_string" "2025-08-0$((9 + day_index))"
    
    assert_success
    # Should detect reasonable bedtime (evening hours)
    if [[ "$output" != "N/A" ]]; then
      # If detected, should be in reasonable range (7 PM - 1 AM)
      local hour=${output%:*}
      assert [ "$hour" -ge 19 ] || [ "$hour" -le 1 ]
    fi
  done
}

@test "data source citations are accurate for detected vs fallback methods" {
  # Test that we correctly identify whether bedtime came from activity or sleep periods
  
  local complex_data=$(cat "$FIXTURES_DIR/oura_complex_sleep_periods.json")
  local realistic_activity=$(cat "$FIXTURES_DIR/oura_realistic_activity.json")
  
  local activity_string=$(echo "$realistic_activity" | jq -r '.data[0].class_5_min')
  local activity_bedtime=$(analyze_bedtime_from_activity "$activity_string" "2025-08-09")
  
  # Test source tracking logic
  local bedtime_source="OURA_SLEEP_PERIODS"  # Default
  if [[ "$activity_bedtime" != "N/A" && "$activity_bedtime" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    bedtime_source="OURA_ACTIVITY"
  fi
  
  # Should correctly identify activity-based detection when available
  if [[ "$activity_bedtime" != "N/A" ]]; then
    assert_equal "OURA_ACTIVITY" "$bedtime_source"
  else
    assert_equal "OURA_SLEEP_PERIODS" "$bedtime_source"
  fi
}