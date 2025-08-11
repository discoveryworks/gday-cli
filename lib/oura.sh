#!/bin/bash

# Oura API integration for gday
# Fetches sleep, readiness, and activity data from Oura Ring

# Oura API configuration
OURA_API_BASE="https://api.ouraring.com/v2"

# Load Oura API token from environment variable
load_oura_credentials() {
  if [[ -z "$OURA_PAT" ]]; then
    echo "❌ OURA_PAT environment variable not set" >&2
    echo "Please export your Oura personal access token:" >&2
    echo "export OURA_PAT=YOUR_TOKEN_HERE" >&2
    echo "Get your token from: https://cloud.ouraring.com/personal-access-tokens" >&2
    return 1
  fi
  
  OURA_TOKEN="$OURA_PAT"
  return 0
}

# Make authenticated API request to Oura
oura_api_request() {
  local endpoint="$1"
  local start_date="$2"
  local end_date="$3"
  
  if [[ -z "$OURA_TOKEN" ]]; then
    echo "❌ Oura token not loaded" >&2
    return 1
  fi
  
  local url="${OURA_API_BASE}${endpoint}?start_date=${start_date}&end_date=${end_date}"
  
  curl -s -L \
    -H "Accept: application/json" \
    -H "Authorization: Bearer ${OURA_TOKEN}" \
    "$url"
}

# Get yesterday's date in YYYY-MM-DD format
get_yesterday_date() {
  date -v-1d +%Y-%m-%d
}

# Get date N days ago in YYYY-MM-DD format
get_date_days_ago() {
  local days_ago="$1"
  date -v-${days_ago}d +%Y-%m-%d
}

# Get date range for weekly data (7 days ago to yesterday)
get_weekly_date_range() {
  local start_date=$(get_date_days_ago 7)
  local end_date=$(get_yesterday_date)
  echo "$start_date $end_date"
}

# Convert date to day name
get_day_name() {
  local date="$1"
  date -j -f "%Y-%m-%d" "$date" "+%A" 2>/dev/null || echo "$date"
}

################################################################################
# OURA SLEEP TIMING DETECTION SYSTEM
################################################################################
# 
# PROBLEM: Determining accurate "in bed" vs "sleep onset" times from Oura data
#
# CONTEXT: Oura Ring provides multiple sleep-related timestamps, but they don't 
# always align with user's actual experience. We need to combine different data 
# sources to get the most accurate sleep timeline.
#
# DATA SOURCES AVAILABLE:
# 1. Sleep Periods (/usercollection/sleep):
#    - bedtime_start: When Oura detected you got in bed  
#    - bedtime_end: When Oura detected you got out of bed
#    - latency: Time between getting in bed and falling asleep (seconds)
#    - movement_30_sec: Movement data in 30-second intervals during sleep
#    - Multiple sessions per night are possible
#
# 2. Daily Activity (/usercollection/daily_activity):
#    - class_5_min: Activity levels in 5-minute intervals for entire day
#    - Values: 1=minimal, 2=light, 3=moderate, 4=vigorous, 0=sleep/no-data
#    - 288 characters total (24 hours × 12 five-minute intervals)
#
# SOLUTION APPROACH:
# - "IN BED" time: Use activity data to find when movement stopped (~10 PM)
# - "SLEEP ONSET" time: Use first sleep session with significant duration + low latency
# - "WAKE UP" time: Use latest bedtime_end across all sessions (final wake-up)
#
# RATIONALE: This combines the strengths of both data sources:
# - Activity data shows actual cessation of movement (getting in bed)  
# - Sleep periods show physiological sleep detection (falling asleep)
# - Multiple sessions capture interrupted sleep patterns
################################################################################

# Analyze Oura daily activity pattern to detect bedtime
# 
# The class_5_min field contains 288 characters representing activity levels
# in 5-minute intervals throughout a 24-hour period (288 = 24h × 12 intervals).
#
# Activity Level Meanings:
# - 0: Sleep/no data (indicates bedtime/sleep period)
# - 1: Minimal activity (sedentary)
# - 2: Light activity (walking slowly, light tasks)  
# - 3: Moderate activity (brisk walking, regular tasks)
# - 4: Vigorous activity (running, intense exercise)
#
# Algorithm: Look for the transition point in evening hours where activity 
# drops from active levels (2-4) to sleep levels (0) for a sustained period.
# This indicates when the user likely got into bed.
#
# @param activity_string The class_5_min string from Oura daily activity data
# @param date The date for this activity data (for debugging/logging)
# @return Estimated bedtime in HH:MM format, or "N/A" if not detectable
analyze_bedtime_from_activity() {
  local activity_string="$1"
  local date="$2"
  
  if [[ -z "$activity_string" || "$activity_string" == "null" ]]; then
    echo "N/A"
    return
  fi
  
  local length=${#activity_string}
  
  # Focus search on evening hours (6 PM - 2 AM next day)
  # Interval calculation: hour * 12 + (minute / 5)
  # 6 PM = 18 * 12 = 216, 2 AM = (24 + 2) * 12 = 312 (but limited by string length)
  local start_interval=216  # 6:00 PM
  local end_interval=$((length > 312 ? 312 : length))  # 2:00 AM or end of string
  
  # Look for the LONGEST sustained sleep period (zeros)
  # Find all zero sequences and choose the one that represents actual night sleep
  local best_bedtime=""
  local longest_sleep_duration=0
  
  for ((i=start_interval; i<end_interval-10; i++)); do
    if [[ $i -lt $length ]]; then
      local current=${activity_string:$i:1}
      
      # Look for transition: active period (>= 2) to in-bed/minimal activity (1)
      # This captures getting into bed, not just falling asleep
      if [[ "$current" -ge 2 ]]; then
        local next_pos=$((i + 1))
        if [[ $next_pos -lt $length ]] && [[ "${activity_string:$next_pos:1}" == "1" ]]; then
          # Count consecutive minimal activity (1s) starting from next position
          local minimal_count=0
          local check_pos=$next_pos
          while [[ $check_pos -lt $length ]] && [[ "${activity_string:$check_pos:1}" == "1" ]]; do
            ((minimal_count++))
            ((check_pos++))
          done
          
          # If this minimal activity sequence is longer than previous best AND at least 20 min (4 intervals)
          if [[ $minimal_count -gt $longest_sleep_duration ]] && [[ $minimal_count -ge 4 ]]; then
            longest_sleep_duration=$minimal_count
            local hour=$((i / 12))  
            local minute=$(((i % 12) * 5))
            
            # Handle day rollover
            if [[ $hour -ge 24 ]]; then
              hour=$((hour - 24))
            fi
            
            printf -v best_bedtime "%02d:%02d" "$hour" "$minute"
          fi
        fi
      fi
    fi
  done
  
  if [[ -n "$best_bedtime" ]]; then
    echo "$best_bedtime"
  else
    echo "N/A"
  fi
}

# Find sleep onset time from multiple sleep sessions
#
# Strategy: Use the EARLIEST sleep session as sleep onset, regardless of duration.
# This captures the moment when physiological sleep detection first triggered,
# which represents actual sleep onset even if it's brief.
#
# Rationale: 
# - User reports falling asleep ~10:45 PM after getting in bed ~10:30 PM
# - Oura detects this as a brief session (10:45 PM, 3 minutes, 0 latency)
# - Later sessions represent deeper sleep phases or post-interruption sleep
# - For sleep onset timing, we want the FIRST detection, not the longest
#
# This approach prioritizes accuracy of sleep onset timing over session duration,
# which aligns better with user's actual experience and allows for validation
# against other data sources (Apple HealthKit, etc.)
#
# @param sleep_periods_data JSON data from /usercollection/sleep endpoint
# @return ISO timestamp of earliest sleep onset
find_sleep_onset_from_periods() {
  local sleep_periods_data="$1"
  
  # Simply use the earliest bedtime_start as sleep onset
  # This represents when Oura first detected sleep, regardless of session length
  echo "$sleep_periods_data" | jq -r '
    .data | map(.bedtime_start) | sort | .[0] // "N/A"' 2>/dev/null
}

# Convert ISO timestamp to readable time
format_sleep_time() {
  local timestamp="$1"
  if [[ "$timestamp" == "N/A" || -z "$timestamp" ]]; then
    echo "N/A"
    return
  fi
  
  # Extract time from ISO timestamp and convert to local time format
  # Handle both +XX:XX and -XX:XX timezone formats
  local clean_timestamp=$(echo "$timestamp" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')
  date -j -f "%Y-%m-%dT%H:%M:%S" "$clean_timestamp" "+%l:%M%p" 2>/dev/null | sed 's/^ *//' || echo "$timestamp"
}

# Convert seconds to HH:MM format
seconds_to_hhmm() {
  local seconds="$1"
  if [[ "$seconds" == "N/A" || -z "$seconds" || ! "$seconds" =~ ^[0-9]+$ ]]; then
    echo "N/A"
    return
  fi
  
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  printf "%d:%02d" "$hours" "$minutes"
}

# Fetch Oura daily sleep data for a date range
get_oura_sleep() {
  local start_date="${1:-$(get_yesterday_date)}"
  local end_date="${2:-$start_date}"
  
  oura_api_request "/usercollection/daily_sleep" "$start_date" "$end_date"
}

# Fetch detailed Oura sleep periods for timing data
get_oura_sleep_periods() {
  local start_date="${1:-$(get_yesterday_date)}"
  local end_date="${2:-$start_date}"
  
  oura_api_request "/usercollection/sleep" "$start_date" "$end_date"
}

# Fetch Oura sleep time data (different endpoint)
get_oura_sleep_time() {
  local start_date="${1:-$(get_yesterday_date)}"
  local end_date="${2:-$start_date}"
  
  oura_api_request "/usercollection/sleep_time" "$start_date" "$end_date"
}

# Fetch Oura readiness data for a date range
get_oura_readiness() {
  local start_date="${1:-$(get_yesterday_date)}"
  local end_date="${2:-$start_date}"
  
  oura_api_request "/usercollection/daily_readiness" "$start_date" "$end_date"
}

# Fetch Oura activity data for a date range
get_oura_activity() {
  local start_date="${1:-$(get_yesterday_date)}"
  local end_date="${2:-$start_date}"
  
  oura_api_request "/usercollection/daily_activity" "$start_date" "$end_date"
}

# Fetch Oura heart rate data for a date range
get_oura_heart_rate() {
  local start_date="$1"
  local end_date="$2"
  
  oura_api_request "/usercollection/heartrate" "$start_date" "$end_date"
}

# Fetch Oura daily stress data for a date range  
get_oura_stress() {
  local start_date="$1"
  local end_date="$2"
  
  oura_api_request "/usercollection/daily_stress" "$start_date" "$end_date"
}

# Display all Oura data for yesterday
show_oura_data() {
  format_oura_summary
}

# Display raw Oura data for debugging
show_oura_raw_data() {
  echo "## 💍 Oura Raw Data Debug"
  echo ""
  
  if ! load_oura_credentials; then
    return 1
  fi
  
  local today=$(date +%Y-%m-%d)
  local yesterday=$(get_yesterday_date)
  local day_before_yesterday=$(get_date_days_ago 2)
  
  echo "Today: $today"
  echo "Yesterday: $yesterday"
  echo "Day before yesterday: $day_before_yesterday" 
  echo ""
  
  echo "### 🛌 SLEEP PERIODS DATA (/usercollection/sleep)"
  echo "Here are ALL the sleep timing keys/values from the sleep periods endpoint:"
  echo ""
  
  local sleep_periods_data=$(get_oura_sleep_periods "$day_before_yesterday" "$today" 2>/dev/null)
  
  echo "$sleep_periods_data" | jq -r '.data[] | 
  "Session \(.day):" +
  "\n  🛏️  bedtime_start: \(.bedtime_start)" +
  "\n  ⏰  bedtime_end: \(.bedtime_end)" + 
  "\n  ⏱️  latency: \(.latency) seconds (\((.latency / 60) | floor):\((.latency % 60) | tostring | if length == 1 then "0" + . else . end))" +
  "\n  🏃  time_in_bed: \(.time_in_bed) seconds (\((.time_in_bed / 3600) | floor):\(((.time_in_bed % 3600) / 60) | floor | tostring | if length == 1 then "0" + . else . end))" +
  "\n  😴  total_sleep_duration: \(.total_sleep_duration) seconds (\((.total_sleep_duration / 3600) | floor):\(((.total_sleep_duration % 3600) / 60) | floor | tostring | if length == 1 then "0" + . else . end))" +
  "\n  📊  efficiency: \(.efficiency)%" +
  "\n  🌙  type: \(.type)" +
  "\n"' 2>/dev/null || echo "❌ Failed to parse sleep data"
  
  echo ""
  echo "### 🚶 ACTIVITY DATA (/usercollection/daily_activity)"
  echo "Activity data that might show when movement stopped (bedtime):"
  echo ""
  
  local activity_data=$(get_oura_activity "$day_before_yesterday" "$today" 2>/dev/null)
  
  # Analyze activity patterns for bedtime detection
  echo "$activity_data" | jq -r '.data[] | 
  "Day: \(.day)" +
  "\n  Possible bedtime from activity: " + 
  "\(.class_5_min)"' | while read -r line; do
    if [[ $line =~ ^Day:\ (.*)$ ]]; then
      echo "$line"
    elif [[ $line =~ ^[[:space:]]*([01234]+)$ ]]; then
      local activity_string="${BASH_REMATCH[1]}"
      local bedtime=$(analyze_bedtime_from_activity "$activity_string" "")
      echo "    Activity-based bedtime estimate: $bedtime"
      echo "    Activity pattern (last 10 intervals): ${activity_string: -10}"
      echo ""
    fi
  done
  
  echo ""
  echo "### 📱 MOVEMENT DATA from Sleep Periods"
  echo "Movement data from sleep sessions (movement_30_sec field):"
  echo ""
  
  echo "$sleep_periods_data" | jq -r '.data[] | 
  "Session \(.day) - \(.bedtime_start):" +
  "\n  Movement pattern: \(.movement_30_sec[:60])..." +
  "\n  (1=no movement, 2=restless, 3=active movement)" +
  "\n"' 2>/dev/null || echo "❌ Failed to parse movement data"
  
  echo ""
  echo "### 🤔 EXPLANATION OF FIELDS:"
  echo "- bedtime_start: When Oura detected you got in bed"  
  echo "- bedtime_end: When Oura detected you got out of bed"
  echo "- latency: Time between getting in bed and falling asleep"
  echo "- time_in_bed: Total time from bedtime_start to bedtime_end"
  echo "- total_sleep_duration: Actual sleep time (excludes awake periods)"
  echo "- efficiency: Sleep efficiency percentage"
  echo "- type: 'sleep' (short) or 'long_sleep' (main session)"
  echo ""
  
  echo "### 📅 Daily Sleep Data"
  local week_dates=($(get_weekly_date_range))
  local week_start="${week_dates[0]}"
  local week_end="${week_dates[1]}"
  get_oura_sleep "$week_start" "$week_end" | jq '.' 2>/dev/null || echo "❌ Failed to fetch sleep data"
}

# Parse and extract score from Oura data for a specific date
extract_oura_score() {
  local data="$1"
  local date="$2"
  local score_field="${3:-score}"
  
  local result=$(echo "$data" | jq -r --arg date "$date" \
    '[.data[] | select(.day == $date) | .'"$score_field"'][0] // "N/A"' 2>/dev/null)
  
  # Clean up any newlines or whitespace  
  local cleaned=$(echo "$result" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  # Return N/A if empty or null
  if [[ -z "$cleaned" || "$cleaned" == "null" ]]; then
    echo "N/A"
  else
    echo "$cleaned"
  fi
}

# Calculate average score from multi-day data
calculate_average() {
  local data="$1"
  local score_field="${2:-score}"
  
  local avg=$(echo "$data" | jq -r \
    '[.data[] | select(.'"$score_field"' != null) | .'"$score_field"'] | 
     if length > 0 then add/length | round else "N/A" end' 2>/dev/null)
  
  echo "$avg"
}

# Format score with emoji
format_score_with_emoji() {
  local score="$1"
  local type="$2"
  
  if [[ "$score" == "N/A" ]]; then
    echo "❓ N/A"
    return
  fi
  
  local emoji="⚡"
  case "$type" in
    "readiness"|"activity") 
      if [[ "$score" =~ ^[0-9]+$ ]]; then
        [[ "$score" -ge 85 ]] && emoji="💚" 
        [[ "$score" -le 69 ]] && emoji="🔴"
      fi
      ;;
    "sleep") 
      emoji="😴"
      if [[ "$score" =~ ^[0-9]+$ ]]; then
        [[ "$score" -ge 85 ]] && emoji="💚"
        [[ "$score" -le 69 ]] && emoji="🔴"
      fi
      ;;
    "heart_rate")
      emoji="❤️"
      ;;
    "stress")
      emoji="😰"
      [[ "$score" == "restored" ]] && emoji="💚"
      [[ "$score" == "stressed" ]] && emoji="🔴"
      ;;
  esac
  
  echo "${emoji} ${score}"
}

# Format compact Oura summary with meaningful baselines
format_oura_summary() {
  if ! load_oura_credentials; then
    return 1
  fi
  
  # Get date ranges (check today and yesterday for most recent data)
  local today=$(date +%Y-%m-%d)
  local yesterday=$(get_yesterday_date)
  local day_before=$(get_date_days_ago 2)
  local week_dates=($(get_weekly_date_range))
  local week_start="${week_dates[0]}"
  local week_end="$today"  # Include today to catch any fresh data
  
  # Fetch weekly data for averages (silently)
  local sleep_data=$(get_oura_sleep "$week_start" "$week_end" 2>/dev/null)
  local readiness_data=$(get_oura_readiness "$week_start" "$week_end" 2>/dev/null)
  local activity_data=$(get_oura_activity "$week_start" "$week_end" 2>/dev/null)
  local stress_data=$(get_oura_stress "$week_start" "$week_end" 2>/dev/null)
  
  
  # Check for today's data first, fallback to yesterday
  local today_readiness=$(extract_oura_score "$readiness_data" "$today" "score")
  local today_sleep=$(extract_oura_score "$sleep_data" "$today" "score")
  local today_activity=$(extract_oura_score "$activity_data" "$today" "score")
  local today_stress=$(extract_oura_score "$stress_data" "$today" "day_summary")
  
  # Use today's data if available, otherwise yesterday's
  local most_recent_date="$yesterday"
  local most_recent_day=$(get_day_name "$yesterday")
  local most_recent_readiness=$(extract_oura_score "$readiness_data" "$yesterday" "score")
  local most_recent_sleep=$(extract_oura_score "$sleep_data" "$yesterday" "score")  
  local most_recent_activity=$(extract_oura_score "$activity_data" "$yesterday" "score")
  local most_recent_stress=$(extract_oura_score "$stress_data" "$yesterday" "day_summary")
  
  # If today has data, use it as most recent
  if [[ "$today_readiness" != "N/A" || "$today_sleep" != "N/A" || "$today_activity" != "N/A" ]]; then
    most_recent_date="$today"
    most_recent_day=$(get_day_name "$today")
    [[ "$today_readiness" != "N/A" ]] && most_recent_readiness="$today_readiness"
    [[ "$today_sleep" != "N/A" ]] && most_recent_sleep="$today_sleep"
    [[ "$today_activity" != "N/A" ]] && most_recent_activity="$today_activity"
    [[ "$today_stress" != "N/A" ]] && most_recent_stress="$today_stress"
  fi
  
  local dayb4_readiness=$(extract_oura_score "$readiness_data" "$day_before" "score")
  local dayb4_sleep=$(extract_oura_score "$sleep_data" "$day_before" "score")
  local dayb4_activity=$(extract_oura_score "$activity_data" "$day_before" "score")
  local dayb4_stress=$(extract_oura_score "$stress_data" "$day_before" "day_summary")
  
  ############################################################################
  # COMPREHENSIVE SLEEP TIMING DETECTION
  # 
  # This section combines multiple Oura data sources to determine accurate
  # sleep timing that matches the user's actual experience:
  #
  # 1. IN BED TIME: Activity data analysis (when movement stopped)
  # 2. SLEEP ONSET TIME: Optimal sleep session detection  
  # 3. WAKE UP TIME: Latest wake-up across all sessions
  ############################################################################
  
  # Get sleep periods data (expand range to catch sleep from previous night)
  local day_before_yesterday=$(get_date_days_ago 2)
  local sleep_periods_data=$(get_oura_sleep_periods "$day_before_yesterday" "$today" 2>/dev/null)
  
  # Get daily activity data to detect actual bedtime (when movement stopped)
  # Use the same range as sleep periods to ensure we get the activity data
  local activity_data=$(get_oura_activity "$day_before_yesterday" "$today" 2>/dev/null)
  local activity_bedtime="N/A"
  
  # Extract activity string and analyze for bedtime
  if [[ -n "$activity_data" ]]; then
    # Look for activity data from the day before yesterday (evening leading to sleep)
    local activity_string=$(echo "$activity_data" | jq -r --arg date "$day_before_yesterday" \
      '.data[] | select(.day == $date) | .class_5_min // ""' 2>/dev/null)
    
    if [[ -n "$activity_string" && "$activity_string" != "null" && "$activity_string" != "" ]]; then
      activity_bedtime=$(analyze_bedtime_from_activity "$activity_string" "$day_before_yesterday")
    fi
  fi
  
  # Get main sleep session for duration and score calculations
  local main_sleep_session=$(echo "$sleep_periods_data" | jq -r \
    '.data | sort_by(.total_sleep_duration) | reverse | .[0]' 2>/dev/null)
  
  ############################################################################
  # CORRECTED SLEEP TIMELINE CALCULATION
  # 
  # Problem: We were treating multiple sleep sessions as separate events,
  # but Apple Health shows they should be combined into one continuous
  # sleep period (10:40 PM - 6:13 AM = 7h 34m in bed, 6h 55m asleep)
  #
  # Solution: Use earliest bedtime_start, latest bedtime_end, and SUM all 
  # sleep durations across sessions to match Apple Health's approach
  ############################################################################
  
  # Try activity-based bedtime detection first (most accurate for actual "in bed" time)
  local bedtime_start="$activity_bedtime"
  local bedtime_source="OURA_SLEEP_PERIODS"
  local sleep_onset_source="OURA_SLEEP_PERIODS"
  
  # If we successfully got activity-based bedtime, mark it as the source
  if [[ "$bedtime_start" != "N/A" && "$bedtime_start" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    bedtime_source="OURA_ACTIVITY"
  else
    # Fallback to earliest sleep period bedtime
    bedtime_start=$(echo "$sleep_periods_data" | jq -r \
      '.data | map(.bedtime_start) | sort | .[0] // "N/A"' 2>/dev/null)
  fi
  
  # Get sleep timing from most recent sleep period (yesterday or day before)
  # Strategy: Use EARLIEST sleep onset (when sleep first detected) and LATEST wake time (final wake up)
  # This matches user's request for "sleep onset to wake time" calculation
  local yesterday=$(get_yesterday_date) 
  local day_before_yesterday=$(get_date_days_ago 2)
  
  # Get the most recent sleep period by finding the date with the longest sleep session
  # This avoids mixing sessions from different nights
  local main_sleep_date=$(echo "$sleep_periods_data" | jq -r \
    '.data | group_by(.day) | map({day: .[0].day, total: map(.total_sleep_duration) | add}) | sort_by(.total) | reverse | .[0].day // "N/A"' 2>/dev/null)
  
  if [[ "$main_sleep_date" == "N/A" ]]; then
    # Fallback to yesterday if no sessions found
    main_sleep_date="$yesterday"
  fi
  
  # Get all sessions from the main sleep date
  local sleep_sessions=$(echo "$sleep_periods_data" | jq --arg date "$main_sleep_date" \
    '.data | map(select(.day == $date))' 2>/dev/null)
  
  # Find the earliest sleep onset and latest wake time from this sleep date
  local sleep_onset=$(echo "$sleep_sessions" | jq -r \
    'map(.bedtime_start) | sort | .[0] // "N/A"' 2>/dev/null)
  local wake_up_time=$(echo "$sleep_sessions" | jq -r \
    'map(.bedtime_end) | sort | reverse | .[0] // "N/A"' 2>/dev/null)
  
  # Get the main (longest) session for sleep stage data
  local main_sleep_session=$(echo "$sleep_sessions" | jq \
    'sort_by(.total_sleep_duration) | reverse | .[0] // null' 2>/dev/null)
  
  # Calculate TOTAL sleep time as simple duration from sleep onset to wake up
  # This gives the raw time in bed sleeping, regardless of sleep quality/interruptions
  local total_sleep_seconds=0
  if [[ "$sleep_onset" != "N/A" && "$wake_up_time" != "N/A" ]]; then
    # Convert ISO timestamps to seconds since epoch for calculation
    local sleep_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$sleep_onset" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')" "+%s" 2>/dev/null || echo "0")
    local wake_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$(echo "$wake_up_time" | sed 's/[+-][0-9][0-9]:[0-9][0-9]$//')" "+%s" 2>/dev/null || echo "0")
    
    if [[ "$sleep_epoch" -gt 0 && "$wake_epoch" -gt 0 && "$wake_epoch" -gt "$sleep_epoch" ]]; then
      total_sleep_seconds=$((wake_epoch - sleep_epoch))
    fi
  fi
  
  # main_sleep_session is already set above for consistency
  local sleep_date=$(echo "$main_sleep_session" | jq -r '.day // ""' 2>/dev/null)
  
  # Calculate weekly averages
  local avg_readiness=$(calculate_average "$readiness_data" "score")
  local avg_sleep=$(calculate_average "$sleep_data" "score")
  local avg_activity=$(calculate_average "$activity_data" "score")
  
  # Get day names for better readability  
  local dayb4_day=$(get_day_name "$day_before")
  
  # Calculate percentage changes from 7-day average
  local sleep_change=""
  local readiness_change=""
  local activity_change=""
  
  if [[ "$most_recent_sleep" != "N/A" && "$avg_sleep" != "N/A" ]]; then
    local sleep_pct=$(echo "scale=0; (($most_recent_sleep - $avg_sleep) * 100) / $avg_sleep" | bc 2>/dev/null || echo "0")
    sleep_change=$([ "$sleep_pct" -ge 0 ] && echo "+$sleep_pct%" || echo "$sleep_pct%")
  fi
  
  if [[ "$most_recent_readiness" != "N/A" && "$avg_readiness" != "N/A" ]]; then
    local readiness_pct=$(echo "scale=0; (($most_recent_readiness - $avg_readiness) * 100) / $avg_readiness" | bc 2>/dev/null || echo "0")
    readiness_change=$([ "$readiness_pct" -ge 0 ] && echo "+$readiness_pct%" || echo "$readiness_pct%")
  fi
  
  if [[ "$most_recent_activity" != "N/A" && "$avg_activity" != "N/A" ]]; then
    local activity_pct=$(echo "scale=0; (($most_recent_activity - $avg_activity) * 100) / $avg_activity" | bc 2>/dev/null || echo "0")
    activity_change=$([ "$activity_pct" -ge 0 ] && echo "+$activity_pct%" || echo "$activity_pct%")
  fi
  
  # Create compact summary format
  ############################################################################
  # DISPLAY COMPREHENSIVE SLEEP TIMELINE
  #
  # Show the complete sleep story using our multi-source detection:
  # - Bedtime: Activity-based detection (when movement stopped)
  # - Sleep onset: Optimal sleep session (when actually fell asleep) 
  # - Wake up: Latest session end (final wake-up, often baby-induced)
  # - Duration: From main sleep session (longest continuous sleep)
  ############################################################################
  
  if [[ "$bedtime_start" != "N/A" || "$wake_up_time" != "N/A" ]]; then
    # Format bedtime - handle both activity time (HH:MM) and timestamp formats
    local bedtime_formatted
    if [[ "$bedtime_start" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
      # Activity-based bedtime is in 24-hour format, convert to 12-hour
      local hour=${bedtime_start%:*}
      local minute=${bedtime_start#*:}
      if [[ $hour -gt 12 ]]; then
        bedtime_formatted="$((hour - 12)):${minute}PM"
      elif [[ $hour -eq 12 ]]; then
        bedtime_formatted="12:${minute}PM"
      elif [[ $hour -eq 0 ]]; then
        bedtime_formatted="12:${minute}AM"
      else
        bedtime_formatted="${hour}:${minute}AM"
      fi
    else
      # Fallback timestamp format needs formatting
      bedtime_formatted=$(format_sleep_time "$bedtime_start")
    fi
    
    # Format sleep onset (always from timestamp, not activity data)
    local sleep_onset_formatted=$(format_sleep_time "$sleep_onset")
    local wake_time_formatted=$(format_sleep_time "$wake_up_time")
    local duration_formatted=$(seconds_to_hhmm "$total_sleep_seconds")
    
    # Get sleep stage breakdown from main session for inline display
    local sleep_stages=""
    if [[ -n "$main_sleep_session" && "$main_sleep_session" != "null" ]]; then
      local rem_sleep=$(echo "$main_sleep_session" | jq -r '.rem_sleep_duration // 0' 2>/dev/null)
      local light_sleep=$(echo "$main_sleep_session" | jq -r '.light_sleep_duration // 0' 2>/dev/null)  
      local deep_sleep=$(echo "$main_sleep_session" | jq -r '.deep_sleep_duration // 0' 2>/dev/null)
      local total_measured=$(echo "$main_sleep_session" | jq -r '.total_sleep_duration // 0' 2>/dev/null)
      
      if [[ "$total_measured" -gt 0 ]]; then
        local rem_pct=$(echo "scale=0; ($rem_sleep * 100) / $total_measured" | bc 2>/dev/null || echo "0")
        local light_pct=$(echo "scale=0; ($light_sleep * 100) / $total_measured" | bc 2>/dev/null || echo "0") 
        local deep_pct=$(echo "scale=0; ($deep_sleep * 100) / $total_measured" | bc 2>/dev/null || echo "0")
        sleep_stages=" (REM: ${rem_pct}% Light: ${light_pct}% Deep: ${deep_pct}%)"
      fi
    fi
    
    # Humanize the data source descriptions
    local bedtime_desc=""
    case "$bedtime_source" in
      "OURA_ACTIVITY") bedtime_desc="Oura activity tracking" ;;
      "OURA_SLEEP_PERIODS") bedtime_desc="Oura sleep period tracking" ;;
      *) bedtime_desc="$bedtime_source" ;;
    esac
    
    local sleep_onset_desc=""
    case "$sleep_onset_source" in
      "OURA_SLEEP_PERIODS") sleep_onset_desc="Oura sleep period tracking" ;;
      "OURA_ACTIVITY") sleep_onset_desc="Oura activity tracking" ;;
      *) sleep_onset_desc="$sleep_onset_source" ;;
    esac
    
    echo "- 🥱 you went to bed at $bedtime_formatted (as detected by $bedtime_desc) and"
    echo "- 😴   went to sleep at $sleep_onset_formatted (as detected by $sleep_onset_desc) and" 
    echo "- 🌞    woke up today at $wake_time_formatted (as detected by Oura sleep period tracking)"
    echo "- 💤      for a total of $duration_formatted sleep$sleep_stages"
  fi
  
  if [[ "$most_recent_sleep" != "N/A" ]]; then
    local direction="same as"
    local prev_sleep=$(extract_oura_score "$sleep_data" "$day_before" "score")
    if [[ "$prev_sleep" != "N/A" ]]; then
      if [[ "$most_recent_sleep" -gt "$prev_sleep" ]]; then
        direction="up from $prev_sleep"
      elif [[ "$most_recent_sleep" -lt "$prev_sleep" ]]; then
        direction="down from $prev_sleep"
      else
        direction="same as $prev_sleep"
      fi
    fi
    echo "- 🛌 Sleep score is $most_recent_sleep, $direction ($sleep_change change from 7-day avg $avg_sleep)"
  fi
  
  if [[ "$most_recent_readiness" != "N/A" ]]; then
    local direction="same as"
    local prev_readiness=$(extract_oura_score "$readiness_data" "$day_before" "score")
    if [[ "$prev_readiness" != "N/A" ]]; then
      if [[ "$most_recent_readiness" -gt "$prev_readiness" ]]; then
        direction="up from $prev_readiness"
      elif [[ "$most_recent_readiness" -lt "$prev_readiness" ]]; then
        direction="down from $prev_readiness"
      else
        direction="same as $prev_readiness"
      fi
    fi
    echo "- 🚥 Readiness is   $most_recent_readiness, $direction ($readiness_change change from 7-day avg $avg_readiness)"
  fi
  
  if [[ "$most_recent_activity" != "N/A" && -n "$most_recent_activity" ]]; then
    local direction="same as"
    local prev_activity=$(extract_oura_score "$activity_data" "$day_before" "score")
    if [[ "$prev_activity" != "N/A" ]]; then
      if [[ "$most_recent_activity" -gt "$prev_activity" ]]; then
        direction="up from $prev_activity"
      elif [[ "$most_recent_activity" -lt "$prev_activity" ]]; then
        direction="down from $prev_activity"  
      else
        direction="same as $prev_activity"
      fi
    fi
    echo "- 🏃 Activity is    $most_recent_activity, $direction ($activity_change change from 7-day avg $avg_activity)"
  fi
  
  echo ""
}