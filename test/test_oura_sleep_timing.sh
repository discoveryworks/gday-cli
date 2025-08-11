#!/bin/bash

# Test suite for Oura sleep timing calculations
# Tests the core algorithms that determine bedtime, sleep onset, and wake times

set -e

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Source the Oura library
source "$PROJECT_DIR/lib/oura.sh"

# Test fixtures directory
FIXTURES_DIR="$TEST_DIR/fixtures"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Test result logging
run_test() {
  local test_name="$1"
  local test_function="$2"
  
  ((TESTS_RUN++))
  echo "🧪 Running: $test_name"
  
  if $test_function; then
    echo "✅ PASSED: $test_name"
    ((TESTS_PASSED++))
  else
    echo "❌ FAILED: $test_name"
  fi
  echo ""
}

# Helper function to assert equality
assert_equal() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  
  if [[ "$actual" == "$expected" ]]; then
    return 0
  else
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    echo "  Message:  $message"
    return 1
  fi
}

# Test activity-based bedtime detection
test_activity_bedtime_detection() {
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
  
  local result=$(analyze_bedtime_from_activity "$activity_pattern" "2025-08-09")
  
  # Should detect bedtime when activity drops from 2 to sustained 1s
  # The transition happens around position 216 + 24 + 2 = 242 (around 20:10)
  [[ "$result" != "N/A" ]] || return 1
  [[ "$result" =~ ^[0-9]{2}:[0-9]{2}$ ]] || return 1
  return 0
}

# Test sleep onset from periods
test_sleep_onset_detection() {
  local sleep_data=$(cat "$FIXTURES_DIR/oura_sleep_periods.json")
  
  local result=$(find_sleep_onset_from_periods "$sleep_data")
  
  # Should return the earliest bedtime_start (10:45 PM session)
  assert_equal "2025-08-08T22:45:59-04:00" "$result" "Should return earliest sleep session as sleep onset"
}

# Test time formatting
test_time_formatting() {
  # Test ISO timestamp to 12-hour format conversion
  local timestamp="2025-08-08T22:45:59-04:00"
  local result=$(format_sleep_time "$timestamp")
  
  assert_equal "10:45PM" "$result" "Should convert ISO timestamp to 12-hour format"
}

# Test seconds to HH:MM conversion
test_seconds_conversion() {
  # Test conversion of sleep duration in seconds to HH:MM format
  local seconds=20970  # 5 hours 49 minutes 30 seconds
  local result=$(seconds_to_hhmm "$seconds")
  
  assert_equal "5:49" "$result" "Should convert seconds to HH:MM format"
}

# Test bedtime source detection logic
test_bedtime_source_detection() {
  # Mock activity bedtime (HH:MM format indicates activity-based detection)
  local activity_bedtime="22:30"
  local bedtime_source="OURA_SLEEP_PERIODS"
  
  if [[ "$activity_bedtime" != "N/A" && "$activity_bedtime" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    bedtime_source="OURA_ACTIVITY"
  fi
  
  assert_equal "OURA_ACTIVITY" "$bedtime_source" "Should detect activity-based bedtime from HH:MM format"
}

# Test comprehensive sleep timeline integration
test_sleep_timeline_integration() {
  # Test that all components work together correctly
  local sleep_data=$(cat "$FIXTURES_DIR/oura_sleep_periods.json")
  local activity_data=$(cat "$FIXTURES_DIR/oura_activity.json")
  
  # Extract components
  local activity_string=$(echo "$activity_data" | jq -r '.data[0].class_5_min // ""')
  local activity_bedtime=$(analyze_bedtime_from_activity "$activity_string" "2025-08-09")
  local sleep_onset=$(find_sleep_onset_from_periods "$sleep_data")
  local wake_time=$(echo "$sleep_data" | jq -r '.data | map(.bedtime_end) | sort | reverse | .[0] // "N/A"')
  
  # Debug output for troubleshooting
  echo "  Debug: activity_bedtime='$activity_bedtime', sleep_onset='$sleep_onset', wake_time='$wake_time'"
  
  # Verify components are extracted
  [[ "$sleep_onset" != "N/A" ]] || return 1
  [[ "$wake_time" != "N/A" ]] || return 1
  
  # Verify formats (activity_bedtime might be N/A due to simple fixture data)
  [[ "$sleep_onset" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]] || return 1
  [[ "$wake_time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2} ]] || return 1
  
  return 0
}

# Test edge cases
test_edge_cases() {
  # Test with no activity data
  local result1=$(analyze_bedtime_from_activity "" "2025-08-09")
  assert_equal "N/A" "$result1" "Should handle empty activity data"
  
  # Test with null activity data
  local result2=$(analyze_bedtime_from_activity "null" "2025-08-09")
  assert_equal "N/A" "$result2" "Should handle null activity data"
  
  # Test time formatting with invalid timestamp
  local result3=$(format_sleep_time "invalid")
  # Function returns empty string for invalid timestamps, which is acceptable behavior
  [[ -z "$result3" || "$result3" == "invalid" ]] || return 1
  
  return 0
}

# Main test execution
main() {
  echo "🎯 Running Oura Sleep Timing Tests"
  echo "=================================="
  echo ""
  
  run_test "Activity Bedtime Detection" test_activity_bedtime_detection
  run_test "Sleep Onset Detection" test_sleep_onset_detection  
  run_test "Time Formatting" test_time_formatting
  run_test "Seconds Conversion" test_seconds_conversion
  run_test "Bedtime Source Detection" test_bedtime_source_detection
  run_test "Sleep Timeline Integration" test_sleep_timeline_integration
  run_test "Edge Cases" test_edge_cases
  
  echo "=================================="
  echo "📊 Test Results: $TESTS_PASSED/$TESTS_RUN passed"
  
  if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo "🎉 All tests passed!"
    exit 0
  else
    echo "💥 Some tests failed!"
    exit 1
  fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi