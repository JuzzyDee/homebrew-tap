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
  end

  def post_install
    configure_claude_code
    configure_claude_desktop
  end

  def configure_claude_code
    config_dir = Pathname.new(Dir.home) / ".claude"
    config_file = config_dir / "settings.json"
    server_path = (bin / "audio-analyzer-mcp").to_s

    patch_mcp_config(config_file, config_dir, server_path, "Claude Code")
  end

  def configure_claude_desktop
    config_dir = Pathname.new(Dir.home) / "Library" / "Application Support" / "Claude"
    config_file = config_dir / "claude_desktop_config.json"
    server_path = (bin / "audio-analyzer-mcp").to_s

    # Only configure if Claude Desktop appears to be installed
    return unless config_dir.directory?

    patch_mcp_config(config_file, config_dir, server_path, "Claude Desktop")
  end

  def patch_mcp_config(config_file, config_dir, server_path, app_name)
    require "json"

    config = if config_file.exist?
      begin
        JSON.parse(config_file.read)
      rescue JSON::ParserError
        ohai "Could not parse existing #{app_name} config, skipping auto-setup"
        return
      end
    else
      {}
    end

    config["mcpServers"] ||= {}

    # Don't overwrite if already configured
    if config["mcpServers"]["audio-analyzer"]
      ohai "#{app_name}: audio-analyzer already configured"
      return
    end

    config["mcpServers"]["audio-analyzer"] = {
      "command" => server_path
    }

    config_dir.mkpath
    config_file.write(JSON.pretty_generate(config) + "\n")

    ohai "#{app_name}: audio-analyzer configured at #{config_file}"
  end

  def caveats
    <<~EOS
      The audio-analyzer MCP server has been installed and configured.

      CLI usage:
        audio-analyzer /path/to/song.mp3

      MCP server:
        The server has been automatically configured for any detected
        Claude applications. Restart Claude Code or Claude Desktop
        to start using it.

        Just ask Claude to analyse an audio file and it will use the
        audio-analyzer tools automatically.

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
