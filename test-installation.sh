#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Expected version
EXPECTED_VERSION="1.7.0"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_homebrew() {
    log "Testing Homebrew installation in clean macOS container..."
    
    # Use homebrew/brew image which has macOS + Homebrew pre-installed
    docker run --rm homebrew/brew:latest bash -c '
        set -e
        echo "=== Testing Homebrew gday installation ==="
        
        # Install gday
        echo "Installing gday via Homebrew..."
        brew install discoveryworks/gday-cli/gday --quiet
        
        # Test that gday is installed and accessible
        echo "Testing gday command..."
        which gday
        
        # Test version output
        echo "Testing version banner..."
        gday --help | head -5
        
        # Test version string specifically
        echo "Checking version string..."
        VERSION=$(gday --help | grep "gday Version" | sed "s/.*gday Version \([0-9.]*\).*/\1/")
        echo "Found version: $VERSION"
        
        if [ "$VERSION" = "'"$EXPECTED_VERSION"'" ]; then
            echo "✅ Version check passed: $VERSION"
        else
            echo "❌ Version check failed: expected '"$EXPECTED_VERSION"', got $VERSION"
            exit 1
        fi
        
        # Test that help shows all expected commands
        echo "Testing help output..."
        gday --help | grep -q "auth.*Re-authenticate" || exit 1
        gday --help | grep -q "later.*Later Today" || exit 1
        
        echo "✅ All Homebrew tests passed!"
    '
}

test_npm() {
    log "Testing npm installation in clean Node.js container..."
    warn "npm installation not yet implemented - placeholder for future"
    
    # Placeholder for future npm testing
    docker run --rm node:18-alpine sh -c '
        echo "=== Future npm test placeholder ==="
        echo "npm install -g gday-cli"
        echo "gday --help"
        echo "✅ npm test placeholder completed"
    '
}

main() {
    log "Starting gday-cli installation testing..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    case "${1:-all}" in
        homebrew|brew)
            test_homebrew
            ;;
        npm)
            test_npm
            ;;
        all)
            test_homebrew
            test_npm
            ;;
        *)
            echo "Usage: $0 [homebrew|npm|all]"
            echo "  homebrew    Test Homebrew installation only"
            echo "  npm         Test npm installation only (placeholder)"
            echo "  all         Test all installation methods (default)"
            exit 1
            ;;
    esac
    
    log "🎉 All installation tests completed successfully!"
}

main "$@"