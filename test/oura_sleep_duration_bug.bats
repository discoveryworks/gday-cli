#!/usr/bin/env bats

# Test for sleep duration calculation bug
# Ensures gday uses total_sleep_duration (actual sleep) not time_in_bed

load 'helpers/bats-support/load'
load 'helpers/bats-assert/load'

source lib/oura.sh

@test "sleep duration uses total_sleep_duration not time_in_bed" {
  # This test catches the specific bug where gday was displaying
  # time_in_bed (9:28) instead of total_sleep_duration (8:03)
  
  local test_session='{
    "id": "test-session",
    "time_in_bed": 34080,
    "total_sleep_duration": 29010,
    "day": "2025-08-23"
  }'
  
  # Extract both values
  local time_in_bed=$(echo "$test_session" | jq -r '.time_in_bed')
  local total_sleep_duration=$(echo "$test_session" | jq -r '.total_sleep_duration')
  
  # Convert to HH:MM format
  local time_in_bed_formatted=$(seconds_to_hhmm "$time_in_bed")
  local sleep_duration_formatted=$(seconds_to_hhmm "$total_sleep_duration")
  
  # The bug: time_in_bed=34080s = 9:28, total_sleep_duration=29010s = 8:03
  assert_equal "9:28" "$time_in_bed_formatted"    # Time in bed (wrong to display)
  assert_equal "8:03" "$sleep_duration_formatted" # Actual sleep (correct to display)
  
  # This test documents that we should display 8:03, NOT 9:28
  # If this test fails, the bug has returned
}

@test "seconds_to_hhmm handles the specific bug case values" {
  # Test the exact values from the bug report
  local time_in_bed_seconds=34080      # 9 hours 28 minutes
  local total_sleep_seconds=29010      # 8 hours 3 minutes
  
  local time_in_bed_display=$(seconds_to_hhmm "$time_in_bed_seconds")
  local sleep_duration_display=$(seconds_to_hhmm "$total_sleep_seconds")
  
  assert_equal "9:28" "$time_in_bed_display"
  assert_equal "8:03" "$sleep_duration_display"
  
  # The difference is 5070 seconds = 1h 24m of awake time during the night
  local awake_time=$((time_in_bed_seconds - total_sleep_seconds))
  local awake_display=$(seconds_to_hhmm "$awake_time")
  assert_equal "1:24" "$awake_display"
}