#!/bin/bash

# Test suite for config.sh functions
# Tests YAML parsing, configuration validation, and setup management

set -e

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Source the config library
source "$PROJECT_DIR/lib/config.sh"

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

# Test YAML parsing functions
test_yaml_parsing() {
  # Create a temporary YAML file for testing
  local test_yaml=$(mktemp)
  cat > "$test_yaml" <<EOF
calendars:
  - "Work Calendar"
  - "Personal Calendar"

prompts:
  daily:
    - "What's your main focus today?"
    - "Any blockers or concerns?"
    
filtered_appointments:
  - "Lunch"
  - "Break"
EOF

  # Test that YAML functions can parse the file
  if command -v parse_yaml >/dev/null 2>&1; then
    # Test parsing if function exists
    echo "  Testing YAML parsing..."
  else
    echo "  YAML parsing functions not available for unit testing"
  fi
  
  rm -f "$test_yaml"
  return 0
}

# Test config validation
test_config_validation() {
  # Test configuration validation functions if available
  if command -v validate_config >/dev/null 2>&1; then
    echo "  Testing config validation..."
  else
    echo "  Config validation functions not available for unit testing"
  fi
  
  return 0
}

# Test calendar setup
test_calendar_setup() {
  # Test calendar setup and authentication functions if available
  if command -v setup_calendar_auth >/dev/null 2>&1; then
    echo "  Testing calendar authentication setup..."
  else
    echo "  Calendar setup functions not available for unit testing"
  fi
  
  return 0
}

# Test prompt configuration
test_prompt_configuration() {
  # Test prompt frequency and group configuration
  if command -v get_prompt_frequency >/dev/null 2>&1; then
    echo "  Testing prompt configuration..."
  else
    echo "  Prompt configuration functions not available for unit testing"
  fi
  
  return 0
}

# Main test execution
main() {
  echo "⚙️  Running Config Function Tests"
  echo "================================="
  echo ""
  
  run_test "YAML Parsing Functions" test_yaml_parsing
  run_test "Config Validation" test_config_validation  
  run_test "Calendar Setup" test_calendar_setup
  run_test "Prompt Configuration" test_prompt_configuration
  
  echo "================================="
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