# Release Process

This document outlines the complete release process for gday-cli, including Homebrew formula updates.

## Version Bumping Strategy

Follow semantic versioning (semver):
- **Major (x.0.0)**: Breaking changes, API changes  
- **Minor (1.x.0)**: New features, significant enhancements
- **Patch (1.6.x)**: Bug fixes, small improvements

## Release Steps

### 1. Prepare the Release

```bash
# Ensure all tests pass
npm test

# Update version in both files
# - lib/version.sh: GDAY_VERSION="x.y.z"  
# - package.json: "version": "x.y.z"

# Create release notes
# - docs/releases/vx.y.z.md following existing format
```

### 2. Commit Version Changes

```bash
git add lib/version.sh package.json docs/releases/vx.y.z.md
git commit -m "feat: Release vx.y.z with [brief summary]

[Commit message following conventional commits format]

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### 3. Create GitHub Release

```bash
# Push changes
git push origin main

# Tag the release  
git tag vx.y.z
git push origin vx.y.z

# Create GitHub release with notes
gh release create vx.y.z --title "gday-cli vx.y.z - [Brief Title]" --notes-file docs/releases/vx.y.z.md
```

### 4. Update Homebrew Formula (REQUIRED)

```bash
# Download and get SHA256 of new release
curl -L https://github.com/discoveryworks/gday-cli/archive/vx.y.z.tar.gz -o /tmp/vx.y.z.tar.gz
shasum -a 256 /tmp/vx.y.z.tar.gz

# Clone the tap repository
git clone https://github.com/discoveryworks/homebrew-gday-cli.git /tmp/homebrew-update

# Update gday.rb with:
# - New version number: version "x.y.z"
# - New URL: url "https://github.com/discoveryworks/gday-cli/archive/vx.y.z.tar.gz"
# - New SHA256: sha256 "[new_hash]"
# - Updated test version assertion: assert_match "VERSION: x.y.z"

# Commit and push
git -C /tmp/homebrew-update add gday.rb
git -C /tmp/homebrew-update commit -m "Update gday formula to vx.y.z

[Brief description of changes]

Release: https://github.com/discoveryworks/gday-cli/releases/tag/vx.y.z"
git -C /tmp/homebrew-update push origin main
```

### 5. Verify Release

```bash
# Test Homebrew installation
brew update
brew upgrade discoveryworks/gday-cli/gday
gday --version  # Should show new version

# Verify GitHub release page
# Check that release notes are correct
```

## Release Checklist

- [ ] All tests passing (`npm test`)
- [ ] Version updated in `lib/version.sh` and `package.json`
- [ ] Release notes created in `docs/releases/vx.y.z.md`
- [ ] Changes committed and pushed
- [ ] Git tag created and pushed
- [ ] GitHub release created
- [ ] **Homebrew formula updated and pushed**
- [ ] Homebrew installation tested and working

## Release Notes Format

Keep release notes concise and user-focused:

```markdown
# gday-cli vx.y.z Release Notes

## New Features

### Command/Feature Name
- Brief description of what's new
- User-visible impact

### Enhanced Feature Name  
- Description of improvements
- Before/after comparison if helpful

## Improvements
- Documentation updates
- Test coverage improvements
- Performance enhancements

## Testing
- New test coverage areas
- Updated test infrastructure

---

**Full Changelog**: https://github.com/discoveryworks/gday-cli/compare/vx.y.z-1...vx.y.z
```

## Troubleshooting

### Common Issues

**Homebrew formula update fails:**
- Ensure SHA256 is correct (run `shasum -a 256` on downloaded archive)
- Check that GitHub release exists and is public
- Verify tap repository permissions

**Version doesn't update:**
- Check both `lib/version.sh` and `package.json` are updated
- Ensure all changes are committed before tagging
- Clear any local caches: `brew cleanup`

**Tests fail after version bump:**
- Update any version assertions in test files
- Update `test-installation.sh` expected version
- Verify no hardcoded version strings elsewhere

## Important Notes

- **Always update Homebrew formula** - This is not optional, users depend on it
- Homebrew is the primary distribution method for macOS users
- Formula updates should happen immediately after GitHub release
- Test the Homebrew installation before considering release complete