class Gday < Formula
  desc "Personal calendar and task management CLI that integrates Google Calendar with daily workflows"
  homepage "https://github.com/jpb/gday-cli"
  url "https://github.com/jpb/gday-cli/archive/v3.10.0.tar.gz"
  sha256 "" # Will be filled when we create actual release
  license "MIT"
  version "3.10.0"

  depends_on "python3"
  
  # gcalcli is installed via pip, not Homebrew
  def install
    bin.install "bin/gday"
    lib.install Dir["lib/*"]
    doc.install "README.md"
    (etc/"gday").install "config.yml.example"
    
    # Create a wrapper script that ensures the lib directory is found
    (bin/"gday").unlink
    (bin/"gday").write <<~EOS
      #!/bin/bash
      export GDAY_LIB_DIR="#{lib}"
      exec "#{libexec}/gday" "$@"
    EOS
    
    libexec.install "bin/gday"
    chmod 0755, bin/"gday"
  end

  def post_install
    puts <<~EOS
      gday has been installed!
      
      Next steps:
      1. Install gcalcli: pip3 install gcalcli
      2. Set up Google Calendar auth: gday auth
      3. Create config file: cp #{etc}/gday/config.yml.example ~/.config/gday/config.yml
      4. Edit ~/.config/gday/config.yml with your calendar names
      5. Run: gday
      
      See the README for detailed setup instructions.
    EOS
  end

  test do
    # Test that the binary exists and shows help
    assert_match "gday - Personal calendar and task management tool", shell_output("#{bin}/gday --help")
    assert_match "VERSION: 3.10.0", shell_output("#{bin}/gday --help")
  end
end