# Release Process

This document outlines the release process for gday-cli.

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
git commit -m "chore: Bump version to vx.y.z and add release notes"
```

### 3. Create GitHub Release

```bash
# Push changes
git push origin main

# Tag the release  
git tag vx.y.z
git push origin vx.y.z

# Create GitHub release with notes
gh release create vx.y.z --title "gday-cli vx.y.z - Title" --notes-file docs/releases/vx.y.z.md
```

### 4. Update Homebrew Formula

```bash
# Clone the tap repository
git clone https://github.com/discoveryworks/homebrew-gday-cli.git /tmp/homebrew-update

# Download and get SHA256 of new release
curl -L https://github.com/discoveryworks/gday-cli/archive/vx.y.z.tar.gz -o /tmp/vx.y.z.tar.gz
shasum -a 256 /tmp/vx.y.z.tar.gz

# Update gday.rb with:
# - New version number
# - New URL
# - New SHA256  
# - Updated test version assertion

# Commit and push
git -C /tmp/homebrew-update add gday.rb
git -C /tmp/homebrew-update commit -m "Update gday formula to vx.y.z"  
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

## Release Notes Format

Keep release notes concise and user-focused:

- **What's New** - New features and improvements
- **What's Fixed** - Bug fixes with before/after examples  
- **Migration Notes** - Breaking changes and upgrade steps

Example structure:
```markdown
# gday-cli vx.y.z - Brief Description

Brief summary sentence.

## What's New/Fixed

### 🎯 **Feature Name**
- Bullet point description
- User-visible impact

**Before:**
```
example of old behavior
```

**After:**  
```
example of new behavior
```
```

## Troubleshooting

### Common Issues

**Homebrew formula update fails:**
- Ensure SHA256 is correct
- Check that GitHub release exists and is public
- Verify tap repository permissions

**Version doesn't update:**
- Check both `lib/version.sh` and `package.json` are updated
- Ensure all changes are committed before tagging
- Clear any local caches: `brew cleanup`

**Tests fail after version bump:**
- Update any version assertions in test files
- Verify no hardcoded version strings elsewhere