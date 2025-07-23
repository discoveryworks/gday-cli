#!/bin/bash

# Configuration management for gday
# Handles YAML parsing and calendar setup

# Default calendar configuration
GCAL_CALENDARS=()

# Load configuration from YAML file
gday_load_config() {
  local config_file="$HOME/.config/gday/config.yml"
  
  if [[ ! -f "$config_file" ]]; then
    echo "Warning: gday configuration file not found at $config_file"
    echo "Create ~/.config/gday/config.yml using the example template"
    return 1
  fi
  
  # Parse calendar names from YAML
  GCAL_CALENDARS=()
  local in_calendars=false
  
  while IFS= read -r line; do
    # Check for calendars section
    if [[ "$line" =~ ^calendars: ]]; then
      in_calendars=true
      continue
    fi
    
    # Stop parsing calendars when we hit a new section
    if [[ "$line" =~ ^[[:alpha:]]+: ]] && [[ $in_calendars == true ]]; then
      break
    fi
    
    # Parse calendar list items
    if [[ $in_calendars == true && "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
      local calendar=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
      GCAL_CALENDARS+=("$calendar")
    fi
  done < "$config_file"
  
  return 0
}

# Parse YAML prompt configuration
gday_parse_prompts() {
  local config_file="$HOME/.config/gday/config.yml"
  
  # Initialize associative arrays
  declare -A prompt_groups_freq
  declare -A prompt_groups_content
  local current_group=""
  local current_frequency=""
  local in_content=false
  local in_prompts=false
  
  while IFS= read -r line; do
    # Check for prompts section start
    if [[ "$line" =~ ^prompts: ]]; then
      in_prompts=true
      continue
    fi
    
    # Stop parsing when we hit a non-prompts section
    if [[ "$line" =~ ^[[:alpha:]_]+: ]] && [[ $in_prompts == true ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
      break
    fi
    
    if [[ $in_prompts == true ]]; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.*)\" ]]; then
        # Start of new prompt group
        current_group="${BASH_REMATCH[1]}"
        in_content=false
      elif [[ "$line" =~ ^[[:space:]]*frequency:[[:space:]]*(.*) ]]; then
        # Frequency line
        current_frequency="${BASH_REMATCH[1]}"
        # Remove comments
        current_frequency=$(echo "$current_frequency" | sed 's/#.*//' | sed 's/[[:space:]]*$//')
        prompt_groups_freq[$current_group]="$current_frequency"
      elif [[ "$line" =~ ^[[:space:]]*content: ]]; then
        # Start of content section
        in_content=true
        prompt_groups_content[$current_group]=""
      elif [[ $in_content == true && "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
        # Content line
        local prompt=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
        local current_content="${prompt_groups_content[$current_group]}"
        if [[ -z "$current_content" ]]; then
          prompt_groups_content[$current_group]="$prompt"
        else
          prompt_groups_content[$current_group]="$current_content|$prompt"
        fi
      fi
    fi
  done < "$config_file"
  
  # Export arrays for use by main script
  for group in "${!prompt_groups_freq[@]}"; do
    echo "PROMPT_FREQ_${group//[^a-zA-Z0-9]/_}=${prompt_groups_freq[$group]}"
    echo "PROMPT_CONTENT_${group//[^a-zA-Z0-9]/_}=${prompt_groups_content[$group]}"
  done
}

# Parse filtered appointments from YAML
gday_parse_filtered_appointments() {
  local config_file="$HOME/.config/gday/config.yml"
  local -a filtered_appointments_array
  local in_filtered_appointments=false
  
  while IFS= read -r line; do
    if [[ "$line" =~ ^filtered_appointments: ]]; then
      in_filtered_appointments=true
      filtered_appointments_array=()
    elif [[ $in_filtered_appointments == true && "$line" =~ ^[[:space:]]*-[[:space:]]*(.*) ]]; then
      local appointment=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
      filtered_appointments_array+=("$appointment")
    elif [[ "$line" =~ ^[[:alpha:]]+: ]] && [[ $in_filtered_appointments == true ]]; then
      # New section started, stop processing filtered appointments
      break
    fi
  done < "$config_file"
  
  # Join with pipe delimiter for awk processing
  local filtered_appointments_joined=""
  for appt in "${filtered_appointments_array[@]}"; do
    if [[ -z "$filtered_appointments_joined" ]]; then
      filtered_appointments_joined="$appt"
    else
      filtered_appointments_joined="$filtered_appointments_joined|$appt"
    fi
  done
  
  echo "$filtered_appointments_joined"
}

# Validate that configured calendars are accessible
gday_validate_calendars() {
  # Get available calendars - extract the entire calendar name, preserving spaces
  local available_calendars=$(gcalcli list --nocolor | awk 'NR > 1 {
    # Skip separator lines that contain only dashes/hyphens
    if ($0 ~ /^[- ]+$/) next;
    # Remove the first two columns (Owner and Access)
    $1=""; $2="";
    # Print the rest of the line (the calendar name)
    sub(/^[ \t]+/, "");
    print
  }')
  local missing_calendars=()
  local found=0

  echo "Checking configured calendars..."

  # Print table header
  echo "\n| Included? | Available Calendars              |"
  echo "|-----------|----------------------------------|"

  # Process each available calendar
  while IFS= read -r cal; do
    # Skip empty lines or lines containing only dashes/hyphens
    if [[ -n "$cal" && ! "$cal" =~ ^[-]+$ ]]; then
      # Check if calendar is in configured list
      local is_configured=false
      local is_accessible=false

      for config_cal in "${GCAL_CALENDARS[@]}"; do
        if [[ "$cal" == "$config_cal" ]]; then
          is_configured=true
          # Verify we can actually use it with gcalcli
          if gcalcli --cal "$cal" agenda "today" "today" --nocolor --no-military >/dev/null 2>&1; then
            is_accessible=true
            ((found++))
          else
            missing_calendars+=("$cal")
          fi
          break
        fi
      done

      # Format the table row
      local cal_status="🔲"
      if $is_configured && $is_accessible; then
        cal_status="✅"
      fi

      # Add padding to make calendar name fit nicely
      local padded_cal="$cal                                   "
      padded_cal="${padded_cal:0:34}"

      # Format the status with consistent spacing - center the emoji in 9 chars
      local formatted_status="    $cal_status    "
      formatted_status="${formatted_status:0:9}"

      echo "| $formatted_status | $padded_cal |"
    fi
  done <<< "$available_calendars"

  echo "\nValidation results:"
  if [[ ${#missing_calendars[@]} -gt 0 ]]; then
    echo "⚠️  The following calendars are configured but not usable:"
    printf "   - %s\n" "${missing_calendars[@]}"
    if [[ $found -eq 0 ]]; then
      echo "❌ No configured calendars were found. Exiting."
      return 1
    fi
  else
    echo "✅ All configured calendars found!"
  fi
  return 0
}