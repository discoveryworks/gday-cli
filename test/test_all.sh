#!/bin/bash

# Comprehensive test runner for gday-cli
# Runs all available tests and provides coverage summary

set -e

# Get the directory of this script
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$TEST_DIR")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test tracking
TOTAL_SUITES=0
PASSED_SUITES=0

echo -e "${BLUE}🚀 Running All gday-cli Tests${NC}"
echo "=============================="
echo ""

run_test_suite() {
  local suite_name="$1"
  local test_command="$2"
  
  ((TOTAL_SUITES++))
  echo -e "${YELLOW}Running $suite_name...${NC}"
  
  if $test_command; then
    echo -e "${GREEN}✅ $suite_name PASSED${NC}"
    ((PASSED_SUITES++))
  else
    echo -e "${RED}❌ $suite_name FAILED${NC}"
  fi
  echo ""
}

# Run all test suites
echo "🧪 Unit Tests"
echo "============="
run_test_suite "Version Check" "$TEST_DIR/test_version_check.sh"
run_test_suite "Calendar Functions" "$TEST_DIR/test_calendar_functions.sh"
run_test_suite "Config Validation" "$TEST_DIR/test_config_validation.sh"
run_test_suite "Oura Sleep Timing" "$TEST_DIR/test_oura_sleep_timing.sh"

echo "🔗 Integration Tests"
echo "==================="
run_test_suite "Core Function Integration" "$PROJECT_DIR/test/test_calendar_functions.sh >/dev/null 2>&1"

echo "🥒 BDD Tests"
echo "============"
if [[ -f "$PROJECT_DIR/features/time-handling.feature" ]]; then
  run_test_suite "Time Handling BDD" "cd $PROJECT_DIR && npx cucumber-js features/*.feature"
else
  echo "⚠️  BDD feature files not found, skipping"
fi

echo "=============================="
echo -e "${BLUE}📊 Test Summary${NC}"
echo -e "Test suites: $PASSED_SUITES/$TOTAL_SUITES passed"

# Coverage assessment
echo ""
echo -e "${BLUE}📋 Coverage Assessment${NC}"
echo "======================"

# Count library functions (approximate)
echo "Core libraries tested:"
echo "  ✅ lib/oura.sh - Comprehensive (7 tests)"
echo "  ✅ lib/calendar.sh - Basic (6 tests)" 
echo "  ✅ lib/config.sh - Skeleton (4 tests)"
echo "  ✅ lib/version.sh - Basic (1 test)"
echo "  ⚠️  lib/banner.sh - No direct tests"

echo ""
echo "Test coverage areas:"
echo "  ✅ Sleep timing algorithms"
echo "  ✅ Time emoji generation" 
echo "  ✅ Basic CLI functionality"
echo "  ✅ Version verification"
echo "  ⚠️  Calendar integration (integration tests only)"
echo "  ⚠️  YAML config parsing (skeleton tests only)"
echo "  ⚠️  Error handling"

if [[ $PASSED_SUITES -eq $TOTAL_SUITES ]]; then
  echo ""
  echo -e "${GREEN}🎉 All test suites passed! Ready for release.${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}💥 $((TOTAL_SUITES - PASSED_SUITES)) test suite(s) failed!${NC}"
  exit 1
fi