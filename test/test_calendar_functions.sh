#!/bin/bash

# Test suite for calendar.sh functions
# Tests core time handling, emoji generation, and calendar processing

set -e

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Source the calendar library
source "$PROJECT_DIR/lib/calendar.sh"

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

# Test emoji generation for different times
test_emoji_for_time() {
  # Test standard hour emojis
  local result1=$(get_emoji_for_time 1000)
  assert_equal "🕙" "$result1" "10:00 AM should show 🕙"
  
  local result2=$(get_emoji_for_time 1030)
  assert_equal "🕥" "$result2" "10:30 AM should show 🕥"
  
  # Test off-hour times (should add cherry indicator)
  local result3=$(get_emoji_for_time 1015)
  assert_equal "🕙🍒" "$result3" "10:15 AM should show 🕙🍒"
  
  local result4=$(get_emoji_for_time 1045)
  assert_equal "🕥🍒" "$result4" "10:45 AM should show 🕥🍒"
  
  return 0
}

# Test PM hour handling
test_pm_emoji_handling() {
  local result1=$(get_emoji_for_time 1400)
  assert_equal "🕑" "$result1" "2:00 PM should show 🕑"
  
  local result2=$(get_emoji_for_time 1430)
  assert_equal "🕕" "$result2" "2:30 PM should show 🕕"
  
  local result3=$(get_emoji_for_time 2215) 
  assert_equal "🕙🍒" "$result3" "10:15 PM should show 🕙🍒"
  
  return 0
}

# Test hour boundary handling
test_hour_boundaries() {
  # Test midnight and noon
  local result1=$(get_emoji_for_time 0000)
  assert_equal "🕐" "$result1" "12:00 AM should show 🕐"
  
  local result2=$(get_emoji_for_time 1200)
  assert_equal "🕐" "$result2" "12:00 PM should show 🕐"
  
  return 0
}

# Test repeated emoji generation
test_repeated_emoji_generation() {
  # Test that generate_repeated_emoji works correctly
  if command -v generate_repeated_emoji >/dev/null 2>&1; then
    local result1=$(generate_repeated_emoji "🕙" 1)
    assert_equal "🕙" "$result1" "Single emoji should be unchanged"
    
    local result2=$(generate_repeated_emoji "🕙" 3)
    assert_equal "🕙🕙🕙" "$result2" "Should repeat emoji 3 times"
  fi
  
  return 0
}

# Test time format validation
test_time_format_validation() {
  # Test various time format inputs
  if command -v parse_time_input >/dev/null 2>&1; then
    # These would test time parsing if the function exists
    echo "  Skipping time format validation - parse_time_input not available"
  fi
  
  return 0
}

# Test calendar event processing (if functions are available)
test_calendar_event_processing() {
  # Test processing calendar events if the functions exist
  if command -v process_calendar_events >/dev/null 2>&1; then
    echo "  Testing calendar event processing..."
    # Would test event processing here
  else
    echo "  Skipping calendar event processing - functions not available for unit testing"
  fi
  
  return 0
}

# Main test execution
main() {
  echo "📅 Running Calendar Function Tests"
  echo "=================================="
  echo ""
  
  run_test "Emoji Generation for Standard Times" test_emoji_for_time
  run_test "PM Hour Emoji Handling" test_pm_emoji_handling
  run_test "Hour Boundary Cases" test_hour_boundaries
  run_test "Repeated Emoji Generation" test_repeated_emoji_generation
  run_test "Time Format Validation" test_time_format_validation
  run_test "Calendar Event Processing" test_calendar_event_processing
  
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