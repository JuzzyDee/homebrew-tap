class AudioAnalyzer < Formula
  desc "MCP server that gives Claude the ability to hear music"
  homepage "https://github.com/JuzzyDee/audio-analyzer-rs"
  version "0.4.0"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/JuzzyDee/audio-analyzer-rs/releases/download/v#{version}/audio-analyzer-aarch64-apple-darwin.tar.gz"
      sha256 "ccf28b2de8d4b85e42e28b83f94523cfd56f59676a50e48658164bfd69cf2285"
    else
      url "https://github.com/JuzzyDee/audio-analyzer-rs/releases/download/v#{version}/audio-analyzer-x86_64-apple-darwin.tar.gz"
      sha256 "95e8cf0abc5d9d2feb42653cf097dc5f53afe98d6031b2061f4e738e199522a6"
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
      ENTRY='"{"command":"'"$MCP_PATH"'"}"'

      setup_config() {
        local config_file="$1"
        local app_name="$2"
        local config_dir
        config_dir="$(dirname "$config_file")"

        if [ -f "$config_file" ]; then
          if grep -q audio-analyzer "$config_file" 2>/dev/null; then
            echo "  $app_name: audio-analyzer already configured"
            return
          fi

          if grep -q mcpServers "$config_file" 2>/dev/null; then
            ruby -rjson -e '
              c = JSON.parse(File.read("'"$config_file"'"))
              c["mcpServers"]["audio-analyzer"] = {"command" => "'"$MCP_PATH"'"}
              File.write("'"$config_file"'", JSON.pretty_generate(c) + "\n")
            '
          else
            ruby -rjson -e '
              c = JSON.parse(File.read("'"$config_file"'"))
              c["mcpServers"] = {"audio-analyzer" => {"command" => "'"$MCP_PATH"'"}}
              File.write("'"$config_file"'", JSON.pretty_generate(c) + "\n")
            '
          fi
        else
          mkdir -p "$config_dir"
          echo '{"mcpServers":{"audio-analyzer":'"$ENTRY"'}}' | ruby -rjson -e 'puts JSON.pretty_generate(JSON.parse(STDIN.read))' > "$config_file"
        fi

        echo "  $app_name: configured successfully"
      }

      echo ""
      echo "Setting up audio-analyzer for Claude..."
      echo ""

      setup_config "$HOME/.claude/settings.json" "Claude Code"

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

  def caveats
    <<~EOS
      To configure Claude Code and/or Claude Desktop, run:

        audio-analyzer-setup

      This auto-detects which apps you have and patches their config files.
      You can re-run it any time (e.g. after installing Claude Desktop).

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
