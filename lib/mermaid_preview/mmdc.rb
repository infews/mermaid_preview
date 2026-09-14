# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "tempfile"

module MermaidPreview
  # The mermaid-cli binary. Knows how to build its argv and how to tell a good
  # run from a bad one; knows nothing about where the SVG ends up.
  class Mmdc
    EXECUTABLE = "mmdc"

    # mmdc can exit 0 and still write nothing, so success means "there is an SVG".
    Result = Data.define(:ok, :output) do
      def ok? = ok
    end

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
      with_config do |config|
        output, status = Open3.capture2e(*argv(source, to, config))
        Result.new(ok: status.success? && !File.size?(to).nil?, output: output)
      end
    end

    private

    def argv(source, target, config)
      [EXECUTABLE, "-i", source, "-o", target, "-t", @theme, "-b", @background] +
        config_argv(config) + puppeteer_argv
    end

    def config_argv(config) = config ? ["-c", config] : []

    # The user's CSS goes in as mermaid's themeCSS rather than as -C. mermaid
    # scopes its theme to the diagram's id, so a bare `.node rect` rule always
    # loses to `#my-svg .node rect` however late it arrives; themeCSS gets the
    # same scoping and is emitted after the theme, which is what makes it win.
    #
    # Read fresh on every render, so editing the stylesheet takes effect without
    # a restart. The config only lives as long as the mmdc run.
    def with_config
      return yield nil unless @stylesheet

      Tempfile.create(["mmd-preview", ".json"]) do |file|
        file.write(JSON.generate(themeCSS: File.read(@stylesheet)))
        file.close
        yield file.path
      end
    end

    # Re-checked every render, so writing the config mid-session takes effect
    # without a restart.
    def puppeteer_argv
      File.file?(@puppeteer_config.to_s) ? ["-p", @puppeteer_config] : []
    end
  end
end
