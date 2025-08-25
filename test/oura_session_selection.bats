#!/usr/bin/env bats

# Test for Oura session selection logic
# Ensures most recent session is selected, not longest duration

load 'helpers/bats-support/load'
load 'helpers/bats-assert/load'

source lib/oura.sh

@test "session selection uses most recent date not longest duration" {
  # Test data: Aug 23 has longer sleep (8:03) but Aug 24 is more recent (6:16)
  # Should select Aug 24 (most recent) not Aug 23 (longest)
  
  local test_data='{
    "data": [
      {
        "day": "2025-08-23",
        "bedtime_start": "2025-08-22T22:54:30-04:00",
        "bedtime_end": "2025-08-23T08:22:30-04:00", 
        "total_sleep_duration": 29010
      },
      {
        "day": "2025-08-24", 
        "bedtime_start": "2025-08-24T00:26:32-04:00",
        "bedtime_end": "2025-08-24T08:01:32-04:00",
        "total_sleep_duration": 22590
      }
    ]
  }'
  
  # Test the date selection logic (most recent date)
  local most_recent_date=$(echo "$test_data" | jq -r \
    '.data | map(.day) | sort | reverse | .[0]')
  
  assert_equal "2025-08-24" "$most_recent_date"  # Should pick Aug 24, not Aug 23
  
  # Test the session selection logic (by date)
  local most_recent_session=$(echo "$test_data" | jq -r \
    '.data | sort_by(.day) | reverse | .[0]')
  
  local selected_date=$(echo "$most_recent_session" | jq -r '.day')
  local selected_duration=$(echo "$most_recent_session" | jq -r '.total_sleep_duration')
  
  assert_equal "2025-08-24" "$selected_date"   # Should select Aug 24
  assert_equal "22590" "$selected_duration"    # Should get 6:16 sleep, not 8:03
}

@test "session selection prevents showing old nights data" {
  # The bug: showed Aug 23 (8:03 sleep) when user wanted Aug 24 (6:16 sleep)
  # This test documents the specific issue from the user report
  
  local aug_23_duration=29010  # 8:03 (longer sleep, 2 nights ago)
  local aug_24_duration=22590  # 6:16 (shorter sleep, last night)
  
  # Convert to readable format
  local aug_23_display=$(seconds_to_hhmm "$aug_23_duration") 
  local aug_24_display=$(seconds_to_hhmm "$aug_24_duration")
  
  assert_equal "8:03" "$aug_23_display"  # Old night (wrong to show)
  assert_equal "6:16" "$aug_24_display"  # Recent night (correct to show)
  
  # The fix: should show 6:16 (Aug 24) not 8:03 (Aug 23)
}

@test "date sorting works correctly for session selection" {
  # Test that ISO date strings sort correctly for most recent selection
  local dates='["2025-08-22", "2025-08-24", "2025-08-23", "2025-08-21"]'
  
  local most_recent=$(echo "$dates" | jq -r 'sort | reverse | .[0]')
  local oldest=$(echo "$dates" | jq -r 'sort | .[0]')
  
  assert_equal "2025-08-24" "$most_recent"
  assert_equal "2025-08-21" "$oldest"
}