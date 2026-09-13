# frozen_string_literal: true

require "fileutils"
require "open3"

module MermaidPreview
  # The mermaid-cli binary. Knows how to build its argv and how to tell a good
  # run from a bad one; knows nothing about where the SVG ends up.
  class Mmdc
    EXECUTABLE = "mmdc"
    INSTALL_HINT = "run mmd-preview-init"

    # mmdc can exit 0 and still write nothing, so success means "there is an SVG".
    Result = Data.define(:ok, :output) do
      def ok? = ok
    end

    def self.available! = Executable.find!(EXECUTABLE, hint: INSTALL_HINT)

    def initialize(theme:, background:, stylesheet: nil, puppeteer_config: Paths.puppeteer_config)
      @theme = theme
      @background = background
      @stylesheet = stylesheet
      @puppeteer_config = puppeteer_config
    end

    # Clears the target first so "there is an SVG" can only mean this run wrote
    # one, rather than resting on a caller having tidied up after the last.
    def render(source, to:)
      FileUtils.rm_f(to)
      output, status = Open3.capture2e(*argv(source, to))
      Result.new(ok: status.success? && !File.size?(to).nil?, output: output)
    end

    private

    def argv(source, target)
      [EXECUTABLE, "-i", source, "-o", target, "-t", @theme, "-b", @background] + stylesheet_argv + puppeteer_argv
    end

    def stylesheet_argv = @stylesheet ? ["-C", @stylesheet] : []

    # Re-checked every render: mmd-preview-init may write it while we're running.
    def puppeteer_argv
      File.file?(@puppeteer_config.to_s) ? ["-p", @puppeteer_config] : []
    end
  end
end
