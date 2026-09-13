# frozen_string_literal: true

require "optparse"

module MermaidPreview
  # Turns ARGV into Options. Raises instead of aborting, so exe/mmd-preview owns
  # every exit path and the parser stays testable.
  class CLI
    BANNER = "usage: mmd-preview DIAGRAM.mmd [STYLE.css] [options]"

    def self.parse(argv) = new.parse(argv)

    def initialize
      @stylesheet = nil
      @theme = "default"
      @background = "transparent"
      @port = 0
      @browser_app = nil
      @open_browser = true
    end

    def parse(argv)
      positional = parser.parse(argv)
      diagram = positional.shift
      stylesheet = @stylesheet || positional.shift

      fail UsageError, "unexpected argument: #{positional.first}" unless positional.empty?
      fail UsageError, parser.to_s if diagram.nil?

      build(diagram, stylesheet)
    rescue OptionParser::ParseError => e
      fail UsageError, "#{e.message}\n#{parser}"
    end

    private

    def build(diagram, stylesheet)
      Options.new(
        diagram: readable!(diagram),
        stylesheet: stylesheet && readable!(stylesheet),
        theme: @theme, background: @background, port: @port,
        browser_app: @browser_app, open_browser: @open_browser
      )
    end

    def readable!(path)
      fail UsageError, "no such file: #{path}" unless File.file?(path)

      File.expand_path(path)
    end

    def parser
      @parser ||= OptionParser.new do |o|
        o.banner = BANNER
        o.on("-c", "--css FILE", "stylesheet (same as the second positional argument)") { @stylesheet = it }
        o.on("-t", "--theme NAME", THEMES, "mermaid theme: #{THEMES.join(" | ")}") { @theme = it }
        o.on("-b", "--background COLOR", "SVG background (default: transparent)") { @background = it }
        o.on("-p", "--port N", Integer, "port to serve on (default: ephemeral)") { @port = it }
        o.on("-B", "--browser NAME", 'open in a specific app, e.g. "Google Chrome"') { @browser_app = it }
        o.on("-n", "--no-open", "don't open a browser, just print the URL") { @open_browser = false }
        o.on("-h", "--help", "show this message") { fail HelpRequested, o.to_s }
      end
    end
  end
end
