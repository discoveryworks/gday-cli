
  🔥 High Priority - Complete the Extraction:

  1. Create GitHub Repository
    - gh repo create gday-cli --public
    - Push the local gday-cli repository
    - Set up GitHub Actions for releases
  2. Update dot-rot Integration
    - Modify plugins/gday/gday.plugin.zsh to call external gday command
    - Add gday-cli installation to setup scripts
    - Test that your daily workflow continues seamlessly

  📦 Medium Priority - Distribution:

  3. Publish Homebrew Formula
    - Create actual GitHub release with tarball
    - Update Formula with correct SHA256
    - Submit to homebrew-core or create tap
  4. Test Installation Flow
    - Verify brew install gday works end-to-end
    - Test first-time user setup (gcalcli auth, config creation)

  🎯 Success Criteria Check:

  - GitHub repo created and accessible
  - dot-rot calls external gday seamlessly
  - Installable via brew install gday
  - New users can follow README to full setup