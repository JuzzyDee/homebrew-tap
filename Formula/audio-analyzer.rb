class AudioAnalyzer < Formula
  desc "MCP server that gives Claude the ability to hear music"
  homepage "https://github.com/JuzzyDee/audio-analyzer-rs"
  version "0.1.0"
  license :cannot_represent

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/JuzzyDee/audio-analyzer-rs/releases/download/v#{version}/audio-analyzer-aarch64-apple-darwin.tar.gz"
      sha256 "42190a7360ed3ac0aff9698f6450f6c9909118d7dcbecbdb3f57a42478d24b5c"
    else
      url "https://github.com/JuzzyDee/audio-analyzer-rs/releases/download/v#{version}/audio-analyzer-x86_64-apple-darwin.tar.gz"
      sha256 "897d1822ff5fa49dbb4311d6631f4fe788b556761b585ab1522149d500fd1bf8"
    end
  end

  def install
    bin.install "mcp-server" => "audio-analyzer-mcp"
    bin.install "cli" => "audio-analyzer"

    # Install a setup script that configures Claude Code and Desktop
    (bin / "audio-analyzer-setup").write <<~BASH
      #!/bin/bash
      set -e

      MCP_PATH="#{opt_bin}/audio-analyzer-mcp"
      ENTRY='{"command":"'"$MCP_PATH"'"}'

      setup_config() {
        local config_file="$1"
        local app_name="$2"
        local config_dir
        config_dir="$(dirname "$config_file")"

        if [ -f "$config_file" ]; then
          # Check if already configured
          if grep -q '"audio-analyzer"' "$config_file" 2>/dev/null; then
            echo "  $app_name: audio-analyzer already configured"
            return
          fi

          # File exists — patch it
          if grep -q '"mcpServers"' "$config_file" 2>/dev/null; then
            # mcpServers exists, add our entry
            ruby -rjson -e '
              c = JSON.parse(File.read("'"$config_file"'"))
              c["mcpServers"]["audio-analyzer"] = {"command" => "'"$MCP_PATH"'"}
              File.write("'"$config_file"'", JSON.pretty_generate(c) + "\\n")
            '
          else
            # No mcpServers key, add it
            ruby -rjson -e '
              c = JSON.parse(File.read("'"$config_file"'"))
              c["mcpServers"] = {"audio-analyzer" => {"command" => "'"$MCP_PATH"'"}}
              File.write("'"$config_file"'", JSON.pretty_generate(c) + "\\n")
            '
          fi
        else
          # File doesn't exist — create it
          mkdir -p "$config_dir"
          echo '{"mcpServers":{"audio-analyzer":'"$ENTRY"'}}' | ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))' > "$config_file"
        fi

        echo "  $app_name: configured successfully"
      }

      echo ""
      echo "Setting up audio-analyzer for Claude..."
      echo ""

      # Claude Code
      setup_config "$HOME/.claude/settings.json" "Claude Code"

      # Claude Desktop (only if the directory exists)
      DESKTOP_DIR="$HOME/Library/Application Support/Claude"
      if [ -d "$DESKTOP_DIR" ]; then
        setup_config "$DESKTOP_DIR/claude_desktop_config.json" "Claude Desktop"
      else
        echo "  Claude Desktop: not detected (skipped)"
      fi

      echo ""
      echo "Done! Restart Claude Code or Claude Desktop to start using audio-analyzer."
      echo "Just ask Claude to analyse any audio file — mp3, wav, flac, ogg, or aac."
      echo ""
    BASH

    chmod 0755, bin / "audio-analyzer-setup"
  end

  def post_install
    # Run the setup script automatically
    system bin / "audio-analyzer-setup"
  end

  def caveats
    <<~EOS
      To configure Claude Code and/or Claude Desktop, run:

        audio-analyzer-setup

      This is run automatically on install, but you can re-run it
      any time (e.g. after installing Claude Desktop).

      CLI usage:
        audio-analyzer /path/to/song.mp3

      To remove the MCP configuration on uninstall, delete the
      "audio-analyzer" entry from:
        Claude Code:    ~/.claude/settings.json
        Claude Desktop: ~/Library/Application Support/Claude/claude_desktop_config.json
    EOS
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/audio-analyzer 2>&1", 1)
  end
end
