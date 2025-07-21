#!/bin/bash

# Banner display functionality for gday
# Version management and visual branding

# Helper function to show banner
gday_show_banner() {
  # Use semantic versioning: major.minor.patch
  local GDAY_BANNER="
    🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞
    🌞🌞🌞    gday Version 3.10.0    🌞🌞🌞
    🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞🌞


"
  echo -e "$GDAY_BANNER"
}