# frozen_string_literal: true

require "json"

module MermaidPreview
  # What the tool needs before it can render, and what to tell you when it is
  # not there. Detects only: never installs, never writes. The remedy text is
  # the product here, so it is meant to be copied and pasted as-is.
  class Doctor
    MMDC_REMEDY = [
      "brew install mermaid-cli",
      "or: npm install -g @mermaid-js/mermaid-cli"
    ].freeze

    PUPPETEER_INSTALL = "npx -y puppeteer browsers install chrome"

    Finding = Data.define(:name, :ok, :detail, :remedy) do
      def ok? = ok
    end

    def self.examine = new.examine

    def examine = Diagnosis.new([mmdc_finding, browser_finding])

    private

    def mmdc_finding
      path = Executable.find(Mmdc::EXECUTABLE)
      return ok("mmdc", path) if path

      problem("mmdc", "not found on PATH", MMDC_REMEDY)
    end

    def browser_finding
      reach = configured_browser || env_browser || cached_browser
      return ok("browser", reach) if reach

      problem("browser", "mmdc has no browser to render with", browser_remedy)
    end

    def ok(name, detail) = Finding.new(name: name, ok: true, detail: detail, remedy: [])

    def problem(name, detail, remedy) = Finding.new(name: name, ok: false, detail: detail, remedy: remedy)

    # -- can mmdc reach a browser? ---------------------------------------------

    def configured_browser
      config = Paths.puppeteer_config
      "configured in #{config}" if File.file?(config)
    end

    def env_browser
      path = ENV["PUPPETEER_EXECUTABLE_PATH"]
      "PUPPETEER_EXECUTABLE_PATH=#{path}" if path && File.executable?(path)
    end

    def cached_browser
      path = Browsers.cached
      "puppeteer's own build: #{path}" if path
    end

    # -- and if it cannot ------------------------------------------------------

    def browser_remedy
      found = Browsers.installed
      found ? point_at(found) : install_a_browser
    end

    # The common case: a perfectly good browser is right there, and mmdc has no
    # way to know. Hand over the finished file rather than describing it.
    def point_at(path)
      ["#{File.basename(path)} is installed, but mmdc can't see it.",
        "Point it there — create #{Paths.puppeteer_config}:",
        "",
        *puppeteer_json(path).lines.map(&:chomp),
        "",
        "Or let puppeteer fetch its own browser:",
        PUPPETEER_INSTALL]
    end

    def install_a_browser
      ["No Chrome or Chromium found.",
        "Install Google Chrome, or let puppeteer fetch its own:",
        PUPPETEER_INSTALL]
    end

    def puppeteer_json(path)
      JSON.pretty_generate(executablePath: path, headless: "new", args: ["--font-render-hinting=none"])
    end

    # The report. Rendered without colour: it travels through `abort`, and half
    # of it is meant to be copied into a file.
    class Diagnosis
      HEADING = "mmd-preview: unmet dependencies"
      GUTTER = " " * 16

      def initialize(findings) = @findings = findings

      def ok? = @findings.all?(&:ok?)

      def to_s = ([HEADING, ""] + @findings.flat_map { |f| lines_for(f) }).join("\n")

      private

      def lines_for(finding)
        head = format("  %s %-11s %s", finding.ok? ? "✓" : "✗", finding.name, finding.detail)
        return [head] if finding.remedy.empty?

        [head, "", *finding.remedy.map { |line| line.empty? ? "" : GUTTER + line }, ""]
      end
    end
  end
end
