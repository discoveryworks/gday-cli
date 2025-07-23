#!/bin/bash

# diagnose-config.sh - Diagnose issues in gday configuration
# This script helps identify problems in your ~/.config/gday/config.yml file

CONFIG_FILE="$HOME/.config/gday/config.yml"
EXAMPLE_CONFIG="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )/config.yml.example"

echo "🔍 gday Configuration Diagnostic Tool 🔍"
echo "========================================"
echo ""

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Configuration file not found at $CONFIG_FILE"
  echo "Suggestion: Copy the example config to this location:"
  echo "  mkdir -p ~/.config/gday"
  echo "  cp \"$EXAMPLE_CONFIG\" \"$CONFIG_FILE\""
  exit 1
fi

echo "✅ Found configuration file at $CONFIG_FILE"
echo ""

# Check for "Mind dump" text that could cause syntax errors
if grep -q "Mind dump" "$CONFIG_FILE"; then
  echo "⚠️  Found 'Mind dump' text in your config file which might cause syntax errors"

  # Show the line containing "Mind dump" with context
  echo ""
  echo "Here are the relevant lines:"
  echo "----------------------------"
  grep -A 3 -B 3 "Mind dump" "$CONFIG_FILE"
  echo "----------------------------"
  echo ""
  echo "Potential issue: The phrase 'Mind dump' appears to be causing a shell syntax error"
  echo "when the script tries to process it."
  echo ""
  echo "Suggestions:"
  echo "1. Make sure any 'Mind dump' text is properly quoted in the YAML file"
  echo "2. If it's in a prompt section, check that the entire prompt content is correctly formatted"
  echo "3. Try escaping any special characters with backslashes"
  echo "4. For testing, you can temporarily rename 'Mind dump' to 'Mind_dump' to see if that resolves the issue"
  echo ""
fi

# Check YAML structure
echo "Checking YAML structure..."
if command -v python3 >/dev/null 2>&1; then
  # Use Python to validate YAML if available
  python3 -c "
import sys
try:
    import yaml
    with open('$CONFIG_FILE', 'r') as f:
        yaml.safe_load(f)
    print('✅ YAML syntax is valid')
except ImportError:
    print('⚠️  Python yaml module not available for validation')
except Exception as e:
    print('❌ YAML syntax error:', e)
" 2>/dev/null || echo "⚠️  Could not validate YAML structure with Python"
else
  echo "⚠️  Python not available for YAML validation"
fi

echo ""
echo "Checking specific sections for issues..."

# Check calendars section
if ! grep -q "^calendars:" "$CONFIG_FILE"; then
  echo "⚠️  Missing 'calendars:' section or it's not at the root level"
fi

# Check prompts section
if ! grep -q "^prompts:" "$CONFIG_FILE"; then
  echo "⚠️  Missing 'prompts:' section or it's not at the root level"
fi

# Check filtered_appointments section
if ! grep -q "^filtered_appointments:" "$CONFIG_FILE"; then
  echo "⚠️  Missing 'filtered_appointments:' section or it's not at the root level"
fi

# Check for any arithmetic expressions
echo ""
echo "Looking for potential arithmetic expressions that might cause errors..."
grep -n "[^\\]\\$" "$CONFIG_FILE" || echo "✅ No suspicious $ characters found"
grep -n "[\\(\\)]" "$CONFIG_FILE" || echo "✅ No suspicious parentheses found"

echo ""
echo "Checking common syntax issues in prompt sections..."
grep -n "^[[:space:]]*-[[:space:]]*[^\"'].*:" "$CONFIG_FILE" || echo "✅ No unquoted keys found in lists"

echo ""
echo "Diagnostic Summary"
echo "=================="
echo "If you're seeing 'Mind dump: syntax error in expression' when running gday,"
echo "the issue is likely in your config file. Common causes include:"
echo ""
echo "1. Unquoted text containing special characters like parentheses, dollar signs, etc."
echo "2. Text that bash is trying to interpret as an arithmetic expression"
echo "3. Improperly formatted YAML (missing indentation, quotes, etc.)"
echo ""
echo "Suggestion: Make a backup of your config and try this fix:"
echo ""
echo "  cp \"$CONFIG_FILE\" \"${CONFIG_FILE}.backup\""
echo "  sed -i.bak 's/Mind dump/\"Mind dump\"/g' \"$CONFIG_FILE\""
echo ""
echo "If that doesn't work, you can try manually editing any lines containing 'Mind dump'"
echo "to ensure they're properly quoted and don't contain special characters that bash"
echo "might interpret as commands."
echo ""
echo "You can also temporarily replace your config with the example one to test:"
echo ""
echo "  cp \"$EXAMPLE_CONFIG\" \"$CONFIG_FILE\""
echo ""
echo "Remember to restore your backup afterward!"
