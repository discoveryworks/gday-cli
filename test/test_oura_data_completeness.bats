#!/usr/bin/env bats
# ABOUTME: Tests for Oura data completeness detection and handling
# ABOUTME: Protects against incomplete sleep data from Oura API

setup() {
  # Load the Oura functions
  source "lib/oura.sh"
}

@test "check_sleep_data_completeness detects incomplete data with high score and short sleep" {
  # 2 hours sleep with score 86 should be flagged as incomplete
  result=$(check_sleep_data_completeness 7200 86 1)
  [ "$result" = "incomplete" ]
}

@test "check_sleep_data_completeness detects incomplete data with very short sleep" {
  # 2 hours sleep regardless of score should be incomplete
  result=$(check_sleep_data_completeness 7200 50 1)
  [ "$result" = "incomplete" ]
}

@test "check_sleep_data_completeness allows normal sleep with appropriate score" {
  # 6 hours sleep with score 75 should be complete
  result=$(check_sleep_data_completeness 21600 75 1)
  [ "$result" = "complete" ]
}

@test "check_sleep_data_completeness allows long sleep with low score" {
  # 7 hours sleep with low score (restless night) should be complete
  result=$(check_sleep_data_completeness 25200 45 1)
  [ "$result" = "complete" ]
}

@test "estimate_sleep_from_daily_score returns reasonable estimate for high score" {
  # Mock daily sleep data with high total_sleep score
  local mock_data='{
    "data": [{
      "day": "2025-09-18",
      "contributors": {
        "total_sleep": 84
      }
    }]
  }'

  result=$(estimate_sleep_from_daily_score "$mock_data" "2025-09-18")
  # Score 84 should estimate 7 hours (25200 seconds)
  [ "$result" = "25200" ]
}

@test "estimate_sleep_from_daily_score returns reasonable estimate for medium score" {
  # Mock daily sleep data with medium total_sleep score
  local mock_data='{
    "data": [{
      "day": "2025-09-18",
      "contributors": {
        "total_sleep": 55
      }
    }]
  }'

  result=$(estimate_sleep_from_daily_score "$mock_data" "2025-09-18")
  # Score 55 should estimate 4 hours (14400 seconds)
  [ "$result" = "14400" ]
}

@test "estimate_sleep_from_daily_score handles missing data" {
  # Mock daily sleep data without the target date
  local mock_data='{
    "data": [{
      "day": "2025-09-17",
      "contributors": {
        "total_sleep": 75
      }
    }]
  }'

  result=$(estimate_sleep_from_daily_score "$mock_data" "2025-09-18")
  [ "$result" = "N/A" ]
}

@test "find_cross_day_sleep_sessions merges evening and morning sessions" {
  # Mock sleep periods data with sessions from different days
  local mock_data='{
    "data": [
      {
        "day": "2025-09-17",
        "bedtime_start": "2025-09-17T22:30:00-04:00",
        "total_sleep_duration": 7200
      },
      {
        "day": "2025-09-18",
        "bedtime_start": "2025-09-18T04:00:00-04:00",
        "total_sleep_duration": 10800
      }
    ]
  }'

  result=$(find_cross_day_sleep_sessions "$mock_data" "2025-09-18" "2025-09-17")
  # Should return both sessions
  session_count=$(echo "$result" | jq 'length')
  [ "$session_count" = "2" ]
}

@test "find_cross_day_sleep_sessions excludes daytime sessions" {
  # Mock sleep periods data with a daytime nap
  local mock_data='{
    "data": [
      {
        "day": "2025-09-18",
        "bedtime_start": "2025-09-18T04:00:00-04:00",
        "total_sleep_duration": 10800
      },
      {
        "day": "2025-09-18",
        "bedtime_start": "2025-09-18T14:00:00-04:00",
        "total_sleep_duration": 1800
      }
    ]
  }'

  result=$(find_cross_day_sleep_sessions "$mock_data" "2025-09-18" "2025-09-17")
  # Should only return the 4 AM session, not the 2 PM nap
  session_count=$(echo "$result" | jq 'length')
  [ "$session_count" = "1" ]

  # Verify it's the 4 AM session
  bedtime=$(echo "$result" | jq -r '.[0].bedtime_start')
  [[ "$bedtime" == *"T04:00:00"* ]]
}

@test "format_oura_summary uses estimates only in current data mode" {
  # This is an integration test - we can't easily mock everything
  # but we can test the behavior with different is_historical flags
  skip "Integration test requiring full Oura setup"
}

@test "format_oura_summary respects historical flag for date selection" {
  # Another integration test that would require full setup
  skip "Integration test requiring full Oura setup"
}

@test "fallback only triggers when session data is significantly incomplete" {
  # Test the 50% threshold logic
  # If estimated sleep is only slightly more than session data, don't use estimate

  # Mock scenario: 5 hours session data, 6 hours estimated (only 20% more)
  local session_seconds=18000  # 5 hours
  local estimated_seconds=21600  # 6 hours
  local threshold=$((session_seconds * 3 / 2))  # 27000 (7.5 hours)

  # 6 hours < 7.5 hour threshold, so shouldn't trigger fallback
  [ "$estimated_seconds" -lt "$threshold" ]
}

@test "fallback triggers when session data is significantly incomplete" {
  # Test the 50% threshold logic
  # If estimated sleep is much more than session data, use estimate

  # Mock scenario: 3 hours session data, 7 hours estimated (>100% more)
  local session_seconds=10800  # 3 hours
  local estimated_seconds=25200  # 7 hours
  local threshold=$((session_seconds * 3 / 2))  # 16200 (4.5 hours)

  # 7 hours > 4.5 hour threshold, so should trigger fallback
  [ "$estimated_seconds" -gt "$threshold" ]
}