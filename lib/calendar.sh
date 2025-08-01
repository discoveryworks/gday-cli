#!/bin/bash

# Calendar processing functionality for gday
# Handles gcalcli integration, event parsing, and formatting

# Get emoji for a given time
get_emoji_for_time() {
  local time_number="$1"
  case "$time_number" in
    800) echo "🕗" ;;
    830) echo "🕣" ;;
    900) echo "🕘" ;;
    930) echo "🕤" ;;
    1000) echo "🕙" ;;
    1030) echo "🕥" ;;
    1100) echo "🕚" ;;
    1130) echo "🕦" ;;
    1200) echo "🕛" ;;
    1230) echo "🕧" ;;
    100) echo "🕐" ;;
    130) echo "🕜" ;;
    200) echo "🕑" ;;
    230) echo "🕝" ;;
    300) echo "🕒" ;;
    330) echo "🕞" ;;
    400) echo "🕓" ;;
    430) echo "🕟" ;;
    500) echo "🕔" ;;
    530) echo "🕠" ;;
    600) echo "🕕" ;;
    630) echo "🕡" ;;
    700) echo "🕖" ;;
    730) echo "🕢" ;;
    *) echo "" ;;
  esac
}

# Extract the first emoji from a string
get_first_emoji() {
  local text="$1"
  local first_char="${text:0:1}"
  # Check if first character is non-alphanumeric and not space (likely an emoji)
  if [[ ! $first_char =~ [[:alnum:][:space:]] ]] && [[ -n "$first_char" ]]; then
    echo "$first_char"
  fi
}

# Generate repeated emoji for time blocks
generate_repeated_emoji() {
  local original_item="$1"
  local block_number="$2"  # 0-based index
  local time_number="$3"
  
  # Get the first emoji from the original item
  local leading_emoji=$(get_first_emoji "$original_item")
  
  # If no leading emoji found, use time-based clock emoji
  if [[ -z "$leading_emoji" ]]; then
    leading_emoji=$(get_emoji_for_time "$time_number")
  fi
  
  # If we still have no emoji, return original item
  if [[ -z "$leading_emoji" ]]; then
    echo "$original_item"
    return
  fi
  
  # Generate repeated emoji (block_number + 1 times)
  local repeated_emoji=""
  for ((i=0; i<=block_number; i++)); do
    repeated_emoji="${repeated_emoji}${leading_emoji}"
  done
  
  # If original item had a leading emoji, replace it; otherwise prepend
  if [[ -n $(get_first_emoji "$original_item") ]]; then
    # Remove the first character (emoji) and prepend our repeated version
    local item_without_emoji="${original_item:1}"
    echo "${repeated_emoji}${item_without_emoji}"
  else
    # No leading emoji, so prepend our repeated emoji
    echo "${repeated_emoji} $original_item"
  fi
}

# Calculate visual display width of text (accounting for emoji width)
get_visual_width() {
  local text="$1"
  local char_count=${#text}
  local emoji_count=$(echo "$text" | grep -o '[^[:alnum:][:space:][:punct:]]' | wc -l | tr -d ' ')
  # Each emoji takes approximately 2 character widths in most terminals
  # So total visual width = regular chars + (emoji_count * extra_width)
  echo $((char_count + emoji_count))
}

# Function to add a pomodoro (30 minutes) to a given time
add_pomodoro() {
  local time=$1
  local new_time=$(date -j -v+30M -f "%I:%M%p" "$time" +"%I:%M%p")
  echo $new_time | sed 's/^0//' | tr '[:upper:]' '[:lower:]'
}

# Process calendar data from gcalcli into structured format
gday_process_calendar_data() {
  local calendar_data="$1"
  local target_day="$2"
  local target_month="$3" 
  local target_date="$4"
  local day_format="$target_day $target_month $target_date"
  
  local body=""
  local lines=()
  local pomodoro_lines=()  # Store pomodoro lines separately for filtering
  local prev_time=""
  local all_day_events=()
  local occupied_time_slots=()  # Track time slots with actual appointments

  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^[ \t]*//') # trim whitespace

    # Check for all-day events in various formats
    if [[ $line == *"******"* ]]; then
      local item=$(echo "$line" | sed -E 's/^[A-Za-z]+ [A-Za-z]+ [0-9]+[[:space:]]+\*+[[:space:]]+//')
      all_day_events+=("all-day|📅 $item (All-day)")
      continue
    fi

    # Check if this line has our target date format (e.g., "Wed May 07")
    if [[ $line == "$target_day $target_month $target_date"* || $line == *"$target_month $target_date"* ]]; then
      # Check if this date line also contains a time-based event (first event of the day)
      if [[ $line =~ ^[A-Za-z]{3}\ [A-Za-z]{3}\ [0-9]{2}[[:space:]]+([0-9]{1,2}:[0-9]{2}[apm]{2})[[:space:]]+(.*) ]]; then
        local time="${BASH_REMATCH[1]}"
        local item="${BASH_REMATCH[2]}"
        local original_time=$time
        
        # Get the next line for duration info
        IFS= read -r next_line
        local duration_raw=$(echo "$next_line" | awk '/Length:/ {print $2}')
        local hours=$(echo "$duration_raw" | cut -d ':' -f 1)
        local minutes=$(echo "$duration_raw" | cut -d ':' -f 2)
        local total_minutes=$((hours * 60 + minutes))
        
        # Process this embedded event the same way as other timed events
        if [[ $total_minutes -eq 1440 || ($time == "12:00am" && $total_minutes -gt 720) ]]; then
          if [[ ! $item =~ ^Length: ]]; then
            all_day_events+=("all-day|📅 $item (All-day)")
          fi
        elif [[ $total_minutes -eq 15 ]]; then
          # For 15-minute appointments, snap to 30-minute boundaries
          if [[ $time =~ :15([ap]m) ]]; then
            time=$(echo "$time" | sed 's/:15/:00/')
            item="$item - $original_time"
          elif [[ $time =~ :45([ap]m) ]]; then
            time=$(echo "$time" | sed 's/:45/:30/')
            item="$item - $original_time"
          fi
          
          # Separate pomodoros from regular appointments  
          if [[ "$item" == "🍅" ]]; then
            pomodoro_lines+=("$time|$item")
          else
            lines+=("$time|$item")
            occupied_time_slots+=("$time")
          fi
        else
          # For longer events, split into 30-minute blocks
          local blocks=$((total_minutes / 30))
          if [[ $blocks -eq 0 ]]; then
            blocks=1
          fi
          
          for ((i=0; i<blocks; i++)); do
            local time_number=$(echo "$time" | tr -d '[:alpha:]' | tr -d ':')
            local padded_item=$(generate_repeated_emoji "$item" "$i" "$time_number")
            
            # Separate pomodoros from regular appointments
            if [[ "$item" == "🍅" ]]; then
              pomodoro_lines+=("$time|$padded_item")
            else
              lines+=("$time|$padded_item")
              occupied_time_slots+=("$time")
            fi
            
            if [[ $i -lt $((blocks - 1)) ]]; then
              time=$(add_pomodoro "$time")
            fi
          done
        fi
      fi
      
      # Keep reading subsequent lines until we find a time-based event
      while IFS= read -r next_line; do
        next_line=$(echo "$next_line" | sed 's/^[ \t]*//') # trim whitespace

        # If we find a line with asterisks, it's an all-day event
        if [[ $next_line == *"******"* ]]; then
          local item=$(echo "$next_line" | sed 's/^[[:space:]]*\*\+[[:space:]]*//')
          all_day_events+=("all-day|📅 $item (All-day)")
          continue
        fi

        # If we find a line without a time stamp, it could be an all-day event
        if [[ ! $next_line =~ ^[0-9]{1,2}:[0-9]{2}[apm]{2} && -n "$next_line" && $next_line != *"No Events"* ]]; then
          # Check if it's not a date line for a different day
          if [[ ! $next_line =~ ^[A-Za-z]{3}\ [A-Za-z]{3}\ [0-9]{2} ]]; then
            # Skip "Length:" lines as they're just duration information, not events
            if [[ ! $next_line =~ ^Length: ]]; then
              all_day_events+=("all-day|📅 $next_line (All-day)")
            fi
          else
            # It's a date line for a different day, stop processing
            line="$next_line"
            break
          fi
        else
          # We found a time-based event or empty line, so we're done with all-day events
          line="$next_line"
          break
        fi
      done
    fi

    if [[ $line =~ ^[0-9]{1,2}:[0-9]{2}[apm]{2} ]]; then # if line starts with time
      local time=$(echo "$line" | awk '{print $1}') # extract vars
      local item=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
      local original_time=$time

      # Get the next line for duration
      IFS= read -r next_line
      local duration_raw=$(echo "$next_line" | awk '/Length:/ {print $2}')
      local hours=$(echo "$duration_raw" | cut -d ':' -f 1)
      local minutes=$(echo "$duration_raw" | cut -d ':' -f 2)
      local total_minutes=$((hours * 60 + minutes))

      # Check for all-day events (typically 24 hours)
      if [[ $total_minutes -eq 1440 || ($time == "12:00am" && $total_minutes -gt 720) ]]; then
        # Exclude "Length:" entries but include all other all-day events
        if [[ ! $item =~ ^Length: ]]; then
          all_day_events+=("all-day|📅 $item (All-day)")
        fi
      # Handle 15-minute appointments
      elif [[ $total_minutes -eq 15 ]]; then
        # For appointments ending in :15, snap to previous :00
        if [[ $time =~ :15([ap]m) ]]; then
          time=$(echo "$time" | sed 's/:15/:00/')
          item="$item - $original_time"
        # For appointments ending in :45, snap to previous :30
        elif [[ $time =~ :45([ap]m) ]]; then
          time=$(echo "$time" | sed 's/:45/:30/')
          item="$item - $original_time"
        fi
        new_line="$time|$item"
        
        # Separate pomodoros from regular appointments
        if [[ "$item" == "🍅" ]]; then
          pomodoro_lines+=("$new_line")
        else
          lines+=("$new_line")
          occupied_time_slots+=("$time")
        fi
      else
        # For longer events, split into 30-minute blocks
        local blocks=$((total_minutes / 30))
        if [[ $blocks -eq 0 ]]; then
          blocks=1
        fi

        for ((i=0; i<blocks; i++)); do
          local time_number=$(echo "$time" | tr -d '[:alpha:]' | tr -d ':')
          local padded_item=$(generate_repeated_emoji "$item" "$i" "$time_number")
          new_line="$time|$padded_item"
          
          # Separate pomodoros from regular appointments
          if [[ "$padded_item" == "🍅" ]]; then
            pomodoro_lines+=("$new_line")
          else
            if [[ "$padded_item" != "🍅" || "$time" != "$prev_time" ]]; then
              lines+=("$new_line")
            fi
            occupied_time_slots+=("$time")
          fi
          
          prev_time="$time"
          time=$(add_pomodoro "$time")
        done
      fi
    fi
  done <<< "$calendar_data"

  # Filter out any "Length:" entries and empty all-day events
  local filtered_all_day_events=()
  for event in "${all_day_events[@]}"; do
    if [[ ! $event =~ Length: ]] && [[ "$event" != "all-day|📅  (All-day)" ]] && [[ "$event" != *"📅 ~~~"* ]]; then
      filtered_all_day_events+=("$event")
    fi
  done

  # Add filtered all-day events to the beginning of the lines array
  lines=("${filtered_all_day_events[@]}" "${lines[@]}")

  # Add non-conflicting pomodoro lines
  for pomodoro_line in "${pomodoro_lines[@]}"; do
    IFS='|' read -r pomo_time pomo_item <<< "$pomodoro_line"
    local is_occupied=false
    
    # Check if this time slot is occupied by a real appointment
    for occupied_slot in "${occupied_time_slots[@]}"; do
      if [[ "$pomo_time" == "$occupied_slot" ]]; then
        is_occupied=true
        break
      fi
    done
    
    # If not occupied, add the pomodoro line
    if ! $is_occupied; then
      lines+=("$pomodoro_line")
    fi
  done

  # Sort all lines by time to maintain chronological order
  # Create a temporary array to hold sortable entries
  local sortable_lines=()
  local non_time_lines=()
  
  for line in "${lines[@]}"; do
    if [[ "$line" =~ ^all-day\| ]]; then
      # Keep all-day events at the beginning
      non_time_lines+=("$line")
    else
      IFS='|' read -r time_part item_part <<< "$line"
      # Convert time to sortable format (24-hour format for sorting)
      local sort_time
      if [[ "$time_part" =~ ([0-9]{1,2}):([0-9]{2})(am|pm) ]]; then
        local hour="${BASH_REMATCH[1]}"
        local minute="${BASH_REMATCH[2]}"
        local ampm="${BASH_REMATCH[3]}"
        
        # Convert to 24-hour format for sorting
        if [[ "$ampm" == "am" ]]; then
          if [[ "$hour" == "12" ]]; then
            sort_time="00$minute"
          else
            sort_time=$(printf "%02d%s" "$hour" "$minute")
          fi
        else
          if [[ "$hour" == "12" ]]; then
            sort_time="12$minute"
          else
            sort_time=$(printf "%02d%s" $((hour + 12)) "$minute")
          fi
        fi
        
        sortable_lines+=("$sort_time|$line")
      else
        # Fallback for any lines that don't match time format
        sortable_lines+=("9999|$line")
      fi
    fi
  done
  
  # Sort the time-based lines and extract just the original line part
  local sorted_lines=()
  while IFS= read -r sorted_line; do
    # Extract everything after the first pipe (the original line)
    sorted_lines+=("${sorted_line#*|}")
  done < <(printf '%s\n' "${sortable_lines[@]}" | sort -t'|' -k1,1n)
  
  # Combine non-time lines (all-day events) with sorted time lines
  lines=("${non_time_lines[@]}" "${sorted_lines[@]}")

  # Add emoji to items lacking emoji and construct the final table
  for line in "${lines[@]}"; do
    IFS='|' read -r time item <<< "$line"
    local time_number=$(echo "$time" | tr -d '[:alpha:]' | tr -d ':')

    # Only add clock emoji if item doesn't start with any emoji at all
    if ! [[ $item =~ ^[^[:alnum:]] ]]; then # if item lacks emoji
      local emoji=$(get_emoji_for_time "$time_number") # then add emoji
      if [[ -n "$emoji" ]]; then
        item="${emoji} $item"
      fi
    fi

    # Format time with consistent spacing (8 characters)
    local formatted_time="${time}        "
    formatted_time="${formatted_time:0:8}"

    # Calculate how much padding needed for right alignment
    local target_width=86  # Target visual width for item column
    local item_visual_width=$(get_visual_width "$item")
    local padding_needed=$((target_width - item_visual_width))
    
    # Ensure minimum padding of 0
    if [[ $padding_needed -lt 0 ]]; then
      padding_needed=0
    fi
    
    # Create padding string
    local padding=$(printf "%*s" "$padding_needed" "")
    
    body="${body}| ${formatted_time} | ${item}${padding} |"$'\n'
  done

  echo "$body"
}

# Generate "Later Today" section with filtering
generate_later_today_h2s() {
  local filtered_appointments_param="$1"
  awk -v appointments="$filtered_appointments_param" '
    BEGIN {
      print "## Later Today..."
      print "```"
      split(appointments, appts, "|")
    }
    function normalize(str) {
      gsub(/[^a-zA-Z0-9 ]/, "", str)
      gsub(/^ +| +$/, "", str)  # Trim leading/trailing whitespace
      gsub(/ +/, " ", str)      # Normalize spaces
      return tolower(str)       # Case-insensitive comparison
    }
    /^\| [0-9]/ {
      line = $0
      sub(/^\|[^|]+\| /, "## ", line)  # Remove everything up to the title
      sub(/ *\|$/, "", line)  # Remove trailing whitespace and pipe
      gsub(/ +$/, "", line)  # Trim any remaining trailing whitespace

      # Extract appointment title for exact matching
      title = line
      sub(/^## /, "", title)  # Remove the ## prefix

      # Check against our list of filtered appointments with exact matching
      skip = 0
      for (i in appts) {
        if (normalize(title) == normalize(appts[i])) {
          skip = 1
          # print "FILTERED: " title " matches " appts[i] > "/dev/stderr"
          break
        }
      }

      if (!skip) {
        norm = normalize(line)
        if (!seen[norm]++) {
          print line
        }
      }
    }
    END {
      print "## Been Reading..."
      print "```"
      print ""
    }
  '
}

# Build calendar arguments for gcalcli command
gday_build_calendar_args() {
  local calendar_args=""
  for cal in "${GCAL_CALENDARS[@]}"; do
    calendar_args="${calendar_args}--cal \"$cal\" "
  done
  echo "$calendar_args"
}

# Get calendar data for a specific date
gday_get_calendar_data() {
  local date_arg="$1"
  local calendar_args=$(gday_build_calendar_args)
  
  echo "~~~ running gcalcli command for $date_arg ~~~"
  echo ""
  
  # Build command as array to avoid eval issues
  local cmd_array=()
  cmd_array+=("gcalcli")
  
  # Add calendar arguments
  for cal in "${GCAL_CALENDARS[@]}"; do
    cmd_array+=("--cal" "$cal")
  done
  
  cmd_array+=("agenda" "1am $date_arg" "11pm $date_arg" "--nocolor" "--no-military" "--details" "length")
  
  echo "Command: ${cmd_array[*]}"
  echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
  echo ""
  
  local calendar_data=$("${cmd_array[@]}" 2>&1)
  local calendar_data_no_color=$(echo "$calendar_data" | sed 's/\x1b\[[0-9;]*m//g')
  
  # Convert pipe characters to an em-dash (bc escaping pipes is hard)
  calendar_data_no_color=$(echo "$calendar_data_no_color" | sed 's/|/—/g')
  
  echo "$calendar_data_no_color"
}