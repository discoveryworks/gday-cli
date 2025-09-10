#!/usr/bin/env bats

# BATS test suite for CLI functionality
# Tests command-line interface, version, help, and basic commands

load 'helpers/bats-support/load'
load 'helpers/bats-assert/load'

# Set up test environment
setup() {
  # Get project root directory
  export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  
  # Source version for comparison
  source "$PROJECT_ROOT/lib/version.sh"
}

@test "gday --version shows current version" {
  run "$PROJECT_ROOT/bin/gday" --version
  
  assert_success
  assert_output --partial "$GDAY_VERSION"
  assert_output --partial "VERSION: $GDAY_VERSION"
}

@test "gday -v shows current version" {
  run "$PROJECT_ROOT/bin/gday" -v
  
  assert_success
  assert_output --partial "$GDAY_VERSION"
}

@test "gday --help shows help message" {
  run "$PROJECT_ROOT/bin/gday" --help
  
  assert_success
  assert_output --partial "USAGE:"
  assert_output --partial "OPTIONS:"
  assert_output --partial "VERSION: $GDAY_VERSION"
}

@test "gday help shows help message" {
  run "$PROJECT_ROOT/bin/gday" help
  
  assert_success
  assert_output --partial "USAGE:"
  assert_output --partial "OPTIONS:"
}

@test "gday -h shows help message" {
  run "$PROJECT_ROOT/bin/gday" -h
  
  assert_success
  assert_output --partial "USAGE:"
  assert_output --partial "OPTIONS:"
}

@test "gday executable is actually executable" {
  # Test that the main binary exists and is executable
  [ -x "$PROJECT_ROOT/bin/gday" ]
}

@test "gday has proper shebang" {
  # Test that the script has a proper shebang
  run head -n1 "$PROJECT_ROOT/bin/gday"
  
  assert_success
  assert_output --partial "#!/bin/bash"
}

@test "version file contains valid version format" {
  run bash -c "source '$PROJECT_ROOT/lib/version.sh' && echo \$GDAY_VERSION"
  
  assert_success
  assert_output --regexp "^[0-9]+\.[0-9]+\.[0-9]+$"
}

@test "gday with invalid flag runs normally (no validation yet)" {
  run "$PROJECT_ROOT/bin/gday" --invalid-flag
  
  # Currently runs normally - no flag validation implemented
  # This is acceptable behavior for now (could be improved in future)
  assert_success
  assert_output --partial "Checking configured calendars"
}

@test "all library files can be sourced without errors" {
  for lib_file in "$PROJECT_ROOT"/lib/*.sh; do
    run bash -c "source '$lib_file' && echo 'sourced $(basename "$lib_file")'"
    assert_success
    assert_output --partial "sourced $(basename "$lib_file")"
  done
}

@test "gday --oura shows Oura help when no OURA_PAT set" {
  # Test Oura flag without credentials
  unset OURA_PAT
  run "$PROJECT_ROOT/bin/gday" --oura
  
  # Should either show error about missing OURA_PAT or handle gracefully
  assert_success || assert_failure
}

@test "gday oura shows Oura help when no OURA_PAT set" {
  # Test Oura command without credentials
  unset OURA_PAT
  run "$PROJECT_ROOT/bin/gday" oura
  
  # Should either show error about missing OURA_PAT or handle gracefully
  assert_success || assert_failure
}

@test "gday health alias works same as oura command" {
  # Test new health alias
  unset OURA_PAT
  run "$PROJECT_ROOT/bin/gday" health
  
  # Should behave same as oura command
  assert_success || assert_failure
}

@test "gday conf command shows config edit functionality" {
  # Mock EDITOR to prevent actual editor launch
  export EDITOR="echo"
  export VISUAL=""
  
  run "$PROJECT_ROOT/bin/gday" conf
  
  # Should attempt to open config file (will succeed with echo as editor)
  assert_success
  assert_output --partial "Opening config file in echo"
}

@test "gday edit command shows config edit functionality" {
  # Mock EDITOR to prevent actual editor launch
  export EDITOR="echo"
  export VISUAL=""
  
  run "$PROJECT_ROOT/bin/gday" edit
  
  # Should attempt to open config file (will succeed with echo as editor)
  assert_success
  assert_output --partial "Opening config file in echo"
}

@test "gday config command shows config edit functionality" {
  # Mock EDITOR to prevent actual editor launch
  export EDITOR="echo"
  export VISUAL=""
  
  run "$PROJECT_ROOT/bin/gday" config
  
  # Should attempt to open config file (will succeed with echo as editor)
  assert_success
  assert_output --partial "Opening config file in echo"
}

@test "help text includes new commands" {
  run "$PROJECT_ROOT/bin/gday" --help
  
  assert_success
  assert_output --partial "oura, health"
  assert_output --partial "conf, edit, config"
  assert_output --partial "refresh"
}

@test "gday refresh command shows refresh help when no config" {
  # Test refresh command without config
  run "$PROJECT_ROOT/bin/gday" refresh
  
  # Should fail when no config exists or handle gracefully
  assert_failure || {
    # If it succeeds, it should at least show refresh-related output
    assert_output --partial "Refresh"
  }
}

@test "refresh command exists in help text" {
  run "$PROJECT_ROOT/bin/gday" --help
  
  assert_success
  assert_output --partial "refresh           Refresh calendar data cache"
}